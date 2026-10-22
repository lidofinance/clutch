#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Execute the exact migration transaction only on an owned disposable loopback fork."""
import json
import os
import subprocess
import time
import urllib.request

from sepolia_rehearse import LOCAL, ROOT

CACHE = ROOT / "cache/sepolia/role-key-migration"


def rpc(method, params):
    request = urllib.request.Request(LOCAL, json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=60) as response:
        payload = json.load(response)
    if "error" in payload:
        raise RuntimeError(f"Owned local fork rejected {method}")
    return payload["result"]


def main():
    package = json.loads((CACHE / "package.json").read_text())
    try:
        rpc("eth_chainId", [])
    except (OSError, ValueError):
        pass
    else:
        raise RuntimeError("Port 8547 is already in use; no existing node will be modified")
    (CACHE / "fork-verification.json").unlink(missing_ok=True)
    node = subprocess.Popen([
        "anvil", "--host", "127.0.0.1", "--port", "8547", "--chain-id", "11155111",
        "--hardfork", "amsterdam", "--fork-url", os.environ["SEPOLIA_RPC"],
        "--fork-block-number", str(package["block"]), "--auto-impersonate",
        "--gas-limit", "16777216", "--silent",
    ], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(60):
            if node.poll() is not None:
                raise RuntimeError("Owned Anvil exited during startup")
            try:
                chain = int(rpc("eth_chainId", []), 16)
                break
            except (OSError, ValueError):
                time.sleep(0.5)
        else:
            raise RuntimeError("Owned local fork startup timed out")
        if chain != 11155111 or int(rpc("eth_blockNumber", []), 16) != package["block"]:
            raise RuntimeError("Local fork does not match the reviewed Sepolia snapshot")
        if rpc("eth_getBlockByNumber", [hex(package["block"]), False])["hash"] != package["blockHash"]:
            raise RuntimeError("Local fork block hash differs")
        sender = package["sourceManifest"]["controller"]
        rpc("anvil_setBalance", [sender, hex(100 * 10**18)])
        transactions = []
        for batch in package["transactions"]:
            transaction = {"from": sender, "to": batch["to"], "value": "0x0", "data": batch["data"]}
            gas = int(rpc("eth_estimateGas", [transaction]), 16)
            if gas > 16_777_216 or node.poll() is not None:
                raise RuntimeError("Migration exceeds the transaction cap or the owned node exited")
            transaction["gas"] = hex(min(16_777_216, (gas * 12 + 9) // 10))
            hashed = rpc("eth_sendTransaction", [transaction])
            receipt = None
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline and receipt is None:
                receipt = rpc("eth_getTransactionReceipt", [hashed])
                if receipt is None:
                    time.sleep(0.1)
            (CACHE / f"fork-batch-{len(transactions)}.json").write_text(json.dumps({"hash": hashed, "gasEstimate": gas, "receipt": receipt}, indent=2) + "\n")
            if not receipt or receipt["status"] != "0x1":
                raise RuntimeError("Local migration transaction failed")
            transactions.append({"hash": hashed, "gasEstimate": gas, "gasUsed": int(receipt["gasUsed"], 16)})
        env = {**os.environ, "SEPOLIA_RPC": LOCAL}
        with (CACHE / "fork-rpc-check.log").open("w") as output:
            result = subprocess.run([
                "bun", "policy/constellation/sepolia/prepare-migration.ts", "verify", ",".join(t["hash"] for t in transactions), "--fork",
            ], cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=300)
        if result.returncode:
            raise RuntimeError("Post-migration RPC comparison failed; inspect fork-rpc-check.log")
        verified = json.loads((CACHE / "fork-verification.json").read_text())
        if not verified["matches"] or not verified["localOnly"]:
            raise RuntimeError("Incomplete local migration verification")
        report = {"localOnly": True, "forkBlock": package["block"], "transactions": transactions,
                  "payloadSha256": package["payloadSha256"],
                  "gasUsed": sum(t["gasUsed"] for t in transactions), "configurationCalls": len(package["calls"]),
                  "policyDifferences": len(verified["differences"]),
                  "sameAllowances": verified["sameAllowances"], "sameSafes": verified["sameSafes"]}
        (CACHE / "rehearsal.json").write_text(json.dumps(report, indent=2) + "\n")
        print(f"Local migration: {len(package['calls'])} calls, two transactions, {report['gasUsed']} gas, zero RPC differences.")
    finally:
        node.terminate()
        try:
            node.wait(timeout=5)
        except subprocess.TimeoutExpired:
            node.kill()
            node.wait()


if __name__ == "__main__":
    main()
