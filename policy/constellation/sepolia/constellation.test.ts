// SPDX-License-Identifier: AGPL-3.0-or-later
import { expect, test } from "bun:test";
import { getAddress } from "ethers";
import { capturePayload, checkPayload, createNodes } from "./constellation";
import { constellation as sdkConstellation } from "@zodiaceco/sdk";
import { call, c } from "../constellation/lib";
import network from "./network.json";

const workspace = "11111111-1111-4111-8111-111111111111";
const names = ["assetSafe", "ordersSafe", "firstLossSafe", "operatorSafe", "emergencySafe", "operatorModifier", "safetyModifier", "ordersModifier", "firstLossModifier", "easyTrackExecutor", "agent", "usdQueue", "ethQueue", "usdShare", "ethShare"];
const manifest: Record<string, any> = { network: "sepolia", chainId: 11155111, dependencies: network };
names.forEach((name, i) => manifest[name] = getAddress("0x" + (i + 256).toString(16).padStart(40, "0")));
manifest.modules = [manifest.operatorModifier, manifest.safetyModifier];

test("real SDK capture binds only existing accounts and preserves original role keys", async () => {
  const fetch = globalThis.fetch;
  globalThis.fetch = (() => { throw new Error("Network forbidden"); }) as unknown as typeof fetch;
  try {
    const { payload, workspace: capturedWorkspace } = await capturePayload(createNodes(manifest, workspace));
    expect(capturedWorkspace).toBe(workspace);
    expect(payload.specification).toHaveLength(7);
    expect(payload.specification.every((n: any) => n.address && n.chain === 11155111 && !("nonce" in n))).toBe(true);
    const safes = payload.specification.filter((n: any) => n.type === "SAFE");
    expect(safes.map((n: any) => n.address)).toEqual([manifest.assetSafe, manifest.ordersSafe, manifest.firstLossSafe].map((a) => a.toLowerCase()));
    safes.forEach((n: any) => expect(Object.keys(n).sort()).toEqual(["address", "chain", "label", "ref", "type"]));
    const roles = payload.specification.filter((n: any) => n.type === "ROLES");
    expect(roles.map((n: any) => Object.keys(n.roles))).toEqual([["operator", "governance"], ["emergency"], ["operator", "emergency"], ["first-loss", "first-loss-burn"]]);
    expect(roles.map((n: any) => n.avatar)).toEqual(["$asset_safe", "$asset_safe", "$orders_safe", "$first_loss_safe"]);
    expect(checkPayload(payload, manifest).calls.to).toHaveLength(63);
  } finally { globalThis.fetch = fetch; }
});

test("serializer preserves the transfer recipient and allowance instead of dropping callback conditions", async () => {
  const { payload } = await capturePayload(createNodes(manifest, workspace));
  const transfer = payload.specification.find((n: any) => n.ref === "operator_modifier").roles.operator.permissions[0];
  expect(transfer.selector).toBe("0xa9059cbb");
  expect(transfer.condition.paramType).toBe(5);
  expect(transfer.condition.operator).toBe(5);
  expect(transfer.condition.children[0].compValue).toBe("0x" + manifest.ordersSafe.slice(2).toLowerCase().padStart(64, "0"));
  expect(transfer.condition.children[1].operator).toBe(28);
  const corrupted = structuredClone(payload);
  delete corrupted.specification.find((n: any) => n.ref === "operator_modifier").roles.operator.permissions[0].condition;
  expect(() => checkPayload(corrupted, manifest)).toThrow("differs");
});

test("governance export preserves Nor in the legacy format accepted by the captured resolver", async () => {
  const { payload } = await capturePayload(createNodes(manifest, workspace));
  const governance = payload.specification.find((n: any) => n.ref === "operator_modifier").roles.governance;
  expect(governance.permissions).toBeUndefined();
  expect(governance.key).toBe("governance");
  expect(governance.members).toEqual([manifest.easyTrackExecutor.toLowerCase()]);
  expect(governance.annotations).toEqual([]);
  expect(governance.targets).toHaveLength(1);
  expect(governance.targets[0].functions).toHaveLength(6);
  const protectedValues = names.slice(0, 9).map((name) => "0x" + manifest[name].slice(2).toLowerCase().padStart(64, "0")).sort();
  const refusals = governance.targets[0].functions.flatMap((fn: any) => fn.condition?.children?.[1]?.operator === 3 ? [fn.condition.children[1]] : []);
  expect(refusals).toHaveLength(5);
  for (const refusal of refusals) {
    expect(refusal.children.map((c: any) => c.compValue).sort()).toEqual(protectedValues);
    expect(refusal.children.every((c: any) => c.operator === 16)).toBe(true);
  }
  expect(checkPayload(payload, manifest).calls.to).toHaveLength(63);
});

test("legacy governance readback refuses altered scopes and annotation-based permissions", async () => {
  const { payload } = await capturePayload(createNodes(manifest, workspace));
  const changed = (mutate: (role: any) => void) => {
    const copy = structuredClone(payload);
    mutate(copy.specification.find((n: any) => n.ref === "operator_modifier").roles.governance);
    return copy;
  };
  expect(() => checkPayload(changed((role) => role.targets[0].functions.pop()), manifest)).toThrow();
  expect(() => checkPayload(changed((role) => role.annotations = [{ uri: "https://example.invalid/permissions" }]), manifest)).toThrow("empty annotations");
  expect(() => checkPayload(changed((role) => delete role.annotations), manifest)).toThrow("empty annotations");
  expect(() => checkPayload(changed((role) => role.permissions = []), manifest)).toThrow("no permissions");
});

test("rejects deployment nonces, Safe overrides, unresolved refs and invalid workspace", async () => {
  const { payload } = await capturePayload(createNodes(manifest, workspace));
  const changed = (mutate: (p: any) => void) => { const p = structuredClone(payload); mutate(p); return p; };
  expect(() => checkPayload(changed((p) => p.specification[0].nonce = "0"), manifest)).toThrow("existing");
  expect(() => checkPayload(changed((p) => p.specification[0].modules = []), manifest)).toThrow("overrides");
  expect(() => checkPayload(changed((p) => p.specification[3].owner = "$missing"), manifest)).toThrow("Unresolved");
  expect(() => checkPayload(changed((p) => p.specification[3].owner = manifest.operatorSafe), manifest)).toThrow("differs");
  expect(() => checkPayload(changed((p) => p.specification[3].multisend = [manifest.operatorSafe]), manifest)).toThrow("unwrappers");
  expect(() => createNodes(manifest, "")).toThrow("UUID");
});

test("upstream callback serialization failure is reproducible with the pinned SDK", async () => {
  const sep = sdkConstellation({ workspace, label: "probe", chain: 11155111 }, { codegen: { users: {}, accounts: {} } as any });
  const node = sep.roles.probe({ address: manifest.operatorModifier, roles: { operator: {
    members: [manifest.operatorSafe], permissions: [call(manifest.dependencies.tokens.usdc.address, "transfer(address,uint256)", manifest.ordersSafe, c.withinAllowance("orders_usdc"))],
  } } });
  const { payload } = await capturePayload({ node } as any);
  expect(payload.specification[0].roles.operator.permissions[0].condition).toBeUndefined();
});

test("keeps observed allowance balances and timestamps instead of resetting budgets", async () => {
  const runtime = ["orders_weth", "orders_usdc"].map((name, i) => ({
    modifier: manifest.operatorModifier, key: "0x" + Buffer.from(name).toString("hex").padEnd(64, "0"), balance: String(700 - i), timestamp: "1792512000",
  }));
  const { payload } = await capturePayload(createNodes(manifest, workspace, runtime));
  const allowances = payload.specification.find((n: any) => n.ref === "operator_modifier").allowances;
  expect(allowances.orders_weth.key).toBe("orders_weth");
  expect(allowances.orders_weth.balance).toBe("700");
  expect(allowances.orders_weth.timestamp).toBe("1792512000");
  expect(checkPayload(payload, manifest, runtime).calls.to).toHaveLength(63);
  expect(() => checkPayload(payload, manifest, runtime.map((a) => ({ ...a, balance: "1" })))).toThrow("differs");
  expect(() => checkPayload(payload, manifest)).toThrow("differs");
  expect(() => createNodes(manifest, workspace, [])).toThrow("Missing allowance");
});
