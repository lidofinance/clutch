#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Safe v1.5.0 adoption on Ethereum mainnet, read from logs (evidence for OD-17).

Lists two sets of logs between two blocks through the Etherscan v2 logs API:
  creations   ProxyCreation logs of the v1.5.0 SafeProxyFactory, any singleton
  migrations  ChangedMasterCopy logs from any emitter whose new singleton is Safe v1.5.0 (L1 or L2)
Writes one TSV per set (block, timestamp, tx hash, Safe, singleton), prints counts by singleton and
by month, and prints each TSV's sha256. With --sample N, it also fetches N random creation
transactions on the v1.5.0 singletons through ETH_RPC_URL and counts their senders.

Usage:
  ETHERSCAN_API_KEY=... [ETH_RPC_URL=...] python3 scripts/research/safe_v150_logs.py FROM TO OUTDIR [--sample N]

The key and the RPC URL come from the environment and are never printed.
"""
import argparse
import datetime as dt
import hashlib
import json
import os
import random
import sys
import time
import urllib.request
from collections import Counter

FACTORY = "0x14F2982D601c9458F93bd70B218933A6f8165e7b"  # SafeProxyFactory v1.5.0
PROXY_CREATION = "0x4f51faf6c4561ff95f067657e43439f0f856d97c04d9ec9070a6199ad418e235"  # ProxyCreation(address,address)
CHANGED_MASTER_COPY = "0x75e41bc35ff1bf14d81d1d2f649c0084a0f974f9289c803ec9898eeec4c8d0b8"  # ChangedMasterCopy(address)
V150 = {
    "0xff51a5898e281db6dfc7855790607438df2ca44b": "Safe v1.5.0",
    "0xedd160febbd92e350d4d398fb636302fccd67c7e": "SafeL2 v1.5.0",
}
SWITCH = dt.datetime(2026, 9, 22, tzinfo=dt.timezone.utc)  # Safe{Wallet} default for new Safes


def etherscan_logs(key, frm, to, topic0, address=None):
    """All logs in [frm, to], 1,000 per page; re-reads the last block of a full page and deduplicates."""
    seen, cur = {}, frm
    while True:
        url = (f"https://api.etherscan.io/v2/api?chainid=1&module=logs&action=getLogs&topic0={topic0}"
               f"&fromBlock={cur}&toBlock={to}&page=1&offset=1000&apikey={key}")
        if address:
            url += f"&address={address}"
        for attempt in range(5):
            try:
                r = json.load(urllib.request.urlopen(url, timeout=60))
                res = r.get("result")
                if isinstance(res, list):
                    break
                if r.get("message") == "No records found":
                    res = []
                    break
            except Exception:
                pass
            time.sleep(2 * (attempt + 1))
        else:
            sys.exit(f"Etherscan failed at block {cur}")
        for x in res:
            seen[(x["transactionHash"], int(x["logIndex"], 16))] = x
        if len(res) < 1000:
            return sorted(seen.values(), key=lambda x: (int(x["blockNumber"], 16), int(x["logIndex"], 16)))
        nxt = int(res[-1]["blockNumber"], 16)
        if nxt <= cur:
            sys.exit(f"block {cur} holds 1,000 logs or more; split the range")
        cur = nxt
        time.sleep(0.25)


def row(x, safe):
    ts = int(x["timeStamp"], 16)
    return (int(x["blockNumber"], 16), ts, x["transactionHash"], safe, "0x" + x["data"][26:66].lower())


def month(ts):
    return dt.datetime.fromtimestamp(ts, dt.timezone.utc).strftime("%Y-%m")


def write(rows, path):
    with open(path, "w") as f:
        for r in rows:
            f.write("\t".join(str(v) for v in r) + "\n")
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def rpc(method, params):
    req = urllib.request.Request(os.environ["ETH_RPC_URL"], headers={"content-type": "application/json"},
                                 data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode())
    return json.load(urllib.request.urlopen(req, timeout=60))["result"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("frm", type=int)
    ap.add_argument("to", type=int)
    ap.add_argument("outdir")
    ap.add_argument("--sample", type=int, default=0)
    a = ap.parse_args()
    key = os.environ.get("ETHERSCAN_API_KEY") or os.environ["ETHERSCAN_TOKEN"]

    created = [row(x, "0x" + x["topics"][1][26:].lower()) for x in etherscan_logs(key, a.frm, a.to, PROXY_CREATION, FACTORY)]
    p1 = os.path.join(a.outdir, f"safe_v150_creations_{a.frm}_{a.to}.tsv")
    print(f"creations: {len(created)} logs, sha256 {write(created, p1)}")
    for s, n in Counter(r[4] for r in created).most_common():
        print(f"  {n:>7}  {s}  {V150.get(s, '')}")
    on150 = [r for r in created if r[4] in V150]
    print(f"  on v1.5.0: {len(on150)} logs, {len({r[3] for r in on150})} Safes")
    for m, n in sorted(Counter(month(r[1]) for r in on150).items()):
        print(f"    {m}  {n}")

    all_mc = etherscan_logs(key, a.frm, a.to, CHANGED_MASTER_COPY)
    migrated = [row(x, x["address"].lower()) for x in all_mc]
    migrated = [r for r in migrated if r[4] in V150]
    p2 = os.path.join(a.outdir, f"safe_v150_migrations_{a.frm}_{a.to}.tsv")
    print(f"ChangedMasterCopy: {len(all_mc)} logs; to v1.5.0: {len(migrated)} logs, "
          f"{len({r[3] for r in migrated})} Safes, sha256 {write(migrated, p2)}")
    before = sum(1 for r in migrated if r[1] < SWITCH.timestamp())
    print(f"  before 2026-09-22T00:00Z: {before} logs; from then on: {len(migrated) - before} logs")
    for m, n in sorted(Counter(month(r[1]) for r in migrated).items()):
        print(f"    {m}  {n}")
    print(f"  overlap with the v1.5.0 creations: {len({r[3] for r in migrated} & {r[3] for r in on150})} Safes")

    if a.sample:
        picks = random.Random(7).sample(on150, a.sample)
        senders = Counter(rpc("eth_getTransactionByHash", [r[2]])["from"].lower() for r in picks)
        top, n = senders.most_common(1)[0]
        print(f"sample of {a.sample} v1.5.0 creations: {len(senders)} distinct senders; the top sender sent {n}")


if __name__ == "__main__":
    main()
