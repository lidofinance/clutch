// SPDX-License-Identifier: AGPL-3.0-or-later
import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import path from "node:path";
import { compileManifest, refuseHosted, render } from "./compile";

const ROOT = path.resolve(import.meta.dir, "..");
const MANIFEST = path.join(ROOT, "manifests/fork-25946643.json");
const ARTIFACT = path.join(ROOT, "artifacts/fork-25946643.json");
const APPROVE = "0x095ea7b3";
const EQUAL_TO = 16;
const LESS_THAN = 18;
const WITHIN_ALLOWANCE = 28;

const artifact = await compileManifest(MANIFEST);
const role = (name: string) => artifact.modifiers.flatMap((m) => m.roles).find((r) => r.name === name)!;
const approvals = (name: string) =>
  role(name).targets.flatMap((t) => t.functions.filter((f) => f.selector === APPROVE).map((f) => ({ token: t.address, f })));

test("refuses an entry that only the hosted app can compile", () => {
  const swap = { label: "swap", action: { type: "swap", sell: [], buy: [] } };
  const preset = { label: "preset", annotation: "https://example.org/permissions" };
  expect(() => refuseHosted("action", swap)).toThrow(/only the hosted app/);
  expect(() => refuseHosted("preset", preset)).toThrow(/only the hosted app/);
  expect(() => refuseHosted("ref", { targetAddress: "$asset_safe", selector: APPROVE })).toThrow(/node reference/);
});

test("the committed artifact equals a fresh compile", () => {
  expect(readFileSync(ARTIFACT, "utf8")).toBe(render(artifact));
});

test("a compile is deterministic", async () => {
  expect(render(await compileManifest(MANIFEST))).toBe(render(artifact));
});

test("every operator approval spends a budget key or stays below a ceiling", () => {
  // In every Matches branch of approve(spender, amount), the second child
  // bounds the amount. The SDK may merge spenders that share a bound into one
  // branch, which keeps this true.
  const MATCHES = 5;
  for (const { f } of approvals("operator")) {
    const branches = f.conditions.flatMap((n, i) => (n.operator === MATCHES ? [i] : []));
    expect(branches.length).toBeGreaterThan(0);
    for (const b of branches) {
      const children = f.conditions.filter((n, i) => i !== b && n.parent === b);
      expect(children.length).toBe(2);
      expect([WITHIN_ALLOWANCE, LESS_THAN]).toContain(children[1].operator);
    }
  }
});

test("the emergency role can zero every approval the operator can give", () => {
  const spendersOf = (name: string) =>
    new Set(
      approvals(name).flatMap(({ f }) =>
        f.conditions.filter((n) => n.operator === EQUAL_TO && n.compValue !== "0x" + "0".repeat(64)).map((n) => n.compValue),
      ),
    );
  const operatorTokens = new Set(approvals("operator").map(({ token }) => token));
  const emergencyTokens = new Set(approvals("emergency").map(({ token }) => token));
  for (const token of operatorTokens) expect(emergencyTokens.has(token)).toBe(true);
  const emergencySpenders = spendersOf("emergency");
  for (const spender of spendersOf("operator")) expect(emergencySpenders.has(spender)).toBe(true);
});
