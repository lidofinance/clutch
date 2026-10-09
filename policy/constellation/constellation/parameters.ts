// SPDX-License-Identifier: AGPL-3.0-or-later
/**
 * Fixed values of the policy.
 *
 * The ceilings are dry-run stand-ins for one TM Floor Value, the fixed ceiling
 * of an approval that has no budget key (ADR 009, ADR 011). They are test
 * values. The production figures come from the attested computation and are
 * not in this repository.
 */

const DAY = 24n * 60n * 60n;

/** One TM Floor Value in stETH: the ceiling of the stETH approval to the wstETH contract (OD-08). */
export const FLOOR_STANDIN_STETH = 10n * 10n ** 18n;

/** One TM Floor Value in DAI or USDS: the ceiling of the approvals to Sky's converter (OD-22). */
export const FLOOR_STANDIN_USD = 10_000n * 10n ** 18n;

/** The refill period of every budget. */
export const MONTH = 30n * DAY;

/** A budget motion cannot set a refill period below 30 days (OD-08). */
export const MIN_REFILL_PERIOD = 30n * DAY;
