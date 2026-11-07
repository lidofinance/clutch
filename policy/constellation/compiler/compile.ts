// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * Compiles the Clutch constellation into the policy artifact of ADR 004
 * (decisions 9, 13 and 14): the ordered modifier calls, the expected
 * condition tree for every role, target and selector, and the allowances.
 *
 *   bun compiler/compile.ts --manifest manifests/fork-25946643.json           write the artifact
 *   bun compiler/compile.ts --manifest manifests/fork-25946643.json --check   fail if it differs
 *
 * The compiler runs offline. It refuses an entry that only the hosted app can
 * compile, such as an action or a DeFi Kit preset, because local tooling
 * cannot verify it (ADR 004, decision 11). It also refuses a policy that lets
 * a role reach the Asset Safe or one of its modules beyond a fixed set of
 * calls (OD-38), or lets the emergency role restore what it stopped (ADR 005,
 * decision 26). The orders account and its modifier get the same protection,
 * and the only delegatecall that a policy may grant is the orders account's
 * call of CoW's order signer (ADR 007, decision 41). Its output is
 * deterministic, so CI can compare the committed artifact with a fresh compile.
 */
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { getAddress, id, Interface, zeroPadValue } from "ethers";
import { Clearance, encodeKey, flattenCondition, processPermissions, rolesAbi } from "zodiac-roles-sdk";

export const FORMAT = "clutch.policy-artifact/1";
const ROOT = path.resolve(import.meta.dir, "..");
const ROLES = new Interface(rolesAbi as any);

type Entry = Record<string, any>;
type Node = Record<string, any>;

export type Artifact = ReturnType<typeof compile>;

/** Compiles every Roles node of the constellation, in export order. */
export function compile(nodes: Record<string, Node>, manifest: Record<string, any>, names: Record<string, string>) {
  const label = (address: string) => names[getAddress(address)] ?? null;
  const calls = { to: [] as string[], data: [] as string[], fn: [] as string[] };
  const emit = (to: string, fn: string, args: unknown[]) => {
    calls.to.push(to);
    calls.data.push(ROLES.encodeFunctionData(fn, args));
    calls.fn.push(fn);
  };

  const modifiers = Object.entries(nodes).map(([ref, node]) => {
    if (node?.type !== "ROLES") {
      throw new Error(`${ref}: only Roles modifiers compile. Clutch's own script deploys the Safes (ADR 004).`);
    }
    const address = getAddress(node.address);

    const allowances = Object.entries(node.allowances ?? {}).map(([name, spec]: [string, any]) => {
      if (spec.key !== undefined && spec.key !== name) throw new Error(`${ref}: allowance ${name} names key ${spec.key}`);
      const allowance = {
        name,
        key: keyOf(name),
        balance: String(spec.balance ?? 0n),
        maxRefill: String(spec.maxRefill ?? 0n),
        refill: String(spec.refill ?? 0n),
        period: String(spec.period ?? 0n),
        timestamp: String(spec.timestamp ?? 0n),
      };
      const { key, balance, maxRefill, refill, period, timestamp } = allowance;
      emit(address, "setAllowance", [key, balance, maxRefill, refill, period, timestamp]);
      return allowance;
    });

    const roles = Object.entries(node.roles ?? {}).map(([name, def]: [string, any]) => {
      const roleKey = keyOf(name);
      const entries: Entry[] = [...def.permissions];
      entries.forEach((entry, i) => refuseHosted(`${ref}.${name}[${i}]`, entry));
      const signatures = new Map<string, string>();
      for (const entry of entries) {
        if (entry.signature) signatures.set(id(entry.signature).slice(0, 10), entry.signature);
      }

      const members = def.members.map((member: string) => getAddress(member));
      for (const member of members) emit(address, "assignRoles", [member, [roleKey], [true]]);

      const { targets } = processPermissions(entries as any);
      const sorted = [...targets].sort((x, y) => x.address.toLowerCase().localeCompare(y.address.toLowerCase()));
      const targetsOut = sorted.map((target) => {
        const targetAddress = getAddress(target.address);
        if (target.clearance === Clearance.Target) {
          emit(address, "allowTarget", [roleKey, targetAddress, target.executionOptions]);
        } else if (target.clearance === Clearance.Function) {
          emit(address, "scopeTarget", [roleKey, targetAddress]);
        } else {
          throw new Error(`${ref}.${name}: target ${targetAddress} has no clearance`);
        }
        const functions = [...target.functions]
          .sort((x, y) => x.selector.localeCompare(y.selector))
          .map((fn) => {
            const conditions = fn.wildcarded ? [] : flattenCondition(fn.condition!).map((n) => ({
              parent: n.parent,
              paramType: n.paramType,
              operator: n.operator,
              compValue: n.compValue ?? "0x",
            }));
            if (fn.wildcarded) {
              emit(address, "allowFunction", [roleKey, targetAddress, fn.selector, fn.executionOptions]);
            } else {
              const flat = conditions.map((n) => [n.parent, n.paramType, n.operator, n.compValue]);
              emit(address, "scopeFunction", [roleKey, targetAddress, fn.selector, flat, fn.executionOptions]);
            }
            return {
              selector: fn.selector,
              signature: signatures.get(fn.selector) ?? null,
              executionOptions: fn.executionOptions,
              wildcarded: fn.wildcarded,
              conditions,
            };
          });
        return {
          address: targetAddress,
          name: label(targetAddress),
          clearance: target.clearance,
          executionOptions: target.executionOptions,
          functions,
        };
      });

      return {
        name,
        key: roleKey,
        members: members.map((member: string) => ({ address: member, name: label(member) })),
        targets: targetsOut,
      };
    });

    return {
      ref,
      label: node.label,
      address,
      owner: getAddress(node.owner),
      avatar: getAddress(node.avatar),
      target: getAddress(node.target),
      allowances,
      roles,
    };
  });

  checkProtected(modifiers, manifest);
  return { format: FORMAT, manifest, sdk: sdkVersions(), modifiers, calls };
}

/** The Roles operators that the checks below read, as the deployed mastercopy numbers them. */
const NOR = 3;
const EQUAL_TO = 16;
const selector = (signature: string) => id(signature).slice(0, 10);

/**
 * What a role may call on the Asset Safe or on one of its modules (OD-38).
 * A `narrow` call only removes authority. A `grant` call gives the operator a
 * permission, so it must refuse every protected account as the target that
 * it administers. A `budget` call must carry a condition. A `restart` call
 * enables the operator modifier again: only the restart role may hold it, and
 * only with its argument pinned to that modifier (ADR 013, decision 12).
 */
const ON_ASSET_SAFE = new Map([
  [selector("disableModule(address,address)"), "narrow"],
  [selector("enableModule(address)"), "restart"],
]);
const ON_MODULE = new Map([
  [selector("revokeTarget(bytes32,address)"), "narrow"],
  [selector("revokeFunction(bytes32,address,bytes4)"), "narrow"],
  [selector("allowTarget(bytes32,address,uint8)"), "grant"],
  [selector("scopeTarget(bytes32,address)"), "grant"],
  [selector("allowFunction(bytes32,address,bytes4,uint8)"), "grant"],
  [selector("scopeFunction(bytes32,address,bytes4,(uint8,uint8,uint8,bytes)[],uint8)"), "grant"],
  [selector("setAllowance(bytes32,uint128,uint128,uint128,uint64,uint64)"), "budget"],
]);

/**
 * The roles that stop and never restore. On the Asset Safe and its modules
 * they hold only `narrow` calls, so they cannot give back what they removed:
 * a motion restarts (ADR 005, decision 26; ADR 013, decision 12).
 */
const STOP_ONLY = new Set(["emergency"]);

/** The only role that may hold a `restart` call. */
const RESTART_ROLE = "restart";

/** No role may call the orders account itself: it is administered only by the DAO's own path. */
const ON_ORDERS_ACCOUNT = new Map<string, string>();

/**
 * CoW's order signer, which runs only by delegatecall (ADR 007; OD-96), and the two functions that a role may
 * delegatecall on it: sign and unsign an order. Every other delegatecall is refused, and so is this one from
 * any account but the orders account, because a delegatecall runs foreign code in the Safe's own storage (OD-36).
 */
const ORDER_SIGNER = getAddress("0x23dA9AdE38E4477b23770DeD512fD37b12381FAB");
const SIGNER_FUNCTIONS = new Set([
  selector("signOrder((address,address,address,uint256,uint256,uint32,bytes32,uint256,bytes32,bool,bytes32,bytes32),uint32,uint256)"),
  selector("unsignOrder((address,address,address,uint256,uint256,uint32,bytes32,uint256,bytes32,bool,bytes32,bytes32))"),
]);
const DELEGATECALL = 2;

/**
 * Refuses a policy in which a role reaches the Asset Safe or one of its
 * modules beyond the calls above, grants a permission without refusing every
 * one of them as the administered target, or lets a role that stops make
 * anything but a `narrow` call there. The manifest's `modules` must list
 * every compiled modifier that acts for the Asset Safe (OD-38). The orders
 * account and its modifier, where the manifest names them, are protected the
 * same way, and no role may call the orders account itself.
 */
export function checkProtected(modifiers: Artifact["modifiers"], manifest: Record<string, any>) {
  const safe = getAddress(manifest.assetSafe);
  const ordersAccount = manifest.ordersModifier ? getAddress(manifest.ordersAccount) : null;
  const ordersModifier = manifest.ordersModifier ? getAddress(manifest.ordersModifier) : null;
  if (!Array.isArray(manifest.modules) || manifest.modules.length === 0) {
    throw new Error("the manifest must list every module of the Asset Safe in `modules` (OD-38)");
  }
  const modules = manifest.modules.map((m: string) => getAddress(m));
  if (new Set(modules).size !== modules.length) throw new Error("the manifest lists a module twice (OD-38)");
  for (const m of modifiers) {
    if (m.avatar === safe && !modules.includes(m.address)) {
      throw new Error(`the manifest's modules must list ${m.ref} ${m.address}, a module of the Asset Safe (OD-38)`);
    }
    if (ordersAccount !== null && m.avatar === ordersAccount && m.address !== ordersModifier) {
      throw new Error(`${m.ref} ${m.address} acts for the orders account, but the manifest's orders modifier is ${ordersModifier}`);
    }
  }
  const protectedAccounts = [safe, ...modules, ...(ordersAccount !== null ? [ordersAccount, ordersModifier!] : [])];
  for (const m of modifiers) {
    for (const role of m.roles) {
      for (const target of role.targets) {
        refuseDelegatecall(m, role.name, target, ordersAccount);
        const allowed =
          target.address === safe
            ? ON_ASSET_SAFE
            : modules.includes(target.address)
              ? ON_MODULE
              : target.address === ordersAccount
                ? ON_ORDERS_ACCOUNT
                : target.address === ordersModifier
                  ? ON_MODULE
                  : null;
        if (!allowed) continue;
        const where = `${m.ref}.${role.name} on ${target.name ?? target.address}`;
        if (target.clearance !== Clearance.Function) {
          throw new Error(`${where}: a role may not call every function of a vault Safe or of one of its modules (OD-38)`);
        }
        for (const fn of target.functions) {
          const kind = allowed.get(fn.selector);
          const name = fn.signature ?? fn.selector;
          if (!kind) throw new Error(`${where}: ${name} is not allowed on a vault Safe or one of its modules (OD-38)`);
          if (kind === "restart" && role.name !== RESTART_ROLE) {
            throw new Error(`${where}: ${name} belongs to the restart role alone (ADR 013, decision 12)`);
          }
          if (kind === "restart" && !pinnedTo(fn.conditions, manifest.operatorModifier)) {
            throw new Error(`${where}: ${name} must pin its argument to the operator modifier (ADR 013, decision 12)`);
          }
          if (kind !== "narrow" && STOP_ONLY.has(role.name)) {
            throw new Error(`${where}: ${name} would let a role that stops restore authority; a motion restarts (ADR 005, decision 26)`);
          }
          if (kind !== "narrow" && fn.wildcarded) throw new Error(`${where}: ${name} needs a condition (OD-38)`);
          const missing = kind === "grant" ? unguarded(fn.conditions, protectedAccounts) : [];
          if (missing.length > 0) {
            throw new Error(`${where}: ${name} must refuse ${missing.join(", ")} as the administered target (OD-38)`);
          }
        }
      }
    }
  }
}

/**
 * Refuses a delegatecall anywhere but the orders account's call of the order signer's sign and unsign
 * functions (OD-36; ADR 007, decision 41), and a whole-target clearance that allows delegatecall.
 */
export function refuseDelegatecall(
  m: { ref: string; avatar: string },
  role: string,
  target: { address: string; name: string | null; clearance: number; executionOptions: number; functions: { selector: string; signature: string | null; executionOptions: number }[] },
  ordersAccount: string | null,
) {
  const where = `${m.ref}.${role} on ${target.name ?? target.address}`;
  if (target.clearance === Clearance.Target && (target.executionOptions & DELEGATECALL) !== 0) {
    throw new Error(`${where}: a whole-target clearance may not allow delegatecall (OD-36)`);
  }
  for (const fn of target.functions) {
    if ((fn.executionOptions & DELEGATECALL) === 0) continue;
    const name = fn.signature ?? fn.selector;
    const signer = target.address === ORDER_SIGNER && SIGNER_FUNCTIONS.has(fn.selector);
    if (!signer || ordersAccount === null || m.avatar !== ordersAccount) {
      throw new Error(`${where}: ${name} delegatecalls, and only the orders account may delegatecall, to sign or unsign a CoW order (OD-36; ADR 007, decision 41)`);
    }
  }
}

/**
 * The accounts that a grant's second parameter, the administered target,
 * does not refuse with Nor. The tree is flat: the root is 0, and its
 * children are the parameters in order.
 */
export function unguarded(conditions: { parent: number; operator: number; compValue: string }[], accounts: string[]) {
  const params = conditions.flatMap((n, i) => (i !== 0 && n.parent === 0 ? [i] : []));
  const target = params[1];
  const refused = new Set(
    target !== undefined && conditions[target].operator === NOR
      ? conditions.filter((n, i) => i !== 0 && n.parent === target && n.operator === EQUAL_TO).map((n) => n.compValue.toLowerCase())
      : [],
  );
  return accounts.filter((account) => !refused.has(zeroPadValue(account, 32).toLowerCase()));
}

/**
 * Whether a one-parameter call's condition pins that parameter to `account`:
 * a root Matches with one child, EqualTo the account.
 */
export function pinnedTo(conditions: { parent: number; operator: number; compValue: string }[], account: string) {
  return (
    conditions.length === 2 &&
    conditions[1].parent === 0 &&
    conditions[1].operator === EQUAL_TO &&
    conditions[1].compValue.toLowerCase() === zeroPadValue(getAddress(account), 32).toLowerCase()
  );
}

/** An entry that only the hosted app can compile has no target, or carries an action or an annotation. */
export function refuseHosted(where: string, entry: Entry) {
  if (entry.action !== undefined || entry.annotation !== undefined || entry.targetAddress === undefined) {
    throw new Error(`${where}: only the hosted app can compile this entry, so local tooling cannot verify it (ADR 004, decision 13)`);
  }
  if (typeof entry.targetAddress !== "string" || !/^0x[0-9a-fA-F]{40}$/.test(entry.targetAddress)) {
    throw new Error(`${where}: the target must be an address, not a node reference`);
  }
}

function keyOf(label: string): string {
  if (new TextEncoder().encode(label).length > 32) throw new Error(`key label longer than 32 bytes: ${label}`);
  return encodeKey(label);
}

function sdkVersions() {
  const version = (name: string) => JSON.parse(readFileSync(path.join(ROOT, "node_modules", name, "package.json"), "utf8")).version;
  return { "@zodiaceco/sdk": version("@zodiaceco/sdk"), "zodiac-roles-sdk": version("zodiac-roles-sdk") };
}

/** Loads the constellation against one manifest and compiles it. */
export async function compileManifest(manifestFile: string) {
  const manifestPath = path.resolve(manifestFile);
  process.env.CLUTCH_MANIFEST = manifestPath;
  await import(path.join(ROOT, ".lib/globals.ts"));
  const { default: _unused, ...all } = await import(path.join(ROOT, "constellation/index.ts"));
  // A node that the manifest does not deploy, such as the orders modifier in the kit, is exported as undefined.
  const nodes = Object.fromEntries(Object.entries(all).filter(([, node]) => node !== undefined)) as Record<string, Node>;
  const { NAMES } = await import(path.join(ROOT, "constellation/addresses.ts"));
  const names = Object.fromEntries(Object.entries(NAMES as Record<string, string>).map(([k, v]) => [getAddress(k), v]));
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  return compile(nodes, manifest, names);
}

export function render(artifact: Artifact): string {
  return JSON.stringify(artifact, null, 2) + "\n";
}

async function main(argv: string[]) {
  const option = (name: string) => {
    const i = argv.indexOf(name);
    return i >= 0 ? argv[i + 1] : undefined;
  };
  const manifestFile = option("--manifest");
  if (!manifestFile) throw new Error("usage: bun compiler/compile.ts --manifest <file> [--out <file>] [--check]");
  const out = path.resolve(option("--out") ?? path.join(ROOT, "artifacts", path.basename(manifestFile)));
  const text = render(await compileManifest(manifestFile));
  if (argv.includes("--check")) {
    const committed = existsSync(out) ? readFileSync(out, "utf8") : "";
    if (committed !== text) {
      console.error(`${path.relative(process.cwd(), out)} differs from a fresh compile. Run the compiler and commit the artifact.`);
      process.exit(1);
    }
    console.log(`${path.relative(process.cwd(), out)} matches a fresh compile.`);
    return;
  }
  writeFileSync(out, text);
  console.log(`wrote ${path.relative(process.cwd(), out)}: ${JSON.parse(text).calls.to.length} calls`);
}

if (import.meta.main) await main(process.argv.slice(2));
