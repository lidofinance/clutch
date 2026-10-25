#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Regression from captured public quote 1723884 and CoW's feeAmount=0 sell rule."""
import copy
import unittest
from sepolia_cow_order import sell_order


class SellQuoteTest(unittest.TestCase):
    def setUp(self):
        # Captured API response: sellAmountBeforeFee was 10000000000000000.
        self.quote = {
            "sellToken": "0xfff9976782d46cc05630d1f6ebab18b2324d6b14",
            "buyToken": "0x1c7d4b196cb0c7b01d743fbc6116a902379c7238",
            "receiver": "0x464f188165bcbe8f7fb3776c10e7b185963922ae",
            "sellAmount": "9940004900000000", "buyAmount": "384612077",
            "validTo": 1792868847, "appData": "0x" + "00" * 32,
            "feeAmount": "59995100000000", "kind": "sell", "partiallyFillable": False,
            "sellTokenBalance": "erc20", "buyTokenBalance": "erc20",
            "signingScheme": "presign", "gasAmount": "599951",
        }

    def test_captured_sell_quote_preserves_requested_total_and_minimum_buy(self):
        original = copy.deepcopy(self.quote)
        order = sell_order(self.quote)
        self.assertEqual(order["sellAmount"], "10000000000000000")
        self.assertEqual(order["feeAmount"], "0")
        self.assertEqual(order["buyAmount"], "384612077")
        self.assertEqual(self.quote, original)
        self.assertNotIn("gasAmount", order)
        self.assertNotIn("signingScheme", order)

    def test_recovery_receiver_and_zero_quote_fee_are_preserved(self):
        self.quote["receiver"] = "0x23fD73dBaA3A5EcE6d388f8f7C0022a869826061"
        self.quote["feeAmount"] = "0"
        order = sell_order(self.quote)
        self.assertEqual(order["receiver"], self.quote["receiver"])
        self.assertEqual(order["sellAmount"], self.quote["sellAmount"])

    def test_buy_quote_requires_its_own_conversion(self):
        self.quote["kind"] = "buy"
        with self.assertRaisesRegex(ValueError, "sell quote"):
            sell_order(self.quote)


if __name__ == "__main__":
    unittest.main()
