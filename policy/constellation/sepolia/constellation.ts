// SPDX-License-Identifier: AGPL-3.0-or-later
import { constellation, push } from "@zodiaceco/sdk";
import { processPermissions, reconstructPermissions } from "zodiac-roles-sdk";
import { build, buildNodes } from "./compile";
import { compile } from "../compiler/compile";
import { key } from "../constellation/lib";

export type RuntimeAllowance = { modifier: string; key: string; balance: string; timestamp: string };

function policyNodes(manifest: Record<string, any>, runtime?: RuntimeAllowance[]) {
  const nodes = buildNodes(manifest);
  if (runtime) for (const node of Object.values(nodes)) for (const [name, allowance] of Object.entries(node.allowances) as [string, any][]) {
    const current = runtime.find((a) => a.modifier.toLowerCase() === node.address.toLowerCase() && a.key.toLowerCase() === key(name));
    if (!current) throw new Error(`Missing allowance readback: ${name}`);
    allowance.balance = BigInt(current.balance);
    allowance.timestamp = BigInt(current.timestamp);
  }
  return nodes;
}

/** Bind existing accounts. Safe configuration stays outside this declaration. */
export function createNodes(manifest: Record<string, any>, workspace: string, runtime?: RuntimeAllowance[]): Record<string, any> {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(workspace)) throw new Error("A Zodiac workspace UUID is required");
  build(manifest);
  const sep = constellation({ workspace, label: "Clutch Sepolia", chain: 11155111 }, {
    codegen: { users: {}, accounts: { [workspace]: { workspaceId: workspace as `${string}-${string}-${string}-${string}-${string}`, workspaceName: workspace, safes: {}, rolesMods: {}, delays: {} } } },
  });
  const asset_safe = sep.safe["Clutch Sepolia — Asset"]({ address: manifest.assetSafe, vault: true });
  const orders_safe = sep.safe["Clutch Sepolia — Orders"]({ address: manifest.ordersSafe, vault: true });
  const first_loss_safe = sep.safe["Clutch Sepolia — First-loss"]({ address: manifest.firstLossSafe, vault: true });
  const safes = [asset_safe, orders_safe, first_loss_safe];
  const roles = Object.fromEntries(Object.entries(policyNodes(manifest, runtime)).map(([ref, node]) => {
    const safe = safes.find((item) => item.address!.toLowerCase() === node.avatar.toLowerCase())!;
    return [ref, sep.roles[`Clutch Sepolia — ${ref}`]({
      ...node, address: node.address as `0x${string}`, owner: safe, avatar: safe, target: safe, multisend: [],
      // The API requires each allowance to repeat its record key; the SDK does not add it.
      allowances: Object.fromEntries(Object.entries(node.allowances).map(([name, allowance]: [string, any]) => [name, { ...allowance, key: name }])),
      roles: Object.fromEntries(Object.entries(node.roles).map(([name, role]: [string, any]) => [name, {
        members: role.members as `0x${string}`[],
        policy: `Clutch Sepolia — ${name}`,
        permissions: role.permissions,
      }])),
    })];
  }));
  return { asset_safe, orders_safe, first_loss_safe, ...roles };
}

/** Capture SDK output locally; retain Nor through the accepted legacy role format. */
export async function capturePayload(nodes: ReturnType<typeof createNodes>) {
  let captured: { workspace: string; payload: any } | undefined;
  await push(nodes, { api: {
    applyConstellation: async (workspace: string, payload: unknown) => {
      if (captured) throw new Error("Expected one Sepolia constellation");
      captured = { workspace, payload };
      return { url: "local:captured" };
    },
  } as any });
  if (!captured) throw new Error("SDK produced no constellation payload");
  const result = JSON.parse(JSON.stringify(captured));
  // SDK 2.1.2 emits permissions only. The captured API resolver accepts Nor
  // through targets with empty annotations (Sepolia deployment findings, s18).
  for (const node of result.payload.specification) {
    const governance = node.roles?.governance;
    if (!governance) continue;
    Object.assign(governance, processPermissions(governance.permissions));
    delete governance.permissions;
  }
  return result;
}

/** Recompile what survives JSON serialization, including node references. */
export function checkPayload(payload: any, manifest: Record<string, any>, runtime?: RuntimeAllowance[]) {
  const refs = Object.fromEntries(payload.specification.map((node: any) => [node.ref, node.address]));
  function resolve(value: any): any {
    if (typeof value === "string" && value.startsWith("$")) {
      if (!refs[value.slice(1)]) throw new Error(`Unresolved reference: ${value}`);
      return refs[value.slice(1)];
    }
    if (Array.isArray(value)) return value.map(resolve);
    if (value && typeof value === "object") return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, resolve(v)]));
    return value;
  }
  if (payload.chain !== 11155111 || payload.specification.some((node: any) => node.chain !== 11155111 || !node.address || "nonce" in node)) throw new Error("Only existing Sepolia accounts may be bound");
  for (const node of payload.specification.filter((item: any) => item.type === "SAFE")) {
    if (Object.keys(node).some((field) => !["ref", "type", "label", "chain", "address", "vault"].includes(field))) throw new Error("Safe configuration overrides refused");
    if (node.vault !== true) throw new Error("Each Safe must be a workspace vault");
  }
  for (const node of payload.specification.filter((item: any) => item.type === "ROLES")) for (const [name, role] of Object.entries(node.roles) as [string, any][]) {
    if (role.key !== name) throw new Error(`${node.ref}.${name}: role key differs`);
    if (role.policy !== `Clutch Sepolia — ${name}`) throw new Error(`${node.ref}.${name}: policy label differs`);
  }
  const nodes = Object.fromEntries(payload.specification.filter((node: any) => node.type === "ROLES").map((node: any) => [node.ref, resolve(node)]));
  if (Object.values(nodes).some((node: any) => JSON.stringify(node.multisend) !== "[]")) throw new Error("Unexpected transaction unwrappers");
  for (const node of Object.values(nodes) as any[]) for (const role of Object.values(node.roles) as any[]) {
    if (role.targets === undefined) continue;
    if (role.permissions !== undefined || JSON.stringify(role.annotations) !== "[]") throw new Error("Legacy targets require empty annotations and no permissions");
    role.permissions = reconstructPermissions(role.targets);
  }
  const candidate = compile(nodes, manifest, {});
  const expected = compile(policyNodes(manifest, runtime), manifest, {});
  const wiring = (artifact: typeof candidate) => artifact.modifiers.map(({ ref, address, owner, avatar, target }) => ({ ref, address, owner, avatar, target }));
  if (JSON.stringify(candidate.calls) !== JSON.stringify(expected.calls) || JSON.stringify(wiring(candidate)) !== JSON.stringify(wiring(expected))) throw new Error("Serialized constellation differs from the Sepolia policy");
  return expected;
}

/** Zodiac requires one policy definition per key and at most one modifier per Safe. */
export function workspacePolicyIssues(payload: any): string[] {
  const refs = new Map(payload.specification.map((n: any) => [`$${n.ref}`, n.address]));
  const seen = new Map<string, { ref: string; avatars: Set<string>; definition: string }>();
  const issues: string[] = [];
  for (const node of payload.specification.filter((n: any) => n.type === "ROLES")) for (const [key, role] of Object.entries(node.roles) as [string, any][]) {
    if (!role?.policy) continue;
    const avatar = String(refs.get(node.avatar) ?? node.avatar).toLowerCase();
    const definition = JSON.stringify({ policy: role.policy, description: role.description,
      members: role.members.map((m: string) => m.toLowerCase()).sort(),
      targets: role.targets ?? processPermissions(role.permissions).targets,
    });
    const previous = seen.get(key);
    if (previous?.definition !== undefined && previous.definition !== definition) issues.push(`${key}: policy grants differ between ${previous.ref} and ${node.ref}`);
    if (previous?.avatars.has(avatar)) issues.push(`${key}: two policy modifiers act for the same Safe`);
    if (previous) previous.avatars.add(avatar);
    else seen.set(key, { ref: node.ref, avatars: new Set([avatar]), definition });
  }
  return issues;
}
