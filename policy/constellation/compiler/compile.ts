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
 * and the only delegatecall that a policy or a motion may grant is the orders
 * account's call of CoW's order signer (ADR 007, decision 41). A grant pins
 * the role key to the keys that its modifier lets a motion write: the
 * operator's on the operator modifier, the emergency role's on the safety
 * modifier, and those three of the orders account on its modifier. Its output
 * is deterministic, so CI can compare the committed artifact with a fresh
 * compile.
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
const OR = 2;
const NOR = 3;
const MATCHES = 5;
const EQUAL_TO = 16;
const LESS_THAN = 18;
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
const STOP_ONLY = new Set(["emergency", "asset-emergency", "orders-emergency"]);

/** The only role that may hold a `restart` call. */
const RESTART_ROLE = "restart";

/**
 * What the insurance-governance role may call on the first-loss modifier (ADR 014, decision 6): the grants that
 * create a fund, and the fund's cap. It holds no `allowTarget`, no `allowFunction` and no revoke.
 */
const ON_FIRST_LOSS_MODIFIER = new Map([
  [selector("scopeTarget(bytes32,address)"), "grant"],
  [selector("scopeFunction(bytes32,address,bytes4,(uint8,uint8,uint8,bytes)[],uint8)"), "grant"],
  [selector("setAllowance(bytes32,uint128,uint128,uint128,uint64,uint64)"), "budget"],
]);
const FIRST_LOSS_GOVERNANCE = "insurance-governance";

/** No role may call the orders account itself: it is administered only by the DAO's own path. */
const ON_ORDERS_ACCOUNT = new Map<string, string>();

/**
 * CoW's order signer, which runs only by delegatecall (ADR 007; OD-96), and the two functions that a role may
 * delegatecall on it: sign and unsign an order. Every other delegatecall is refused, and so is this one from
 * any account but the orders account, because a delegatecall runs foreign code in the Safe's own storage (OD-36).
 */
const ORDER_SIGNER = getAddress("0x23dA9AdE38E4477b23770DeD512fD37b12381FAB");
const SIGN_ORDER = selector("signOrder((address,address,address,uint256,uint256,uint32,bytes32,uint256,bytes32,bool,bytes32,bytes32),uint32,uint256)");
const UNSIGN_ORDER = selector("unsignOrder((address,address,address,uint256,uint256,uint32,bytes32,uint256,bytes32,bool,bytes32,bytes32))");
const SIGNER_FUNCTIONS = new Set([SIGN_ORDER, UNSIGN_ORDER]);
const DELEGATECALL = 2;

/**
 * Where a grant's execution options sit among its parameters, and which signer functions it may grant with
 * delegatecall: `signOrder` only with a condition, so by `scopeFunction`, and `unsignOrder` either way. A
 * whole-target clearance never delegatecalls.
 */
const GRANT_OPTIONS = new Map<string, { index: number; signer: Set<string> }>([
  [selector("allowTarget(bytes32,address,uint8)"), { index: 2, signer: new Set() }],
  [selector("allowFunction(bytes32,address,bytes4,uint8)"), { index: 3, signer: new Set([UNSIGN_ORDER]) }],
  [selector("scopeFunction(bytes32,address,bytes4,(uint8,uint8,uint8,bytes)[],uint8)"), { index: 4, signer: SIGNER_FUNCTIONS }],
]);

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
  const firstLossSafe = getAddress(manifest.firstLossSafe);
  const firstLossModifier = manifest.firstLossModifier ? getAddress(manifest.firstLossModifier) : null;
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
    if (m.avatar === firstLossSafe && m.address !== firstLossModifier) {
      throw new Error(`${m.ref} ${m.address} acts for the first-loss Safe, but the manifest's first-loss modifier is ${firstLossModifier ?? "not named"}`);
    }
  }
  checkFirstLoss(modifiers, firstLossSafe, firstLossModifier, safe);
  checkZeroing(modifiers, manifest);
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
                  : target.address === firstLossModifier
                    ? ON_FIRST_LOSS_MODIFIER
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
          // A grant on the first-loss modifier also refuses the first-loss Safe, its modifier and the share tokens.
          const guarded =
            target.address === firstLossModifier
              ? [...protectedAccounts, firstLossSafe, firstLossModifier, ...firstLossShares(modifiers, firstLossModifier)]
              : protectedAccounts;
          const missing = kind === "grant" ? unguarded(fn.conditions, guarded) : [];
          if (missing.length > 0) {
            throw new Error(`${where}: ${name} must refuse ${missing.join(", ")} as the administered target (OD-38)`);
          }
          if (kind === "grant") {
            checkGrantKeys(where, name, fn.conditions, role.key, writableKeys(manifest, target.address));
            checkGrantDelegatecall(where, name, fn.selector, fn.conditions, target.address === ordersModifier);
          }
        }
      }
    }
  }
}

/**
 * The emergency role's zeroing of an approval (ADR 005, decision 34; OD-139). Every approval of the emergency role
 * on the safety modifier is the same tree: any spender, and the amount zero. And for every token on which the
 * operator holds an approval, the emergency role holds that zeroing, so that it can take each approval away. A
 * policy change that gives the operator an approval of a new token without the zeroing does not compile.
 */
export function checkZeroing(modifiers: Artifact["modifiers"], manifest: Record<string, any>) {
  const APPROVE = selector("approve(address,uint256)");
  const roleOn = (modifier: string, name: string) => modifiers.find((m) => m.address === getAddress(modifier))?.roles.find((r) => r.name === name);
  const approvals = (role: ReturnType<typeof roleOn>) =>
    (role?.targets ?? []).flatMap((target) => target.functions.filter((fn) => fn.selector === APPROVE).map((fn) => ({ target, fn })));
  const zero = zeroPadValue("0x", 32);
  const zeroing = (c: { parent: number; paramType: number; operator: number; compValue: string }[]) =>
    c.length === 3 &&
    c.every((n) => n.parent === 0) &&
    c[0].paramType === 5 && c[0].operator === MATCHES &&
    c[1].paramType === 1 && c[1].operator === 0 &&
    c[2].paramType === 1 && c[2].operator === EQUAL_TO && c[2].compValue === zero;
  const account = manifest.roleKeyScheme === "account";
  const emergency = approvals(roleOn(manifest.safetyModifier, account ? "asset-emergency" : "emergency"));
  for (const { target, fn } of emergency) {
    if (fn.wildcarded || fn.executionOptions !== 0 || !zeroing(fn.conditions)) {
      throw new Error(`the emergency role's approval on ${target.name ?? target.address} must be the zeroing for any spender, and nothing else (ADR 005, decision 34)`);
    }
  }
  const zeroed = new Set(emergency.map(({ target }) => target.address));
  for (const { target } of approvals(roleOn(manifest.operatorModifier, account ? "asset-operator" : "operator"))) {
    if (!zeroed.has(target.address)) {
      throw new Error(`the operator can approve ${target.name ?? target.address}, and the emergency role cannot set that approval to zero (ADR 005, decision 34)`);
    }
  }
}

/**
 * The first-loss Safe and its modifier (ADR 008, decisions 19, 21, 23 and 28; ADR 014, decisions 6 and 12). No
 * role of any modifier may call the first-loss Safe, and only the insurance-governance role of the first-loss
 * modifier may call that modifier; `checkProtected` checks what it calls there. On the first-loss modifier, a role
 * holds only single functions, each a plain call. A share token is a target on which a role holds
 * `burn(uint256)`: on it, no role holds anything but that burn, so no role moves the first-loss shares to another
 * holder or lets a spender take them. The only transfer in the compiled policy is the first-loss role's exit of a
 * fund, pinned to the Asset Safe. An approval must pin its spender, and only the insurance role holds one.
 */
const TRANSFER_SELECTOR = selector("transfer(address,uint256)");
const TRANSFER_FROM_SELECTOR = selector("transferFrom(address,address,uint256)");
const APPROVE_SELECTOR = selector("approve(address,uint256)");
const BURN_SELECTOR = selector("burn(uint256)");
const INSURANCE_ROLE = "insurance";
const FIRST_LOSS_ROLE = "first-loss";
/** The share tokens of the first-loss Safe: each target on which a role of the first-loss modifier holds a burn. */
export function firstLossShares(modifiers: Artifact["modifiers"], firstLossModifier: string | null): string[] {
  return modifiers
    .filter((m) => m.address === firstLossModifier)
    .flatMap((m) => m.roles)
    .flatMap((r) => r.targets)
    .filter((t) => t.functions.some((f) => f.selector === selector("burn(uint256)")))
    .map((t) => t.address);
}

export function checkFirstLoss(
  modifiers: Artifact["modifiers"],
  firstLossSafe: string,
  firstLossModifier: string | null,
  assetSafe: string,
) {
  const shares = new Set(firstLossShares(modifiers, firstLossModifier));
  for (const m of modifiers) {
    for (const role of m.roles) {
      for (const target of role.targets) {
        const where = `${m.ref}.${role.name} on ${target.name ?? target.address}`;
        if (target.address === firstLossSafe) {
          throw new Error(`${where}: no role may call the first-loss Safe (ADR 008, decision 19)`);
        }
        if (target.address === firstLossModifier) {
          if (m.address !== firstLossModifier || role.name !== FIRST_LOSS_GOVERNANCE) {
            throw new Error(`${where}: only the insurance-governance role may call the first-loss modifier (ADR 014, decision 6)`);
          }
          continue;
        }
        if (m.address !== firstLossModifier) continue;
        if (role.name === FIRST_LOSS_GOVERNANCE) {
          throw new Error(`${where}: the insurance-governance role calls only the first-loss modifier (ADR 014, decision 6)`);
        }
        if (target.clearance !== Clearance.Function) {
          throw new Error(`${where}: a role of the first-loss modifier may not call every function of a target (ADR 008, decision 21)`);
        }
        for (const fn of target.functions) {
          const name = fn.signature ?? fn.selector;
          if (fn.executionOptions !== 0) {
            throw new Error(`${where}: ${name} must be a plain call, without value or delegatecall (ADR 008, decision 21)`);
          }
          if (shares.has(target.address) && fn.selector !== BURN_SELECTOR) {
            throw new Error(`${where}: ${name} would move or lend the first-loss shares (ADR 008, decision 21)`);
          }
          if (fn.selector === TRANSFER_FROM_SELECTOR) {
            throw new Error(`${where}: ${name} would move a token out of the first-loss Safe (ADR 008, decision 21)`);
          }
          if (fn.selector === TRANSFER_SELECTOR) {
            if (role.name !== FIRST_LOSS_ROLE || fn.wildcarded || !pinnedTo(fn.conditions, assetSafe)) {
              throw new Error(`${where}: ${name} would move a token out of the first-loss Safe; only the first-loss role's exit to the Asset Safe may (ADR 008, decision 28)`);
            }
            continue;
          }
          if (fn.selector !== APPROVE_SELECTOR) continue;
          if (role.name !== INSURANCE_ROLE) {
            throw new Error(`${where}: only the insurance role may approve a spender (ADR 014, decision 12)`);
          }
          const spender = fn.wildcarded ? null : fixedValues(fn.conditions, childrenOf(fn.conditions, 0)[0]);
          if (spender === null || spender.length !== 1) {
            throw new Error(`${where}: ${name} must pin its spender to one address (ADR 014, decision 12)`);
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
  target: {
    address: string;
    name: string | null;
    clearance: number;
    executionOptions: number;
    functions: { selector: string; signature: string | null; executionOptions: number; wildcarded?: boolean }[];
  },
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
    if (fn.selector === SIGN_ORDER && fn.wildcarded) {
      throw new Error(`${where}: ${name} needs a condition: a signer order without one pays anyone (ADR 007, decision 18)`);
    }
  }
}

/**
 * The keys that a motion may write under, by the modifier that its grant administers: the operator's on the
 * operator modifier (INV-004), the emergency role's on the safety modifier (INV-025), the operator's, the
 * emergency role's and the approvals role's on the orders modifier (INV-040), and the insurance role's on the
 * first-loss modifier (INV-039). Any other module takes no grant.
 * A manifest with `roleKeyScheme: account` uses the account-specific keys of OD-152 in place of `operator` and
 * `emergency`.
 */
export function writableKeys(manifest: Record<string, any>, modifier: string): string[] {
  const at = (field: string) => typeof manifest[field] === "string" && getAddress(manifest[field]) === getAddress(modifier);
  const account = manifest.roleKeyScheme === "account";
  if (at("operatorModifier")) return [keyOf(account ? "asset-operator" : "operator")];
  if (at("safetyModifier")) return [keyOf(account ? "asset-emergency" : "emergency")];
  if (at("ordersModifier")) return (account ? ["orders-operator", "orders-emergency", "approvals"] : ["operator", "emergency", "approvals"]).map(keyOf);
  if (at("firstLossModifier")) return [keyOf("insurance")];
  return [];
}

/**
 * Refuses a grant that leaves the role key open in a branch, that may write under its own role's key, or that may
 * write under a key that its modifier keeps from motions: a governance role never widens itself or another motion
 * role, and never touches a role that it does not administer (ADR 006).
 */
export function checkGrantKeys(where: string, name: string, conditions: Flat[], ownKey: string, writable: string[]) {
  const allowed = writable.map((k) => k.toLowerCase());
  for (const b of readable(where, name, conditions)) {
    const keys = fixedValues(conditions, childrenOf(conditions, b)[0]);
    if (keys === null) throw new Error(`${where}: ${name} must pin the role key that it writes under (ADR 006)`);
    if (keys.includes(ownKey.toLowerCase())) throw new Error(`${where}: ${name} may not write under its own role's key (ADR 006)`);
    const other = keys.filter((k) => !allowed.includes(k));
    if (other.length > 0) {
      throw new Error(`${where}: ${name} may write under ${other.map(decodeLabel).join(", ")}, which this modifier keeps from motions (INV-004, INV-025, INV-040)`);
    }
  }
}

/** A key's label, for an error message: the bytes32 key without its zero padding. */
function decodeLabel(key: string) {
  const hex = key.slice(2).replace(/(00)+$/, "");
  return `\`${Buffer.from(hex, "hex").toString("utf8")}\``;
}

/**
 * Refuses a grant that may give delegatecall, unless it is a grant on the orders modifier of the order signer's
 * sign or unsign function, the target and the function pinned (OD-36; ADR 007, decision 41). Execution options
 * whose condition this cannot read count as delegatecall.
 */
export function checkGrantDelegatecall(where: string, name: string, fnSelector: string, conditions: Flat[], onOrdersModifier: boolean) {
  const options = GRANT_OPTIONS.get(fnSelector);
  if (options === undefined) return;
  for (const b of readable(where, name, conditions)) {
    const params = childrenOf(conditions, b);
    if (!mayDelegatecall(conditions, params[options.index])) continue;
    const targets = fixedValues(conditions, params[1]);
    const selectors = fixedValues(conditions, params[2]);
    const signer = zeroPadValue(ORDER_SIGNER, 32).toLowerCase();
    const allowed = [...options.signer].map((s) => s.toLowerCase().padEnd(66, "0"));
    if (
      !onOrdersModifier ||
      targets === null ||
      !targets.every((t) => t === signer) ||
      selectors === null ||
      !selectors.every((s) => allowed.includes(s))
    ) {
      throw new Error(`${where}: ${name} may grant delegatecall, and a motion may grant it only on the orders modifier, for the order signer's sign or unsign function (OD-36; ADR 007, decision 41)`);
    }
  }
}

/** The branches of a grant's condition, or an error if the checks cannot read its shape. */
function readable(where: string, name: string, conditions: Flat[]) {
  const bs = branches(conditions);
  if (bs === null) throw new Error(`${where}: ${name} has a condition whose shape the checks cannot read`);
  return bs;
}

/** Whether an execution-options parameter may carry the delegatecall bit. An open or unread condition may. */
function mayDelegatecall(conditions: Flat[], i: number | undefined) {
  if (i === undefined) return true;
  const n = conditions[i];
  if (n.operator === LESS_THAN) return BigInt(n.compValue) > BigInt(DELEGATECALL);
  const values = fixedValues(conditions, i);
  return values === null || values.some((v) => (BigInt(v) & BigInt(DELEGATECALL)) !== 0n);
}

type Flat = { parent: number; operator: number; compValue: string };

/** The children of node `i` of a flat tree, in order. The root is its own parent, so it is not its own child. */
function childrenOf(conditions: Flat[], i: number) {
  return conditions.flatMap((n, j) => (j !== i && n.parent === i ? [j] : []));
}

/**
 * The branches of a call's condition, each a Matches whose children are the parameters in order: the root, or
 * the children of a root Or. Null for any other shape, which no check below can read.
 */
function branches(conditions: Flat[]): number[] | null {
  const root = conditions[0];
  if (root === undefined) return null;
  if (root.operator === MATCHES) return [0];
  if (root.operator !== OR) return null;
  const kids = childrenOf(conditions, 0);
  return kids.length > 0 && kids.every((k) => conditions[k].operator === MATCHES) ? kids : null;
}

/** The values that a parameter may take, lower-case, if it is EqualTo one value or an Or of EqualTo; else null. */
function fixedValues(conditions: Flat[], i: number | undefined): string[] | null {
  if (i === undefined) return null;
  const n = conditions[i];
  if (n.operator === EQUAL_TO) return [n.compValue.toLowerCase()];
  if (n.operator !== OR) return null;
  const kids = childrenOf(conditions, i);
  if (kids.length === 0 || !kids.every((k) => conditions[k].operator === EQUAL_TO)) return null;
  return kids.map((k) => conditions[k].compValue.toLowerCase());
}

/**
 * The accounts that a grant leaves open as the administered target, its second parameter. In every branch the
 * target must refuse each account with Nor, or be pinned to accounts outside the list, such as the order signer.
 * A condition of any other shape leaves every account open.
 */
export function unguarded(conditions: Flat[], accounts: string[]) {
  const bs = branches(conditions);
  if (bs === null) return [...accounts];
  const open = new Set<string>();
  for (const b of bs) {
    const target = childrenOf(conditions, b)[1];
    const pinned = fixedValues(conditions, target);
    const refused = new Set(
      target !== undefined && conditions[target].operator === NOR
        ? childrenOf(conditions, target).filter((k) => conditions[k].operator === EQUAL_TO).map((k) => conditions[k].compValue.toLowerCase())
        : [],
    );
    for (const account of accounts) {
      const word = zeroPadValue(account, 32).toLowerCase();
      if (pinned !== null ? pinned.includes(word) : !refused.has(word)) open.add(account);
    }
  }
  return accounts.filter((account) => open.has(account));
}

/**
 * Whether a one-parameter call's condition pins that parameter to `account`:
 * a root Matches with one child, EqualTo the account.
 */
export function pinnedTo(conditions: Flat[], account: string) {
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
