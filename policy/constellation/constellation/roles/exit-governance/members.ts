// SPDX-License-Identifier: AGPL-3.0-or-later
import { manifest } from "../../addresses";

// The Easy Track script executor: an enacted motion acts as this role (ADR 006, decision 13; OD-49).
export default [manifest.easyTrackExecutor as `0x${string}`] satisfies Members;
