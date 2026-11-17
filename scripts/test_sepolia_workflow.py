#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Offline checks for the Sepolia runners."""
import unittest

from sepolia_rehearse import validate_drills


def suite(passed, summary=None):
    names = [f"test_{i}" for i in range(passed)]
    return "\n".join(f"[PASS] {name}() (gas: 123)" for name in names) + "\nSuite result: " + (summary or f"ok. {passed} passed; 0 failed; 0 skipped")


class DrillResults(unittest.TestCase):
    def test_green_suites(self):
        validate_drills(suite(7))
        validate_drills(suite(3) + "\n" + suite(4), suites=2)

    def test_refuses_empty_failed_skipped_missing_or_miscounted_suites(self):
        for output, suites in [
            (suite(0, "ok. 0 passed; 0 failed; 0 skipped"), 1),
            (suite(6, "ok. 6 passed; 0 failed; 1 skipped"), 1),
            (suite(6, "FAILED. 6 passed; 1 failed; 0 skipped"), 1),
            (suite(7).split("\nSuite result:")[0], 1),
            (suite(7, "ok. 8 passed; 0 failed; 0 skipped"), 1),
            (suite(7), 2),
            (suite(7) + "\n[FAIL: x] test_x() (gas: 1)", 1),
        ]:
            with self.subTest(output=output[-60:], suites=suites), self.assertRaises(ValueError):
                validate_drills(output, suites=suites)


if __name__ == "__main__":
    unittest.main()
