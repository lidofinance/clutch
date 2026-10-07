// SPDX-License-Identifier: AGPL-3.0-or-later
import { describe, expect, test } from "bun:test";
import { refusals } from "./owner-guard";

describe("owner guard for the hosted-app scripts (ADR 012)", () => {
  test("an owner on a clean main may call the hosted app", () => {
    expect(refusals({ CLUTCH_OWNER_PUSH: "1" }, "main", false)).toEqual([]);
  });
  test("refuses without the owner's confirmation", () => {
    expect(refusals({}, "main", false).join()).toContain("CLUTCH_OWNER_PUSH=1");
  });
  test("refuses in CI, even with the confirmation", () => {
    expect(refusals({ CLUTCH_OWNER_PUSH: "1", CI: "true" }, "main", false).join()).toContain("CI never calls");
  });
  test("refuses outside main", () => {
    expect(refusals({ CLUTCH_OWNER_PUSH: "1" }, "decisions/x", false).join()).toContain("check out main");
  });
  test("refuses with local changes", () => {
    expect(refusals({ CLUTCH_OWNER_PUSH: "1" }, "main", true).join()).toContain("local changes");
  });
});
