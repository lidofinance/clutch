#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Reconcile seven captured public fills against pinned CoW fee/accounting rules."""
import copy
from fractions import Fraction
import json
from pathlib import Path
import unittest

FIXTURE = Path(__file__).parent / 'fixtures/sepolia-protocol-fees.json'


def floor(value):
    return value.numerator // value.denominator


def ceil_ratio(numerator, denominator):
    return (numerator + denominator - 1) // denominator


def reconcile(case):
    order, trade = case['order'], case['trade']
    buy = order['kind'] == 'buy'
    sell_token, buy_token = trade['sellToken'].lower(), trade['buyToken'].lower()
    tokens, prices = [x.lower() for x in case['tokens']], case['prices']
    si, bi = case['tradeIndices']
    # These captured transactions list uniform prices first, then custom prices.
    assert len(tokens) == 4 and set(tokens[:2]) == {sell_token, buy_token}
    assert [si, bi] == [2, 3] and tokens[si] == sell_token and tokens[bi] == buy_token
    usi, ubi = tokens[:2].index(sell_token), tokens[:2].index(buy_token)
    assert int(order['feeAmount']) == trade['feeAmount'] == 0
    assert case['apiSellAmountBeforeFees'] == trade['sellAmount'] - trade['feeAmount']
    if buy:
        assert trade['sellAmount'] == trade['buyAmount'] * prices[bi] // prices[si]
    else:
        assert trade['buyAmount'] == ceil_ratio(trade['sellAmount'] * prices[si], prices[bi])
    improvement, volume = case['fees']
    policy = improvement['policy']['priceImprovement']
    rate = Fraction(str(volume['policy']['volume']['factor']))
    cap, share = Fraction(str(policy['maxVolumeFactor'])), Fraction(str(policy['factor']))
    net = trade['sellAmount'] if buy else trade['buyAmount']
    volume_fee = floor(net * rate / (1 + rate if buy else 1 - rate))
    after_improvement = net - volume_fee if buy else net + volume_fee
    q = {k: int(v) for k, v in policy['quote'].items()}
    if buy:
        limit = min(int(order['sellAmount']), (q['sellAmount'] + q['fee']) * int(order['buyAmount']) // q['buyAmount'])
        reference = limit * trade['buyAmount'] // int(order['buyAmount'])
        surplus = max(0, reference - after_improvement)
    else:
        quote_buy = q['buyAmount'] - q['fee'] * q['buyAmount'] // q['sellAmount']
        limit = max(int(order['buyAmount']), quote_buy * int(order['sellAmount']) // q['sellAmount'])
        reference = ceil_ratio(limit * trade['sellAmount'], int(order['sellAmount']))
        surplus = max(0, after_improvement - reference)
    surplus_fee = floor(surplus * share / (1 - share))
    cap_fee = floor(after_improvement * cap / (1 + cap if buy else 1 - cap))
    improvement_fee = min(surplus_fee, cap_fee)
    expected = [improvement_fee, volume_fee]
    assert expected == [int(f['amount']) for f in case['fees']]
    surplus_token = sell_token if buy else buy_token
    assert all(f['token'].lower() == surplus_token for f in case['fees'])
    protocol_fee = sum(expected)
    uniform = (trade['buyAmount'] * prices[ubi] // prices[usi] if buy
               else ceil_ratio(trade['sellAmount'] * prices[usi], prices[ubi]))
    total_fee = net - uniform if buy else uniform - net
    network_fee = total_fee - protocol_fee
    assert network_fee >= 0
    settlement = case['settlement']
    def flow(token, sender=None, receiver=None):
        return sum(x['amount'] for x in case['transfers'] if x['token'] == token
                   and (sender is None or x['from'] == sender)
                   and (receiver is None or x['to'] == receiver))
    owner, receiver = trade['owner'].lower(), order['receiver'].lower()
    assert flow(sell_token, owner, settlement) == trade['sellAmount']
    assert flow(buy_token, settlement, receiver) == trade['buyAmount']
    external_sell = flow(sell_token, settlement)
    external_buy = flow(buy_token, receiver=settlement)
    slippage = uniform - external_sell if buy else external_buy - uniform
    surplus_delta = (flow(surplus_token, receiver=settlement)
                     - flow(surplus_token, sender=settlement))
    assert surplus_delta == protocol_fee + network_fee + slippage
    other_delta = (external_buy - trade['buyAmount'] if buy
                   else trade['sellAmount'] - external_sell)
    for token, (before, after) in case['blockSettlementBalances'].items():
        assert after - before == case['blockLedgerDeltas'][token]
        transaction_delta = flow(token, receiver=settlement) - flow(token, sender=settlement)
        assert transaction_delta + case['otherTransactionsLedgerDeltas'][token] == after - before
    return {'branch': 'cap' if cap_fee < surplus_fee else 'surplus',
            'protocolFee': protocol_fee, 'networkFee': network_fee,
            'surplusTokenBufferDelta': surplus_delta, 'slippage': slippage,
            'otherTokenBufferDelta': other_delta}


class PublicProtocolFeeAccounting(unittest.TestCase):
    def setUp(self):
        self.cases = json.loads(FIXTURE.read_text())['cases']

    def test_sell_partial_surplus_branch_and_buy_cap_branch(self):
        results = [reconcile(c) for c in self.cases]
        self.assertEqual(len(results), 7)
        self.assertEqual([r['branch'] for r in results[:2]], ['surplus', 'cap'])

    def test_each_reported_fee_is_checked_independently(self):
        for case in self.cases:
            for fee in range(2):
                with self.subTest(case=case['name'], fee=fee):
                    changed = copy.deepcopy(case)
                    changed['fees'][fee]['amount'] = str(int(changed['fees'][fee]['amount']) + 1)
                    with self.assertRaises(AssertionError): reconcile(changed)

    def test_custom_price_indices_cannot_be_replaced_by_uniform_indices(self):
        for case in self.cases:
            changed = copy.deepcopy(case); changed['tradeIndices'] = [0, 1]
            with self.assertRaises(AssertionError): reconcile(changed)

    def test_missing_receiver_transfer_is_rejected(self):
        for case in self.cases:
            changed = copy.deepcopy(case)
            changed['transfers'] = [x for x in changed['transfers'] if x['to'] != changed['order']['receiver'].lower()]
            with self.assertRaises(AssertionError): reconcile(changed)

    def test_full_block_balance_mismatch_is_rejected(self):
        for case in self.cases:
            changed = copy.deepcopy(case)
            token = next(iter(changed['blockLedgerDeltas']))
            changed['blockLedgerDeltas'][token] += 1
            with self.assertRaises(AssertionError): reconcile(changed)

    def test_changed_external_transfer_cannot_be_hidden_as_slippage(self):
        for case in self.cases:
            changed = copy.deepcopy(case)
            transfer = next(x for x in changed['transfers'] if x['from'] == changed['settlement']
                            and x['to'] != changed['order']['receiver'].lower())
            transfer['amount'] += 1
            with self.assertRaises(AssertionError): reconcile(changed)


if __name__ == '__main__':
    unittest.main()
