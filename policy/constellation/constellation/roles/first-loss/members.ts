// SPDX-License-Identifier: AGPL-3.0-or-later
import { manifest } from "../../addresses";

// The committee's own Safe, at 4 of 7: it executes the first-loss terms on
// the Earn team's written instruction (ADR 008, decisions 21 and 22). The
// manifest keeps the key `operatorSafe` for that Safe.
export default [manifest.operatorSafe as `0x${string}`] satisfies Members;
