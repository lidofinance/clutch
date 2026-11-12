// SPDX-License-Identifier: AGPL-3.0-or-later
import { manifest } from "../../addresses";

// The universal factory: a first-loss burn runs only as an enacted motion of
// the factory, so it waits for the objection window (ADR 008, decision 23;
// ADR 013, decision 18).
export default [manifest.universalFactory as `0x${string}`] satisfies Members;
