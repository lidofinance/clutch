#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Run the stand drills on a pinned fork of the existing Sepolia deployment."""
import json
import hashlib
import os
from pathlib import Path
import subprocess
import urllib.request

from sepolia_rehearse import EXPECTED_DRILLS, validate_drills

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "cache/sepolia/current-stand"
CURRENT_DRILLS = EXPECTED_DRILLS | {
    "test_role_keys_reject_old_wrong_account_and_non_member",
    "test_usdc_budget_boundary_and_refill",
    "test_order_boundaries_and_asset_signing_are_restricted",
    "test_quote_1723885_zero_fee_order_passes_deployed_policy",
    "test_market_and_limit_settlement_and_cancelled_order_refusal",
    "test_twap_settles_two_parts_and_cancelled_next_part_fails",
    "test_governance_executor_restricts_keys_membership_and_administrative_targets",
    "test_emergency_recovery_zero_approvals_and_voting_restart",
}
COVERAGE_DRILLS = {
    "test_GOV_stale_owner_restore_rearms_later_revocation_selective_restart_preserves_it",
    "test_SETTLE_nonzero_remainders_partial_fees_and_cumulative_rounding",
    "test_TWAP_alternative_creation_roots_and_guard_setters_are_denied",
    "test_TWAP_stop_loss_payload_cannot_use_pinned_or_foreign_handler",
    "test_EM_zero_and_revoke_before_cancel_repeated_stop_and_retry",
    "test_EM_repeated_switch_pending_burn_cancel_and_restart",
    "test_EM_asset_administration_selector_key_matrix",
    "test_EM_orders_administration_selector_key_matrix",
    "test_EM_combined_filled_order_claims_frozen_governance_and_restart",
    "test_GOV_allowance_timestamp_classes_and_overflow_recovery",
    "test_GOV_existing_delegatecall_can_only_be_downgraded",
    "test_GOV_fallback_and_singleton_routes_fail_at_policy_boundary",
    "test_GOV_executor_cannot_use_direct_owner_or_module_routes",
    "test_FL_failed_burn_and_claim_preserve_all_queue_and_share_state",
    "test_FL_pending_redeem_survives_cancelled_burn_and_restart",
    "test_ORD_chain_domain_and_every_typed_field_bind_presign",
    "test_ORD_repeated_emergency_and_operator_cancel_preserve_other_orders",
    "test_SETTLE_overfill_before_and_after_partial_fill_is_atomic",
    "test_SETTLE_approval_spender_amount_matrix_and_zero_allowance_transfer",
    "test_TWAP_before_start_and_complete_daily_weekly_uid_schedule",
    "test_TWAP_changed_merkle_proof_fails_generation_signature_and_settlement",
    "test_TWAP_both_removal_roles_reject_cached_settlement_and_preserve_other_order",
    "test_TWAP_duplicate_create_preserves_identity_and_refreshes_context",
    "test_CFG_exact_owners_thresholds_modules_guards_handlers_and_runtimes",
    "test_CFG_exact_initial_token_approvals_and_fixture_wiring",
    "test_CFG_approved_hash_nonce_replay_wrong_safe_chain_and_signatures",
    "test_CFG_actor_matrix_asset_operator",
    "test_CFG_actor_matrix_asset_safety",
    "test_CFG_actor_matrix_orders",
    "test_CFG_actor_matrix_first_loss",
    "test_FUND_first_transfer_logs_nonces_and_unchanged_configuration",
    "test_FUND_receiver_checks_have_unspent_budget_and_exact_error",
    "test_FUND_wrong_token_selector_operation_value_and_malformed_data",
    "test_FUND_partial_transfers_independent_decimals_zero_and_return_no_refund",
    "test_FUND_refill_before_exact_after_multiple_periods_and_cap",
    "test_FUND_failed_token_call_rolls_back_allowance_and_safe_outcomes",
    "test_FUND_empty_duplicate_reordered_and_failing_batches_are_atomic",
    "test_FUND_safe_failure_event_consumes_nonce_but_not_budget",
    "test_FUND_safe_success_can_wrap_false_role_result_without_transfer",
    "test_ORD_token_direction_kind_fill_mode_and_same_token_matrix",
    "test_ORD_each_invalid_typed_field_fails_without_presign",
    "test_ORD_expiry_duration_strict_boundaries_and_expired_settlement",
    "test_ORD_fee_ceiling_rounding_plus_one_and_overflow",
    "test_ORD_uid_mutations_cancellation_isolation_repeated_and_resign",
    "test_SETTLE_both_directions_buy_sell_partial_full_and_exact_deltas",
    "test_SETTLE_missing_funds_approval_unsigned_unauthorized_and_retry",
    "test_SETTLE_cancel_partial_revoke_still_live_and_zero_approval_recovery",
    "test_TWAP_daily_weekly_exact_schedule_boundaries_and_invalid_shapes",
    "test_TWAP_part_replay_interval_edges_skips_final_and_amounts",
    "test_TWAP_signature_mutations_removal_isolation_recreate_and_context",
    "test_TWAP_remove_recreate_same_block_and_later_cached_signature_semantics",
    "test_TWAP_reverse_direction_typed_fields_and_signature_binding",
    "test_TWAP_missing_funds_or_approval_does_not_fill_and_can_retry",
    "test_FL_request_boundaries_queue_authority_and_supply_accounting",
    "test_FL_same_and_multiple_timestamp_partial_duplicate_empty_and_double_claim",
    "test_FL_denied_routes_both_shares_leave_all_state_unchanged",
    "test_FL_pending_claim_survives_unrelated_asset_stop_and_restart",
    "test_ET_factory_callers_inputs_unknown_factory_and_unauthorized_cancellation",
    "test_ET_window_exact_substituted_input_supply_and_reenactment_both_shares",
    "test_ET_objection_threshold_multiple_current_weight_and_repeated_objector_fixture",
    "test_ET_failed_overbalance_competing_motions_and_removed_factory_behavior",
    "test_ET_voting_cancel_unknown_nonpending_mixed_ids_are_atomic",
    "test_ET_executor_auth_encoding_and_batch_failure_are_atomic",
    "test_GOV_all_target_function_admin_paths_and_options_roundtrip",
    "test_GOV_all_admin_selectors_reject_wrong_keys_and_every_protected_target",
    "test_GOV_forbidden_administration_and_both_budget_key_updates",
    "test_GOV_disabled_modifier_cannot_admin_and_only_voting_restores",
    "test_GOV_owner_nonowner_and_failed_atomic_batch_preserve_state",
    "test_EM_all_transfer_routes_tokens_and_forbidden_receivers",
    "test_EM_target_and_function_revokes_for_both_accounts_preserve_other_token",
    "test_EM_switch_wrong_predecessor_module_and_full_stop_only_admin_matrix",
    "test_EM_recovery_order_field_boundaries_and_token_directions",
    "test_EM_two_stop_restart_cycles_new_settlement_and_closed_uid_replay",
}
CURRENT_DRILLS |= COVERAGE_DRILLS


INPUT_SOURCES = ["test/SepoliaStand.t.sol", "test/SepoliaCurrentStand.t.sol", "test/utils/SepoliaStandFixture.sol",
               "scripts/sepolia_test_current.py", "scripts/sepolia_rehearse.py", "test/SepoliaCoverage.t.sol",
               "policy/constellation/sepolia/verify-test-payload.ts", "policy/constellation/sepolia/constellation.ts",
               "policy/constellation/sepolia/compile.ts", "policy/constellation/compiler/compile.ts",
               "policy/constellation/constellation/lib.ts", "policy/constellation/bun.lock"]


def rpc(method, params):
    request = urllib.request.Request(os.environ["SEPOLIA_RPC"], json.dumps({
        "jsonrpc": "2.0", "id": 1, "method": method, "params": params,
    }).encode(), {"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.load(response)
        if "error" in payload:
            raise ValueError()
        return payload["result"]
    except Exception:
        raise RuntimeError(f"{method}: RPC request failed; endpoint and response suppressed") from None



def usdc_approval_state(stand, number):
    """Recompute Circle USDC's spent max allowance from canonical events."""
    usdc = stand["dependencies"]["tokens"]["usdc"]["address"]
    settlement = stand["dependencies"]["contracts"]["settlement"]["address"]
    relayer = stand["dependencies"]["contracts"]["vaultRelayer"]["address"]
    owner_topic = "0x" + stand["ordersSafe"][2:].lower().rjust(64, "0")
    spender_topic = "0x" + relayer[2:].lower().rjust(64, "0")
    approval_topic = subprocess.check_output(["cast", "sig-event", "Approval(address,address,uint256)"], text=True).strip()
    trade_topic = subprocess.check_output(["cast", "sig-event", "Trade(address,address,address,uint256,uint256,uint256,bytes)"], text=True).strip()
    maximum = 2**256 - 1
    position = lambda log: (int(log["blockNumber"], 16), int(log["logIndex"], 16))
    anchor = None
    for end in range(number, stand["deployBlock"] - 1, -2000):
        logs = rpc("eth_getLogs", [{"address": usdc, "fromBlock": hex(max(end - 1999, stand["deployBlock"])),
            "toBlock": hex(end), "topics": [approval_topic, owner_topic, spender_topic]}])
        candidates = [log for log in logs if int(log["data"], 16) == maximum]
        if candidates:
            anchor = max(candidates, key=position)
            break
    if anchor is None:
        raise ValueError("Missing max USDC relayer Approval")
    spent = 0
    trades = []
    for start in range(position(anchor)[0], number + 1, 2000):
        logs = rpc("eth_getLogs", [{"address": settlement, "fromBlock": hex(start),
            "toBlock": hex(min(start + 1999, number)), "topics": [trade_topic, owner_topic]}])
        for log in logs:
            if position(log) <= position(anchor):
                continue
            raw = log["data"][2:]
            if len(raw) < 6 * 64:
                raise ValueError("Malformed Settlement Trade")
            if ("0x" + raw[:64][-40:]).lower() != usdc.lower():
                continue
            transaction = rpc("eth_getTransactionByHash", [log["transactionHash"]])
            if (not transaction or transaction["to"].lower() != settlement.lower()
                    or not transaction["input"].startswith("0x13d79a0b")):
                raise ValueError("USDC allowance proof requires direct GPv2 settle trades")
            sold = int(raw[128:192], 16)
            fee = int(raw[256:320], 16)
            # GPv2 emits sellAmount after adding the legacy fee.
            spent += sold
            trades.append({"transactionHash": log["transactionHash"], "block": position(log)[0],
                           "logIndex": position(log)[1], "sellAmount": str(sold), "feeAmount": str(fee)})
    if spent > maximum:
        raise ValueError("USDC allowance event history exceeds max approval")
    return {"expected": str(maximum - spent), "spent": str(spent), "trades": trades,
            "lastMaxApproval": {"transactionHash": anchor["transactionHash"],
                                "block": position(anchor)[0], "logIndex": position(anchor)[1]}}


def stand_inventory(stand, number):
    """Reject an inconsistent stand before running any drill; pin all runtimes."""
    if (stand.get("network") != "sepolia" or stand.get("chainId") != 11155111
            or stand["dependencies"].get("chainId") != 11155111):
        raise ValueError("Manifest network and chain IDs must identify Sepolia")
    if not 0 < stand["deployBlock"] <= number:
        raise ValueError("Stand deployment must precede the fork block")
    if stand["modules"] != [stand["operatorModifier"], stand["safetyModifier"]]:
        raise ValueError("Manifest Asset modules must match the two named modifiers")
    required = ('agent', 'assetSafe', 'burnFactory', 'controller', 'easyTrack', 'easyTrackExecutor', 'emergencySafe', 'ethClaimAsset', 'ethQueue', 'ethShare', 'firstLossModifier', 'firstLossSafe', 'objectionToken', 'operatorModifier', 'operatorSafe', 'ordersModifier', 'ordersSafe', 'safetyModifier', 'usdClaimAsset', 'usdQueue', 'usdShare', 'voting')
    if any(key not in stand for key in required):
        raise ValueError("Stand manifest is missing a named account or dependency")
    entries = {key: stand[key] for key in required}
    for group in ["contracts", "tokens"]:
        entries.update({f"{group}.{key}": value["address"]
                        for key, value in stand["dependencies"][group].items()})
    seen = {}
    result = []
    for label, address in entries.items():
        if len(address) != 42 or any(c not in "0123456789abcdef" for c in address[2:].lower()) or int(address, 16) == 0:
            raise ValueError(f"Invalid stand address: {label}")
        normalized = address.lower()
        if normalized in seen and {label, seen[normalized]} != {"contracts.weth", "tokens.weth"}:
            raise ValueError(f"Unexpected stand address alias: {seen[normalized]} and {label}")
        seen[normalized] = label
        code = rpc("eth_getCode", [address, hex(number)])
        if label == "controller":
            if code != "0x":
                raise ValueError("Stand controller must be an EOA")
        elif code == "0x":
            raise ValueError(f"Missing stand runtime: {label}")
        code_hash = subprocess.check_output(["cast", "keccak", code], text=True).strip()
        expected = stand["dependencies"]["contracts"].get(label.removeprefix("contracts."), {}) if label.startswith("contracts.") else {}
        if expected.get("codeHash") and (code_hash.lower() != expected["codeHash"].lower()
                or (len(code) - 2) // 2 != expected["codeBytes"]):
            raise ValueError(f"Dependency runtime mismatch: {label}")
        result.append({"label": label, "address": address, "codeBytes": (len(code) - 2) // 2,
                       "codeHash": code_hash, "expectedCodeHash": expected.get("codeHash")})
    return result


def funding_allowances(stand, number):
    """Capture the two stored funding tuples at the fork block, not accrued balances."""
    result = []
    for name in ["orders_weth", "orders_usdc"]:
        key = "0x" + name.encode().hex().ljust(64, "0")
        raw = rpc("eth_call", [{"to": stand["operatorModifier"], "data": "0x5e7c9fe8" + key[2:]}, hex(number)])
        try:
            if (not isinstance(raw, str) or not raw.startswith("0x") or len(raw) != 322
                    or any(c not in "0123456789abcdefABCDEF" for c in raw[2:])):
                raise ValueError()
            values = [int(raw[i:i + 64], 16) for i in range(2, 322, 64)]
            if any(value >= 2**bits for value, bits in zip(values, [128, 128, 64, 128, 64])):
                raise ValueError()
        except ValueError:
            raise ValueError("Malformed funding allowance readback") from None
        result.append({"modifier": stand["operatorModifier"], "key": key,
                       "balance": str(values[3]), "timestamp": str(values[4])})
    return result


def assert_input_hashes(hashes, manifest, payload):
    for name, expected in hashes.items():
        path = manifest if name == "manifest" else payload if name == "payload" else ROOT / name
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError("Test sources, manifest or payload changed during the run")


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    # A failed preparation must not leave a previous success as the current result.
    (CACHE / "result.json").unlink(missing_ok=True)
    hashes = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in INPUT_SOURCES}
    if int(rpc("eth_chainId", []), 16) != 11155111:
        raise ValueError("Sepolia required")
    tag = hex(int(os.environ["SEPOLIA_STAND_BLOCK"])) if os.environ.get("SEPOLIA_STAND_BLOCK") else "latest"
    block = rpc("eth_getBlockByNumber", [tag, False])
    number = int(block["number"], 16)
    manifest = Path(os.environ.get("SEPOLIA_MANIFEST", ROOT / "cache/sepolia/manifest.json"))
    manifest_bytes = manifest.read_bytes()
    stand = json.loads(manifest_bytes)
    if stand.get("roleKeyScheme") != "account" or stand.get("chainId") != 11155111:
        raise ValueError("Current Sepolia account-key manifest required")
    hashes["manifest"] = hashlib.sha256(manifest_bytes).hexdigest()
    payload = ROOT / "cache/sepolia/constellation/payload.json"
    hashes["payload"] = hashlib.sha256(payload.read_bytes()).hexdigest()
    inventory = stand_inventory(stand, number)
    # Discover an existing solver from canonical Settlement(address) logs, without changing its allowlist.
    solver_log = None
    for end in range(number, max(number - 5000, 0), -1000):
        logs = rpc("eth_getLogs", [{
            "address": stand["dependencies"]["contracts"]["settlement"]["address"],
            "fromBlock": hex(max(end - 999, 0)), "toBlock": hex(end),
            "topics": ["0x40338ce1a7c49204f0099533b1e9a7ee0a3d261f84974ab7af36105b8c4e9db4"],
        }])
        if logs:
            solver_log = logs[-1]
            break
    if solver_log is None:
        raise ValueError("No recent settlement solver found")
    solver = "0x" + solver_log["topics"][1][-40:]
    usdc_approval = usdc_approval_state(stand, number)
    allowances = funding_allowances(stand, number)
    assert_input_hashes(hashes, manifest, payload)
    env = {**os.environ, "SEPOLIA_EXPECTED_USDC_ALLOWANCE": usdc_approval["expected"], "SEPOLIA_STAND_BLOCK": str(number), "SEPOLIA_MANIFEST": str(manifest),
           "SEPOLIA_TEST_SOLVER": solver}
    (CACHE / "snapshot.json").write_text(json.dumps({
        "block": number, "blockHash": block["hash"], "solver": solver, "inventory": inventory,
        "solverSettlementTransaction": solver_log["transactionHash"], "usdcApproval": usdc_approval,
        "fundingAllowances": allowances, "sha256": hashes,
    }, indent=2) + "\n")
    validation = subprocess.run(["bun", "--no-env-file", "policy/constellation/sepolia/verify-test-payload.ts",
        str(manifest), str(payload), str(CACHE / "snapshot.json")], cwd=ROOT,
        env={"PATH": os.environ["PATH"]}, capture_output=True, text=True)
    (CACHE / "payload-validation.log").write_text(validation.stdout + validation.stderr)
    validation.check_returncode()
    proof = json.loads(validation.stdout)
    if (proof["payloadSha256"] != hashes["payload"] or proof["block"] != number
            or proof["blockHash"] != block["hash"] or proof["fundingAllowances"] != allowances):
        raise ValueError("Payload proof differs from the pinned inputs")
    assert_input_hashes(hashes, manifest, payload)
    print(f"Existing Sepolia stand fork: block {number}, {block['hash']}", flush=True)
    result = subprocess.run([
        "forge", "test", "--match-contract", "^Sepolia(Stand|CurrentStand|CoWSettlement|.*Coverage)Test$", "--hardfork", "amsterdam",
        "--threads", "1", "-vv",
    ], cwd=ROOT, env=env, capture_output=True, text=True)
    output = (result.stdout + result.stderr).replace(os.environ["SEPOLIA_RPC"], "<RPC>")
    (CACHE / "drills.log").write_text(output)
    print(output, end="")
    result.check_returncode()
    validate_drills(output, CURRENT_DRILLS, suites=15)
    assert_input_hashes(hashes, manifest, payload)
    if rpc("eth_getBlockByNumber", [hex(number), False])["hash"] != block["hash"]:
        raise ValueError("Fork block changed during the run")
    (CACHE / "result.json").write_text(json.dumps({
        "chainId": 11155111, "block": number, "blockHash": block["hash"],
        "localOnly": True, "hardfork": "amsterdam", "passed": True,
        "tests": sorted(CURRENT_DRILLS), "solver": solver, "inventory": inventory,
        "solverSettlementTransaction": solver_log["transactionHash"],
        "usdcApproval": usdc_approval, "fundingAllowances": allowances,
        "payloadValidation": proof, "sha256": hashes,
    }, indent=2) + "\n")


if __name__ == "__main__":
    main()
