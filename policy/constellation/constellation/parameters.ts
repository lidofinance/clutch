// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * Fixed values of the policy.
 *
 * The ceilings are dry-run stand-ins for one mandate size, the fixed ceiling
 * of an approval that has no budget key (ADR 009, ADR 011; OD-89). They are test
 * values. The production figures come from the attested computation and are
 * not in this repository.
 */

export const DAY = 24n * 60n * 60n;

/** One mandate size in stETH: the ceiling of the stETH approval to the wstETH contract (OD-08). */
export const SIZE_STANDIN_STETH = 10n * 10n ** 18n;

/** One mandate size in DAI or USDS: the ceiling of the approvals to Sky's converter (OD-22). */
export const SIZE_STANDIN_USD = 10_000n * 10n ** 18n;

/** The refill period of every budget. */
export const MONTH = 30n * DAY;

/** A budget motion cannot set a refill period below 30 days (OD-08). */
export const MIN_REFILL_PERIOD = 30n * DAY;

/** An operator order lives at most 90 days: the order signer's `validDuration` (ADR 007, decision 29). */
export const ORDER_LIFE_MAX = 90n * DAY;

/** A recovery order lives at most 1 day (ADR 007, decision 25). */
export const RECOVERY_LIFE_MAX = DAY;

/**
 * The two shapes of an operator TWAP order, each ending within 90 days: at most 90 parts at most a day apart,
 * or at most 12 parts at most 7 days apart (ADR 007, decision 29).
 */
export const TWAP_SHAPES = [
  { parts: 90n, spacing: DAY },
  { parts: 12n, spacing: 7n * DAY },
] as const;
