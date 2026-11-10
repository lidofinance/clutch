// SPDX-License-Identifier: AGPL-3.0-or-later
import { manifest } from "../../addresses";

// The universal factory: a restart runs only as an enacted motion of the
// factory, after the objection window (ADR 013, decisions 12 and 18).
export default [manifest.universalFactory as `0x${string}`] satisfies Members;
