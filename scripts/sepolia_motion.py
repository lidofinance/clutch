#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Print the input of one universal-factory motion on the stand. Reads the chain only.

Each motion uses one motion role. Where a role can only change the policy, its write repeats a target that the
policy already scopes, so the chain still matches the artifact.
"""
import json
import os
import subprocess
import sys

MANIFEST = os.environ.get("SEPOLIA_MANIFEST", "cache/sepolia/manifest.json")
RPC = os.environ["SEPOLIA_RPC"]
SENTINEL = "0x0000000000000000000000000000000000000001"
MAX = str(2**256 - 1)
FUNDING = str(5 * 10**15)


def cast(*args):
    return subprocess.check_output(["cast", *args], text=True).strip()


def call(to, signature, *args):
    return cast("call", to, signature, *args, "--rpc-url", RPC).split()[0]


def writes(name, m):
    weth, usdc = (m["dependencies"]["tokens"][t]["address"] for t in ("weth", "usdc"))
    fl, op = m["firstLossSafe"].lower()[2:], m["operatorModifier"]
    key = lambda token: "0x6b3a" + fl + token.lower()[2:22]
    cap = lambda token, amount: cast("calldata", "setAllowance(bytes32,uint128,uint128,uint128,uint64,uint64)", key(token), amount, amount, amount, "2592000", "0")
    scope = lambda role: cast("calldata", "scopeTarget(bytes32,address)", cast("format-bytes32-string", role), weth)
    return {
        "caps": [(op, "governance", op, cap(weth, str(10**18))), (op, "governance", op, cap(usdc, str(10**9)))],
        "insurance-funding": [(op, "insurance-funding", weth, cast("calldata", "transfer(address,uint256)", m["firstLossSafe"], FUNDING))],
        "insurance": [
            (m["firstLossModifier"], "insurance", weth, cast("calldata", "approve(address,uint256)", m["ethDepositQueue"], FUNDING)),
            (m["firstLossModifier"], "insurance", m["ethDepositQueue"], cast("calldata", "deposit(uint224,address,bytes32[])", FUNDING, "0x0000000000000000000000000000000000000000", "[]")),
        ],
        "first-loss-burn": [(m["firstLossModifier"], "first-loss-burn", m["usdShare"], cast("calldata", "burn(uint256)", str(10**18)))],
        "approvals": [(m["ordersModifier"], "approvals", weth, cast("calldata", "approve(address,uint256)", m["dependencies"]["contracts"]["vaultRelayer"]["address"], MAX))],
        "orders-governance": [(m["ordersModifier"], "governance", m["ordersModifier"], scope("orders-operator"))],
        "exit-governance": [(m["safetyModifier"], "exit-governance", m["safetyModifier"], scope("asset-emergency"))],
        "insurance-governance": [(m["firstLossModifier"], "insurance-governance", m["firstLossModifier"], scope("insurance"))],
        "restart": [(m["safetyModifier"], "restart", m["assetSafe"], cast("calldata", "enableModule(address)", op))],
    }[name]


def main():
    m = json.loads(open(MANIFEST).read())
    command, name = sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None
    if command == "input":
        uf = m["universalFactory"]
        items = ",".join(f"({mod},{cast('format-bytes32-string', role)},{to},{data})" for mod, role, to, data in writes(name, m))
        print(cast("abi-encode", "f(uint256,uint256,(address,bytes32,address,bytes)[])",
                   call(uf, "epoch()(uint256)"), call(uf, "policyVersion()(uint256)"), f"[{items}]"))
    elif command == "stop":
        # The Emergency Safe's asset-emergency role disables the operator modifier on the Asset Safe.
        modules = cast("call", m["assetSafe"], "getModulesPaginated(address,uint256)(address[],address)", SENTINEL, "10", "--rpc-url", RPC).splitlines()[0].strip("[]").split(", ")
        previous = SENTINEL
        for module in modules:
            if module.lower() == m["operatorModifier"].lower():
                break
            previous = module
        else:
            raise SystemExit("The operator modifier is not enabled")
        disable = cast("calldata", "disableModule(address,address)", previous, m["operatorModifier"])
        print(cast("calldata", "execTransactionWithRole(address,uint256,bytes,uint8,bytes32,bool)", m["assetSafe"], "0", disable, "0", cast("format-bytes32-string", "asset-emergency"), "true"))
    else:
        raise SystemExit("usage: sepolia_motion.py input <name> | stop")


if __name__ == "__main__":
    main()
