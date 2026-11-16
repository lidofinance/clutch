#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Offline checks for the Sepolia runners."""
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from sepolia_test_current import usdc_approval_state
from sepolia_rehearse import validate_drills


def suite(passed, summary=None):
    names = [f"test_{i}" for i in range(passed)]
    return "\n".join(f"[PASS] {name}() (gas: 123)" for name in names) + "\nSuite result: " + (summary or f"ok. {passed} passed; 0 failed; 0 skipped")


class UsdcApprovalHistory(unittest.TestCase):
    def setUp(self):
        fixture = Path(__file__).parent / "fixtures/sepolia-usdc-allowance.json"
        self.fixture = json.loads(fixture.read_text())

    def logs(self, method, params):
        if method == "eth_getTransactionByHash":
            return self.fixture["transactions"][params[0]]
        self.assertEqual(method, "eth_getLogs")
        query = params[0]
        return [log for log in self.fixture["logs"]
                if log["address"].lower() == query["address"].lower()
                and int(query["fromBlock"], 16) <= int(log["blockNumber"], 16) <= int(query["toBlock"], 16)
                and all(log["topics"][i].lower() == value.lower() for i, value in enumerate(query["topics"]))]

    def observed(self, name):
        case = self.fixture["observations"][name]
        topics = [self.fixture["logs"][0]["topics"][0], self.fixture["logs"][2]["topics"][0]]
        with patch("sepolia_test_current.rpc", side_effect=self.logs), patch("sepolia_test_current.subprocess.check_output", side_effect=topics):
            result = usdc_approval_state(self.fixture["stand"], case["block"])
        self.assertEqual(result["expected"], case["observedAllowance"])
        return result

    def test_actual_usdc_trade_matches_independent_allowance_getter(self):
        result = self.observed("afterUsdcTrade")
        self.assertEqual(result["spent"], "399335355")
        self.assertEqual(len(result["trades"]), 1)
        self.assertEqual(result["lastMaxApproval"]["transactionHash"], self.fixture["logs"][1]["transactionHash"])

    def test_weth_trade_preserves_usdc_allowance_before_later_reset(self):
        result = self.observed("wethTradeOnly")
        self.assertEqual(result["spent"], "0")
        self.assertEqual(result["lastMaxApproval"]["transactionHash"], self.fixture["logs"][0]["transactionHash"])

    def test_trade_sell_amount_already_includes_legacy_fee(self):
        # GPv2Settlement emits gross sellAmount after adding its legacy fee.
        trade = self.fixture["logs"][3]
        raw = trade["data"][2:]
        trade["data"] = "0x" + raw[:256] + f"{1:064x}" + raw[320:]
        result = self.observed("afterUsdcTrade")
        self.assertEqual(result["spent"], "399335355")

    def test_unknown_trade_entrypoint_cannot_supply_an_allowance_proof(self):
        self.fixture["transactions"][self.fixture["logs"][3]["transactionHash"]]["input"] = "0xdeadbeef"
        with self.assertRaisesRegex(ValueError, "direct GPv2 settle"):
            self.observed("afterUsdcTrade")

    def test_missing_max_approval_cannot_default_to_success(self):
        topics = [self.fixture["logs"][0]["topics"][0], self.fixture["logs"][2]["topics"][0]]
        with patch("sepolia_test_current.rpc", return_value=[]), patch("sepolia_test_current.subprocess.check_output", side_effect=topics):
            with self.assertRaisesRegex(ValueError, "Missing max USDC"):
                usdc_approval_state(self.fixture["stand"], self.fixture["observations"]["afterUsdcTrade"]["block"])


class DrillResults(unittest.TestCase):
    def test_green_suites(self):
        validate_drills(suite(7))
        validate_drills(suite(3) + "\n" + suite(4), suites=2)

    def test_refuses_empty_failed_skipped_missing_or_miscounted_suites(self):
        for output, suites in [
            (suite(0, "ok. 0 passed; 0 failed; 0 skipped"), 1),
            (suite(6, "ok. 6 passed; 0 failed; 1 skipped"), 1),
            (suite(6, "FAILED. 6 passed; 1 failed; 0 skipped"), 1),
            (suite(7).split("\nSuite result:")[0], 1),
            (suite(7, "ok. 8 passed; 0 failed; 0 skipped"), 1),
            (suite(7), 2),
            (suite(7) + "\n[FAIL: x] test_x() (gas: 1)", 1),
        ]:
            with self.subTest(output=output[-60:], suites=suites), self.assertRaises(ValueError):
                validate_drills(output, suites=suites)


if __name__ == "__main__":
    unittest.main()
