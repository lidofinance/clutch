// SPDX-License-Identifier: LGPL-3.0-only
// Modified for Clutch on 2026-10-06: the holder is the operator Safe
// (ADR 005, decision 7). See PROVENANCE.md.
// Changed for Clutch on 2026-10-14: the holder is the committee's own Safe
// (ADR 005, decision 31).
import { manifest } from "../../addresses";

// The committee's own Safe is the only member, at 4 of 7 (ADR 005, decision
// 31). The manifest keeps the key `operatorSafe` for the role's holder.
// Signers rotate inside that Safe, so a rotation never touches this role.
export default [manifest.operatorSafe as `0x${string}`] satisfies Members;
