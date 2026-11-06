// SPDX-License-Identifier: AGPL-3.0-or-later
import { manifest } from "../../addresses";

// The Easy Track script executor: a restart runs only as an enacted motion of
// the universal factory, after the objection window (ADR 013, decision 12).
export default [manifest.easyTrackExecutor as `0x${string}`] satisfies Members;
