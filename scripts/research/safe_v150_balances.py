#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Balances held by Safes on the v1.5.0 singleton at one block (evidence for OD-17).

Reads the Safe addresses from column 4 of a TSV written by safe_v150_logs.py. At BLOCK, it reads each
Safe's singleton with Safe's own getStorageAt(0, 1), keeps the Safes still on v1.5.0, and sums their
ETH and six token balances through Multicall3 aggregate3. Seven assets only; no DeFi positions and
no prices.

Usage:
  ETH_RPC_URL=... uv run --with eth-abi python3 scripts/research/safe_v150_balances.py TSV BLOCK [--top N]

With --top N it also prints the N largest holdings of each asset.

The RPC URL comes from the environment and is never printed.
"""
import concurrent.futures as cf
import json
import os
import sys
import time
import urllib.request

from eth_abi import decode, encode

MULTICALL3 = "0xcA11bde05977b3631167028862bE2a173976CA11"
V150 = {"0xff51a5898e281db6dfc7855790607438df2ca44b", "0xedd160febbd92e350d4d398fb636302fccd67c7e"}
TOKENS = {  # symbol: (address, decimals); ETH is read through Multicall3.getEthBalance
    "USDC": ("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", 6),
    "USDT": ("0xdAC17F958D2ee523a2206206994597C13D831ec7", 6),
    "WETH": ("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 18),
    "stETH": ("0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84", 18),
    "wstETH": ("0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0", 18),
    "DAI": ("0x6B175474E89094C44Da98b954EedeAC495271d0F", 18),
}
GET_ETH_BALANCE = bytes.fromhex("4d2301cc")  # getEthBalance(address)
BALANCE_OF = bytes.fromhex("70a08231")       # balanceOf(address)
GET_STORAGE_AT = bytes.fromhex("5624b25b")   # getStorageAt(uint256,uint256)
AGGREGATE3 = bytes.fromhex("82ad56cb")       # aggregate3((address,bool,bytes)[])
BATCH = 800


def eth_call(data, block):
    body = {"jsonrpc": "2.0", "id": 1, "method": "eth_call",
            "params": [{"to": MULTICALL3, "data": "0x" + data.hex()}, hex(block)]}
    req = urllib.request.Request(os.environ["ETH_RPC_URL"], data=json.dumps(body).encode(),
                                 headers={"content-type": "application/json"})
    for attempt in range(6):
        try:
            r = json.load(urllib.request.urlopen(req, timeout=120))
            if "result" in r:
                return bytes.fromhex(r["result"][2:])
        except Exception:
            pass
        time.sleep(2 * (attempt + 1))
    sys.exit("RPC failed")


def multicall(calls, block):
    out = decode(["(bool,bytes)[]"], eth_call(AGGREGATE3 + encode(["(address,bool,bytes)[]"], [calls]), block))[0]
    return [(ok, data) for ok, data in out]


def run_batches(make_calls, items, block, parse):
    results = [None] * len(items)
    chunks = [(i, items[i:i + BATCH]) for i in range(0, len(items), BATCH)]
    with cf.ThreadPoolExecutor(6) as ex:
        futs = {ex.submit(multicall, [make_calls(x) for x in chunk], block): i for i, chunk in chunks}
        for f in cf.as_completed(futs):
            i = futs[f]
            for j, res in enumerate(f.result()):
                results[i + j] = parse(res)
    return results


def main():
    path, block = sys.argv[1], int(sys.argv[2])
    top = int(sys.argv[sys.argv.index("--top") + 1]) if "--top" in sys.argv else 1
    safes = sorted({line.split("\t")[3] for line in open(path)})

    def singleton(res):
        ok, data = res
        if not ok:
            return None
        raw = decode(["bytes"], data)[0]
        return "0x" + raw[12:32].hex() if len(raw) >= 32 else None

    singletons = run_batches(lambda s: (s, True, GET_STORAGE_AT + encode(["uint256", "uint256"], [0, 1])), safes, block, singleton)
    live = [s for s, sg in zip(safes, singletons) if sg in V150]
    print(f"block {block}: {len(safes)} Safes listed, {len(live)} on v1.5.0 at the block")

    def amount(res):
        ok, data = res
        return int.from_bytes(data[:32], "big") if ok and len(data) >= 32 else None

    assets = [("ETH", None, 18)] + [(k, v[0], v[1]) for k, v in TOKENS.items()]
    for sym, token, dec in assets:
        if token is None:
            vals = run_batches(lambda s: (MULTICALL3, True, GET_ETH_BALANCE + encode(["address"], [s])), live, block, amount)
        else:
            vals = run_batches(lambda s: (token, True, BALANCE_OF + encode(["address"], [s])), live, block, amount)
        failed = sum(1 for v in vals if v is None)
        vals = [v or 0 for v in vals]
        held = sum(1 for v in vals if v)
        largest = ", ".join(f"{v / 10**dec:,.2f}" for v in sorted(vals, reverse=True)[:top])
        print(f"  {sym:<7} total {sum(vals) / 10**dec:>18,.2f}  held by {held:>4}  largest {largest}  failed calls {failed}")


if __name__ == "__main__":
    main()
