// SPDX-License-Identifier: LGPL-3.0-only
import { createRequire } from "node:module";
import path from "node:path";
import { constellation as sdkConstellation } from "@zodiaceco/sdk";

// Lazy codegen load: if `bun pull-org` hasn't been run, fall back to an empty
// stub so `push` still works for constellations that don't reference
// existing workspace vaults or users. Referenced entries will throw at use.
const requireCodegen = createRequire(import.meta.url);
// Modified for Clutch on 2026-10-06: the stub gains `accounts`, which
// @zodiaceco/sdk 2.1.2 reads. See PROVENANCE.md.
const emptyCodegen = { users: {}, vaults: {}, accounts: {} } as const;
let cached: unknown;
const loadCodegen = () => {
  if (cached !== undefined) return cached;
  try {
    cached = requireCodegen(path.join(process.cwd(), ".zodiac"));
  } catch {
    cached = emptyCodegen;
  }
  return cached;
};

/**
 * Thin wrapper around `@zodiaceco/sdk`'s `constellation()` that pre-binds the
 * local codegen result, so callers don't have to thread it through.
 */
export const constellation: typeof sdkConstellation = ((
  opts: any,
  internal?: any,
) =>
  sdkConstellation(opts, {
    codegen: loadCodegen() as any,
    ...internal,
  })) as typeof sdkConstellation;
