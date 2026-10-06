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
 * cannot verify it (ADR 004, decision 11). Its output is deterministic, so CI
 * can compare the committed artifact with a fresh compile.
 */
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { getAddress, id, Interface } from "ethers";
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

  return { format: FORMAT, manifest, sdk: sdkVersions(), modifiers, calls };
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
  const { default: _unused, ...nodes } = await import(path.join(ROOT, "constellation/index.ts"));
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
