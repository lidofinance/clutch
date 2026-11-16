#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Run the stand suites on a pinned fork of the existing Sepolia deployment."""
import json
import os
from pathlib import Path
import subprocess
import urllib.request

from sepolia_rehearse import validate_drills

ROOT = Path(__file__).resolve().parent.parent
SUITES = 16


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


def recent_solver(stand, number):
    """Discover an existing solver from canonical Settlement(address) logs, without changing its allowlist."""
    for end in range(number, max(number - 5000, 0), -1000):
        logs = rpc("eth_getLogs", [{
            "address": stand["dependencies"]["contracts"]["settlement"]["address"],
            "fromBlock": hex(max(end - 999, 0)), "toBlock": hex(end),
            "topics": ["0x40338ce1a7c49204f0099533b1e9a7ee0a3d261f84974ab7af36105b8c4e9db4"],
        }])
        if logs:
            return logs[-1]
    raise ValueError("No recent settlement solver found")


def main():
    if int(rpc("eth_chainId", []), 16) != 11155111:
        raise ValueError("Sepolia required")
    tag = hex(int(os.environ["SEPOLIA_STAND_BLOCK"])) if os.environ.get("SEPOLIA_STAND_BLOCK") else "latest"
    block = rpc("eth_getBlockByNumber", [tag, False])
    number = int(block["number"], 16)
    manifest = Path(os.environ.get("SEPOLIA_MANIFEST", ROOT / "cache/sepolia/manifest.json"))
    stand = json.loads(manifest.read_text())
    if stand.get("roleKeyScheme") != "account" or stand.get("chainId") != 11155111:
        raise ValueError("Current Sepolia account-key manifest required")
    solver = "0x" + recent_solver(stand, number)["topics"][1][-40:]
    env = {**os.environ, "SEPOLIA_EXPECTED_USDC_ALLOWANCE": usdc_approval_state(stand, number)["expected"],
           "SEPOLIA_STAND_BLOCK": str(number), "SEPOLIA_MANIFEST": str(manifest), "SEPOLIA_TEST_SOLVER": solver}
    print(f"Existing Sepolia stand fork: block {number}, {block['hash']}", flush=True)
    result = subprocess.run([
        "forge", "test", "--match-contract", "^Sepolia(Stand|CurrentStand|CoWSettlement|.*Coverage)Test$", "--hardfork", "amsterdam",
        "--threads", "1", "-vv",
    ], cwd=ROOT, env=env, capture_output=True, text=True)
    output = (result.stdout + result.stderr).replace(os.environ["SEPOLIA_RPC"], "<RPC>")
    print(output, end="")
    result.check_returncode()
    validate_drills(output, suites=SUITES)


if __name__ == "__main__":
    main()
