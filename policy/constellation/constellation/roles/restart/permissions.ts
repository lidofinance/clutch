// SPDX-License-Identifier: AGPL-3.0-or-later
import { call } from "../../lib";
import { manifest } from "../../addresses";

/**
 * The restart after the emergency switch (ADR 013, decision 12): enable the
 * operator modifier again on the Asset Safe. The module argument is pinned to
 * that modifier, so the role cannot enable any other module. The role sits on
 * the safety modifier, which stays enabled when the switch disables the
 * operator modifier. No emergency body holds it: the emergency role only
 * removes authority (ADR 005, decision 26), and the compiler checks both.
 */
export default [call(manifest.assetSafe, "enableModule(address)", manifest.operatorModifier)] satisfies Permissions;
