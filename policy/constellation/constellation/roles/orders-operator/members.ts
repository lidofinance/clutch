// SPDX-License-Identifier: AGPL-3.0-or-later
import { manifest } from "../../addresses";

// The committee's own Safe, as on the operator modifier (ADR 005, decision 31).
export default [manifest.operatorSafe as `0x${string}`] satisfies Members;
