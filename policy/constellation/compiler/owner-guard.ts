// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * The hosted Zodiac app is outside Clutch's path (ADR 004, decisions 11 and 16). Only a
 * member of the repository-owner team pushes to it or pulls from it, from a clean checkout
 * of the merged `main`, with the API key in a local `.env`. Agents and CI never do
 * (AGENTS.md, ADR 012). Every package script that calls the hosted app runs this guard
 * first, and the guard refuses unless that member asks for the call.
 */

export function refusals(env: Record<string, string | undefined>, branch: string, dirty: boolean): string[] {
  const reasons: string[] = [];
  if (env.CLUTCH_OWNER_PUSH !== "1") {
    reasons.push("set CLUTCH_OWNER_PUSH=1 to confirm that you are a member of the repository-owner team");
  }
  if (env.CI) reasons.push("CI never calls the hosted app");
  if (branch !== "main") reasons.push(`check out main, not ${branch || "a detached HEAD"}`);
  if (dirty) reasons.push("commit or remove the local changes first");
  return reasons;
}

if (import.meta.main) {
  const git = (...args: string[]) => Bun.spawnSync(["git", ...args]).stdout.toString().trim();
  const reasons = refusals(process.env, git("rev-parse", "--abbrev-ref", "HEAD"), git("status", "--porcelain") !== "");
  if (reasons.length > 0) {
    console.error(`Refused: this script calls the hosted Zodiac app (ADR 004, decision 16): ${reasons.join("; ")}.`);
    process.exit(1);
  }
}
