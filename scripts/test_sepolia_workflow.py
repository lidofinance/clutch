#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Offline checks for Sepolia rehearsal results and saved-run guards."""
from copy import deepcopy
import hashlib
import json
import os
import shutil
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from sepolia_test_current import main as run_current_stand, stand_inventory, usdc_approval_state, funding_allowances, assert_input_hashes, INPUT_SOURCES

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



class StandInventory(unittest.TestCase):
    def setUp(self):
        self.stand = json.loads((Path(__file__).parent / "fixtures/sepolia-stand-manifest.json").read_text())
        self.number = self.stand["deployBlock"] + 1

    def run_inventory(self, missing=None):
        def code(method, params):
            self.assertEqual(method, "eth_getCode")
            self.assertEqual(params[1], hex(self.number))
            if params[0] in [self.stand["controller"], missing]:
                return "0x"
            return "0x6000"
        # Synthetic bytecode tests the refusal boundary, not deployed-runtime identity.
        for item in self.stand["dependencies"]["contracts"].values():
            item.pop("codeHash", None)
        with patch("sepolia_test_current.rpc", side_effect=code), patch("sepolia_test_current.subprocess.check_output", return_value="0xhash"):
            return stand_inventory(self.stand, self.number)

    def test_inventory_covers_each_top_level_contract_and_both_token_labels(self):
        result = self.run_inventory()
        labels = {r["label"] for r in result}
        self.assertIn("usdQueue", labels)
        self.assertIn("tokens.usdc", labels)
        self.assertIn("contracts.weth", labels)
        self.assertIn("tokens.weth", labels)
        self.assertEqual(next(r for r in result if r["label"] == "controller")["codeBytes"], 0)

    def test_wrong_network_or_nested_chain_id_stops_preparation(self):
        for field in ["network", "nested"]:
            with self.subTest(field=field):
                original = deepcopy(self.stand)
                if field == "network": self.stand["network"] = "mainnet"
                else: self.stand["dependencies"]["chainId"] = 1
                with self.assertRaisesRegex(ValueError, "network and chain IDs"):
                    self.run_inventory()
                self.stand = original

    def test_future_deployment_and_unexpected_alias_stop_preparation(self):
        self.number = self.stand["deployBlock"] - 1
        with self.assertRaisesRegex(ValueError, "deployment"):
            self.run_inventory()
        self.number += 2
        self.stand["ordersSafe"] = self.stand["assetSafe"]
        with self.assertRaisesRegex(ValueError, "alias"):
            self.run_inventory()

    def test_failed_network_preparation_removes_old_success_and_never_runs_forge(self):
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory)
            result = cache / "result.json"
            result.write_text('{"passed": true}')
            with patch("sepolia_test_current.CACHE", cache), patch("sepolia_test_current.rpc", return_value="0x1"), patch("sepolia_test_current.subprocess.run") as forge:
                with self.assertRaisesRegex(ValueError, "Sepolia required"):
                    run_current_stand()
                forge.assert_not_called()
            self.assertFalse(result.exists())

    def test_zero_address_and_module_alias_stop_preparation(self):
        original = deepcopy(self.stand)
        self.stand["usdQueue"] = "0x" + "00" * 20
        with self.assertRaisesRegex(ValueError, "Invalid stand address"):
            self.run_inventory()
        self.stand = original
        self.stand["modules"] = [self.stand["operatorModifier"]] * 2
        with self.assertRaisesRegex(ValueError, "Asset modules"):
            self.run_inventory()

    def test_missing_named_account_stops_preparation(self):
        self.stand.pop("usdQueue")
        with self.assertRaisesRegex(ValueError, "missing a named"):
            self.run_inventory()

    def test_missing_queue_runtime_stops_before_forge(self):
        with self.assertRaisesRegex(ValueError, "Missing stand runtime: usdQueue"):
            self.run_inventory(missing=self.stand["usdQueue"])

    def test_declared_dependency_hash_is_enforced(self):
        with patch("sepolia_test_current.rpc", side_effect=lambda method, params: "0x" if params[0] == self.stand["controller"] else "0x6000"), patch("sepolia_test_current.subprocess.check_output", return_value="0xwrong"):
            self.stand["controller"] = "0x" + "99" * 20
            with self.assertRaisesRegex(ValueError, "Dependency runtime mismatch"):
                stand_inventory(self.stand, self.number)


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


class PayloadInputs(unittest.TestCase):
    def test_funding_tuple_readback_uses_the_fork_block_and_both_exact_keys(self):
        calls = []
        def read(method, params):
            calls.append((method, params))
            return "0x" + "".join(f"{value:064x}" for value in [20, 100, 2592000, 73, 1792507104])
        with patch("sepolia_test_current.rpc", side_effect=read):
            observed = funding_allowances({"operatorModifier": TARGET}, 11988411)
        self.assertEqual([item[0] for item in calls], ["eth_call", "eth_call"])
        self.assertEqual([item[1][1] for item in calls], [hex(11988411)] * 2)
        for index, name in enumerate(["orders_weth", "orders_usdc"]):
            key = "0x" + name.encode().hex().ljust(64, "0")
            self.assertEqual(calls[index][1][0], {"to": TARGET, "data": "0x5e7c9fe8" + key[2:]})
            self.assertEqual(observed[index], {"modifier": TARGET, "key": key, "balance": "73", "timestamp": "1792507104"})

    def test_invalid_tuple_shape_hex_and_abi_widths_stop_preparation(self):
        encoded = lambda values: "0x" + "".join(f"{value:064x}" for value in values)
        values = [1, 2, 3, 4, 5]
        malformed = [None, "0x0", "0x" + "g" * 320, "0x+" + "0" * 319]
        for index, bits in enumerate([128, 128, 64, 128, 64]):
            changed = list(values); changed[index] = 2**bits; malformed.append(encoded(changed))
        for raw in malformed:
            with self.subTest(raw=raw), patch("sepolia_test_current.rpc", return_value=raw):
                with self.assertRaisesRegex(ValueError, "Malformed funding allowance"):
                    funding_allowances({"operatorModifier": TARGET}, 11988411)

    def test_payload_manifest_and_source_changes_invalidate_the_recorded_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            files = {name: root / name for name in ["source", "manifest", "payload"]}
            for name, path in files.items(): path.write_text(name)
            hashes = {name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in files.items()}
            with patch("sepolia_test_current.ROOT", root):
                assert_input_hashes(hashes, files["manifest"], files["payload"])
                for name, path in files.items():
                    with self.subTest(name=name):
                        path.write_text("changed")
                        with self.assertRaisesRegex(ValueError, "changed during the run"):
                            assert_input_hashes(hashes, files["manifest"], files["payload"])
                        path.write_text(name)


    def test_changes_during_rpc_preparation_stop_before_payload_validation(self):
        original_root = Path(__file__).resolve().parent.parent
        for changed_name in ["payload", "manifest", "test/SepoliaStand.t.sol"]:
            with self.subTest(changed=changed_name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                for source in INPUT_SOURCES:
                    target = root / source; target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(original_root / source, target)
                cache = root / "cache/sepolia/current-stand"; cache.mkdir(parents=True)
                (cache / "result.json").write_text('{"passed":true}')
                manifest = root / "manifest.json"
                shutil.copy2(original_root / "scripts/fixtures/sepolia-stand-manifest.json", manifest)
                payload = root / "cache/sepolia/constellation/payload.json"
                payload.parent.mkdir(parents=True); payload.write_text('{}')
                def rpc(method, params):
                    if method == "eth_chainId": return hex(11155111)
                    if method == "eth_getBlockByNumber": return {"number": hex(11988436), "hash": "0x" + "ab" * 32}
                    if method == "eth_getLogs": return [{"topics": ["0x00", "0x" + "00" * 12 + "11" * 20], "transactionHash": "0x" + "cd" * 32}]
                    self.fail(method)
                def mutate(*args):
                    target = payload if changed_name == "payload" else manifest if changed_name == "manifest" else root / changed_name
                    target.write_text(target.read_text() + " ")
                    return []
                with patch("sepolia_test_current.ROOT", root), patch("sepolia_test_current.CACHE", cache), \
                     patch.dict(os.environ, {"SEPOLIA_MANIFEST": str(manifest)}), \
                     patch("sepolia_test_current.rpc", side_effect=rpc), \
                     patch("sepolia_test_current.stand_inventory", return_value=[]), \
                     patch("sepolia_test_current.usdc_approval_state", return_value={"expected": "0"}), \
                     patch("sepolia_test_current.funding_allowances", side_effect=mutate), \
                     patch("sepolia_test_current.subprocess.run", side_effect=AssertionError("Validator reached changed inputs")) as process:
                    with self.assertRaisesRegex(ValueError, "changed during the run"):
                        run_current_stand()
                    process.assert_not_called()
                self.assertFalse((cache / "result.json").exists())


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

    def test_multiple_suites_require_the_complete_named_set_and_matching_counts(self):
        output = (drill_output(DRILLS[:3], "ok. 3 passed; 0 failed; 0 skipped") + "\n"
                  + drill_output(DRILLS[3:], "ok. 4 passed; 0 failed; 0 skipped"))
        validate_drills(output, set(DRILLS), suites=2)
        for invalid in [output.replace("4 passed", "3 passed"),
                        output.replace("0 skipped", "1 skipped"),
                        output.replace(f"[PASS] {DRILLS[-1]}()", "[PASS] test_unknown()")]:
            with self.subTest(output=invalid), self.assertRaises(ValueError):
                validate_drills(invalid, set(DRILLS), suites=2)


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

    def test_every_receipt_subset_of_captured_funding_run_has_correct_resume_state(self):
        fixture = Path(__file__).parent / "fixtures/sepolia-funding-complete.json"
        complete = json.loads(fixture.read_text())
        sender = complete["transactions"][0]["transaction"]["from"]
        self.assertEqual(len(complete["transactions"]), 4)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "run.json"
            for mask in range(16):
                with self.subTest(receipt_mask=mask):
                    record = deepcopy(complete)
                    record["receipts"] = [r for i, r in enumerate(complete["receipts"]) if mask & (1 << i)]
                    confirmed = {r["transactionHash"] for r in record["receipts"]}
                    record["pending"] = [t["hash"] for t in record["transactions"] if t["hash"] not in confirmed]
                    self.assertEqual(inspect_run(record, sender), {
                        "transactions": 4, "receipts": mask.bit_count(), "complete": mask == 15,
                    })
                    path.write_text(json.dumps(record))
                    with self.assertRaisesRegex(ValueError, "Saved run exists"):
                        guard("fresh", path, sender)
                    if mask == 15:
                        with self.assertRaisesRegex(ValueError, "complete"):
                            guard("resume", path, sender)
                    else:
                        guard("resume", path, sender)

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
