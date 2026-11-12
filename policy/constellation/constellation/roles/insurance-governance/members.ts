// SPDX-License-Identifier: AGPL-3.0-or-later
import { manifest } from "../../addresses";

// The universal factory: a fund is created only by an enacted motion of the
// factory (ADR 014, decision 6; ADR 013, decision 18).
export default [manifest.universalFactory as `0x${string}`] satisfies Members;
