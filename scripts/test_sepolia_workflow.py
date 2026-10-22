#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Offline checks for Sepolia rehearsal results and saved-run guards."""
from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest

from sepolia_rehearse import validate_drills
from sepolia_receipts import guard, inspect_run


# Captured names from the successful SepoliaStandTest run.
DRILLS = """test_account_graph_and_domain_verifier
test_burn_motion_wait_objection_and_voting_cancellation
test_emergency_stops_asset_operator_but_cannot_restart
test_first_loss_redeem_claim_both_assets_and_denied_bypass
test_funding_budget_and_safe_owner_path
test_twap_two_parts_signature_and_cancellation
test_typed_order_presign_unsign_and_receivers""".splitlines()


def drill_output(names=DRILLS, summary="ok. 7 passed; 0 failed; 0 skipped"):
    return "\n".join(f"[PASS] {name}() (gas: 123)" for name in names) + "\nSuite result: " + summary


class DrillResults(unittest.TestCase):
    def test_complete_captured_run(self):
        validate_drills(drill_output())

    def test_zero_tests(self):
        with self.assertRaises(ValueError):
            validate_drills(drill_output([], "ok. 0 passed; 0 failed; 0 skipped"))

    def test_missing_test_even_with_green_summary(self):
        with self.assertRaises(ValueError):
            validate_drills(drill_output(DRILLS[:-1], "ok. 6 passed; 0 failed; 0 skipped"))

    def test_skipped_test(self):
        with self.assertRaises(ValueError):
            validate_drills(drill_output(DRILLS[:-1], "ok. 6 passed; 0 failed; 1 skipped"))

    def test_failed_test(self):
        with self.assertRaises(ValueError):
            validate_drills(drill_output(DRILLS[:-1], "FAILED. 6 passed; 1 failed; 0 skipped"))

    def test_unexpected_or_duplicate_test(self):
        for names in [DRILLS + ["test_unknown"], DRILLS + [DRILLS[0]]]:
            with self.subTest(names=names), self.assertRaises(ValueError):
                validate_drills(drill_output(names))

    def test_missing_summary(self):
        with self.assertRaises(ValueError):
            validate_drills(drill_output().split("\nSuite result:")[0])


SENDER = "0x" + "11" * 20
TARGET = "0x" + "22" * 20
HASHES = ["0x" + value * 64 for value in ["a", "b"]]


def saved_run(confirmed=1):
    # Fields retained from Foundry 1.8.5 CALL records and receipts.
    return {
        "chain": 11155111,
        "transactions": [{
            "hash": hashed, "transactionType": "CALL",
            "transaction": {"from": SENDER, "to": TARGET, "chainId": "0xaa36a7", "nonce": hex(39 + i)},
        } for i, hashed in enumerate(HASHES)],
        "receipts": [{"transactionHash": hashed, "status": "0x1", "from": SENDER, "to": TARGET} for hashed in HASHES[:confirmed]],
        "pending": [],
    }


class ReceiptGuards(unittest.TestCase):
    def test_partial_and_complete_captured_shapes(self):
        self.assertEqual(inspect_run(saved_run(), SENDER), {"transactions": 2, "receipts": 1, "complete": False})
        self.assertTrue(inspect_run(saved_run(2), SENDER)["complete"])

    def test_guard_missing_partial_and_complete_runs(self):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / "run.json"
            guard("fresh", file, SENDER)
            with self.assertRaisesRegex(ValueError, "No saved run"):
                guard("resume", file, SENDER)
            file.write_text(json.dumps(saved_run()))
            guard("resume", file, SENDER)
            with self.assertRaisesRegex(ValueError, "Saved run exists"):
                guard("fresh", file, SENDER)
            file.write_text(json.dumps(saved_run(2)))
            with self.assertRaisesRegex(ValueError, "complete"):
                guard("resume", file, SENDER)

    def test_unsigned_and_pending_transactions(self):
        unsigned = saved_run()
        unsigned["transactions"][1]["hash"] = None
        self.assertFalse(inspect_run(unsigned, SENDER)["complete"])
        pending = saved_run()
        pending["pending"] = [HASHES[1]]
        self.assertFalse(inspect_run(pending, SENDER)["complete"])

    def test_chain_sender_nonce_and_format_mismatches(self):
        wrong = []
        for key, value in [("chain", 1), ("pending", {}), ("receipts", None), ("transactions", [])]:
            item = saved_run()
            item[key] = value
            wrong.append(item)
        for key, value in [("chainId", "0x1"), ("from", TARGET), ("nonce", "0x27"), ("to", "0x123")]:
            item = saved_run()
            item["transactions"][1]["transaction"][key] = value
            wrong.append(item)
        for item in wrong:
            with self.subTest(item=item), self.assertRaises(ValueError):
                inspect_run(item, SENDER)

    def test_duplicate_or_unknown_associations(self):
        duplicate_tx = saved_run()
        duplicate_tx["transactions"][1]["hash"] = HASHES[0]
        duplicate_receipt = saved_run()
        duplicate_receipt["receipts"].append(deepcopy(duplicate_receipt["receipts"][0]))
        unknown_receipt = saved_run()
        unknown_receipt["receipts"][0]["transactionHash"] = "0x" + "c" * 64
        for item in [duplicate_tx, duplicate_receipt, unknown_receipt]:
            with self.subTest(item=item), self.assertRaises(ValueError):
                inspect_run(item, SENDER)

    def test_failed_receipt_and_mismatched_parties(self):
        for key, value in [("status", "0x0"), ("status", "success"), ("from", TARGET), ("to", SENDER)]:
            item = saved_run()
            item["receipts"][0][key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                inspect_run(item, SENDER)

    def test_status_one_with_safe_execution_failure_refuses(self):
        item = saved_run()
        # Foundry receipt/log shape, with Safe's ExecutionFailure(bytes32,uint256) topic.
        item["receipts"][0]["logs"] = [{
            "address": TARGET,
            "topics": ["0x23428b18acfb3ea64b08dc0c1d296ea9c09702c09083ca5272e64d115b687d23"],
            "data": "0x" + "00" * 64,
        }]
        with self.assertRaisesRegex(ValueError, "Safe ExecutionFailure"):
            inspect_run(item, SENDER)

    def test_pending_must_be_known_unconfirmed_and_unique(self):
        for values in [[HASHES[0]], [HASHES[1], HASHES[1]], ["0x" + "c" * 64], [{}]]:
            item = saved_run()
            item["pending"] = values
            with self.subTest(values=values), self.assertRaises(ValueError):
                inspect_run(item, SENDER)

    def test_create_receipt_has_no_recipient(self):
        item = saved_run()
        item["transactions"][0]["transactionType"] = "CREATE"
        item["transactions"][0]["transaction"]["to"] = None
        item["receipts"][0]["to"] = None
        inspect_run(item, SENDER)
        item["transactions"][0]["transactionType"] = "UNKNOWN"
        with self.assertRaises(ValueError):
            inspect_run(item, SENDER)


if __name__ == "__main__":
    unittest.main()
