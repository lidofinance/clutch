// SPDX-License-Identifier: AGPL-3.0-or-later
import { manifest } from "../../addresses";

// The universal factory: an enacted motion's one call acts as this role (ADR 006, decision 13; ADR 013, decision 18).
export default [manifest.universalFactory as `0x${string}`] satisfies Members;
