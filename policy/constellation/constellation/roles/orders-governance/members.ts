// SPDX-License-Identifier: AGPL-3.0-or-later
import { manifest } from "../../addresses";

// The Easy Track script executor, as on the operator modifier: an enacted motion acts as this role (ADR 007,
// decision 41).
export default [manifest.easyTrackExecutor as `0x${string}`] satisfies Members;
