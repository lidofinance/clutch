#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Deploy and apply only to an owned, disposable Anvil fork on loopback."""
import json
import os
import re
from pathlib import Path
import subprocess
import time
import urllib.request

from sepolia_receipts import inspect_run

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "cache/sepolia/rehearsal"
LOCAL = "http://127.0.0.1:8547"
EXPECTED_DRILLS = {
    "test_account_graph_and_domain_verifier",
    "test_burn_motion_wait_objection_and_voting_cancellation",
    "test_emergency_stops_asset_operator_but_cannot_restart",
    "test_first_loss_redeem_claim_both_assets_and_denied_bypass",
    "test_funding_budget_and_safe_owner_path",
    "test_twap_two_parts_signature_and_cancellation",
    "test_typed_order_presign_unsign_and_receivers",
}


def validate_drills(output, expected=EXPECTED_DRILLS, suites=1):
    passed = re.findall(r"^\[PASS\] (test_\w+)\(\)", output, re.MULTILINE)
    summaries = re.findall(r"^Suite result: (.+)$", output, re.MULTILINE)
    if (len(passed) != len(expected) or set(passed) != expected
            or re.search(r"^\[(?:FAIL|SKIP)", output, re.MULTILINE)
            or len(summaries) != suites
            or any(not re.match(r"ok\. [1-9][0-9]* passed; 0 failed; 0 skipped(?:;|$)", s) for s in summaries)
            or sum(int(re.search(r"(\d+) passed", s)[1]) for s in summaries) != len(expected)):
        raise ValueError("Expected all named Sepolia drills, with no failures or skips")


def rpc(method, params):
    request = urllib.request.Request(LOCAL, json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=5) as response:
        payload = json.load(response)
    if "error" in payload:
        raise RuntimeError(f"Local Anvil rejected {method}")
    return payload["result"]


def run(command, name, env):
    log = CACHE / f"{name}.log"
    with log.open("w") as output:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=300)
    if result.returncode:
        raise RuntimeError(f"{name} failed; inspect {log.relative_to(ROOT)}")
    print(f"{name}: passed", flush=True)


def main():
    upstream = os.environ["SEPOLIA_RPC"]
    sender = os.environ["SEPOLIA_SENDER"]
    CACHE.mkdir(parents=True, exist_ok=True)
    (CACHE / "result.json").unlink(missing_ok=True)
    try:
        rpc("eth_chainId", [])
    except (OSError, ValueError):
        pass
    else:
        raise RuntimeError("Port 8547 is already in use; stop that local node first")
    block = json.loads((ROOT / "policy/constellation/sepolia/network.json").read_text())["observedBlock"]
    env = {**os.environ, "CLUTCH_SEPOLIA": "1", "SEPOLIA_MANIFEST": str(CACHE / "manifest.json"), "SEPOLIA_ARTIFACT": str(CACHE / "policy.json"), "SEPOLIA_REHEARSAL_RPC": LOCAL, "FOUNDRY_BROADCAST": str(CACHE / "broadcast"), "SEPOLIA_FUND_WETH_WEI": "20000000000000000", "SEPOLIA_FUND_SHARES_WEI": "10000000000000000000"}
    node = subprocess.Popen(["anvil", "--host", "127.0.0.1", "--port", "8547", "--chain-id", "11155111", "--hardfork", "amsterdam", "--fork-url", upstream, "--fork-block-number", str(block), "--auto-impersonate", "--gas-limit", "100000000", "--silent", "--block-time", "1", "--mixed-mining"], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(60):
            if node.poll() is not None:
                raise RuntimeError("Local fork exited during startup")
            try:
                chain = rpc("eth_chainId", [])
                break
            except (OSError, ValueError):
                time.sleep(0.5)
        else:
            raise RuntimeError("Local fork startup timed out")
        if int(chain, 16) != 11155111:
            raise RuntimeError("Wrong local chain")
        rpc("anvil_setBalance", [sender, hex(100 * 10**18)])
        args = ["--hardfork", "amsterdam", "--rpc-url", LOCAL, "--sender", sender, "--unlocked", "--broadcast", "--non-interactive", "--slow", "--gas-estimate-multiplier", "200"]
        run(["forge", "script", "script/sepolia/DeploySepolia.s.sol", *args], "deploy", env)
        run(["bun", "policy/constellation/sepolia/compile.ts", env["SEPOLIA_MANIFEST"], env["SEPOLIA_ARTIFACT"]], "compile", env)
        run(["forge", "script", "script/sepolia/ApplySepolia.s.sol", *args], "apply", env)
        run(["forge", "script", "script/sepolia/FundSepolia.s.sol", *args], "fund", env)
        # Keep one local head while Forge reads the deployed state in parallel.
        rpc("anvil_setAutomine", [True])
        run(["forge", "test", "--match-contract", "SepoliaStandTest", "--hardfork", "amsterdam", "-vv"], "drills", env)
        validate_drills((CACHE / "drills.log").read_text())
        stages = {}
        for name in ["DeploySepolia", "ApplySepolia", "FundSepolia"]:
            records = json.loads((CACHE / f"broadcast/{name}.s.sol/11155111/run-latest.json").read_text())
            receipts = records["receipts"]
            if not inspect_run(records, sender)["complete"]:
                raise RuntimeError(f"Incomplete local receipts for {name}")
            stages[name] = {"transactions": len(receipts), "gasUsed": sum(int(r["gasUsed"], 16) for r in receipts), "feeWei": str(sum(int(r["gasUsed"], 16) * int(r["effectiveGasPrice"], 16) for r in receipts))}
        report = {"chainId": 11155111, "hardfork": "amsterdam", "forkBlock": block, "localOnly": True, "stages": stages}
        (CACHE / "result.json").write_text(json.dumps(report, indent=2) + "\n")
        print(f"Local rehearsal complete: {CACHE.relative_to(ROOT)}/result.json", flush=True)
    finally:
        node.terminate()
        try:
            node.wait(timeout=5)
        except subprocess.TimeoutExpired:
            node.kill()
            node.wait()


if __name__ == "__main__":
    main()
