#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Offline checks for the public motions of scripts/sepolia_motion.py against the compiled stand policy."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
FIXTURE = ROOT / "scripts/fixtures/sepolia-stand-manifest.json"
os.environ.setdefault("SEPOLIA_RPC", "http://127.0.0.1:9")

from sepolia_motion import writes

# The roles and allowances that the compiler gives each modifier of the fixture stand.
ARTIFACT = """
import { build } from "./sepolia/compile";
const manifest = JSON.parse(await Bun.file(process.argv[1]).text());
console.log(JSON.stringify(build(manifest).modifiers.map((mod) => ({
  address: mod.address.toLowerCase(),
  roles: Object.fromEntries(mod.roles.map((role) => [role.name, role.members.map((member) => member.address.toLowerCase())])),
  allowances: mod.allowances,
}))));
"""


class SepoliaMotionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(FIXTURE.read_text())
        output = subprocess.check_output(["bun", "-e", ARTIFACT, str(FIXTURE)], cwd=ROOT / "policy/constellation", text=True)
        cls.modifiers = {mod["address"]: mod for mod in json.loads(output)}

    def run_script(self, *args, rpc="http://127.0.0.1:9", path=os.environ["PATH"]):
        env = {**os.environ, "SEPOLIA_RPC": rpc, "SEPOLIA_MANIFEST": str(FIXTURE), "PATH": path}
        return subprocess.run([sys.executable, str(ROOT / "scripts/sepolia_motion.py"), *args], env=env, capture_output=True, text=True, timeout=60)

    def test_failed_rpc_call_prints_no_url(self):
        # A cast that prints its RPC URL in the error, as some cast versions do.
        with tempfile.TemporaryDirectory() as bin_dir:
            fake = Path(bin_dir) / "cast"
            fake.write_text('#!/bin/sh\necho "error sending request for url ($ETH_RPC_URL)" >&2\nexit 1\n')
            fake.chmod(0o755)
            for args in [("input", "caps"), ("stop",)]:
                result = self.run_script(*args, rpc="http://127.0.0.1:9/v2/SECRETKEY", path=f"{bin_dir}:{os.environ['PATH']}")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("<RPC>", result.stderr)
                self.assertNotIn("SECRETKEY", result.stdout + result.stderr)

    def test_unknown_motion_names_the_motions(self):
        result = self.run_script("input", "nope")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unknown motion 'nope'", result.stderr)

    def test_each_write_uses_a_role_of_the_universal_factory_on_its_modifier(self):
        factory = self.manifest["universalFactory"].lower()
        names = ["caps", "insurance-funding", "insurance", "first-loss-burn", "approvals", "orders-governance", "exit-governance", "insurance-governance", "restart"]
        used = set()
        for name in names:
            for modifier, role, _, _ in writes(name, self.manifest):
                roles = self.modifiers[modifier.lower()]["roles"]
                self.assertIn(factory, roles.get(role, []), f"{name}: {role}")
                used.add((modifier.lower(), role))
        # Each factory role on the stand gets one public motion.
        held = {(address, role) for address, mod in self.modifiers.items() for role, members in mod["roles"].items() if factory in members}
        self.assertEqual(used, held)

    def test_caps_motion_sets_the_derived_caps_that_the_artifact_expects(self):
        operator = self.modifiers[self.manifest["operatorModifier"].lower()]
        expected = {a["key"].lower(): a for a in operator["allowances"] if a["key"].startswith("0x6b3a")}
        self.assertEqual(len(expected), 2)
        writes_ = writes("caps", self.manifest)
        self.assertEqual(len(writes_), 2)
        for _, role, to, data in writes_:
            self.assertEqual((role, to.lower()), ("governance", self.manifest["operatorModifier"].lower()))
            key, balance, max_refill, refill, period, timestamp = subprocess.check_output(
                ["cast", "decode-calldata", "setAllowance(bytes32,uint128,uint128,uint128,uint64,uint64)", data], text=True).split("\n")[:6]
            balance, max_refill, refill, period, timestamp = (v.split()[0] for v in (balance, max_refill, refill, period, timestamp))
            cap = expected.pop(key.lower())
            self.assertEqual([balance, max_refill, refill, period, timestamp],
                             [cap["balance"], cap["maxRefill"], cap["refill"], cap["period"], cap["timestamp"]])
        self.assertEqual(expected, {})


if __name__ == "__main__":
    unittest.main()
