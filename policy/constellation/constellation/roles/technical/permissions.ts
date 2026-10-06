// SPDX-License-Identifier: AGPL-3.0-or-later
import { call } from "../../lib";
import { manifest } from "../../addresses";

/**
 * The technical role's one power: disable the operator modifier (ADR 005).
 * The module argument is pinned to that modifier, so the power cannot reach
 * the safety modifier or a later module. The first argument is a pointer in
 * the Safe's module list whose value depends on that list at call time, so it
 * stays open.
 */
export default [
  call(manifest.assetSafe, "disableModule(address,address)", undefined, manifest.operatorModifier),
] satisfies Permissions;
