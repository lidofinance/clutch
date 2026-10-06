// SPDX-License-Identifier: LGPL-3.0-only
// Modified for Clutch on 2026-10-06: the holder is the emergency Safe, the
// committee's signers at 2 of 7 (ADR 005, decisions 1 and 16). See PROVENANCE.md.
import { manifest } from "../../addresses";

export default [manifest.emergencySafe as `0x${string}`] satisfies Members;
