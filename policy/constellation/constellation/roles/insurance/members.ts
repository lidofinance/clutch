// SPDX-License-Identifier: AGPL-3.0-or-later
import { manifest } from "../../addresses";

// The universal factory: an insurance deposit runs only as an enacted motion
// of the factory (ADR 014, decision 12; ADR 013, decision 18).
export default [manifest.universalFactory as `0x${string}`] satisfies Members;
