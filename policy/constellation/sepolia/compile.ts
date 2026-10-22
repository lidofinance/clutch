// SPDX-License-Identifier: AGPL-3.0-or-later
import { readFileSync, writeFileSync } from "node:fs";
import { getAddress, id, ZeroHash } from "ethers";
import { compile, checkProtected, unguarded } from "../compiler/compile";
import { anyOf, c, call, key, noneOf } from "../constellation/lib";

const ORDER = "(address,address,address,uint256,uint256,uint32,bytes32,uint256,bytes32,bool,bytes32,bytes32)";
const SIGN = `signOrder(${ORDER},uint32,uint256)`;
const UNSIGN = `unsignOrder(${ORDER})`;
const TWAP_TYPES = ["address", "address", "address", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "bytes32"];
const PERIOD = 30n * 86400n;

export const ROLE_MIGRATION = [
  ["operator_modifier", "operator", "asset-operator"],
  ["safety_modifier", "emergency", "asset-emergency"],
  ["orders_modifier", "operator", "orders-operator"],
  ["orders_modifier", "emergency", "orders-emergency"],
] as const;

/** Test-only profile: two swap assets and two synthetic first-loss positions. */
export function buildNodes(manifest: Record<string, any>) {
  if (manifest.chainId !== 11155111 || manifest.network !== "sepolia" || manifest.dependencies?.chainId !== 11155111) throw new Error("Sepolia manifest required");
  const m = manifest;
  if (m.roleKeyScheme !== undefined && m.roleKeyScheme !== "account") throw new Error("Unknown Sepolia role-key scheme");
  const accountKeys = m.roleKeyScheme === "account";
  const assetOperator = accountKeys ? "asset-operator" : "operator";
  const ordersOperator = accountKeys ? "orders-operator" : "operator";
  const assetEmergency = accountKeys ? "asset-emergency" : "emergency";
  const ordersEmergency = accountKeys ? "orders-emergency" : "emergency";
  const d = (name: string) => m.dependencies.contracts[name].address as string;
  const tokens = [m.dependencies.tokens.weth.address, m.dependencies.tokens.usdc.address] as string[];
  const allSafes = [m.assetSafe, m.ordersSafe, m.firstLossSafe, m.operatorSafe, m.emergencySafe];
  const allModules = [m.operatorModifier, m.safetyModifier, m.ordersModifier, m.firstLossModifier];
  const protectedAccounts = [...allSafes, ...allModules];
  if (new Set(protectedAccounts.map((a) => a.toLowerCase())).size !== protectedAccounts.length) throw new Error("Account addresses must differ");
  const notAdmin = noneOf(...protectedAccounts);
  const allowance = (amount: bigint) => ({ balance: amount, maxRefill: amount, refill: amount, period: PERIOD, timestamp: 0n });
  const role = (member: string, permissions: any[]) => ({ members: [member], permissions });
  const node = (address: string, avatar: string, roles: any, allowances = {}) => ({ type: "ROLES", address, owner: avatar, avatar, target: avatar, roles, allowances });
  const order = (receiver: string, buy = tokens) => c.matches([
    anyOf(tokens), anyOf(buy), receiver, c.gt(0n), c.gt(0n), undefined, ZeroHash,
    undefined, anyOf([id("sell"), id("buy")]), undefined, id("erc20"), id("erc20"),
  ] as any);
  const signer = (receiver: string, lifetime: bigint, buy = tokens) => ({
    ...call(d("orderSigner"), SIGN, order(receiver, buy), c.and(c.gt(0n), c.lte(lifetime)), c.lte(100n)),
    delegatecall: true,
  });
  const twap = (parts: bigint, spacing: bigint) => c.abiEncodedMatches([
    anyOf(tokens), anyOf(tokens), m.assetSafe, c.gt(0n), c.gt(0n), 0n,
    c.and(c.gt(1n), c.lte(parts)), c.and(c.gt(0n), c.lte(spacing)), 0n, ZeroHash,
  ] as any, TWAP_TYPES);
  const governance = [
    call(m.operatorModifier, "scopeTarget(bytes32,address)", key(assetOperator), notAdmin),
    call(m.operatorModifier, "revokeTarget(bytes32,address)", key(assetOperator), notAdmin),
    call(m.operatorModifier, "allowFunction(bytes32,address,bytes4,uint8)", key(assetOperator), notAdmin, undefined, c.lt(2)),
    call(m.operatorModifier, "revokeFunction(bytes32,address,bytes4)", key(assetOperator), notAdmin),
    call(m.operatorModifier, "scopeFunction(bytes32,address,bytes4,(uint8,uint8,uint8,bytes)[],uint8)", key(assetOperator), notAdmin, undefined, undefined, c.lt(2)),
    call(m.operatorModifier, "setAllowance(bytes32,uint128,uint128,uint128,uint64,uint64)", anyOf([key("orders_weth"), key("orders_usdc")]), undefined, undefined, undefined, c.gte(PERIOD)),
  ];
  const revoke = (modifier: string, roleKey: string) => [
    call(modifier, "revokeTarget(bytes32,address)", key(roleKey)),
    call(modifier, "revokeFunction(bytes32,address,bytes4)", key(roleKey)),
  ];
  const nodes = {
    operator_modifier: node(m.operatorModifier, m.assetSafe, {
      [assetOperator]: role(m.operatorSafe, tokens.map((token, i) => call(token, "transfer(address,uint256)", m.ordersSafe, c.withinAllowance(i ? "orders_usdc" : "orders_weth")))),
      governance: role(m.easyTrackExecutor, governance),
    }, { orders_weth: allowance(1n * 10n ** 18n), orders_usdc: allowance(1000n * 10n ** 6n) }),
    safety_modifier: node(m.safetyModifier, m.assetSafe, {
      [assetEmergency]: role(m.emergencySafe, [
        ...tokens.map((token) => call(token, "transfer(address,uint256)", anyOf([m.ordersSafe, m.agent]))),
        ...revoke(m.operatorModifier, assetOperator),
        call(m.assetSafe, "disableModule(address,address)", undefined, m.operatorModifier),
      ]),
    }),
    orders_modifier: node(m.ordersModifier, m.ordersSafe, {
      [ordersOperator]: role(m.operatorSafe, [
        signer(m.assetSafe, 90n * 86400n),
        { ...call(d("orderSigner"), UNSIGN, order(m.assetSafe)), delegatecall: true },
        call(d("composableCow"), "createWithContext((address,bytes32,bytes),address,bytes,bool)", c.matches([d("twap"), undefined, c.or(twap(90n, 86400n), twap(12n, 7n * 86400n))] as any), d("timestampFactory"), "0x", true),
        call(d("composableCow"), "remove(bytes32)"),
        ...tokens.map((token) => call(token, "transfer(address,uint256)", m.assetSafe)),
      ]),
      [ordersEmergency]: role(m.emergencySafe, [
        signer(m.agent, 86400n, [tokens[1]]),
        { ...call(d("orderSigner"), UNSIGN), delegatecall: true },
        call(d("composableCow"), "remove(bytes32)"),
        ...tokens.flatMap((token) => [
          call(token, "approve(address,uint256)", d("vaultRelayer"), 0n),
          call(token, "transfer(address,uint256)", anyOf([m.assetSafe, m.agent])),
        ]),
        ...revoke(m.ordersModifier, ordersOperator),
      ]),
    }),
    first_loss_modifier: node(m.firstLossModifier, m.firstLossSafe, {
      "first-loss": role(m.operatorSafe, [m.usdQueue, m.ethQueue].flatMap((queue) => [
        call(queue, "redeem(uint256)"), call(queue, "claim(address,uint32[])", m.agent),
      ])),
      "first-loss-burn": role(m.easyTrackExecutor, [m.usdShare, m.ethShare].map((token) => call(token, "burn(uint256)"))),
    }),
  };
  return nodes;
}

export function build(manifest: Record<string, any>) {
  const m = manifest;
  const nodes = buildNodes(m);
  const allSafes = [m.assetSafe, m.ordersSafe, m.firstLossSafe, m.operatorSafe, m.emergencySafe];
  const protectedAccounts = [...allSafes, m.operatorModifier, m.safetyModifier, m.ordersModifier, m.firstLossModifier];
  const names = Object.fromEntries(Object.entries(m).filter(([, value]) => typeof value === "string" && /^0x[0-9a-fA-F]{40}$/.test(value)).map(([name, value]) => [getAddress(value as string), name]));
  const artifact = compile(nodes, m, names);
  for (const [avatar, modules] of [[m.ordersSafe, [m.ordersModifier]], [m.firstLossSafe, [m.firstLossModifier]]] as [string, string[]][]) {
    checkProtected(artifact.modifiers, { assetSafe: avatar, modules });
  }
  const grants = new Set(["scopeTarget(bytes32,address)", "allowFunction(bytes32,address,bytes4,uint8)", "scopeFunction(bytes32,address,bytes4,(uint8,uint8,uint8,bytes)[],uint8)"].map((fn) => id(fn).slice(0, 10)));
  for (const modifier of artifact.modifiers) for (const r of modifier.roles) for (const target of r.targets) {
    if (protectedAccounts.some((a) => a.toLowerCase() === target.address.toLowerCase())) {
      const owner = allSafes.some((a) => a.toLowerCase() === target.address.toLowerCase()) ? target.address : artifact.modifiers.find((mod) => mod.address.toLowerCase() === target.address.toLowerCase())?.avatar;
      if (owner?.toLowerCase() !== modifier.avatar.toLowerCase()) throw new Error("Cross-account administration refused");
    }
    if (r.name === "governance") for (const fn of target.functions) {
      if (grants.has(fn.selector) && unguarded(fn.conditions, protectedAccounts).length) throw new Error("Governance leaves protected accounts unguarded");
    }
  }
  const avatars = new Map(artifact.modifiers.map((mod) => [mod.address, mod.avatar]));
  return { ...artifact, testOnly: true, calls: { ...artifact.calls, avatar: artifact.calls.to.map((to) => avatars.get(to)!) } };
}

if (import.meta.main) {
  const manifest = process.argv[2];
  const out = process.argv[3];
  if (!manifest || !out) throw new Error("usage: bun sepolia/compile.ts <manifest> <artifact>");
  const artifact = build(JSON.parse(readFileSync(manifest, "utf8")));
  writeFileSync(out, JSON.stringify(artifact, null, 2) + "\n");
  console.log(`Compiled ${artifact.modifiers.length} Sepolia modifiers; ${artifact.calls.to.length} calls.`);
}
