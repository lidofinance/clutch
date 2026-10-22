#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Check saved Foundry records before a fresh or resumed Sepolia run."""
import argparse
import json
import os
from pathlib import Path
import re
import sys

# Safe event signature, computed with ethers.id("ExecutionFailure(bytes32,uint256)").
# The block-pinned deployment verifier checks the same topic.
SAFE_EXECUTION_FAILURE = "0x23428b18acfb3ea64b08dc0c1d296ea9c09702c09083ca5272e64d115b687d23"


def address(value):
    if not isinstance(value, str) or not re.fullmatch(r"0x[0-9a-fA-F]{40}", value):
        raise ValueError("Invalid sender or transaction address")
    return value.lower()


def tx_hash(value):
    if not isinstance(value, str) or not re.fullmatch(r"0x[0-9a-fA-F]{64}", value):
        raise ValueError("Unknown transaction hash format")
    return value.lower()


def quantity(value):
    if not isinstance(value, str) or not re.fullmatch(r"0x[0-9a-fA-F]+", value):
        raise ValueError("Unknown transaction quantity format")
    return int(value, 16)


def inspect_run(records, sender):
    sender = address(sender)
    if not isinstance(records, dict) or records.get("chain") != 11155111:
        raise ValueError("Saved run must use Sepolia chain 11155111")
    transactions, receipts, pending = (records.get(key) for key in ["transactions", "receipts", "pending"])
    if not isinstance(transactions, list) or not transactions or not isinstance(receipts, list) or not isinstance(pending, list):
        raise ValueError("Unknown Foundry run format")
    hashes, nonces = {}, []
    for item in transactions:
        if not isinstance(item, dict) or item.get("transactionType") not in {"CALL", "CREATE"}:
            raise ValueError("Unknown Foundry transaction type")
        tx = item.get("transaction")
        if not isinstance(tx, dict) or address(tx.get("from")) != sender or quantity(tx.get("chainId")) != 11155111:
            raise ValueError("Saved transaction sender or chain differs")
        if item["transactionType"] == "CALL":
            address(tx.get("to"))
        elif tx.get("to") is not None:
            raise ValueError("CREATE transaction has a recipient")
        nonces.append(quantity(tx.get("nonce")))
        if item.get("hash") is not None:
            hashed = tx_hash(item["hash"])
            if hashed in hashes:
                raise ValueError("Duplicate transaction hash")
            hashes[hashed] = tx
    if nonces != list(range(nonces[0], nonces[0] + len(nonces))):
        raise ValueError("Saved transaction nonces must be consecutive")
    confirmed = set()
    for receipt in receipts:
        if not isinstance(receipt, dict):
            raise ValueError("Unknown receipt format")
        hashed = tx_hash(receipt.get("transactionHash"))
        if hashed not in hashes or hashed in confirmed:
            raise ValueError("Unknown or duplicate receipt transaction")
        if receipt.get("status") != "0x1":
            raise ValueError("Saved run has a failed or unknown receipt; inspect it before continuing")
        logs = receipt.get("logs", [])
        if not isinstance(logs, list):
            raise ValueError("Unknown receipt logs format")
        for log in logs:
            if not isinstance(log, dict) or not isinstance(log.get("topics"), list):
                raise ValueError("Unknown receipt log format")
            if log["topics"] and str(log["topics"][0]).lower() == SAFE_EXECUTION_FAILURE:
                raise ValueError("Saved run contains Safe ExecutionFailure; inspect it before continuing")
        tx = hashes[hashed]
        recipient = address(receipt["to"]) if receipt.get("to") is not None else None
        if address(receipt.get("from")) != sender or recipient != (address(tx["to"]) if tx.get("to") else None):
            raise ValueError("Receipt sender or recipient differs from its transaction")
        confirmed.add(hashed)
    pending_hashes = [tx_hash(value) for value in pending]
    if len(set(pending_hashes)) != len(pending_hashes) or any(value not in hashes or value in confirmed for value in pending_hashes):
        raise ValueError("Unknown, duplicate or already confirmed pending transaction")
    return {"transactions": len(transactions), "receipts": len(receipts), "complete": len(receipts) == len(transactions)}


def guard(mode, file, sender):
    if not file.exists():
        if mode == "resume":
            raise ValueError("No saved run to resume")
        return
    state = inspect_run(json.loads(file.read_text()), sender)
    if mode == "fresh":
        raise ValueError("Saved run exists; inspect receipts and use the matching resume recipe")
    if state["complete"]:
        raise ValueError("Saved run is complete; refusing to send it again")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["fresh", "resume"])
    parser.add_argument("file", type=Path)
    args = parser.parse_args()
    try:
        guard(args.mode, args.file, os.environ["SEPOLIA_SENDER"])
    except (ValueError, KeyError, OSError) as error:
        print(f"Sepolia run guard: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
