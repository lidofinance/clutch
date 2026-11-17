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

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "cache/sepolia/rehearsal"
LOCAL = "http://127.0.0.1:8547"


def validate_drills(output, suites=1):
    """Each suite ran, passed at least one test, and failed and skipped none."""
    passed = re.findall(r"^\[PASS\] test_\w+\(\)", output, re.MULTILINE)
    summaries = re.findall(r"^Suite result: (.+)$", output, re.MULTILINE)
    if (re.search(r"^\[(?:FAIL|SKIP)", output, re.MULTILINE) or len(summaries) != suites
            or any(not re.match(r"ok\. [1-9][0-9]* passed; 0 failed; 0 skipped(?:;|$)", s) for s in summaries)
            or sum(int(re.search(r"(\d+) passed", s)[1]) for s in summaries) != len(passed)):
        raise ValueError(f"Expected {suites} Sepolia suites, with no failures or skips")


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


def steps(env):
    """The stand owner's public recipes, signed by the unlocked sender."""
    recipe = {**env, "SEPOLIA_RPC": LOCAL, "SEPOLIA_SIGNER": "--unlocked", "SEPOLIA_MOTIONS": str(CACHE / "motions")}
    stand = json.loads(Path(env["SEPOLIA_MANIFEST"]).read_text())
    call = lambda to, signature, *args: subprocess.check_output(
        ["cast", "call", to, signature, *args, "--rpc-url", LOCAL], text=True).split()[0]
    just = lambda name, *args: run(["just", "--justfile", "sepolia.just", *args], name, recipe)

    def motion(name):
        just(f"motion-{name}", "motion", name)
        rpc("evm_increaseTime", [int(call(stand["easyTrack"], "motionDuration()(uint256)"))])
        rpc("evm_mine", [])
        just(f"enact-{name}", "enact", str(int(call(stand["easyTrack"], "motionsCount()(uint256)")) - 1))

    def check(condition, message):
        if not condition:
            raise RuntimeError(message)

    def caps():
        motion("caps")
        check(call(stand["universalFactory"], "policyVersion()(uint256)") == "1", "The caps motion left another policy version")
        run(["bun", "-e", DIFF], "diff", recipe)

    def motions():
        for name in ["insurance-funding", "insurance", "first-loss-burn", "approvals", "orders-governance", "exit-governance", "insurance-governance"]:
            motion(name)
        just("emergency-stop", "emergency-stop")
        check(call(stand["assetSafe"], "isModuleEnabled(address)(bool)", stand["operatorModifier"]) == "false", "emergency-stop left the operator enabled")
        motion("restart")
        check(call(stand["assetSafe"], "isModuleEnabled(address)(bool)", stand["operatorModifier"]) == "true", "restart left the operator disabled")
        check(call(stand["universalFactory"], "policyVersion()(uint256)") == "4", "The motions left another policy version")
        run(["bun", "-e", DIFF], "diff-motions", recipe)

    return caps, motions


# The chain against the artifact, every role, module and allowance, as `constellation` compares the public stand.
DIFF = """
import { readFileSync } from "node:fs";
import { build } from "./policy/constellation/sepolia/compile";
import { diffPolicy } from "./policy/constellation/sepolia/diff";
import { readOnlyRpc } from "./policy/constellation/sepolia/prepare-constellation";
const manifest = JSON.parse(readFileSync(process.env.SEPOLIA_MANIFEST!, "utf8"));
const report = await diffPolicy(readOnlyRpc(process.env.SEPOLIA_RPC!), manifest, build(manifest));
for (const difference of report.differences) console.log(difference.path);
if (!report.matches) process.exit(1);
"""


def main():
    upstream = os.environ["SEPOLIA_RPC"]
    sender = os.environ["SEPOLIA_SENDER"]
    CACHE.mkdir(parents=True, exist_ok=True)
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
        caps, motions = steps(env)
        caps()
        # Keep one local head while Forge reads the deployed state in parallel.
        rpc("anvil_setAutomine", [True])
        run(["forge", "test", "--match-contract", "SepoliaStandTest", "--hardfork", "amsterdam", "-vv"], "drills", env)
        validate_drills((CACHE / "drills.log").read_text())
        motions()
        print("Local rehearsal complete", flush=True)
    finally:
        node.terminate()
        try:
            node.wait(timeout=5)
        except subprocess.TimeoutExpired:
            node.kill()
            node.wait()


if __name__ == "__main__":
    main()
