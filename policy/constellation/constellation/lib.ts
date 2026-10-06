// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * Helpers for writing Clutch permissions with explicit function signatures.
 *
 * Each helper returns a plain permission entry. Clutch's compiler compiles it
 * locally with the roles SDK (ADR 004, decision 13), and the hosted app
 * receives the same entry. No entry made here needs the hosted app to compile
 * it, so local tooling can verify every one (ADR 004, decision 11).
 */
import { c, encodeKey, Operator, ParameterType } from "zodiac-roles-sdk";
import { zeroPadValue } from "ethers";

export { c };

/** The parameter types of a signature such as `approve(address,uint256)`. */
export function paramTypes(signature: string): string[] {
  const open = signature.indexOf("(");
  if (open < 1 || !signature.endsWith(")")) throw new Error(`not a function signature: ${signature}`);
  const inner = signature.slice(open + 1, -1);
  const types: string[] = [];
  let depth = 0;
  let start = 0;
  for (let i = 0; i < inner.length; i++) {
    if (inner[i] === "(") depth++;
    else if (inner[i] === ")") depth--;
    else if (inner[i] === "," && depth === 0) {
      types.push(inner.slice(start, i));
      start = i + 1;
    }
  }
  if (inner.length > 0) types.push(inner.slice(start));
  return types;
}

/**
 * A call of `signature` on `target`. Each parameter is a value, which must
 * match exactly, a condition from `c`, or `undefined`, which leaves the
 * parameter open. The SDK drops open parameters at the end of the list.
 */
export function call(target: string, signature: string, ...params: unknown[]) {
  const entry = { targetAddress: target as `0x${string}`, signature };
  if (params.length === 0) return entry;
  return { ...entry, condition: c.calldataMatches(params as any, paramTypes(signature)) };
}

/** The same as `call`, with ETH attached. */
export function callWithValue(target: string, signature: string, ...params: unknown[]) {
  return { ...call(target, signature, ...params), send: true as const };
}

/** Or over a list of values: the parameter equals one of them. */
export function anyOf(values: readonly unknown[]) {
  if (values.length === 0) throw new Error("anyOf needs at least one value");
  return (c.or as unknown as (...branches: unknown[]) => unknown)(...values);
}

/**
 * Nor: the parameter equals none of `addresses`. The deployed mastercopy has
 * this operator, but the roles SDK's enum and condition kit do not, so this
 * writes the raw condition. The SDK compiles it unchanged (research note of
 * 2026-10-06, section 3).
 */
export const noneOf =
  (...addresses: string[]) =>
  () => ({
    paramType: ParameterType.None,
    operator: 3 as unknown as Operator,
    children: addresses.map((address) => ({
      paramType: ParameterType.Static,
      operator: Operator.EqualTo,
      compValue: zeroPadValue(address, 32) as `0x${string}`,
    })),
  });

/** A role or allowance key, encoded as the Zodiac app encodes it: the label as bytes32. */
export function key(label: string): `0x${string}` {
  if (new TextEncoder().encode(label).length > 32) throw new Error(`key label longer than 32 bytes: ${label}`);
  return encodeKey(label) as `0x${string}`;
}

/** The distinct values of a list, in first-seen order. */
export function unique<T>(values: readonly T[]): T[] {
  return [...new Set(values)];
}
