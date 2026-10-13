// SPDX-License-Identifier: LGPL-3.0-only
// Modified for Clutch on 2026-10-06: the holder is the emergency Safe, the
// committee's signers at 2 of 7 (ADR 005, decisions 1 and 16). See PROVENANCE.md.
// Changed for Clutch on 2026-10-13: the emergency Safe is three of five, two
// committee members, two Emergency Brakes members and one member of neither
// body (ADR 005, decision 24).
import { manifest } from "../../addresses";

export default [manifest.emergencySafe as `0x${string}`] satisfies Members;
