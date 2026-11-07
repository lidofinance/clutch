// SPDX-License-Identifier: AGPL-3.0-or-later
import { manifest } from "../../addresses";

// The Easy Track script executor: insurance money moves only as an enacted
// motion of the universal factory (ADR 014, decision 7).
export default [manifest.easyTrackExecutor as `0x${string}`] satisfies Members;
