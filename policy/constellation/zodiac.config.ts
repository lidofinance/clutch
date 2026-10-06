// SPDX-License-Identifier: LGPL-3.0-only
// Modified for Clutch on 2026-10-06: no contracts for the `allow` kit. See PROVENANCE.md.
import { defineConfig } from "@zodiaceco/sdk/cli/config";

/**
 * Contracts that the `allow` kit generates typed permissions for.
 *
 * Clutch writes its permissions with explicit function signatures
 * (`constellation/lib.ts`), so it needs no generated kit and no ABI files.
 * The fork tests catch a wrong signature, because the call it should permit
 * fails.
 */
export default defineConfig({
  contracts: {},
});
