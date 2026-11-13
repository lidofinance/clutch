// SPDX-License-Identifier: AGPL-3.0-or-later
import { readFileSync } from "node:fs";
import path from "node:path";
import { checkPayload, createNodes, capturePayload } from "./constellation";

const root = path.resolve(import.meta.dir, "../../..");
const context = JSON.parse(readFileSync(path.join(root, "cache/sepolia/constellation/context.json"), "utf8"));
const nodes = createNodes(context.manifest, context.workspace, context.allowances);
checkPayload((await capturePayload(nodes)).payload, context.manifest, context.allowances);

export const { asset_safe, orders_safe, first_loss_safe } = nodes;
export const operator_modifier = nodes.operator_modifier;
export const safety_modifier = nodes.safety_modifier;
export const orders_modifier = nodes.orders_modifier;
export const first_loss_modifier = nodes.first_loss_modifier;
