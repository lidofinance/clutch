#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Rehearse the stand's move to the universal factory on a pinned fork. No public transaction.

The runner predicts the addresses that `deploy-factory` gives the two deposit queues and the factory from the
controller's nonce at the fork block, and compiles the policy for them. The fixture deploys them and applies the
policy on the fork, and then the migration test and every suite of the current stand run on the moved stand.
"""
import json
import os
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sepolia_test_current import recent_solver, rpc, usdc_approval_state  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "cache/sepolia/factory-migration"
# The order of DeployFactorySepolia.deploy: the USD queue, the ETH queue, then the factory.
DEPLOYED = ["usdDepositQueue", "ethDepositQueue", "universalFactory"]
SUITES = "^Sepolia(FactoryMigration|Stand|CurrentStand|CoWSettlement|.*Coverage)Test$"


def main():
    if int(rpc("eth_chainId", []), 16) != 11155111:
        raise ValueError("Sepolia required")
    number = int(os.environ["SEPOLIA_STAND_BLOCK"])
    stand = json.loads(Path(os.environ.get("SEPOLIA_MANIFEST", ROOT / "cache/sepolia/manifest.json")).read_text())
    if any(name in stand for name in DEPLOYED):
        raise ValueError("The manifest already names the factory; this rehearsal is for the stand before it")
    nonce = int(rpc("eth_getTransactionCount", [stand["controller"], hex(number)]), 16)
    for i, name in enumerate(DEPLOYED):
        stand[name] = subprocess.check_output(
            ["cast", "compute-address", stand["controller"], "--nonce", str(nonce + i)], text=True
        ).split()[-1]
    OUT.mkdir(parents=True, exist_ok=True)
    manifest, artifact = OUT / "manifest.json", OUT / "policy.json"
    manifest.write_text(json.dumps(stand, indent=2) + "\n")
    subprocess.run(["bun", "policy/constellation/sepolia/compile.ts", str(manifest), str(artifact)], cwd=ROOT, check=True)
    solver = "0x" + recent_solver(stand, number)["topics"][1][-40:]
    env = {**os.environ, "SEPOLIA_STAND_BLOCK": str(number), "SEPOLIA_MANIFEST": str(manifest),
           "SEPOLIA_MIGRATION_ARTIFACT": str(artifact), "SEPOLIA_TEST_SOLVER": solver,
           "SEPOLIA_EXPECTED_USDC_ALLOWANCE": usdc_approval_state(stand, number)["expected"]}
    result = subprocess.run(
        ["forge", "test", "--match-contract", SUITES, "--hardfork", "amsterdam", "--threads", "1", "-vv"],
        cwd=ROOT, env=env, capture_output=True, text=True,
    )
    output = (result.stdout + result.stderr).replace(os.environ["SEPOLIA_RPC"], "<RPC>")
    (OUT / "drills.log").write_text(output)
    print(output, end="")
    result.check_returncode()


if __name__ == "__main__":
    main()
