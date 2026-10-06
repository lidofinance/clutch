// SPDX-License-Identifier: AGPL-3.0-or-later
import { manifest } from "../../addresses";

// The Emergency Brakes multisig, 3 of 5 (ADR 005, decision 3).
export default [manifest.emergencyBrakes as `0x${string}`] satisfies Members;
