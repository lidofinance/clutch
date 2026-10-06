// SPDX-License-Identifier: LGPL-3.0-only
// Modified for Clutch on 2026-10-06: the holder is the operator Safe
// (ADR 005, decision 7). See PROVENANCE.md.
import { manifest } from "../../addresses";

// The operator Safe is the only member: the committee's signers, 4 of 7, with
// the screening guard (ADR 005, ADR 010). Signers rotate inside that Safe, so
// a rotation never touches this role.
export default [manifest.operatorSafe as `0x${string}`] satisfies Members;
