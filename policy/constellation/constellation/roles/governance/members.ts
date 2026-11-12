// SPDX-License-Identifier: AGPL-3.0-or-later
import { manifest } from "../../addresses";

// The universal factory. An enacted motion's one call makes the motion's writes
// as this role (ADR 013, decision 18), so Easy Track needs no authority on the
// Aragon Agent (ADR 006).
export default [manifest.universalFactory as `0x${string}`] satisfies Members;
