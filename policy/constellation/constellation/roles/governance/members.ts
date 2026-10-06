// SPDX-License-Identifier: AGPL-3.0-or-later
import { manifest } from "../../addresses";

// The Easy Track script executor. An enacted motion acts as this role, so
// Easy Track needs no authority on the Aragon Agent (ADR 006).
export default [manifest.easyTrackExecutor as `0x${string}`] satisfies Members;
