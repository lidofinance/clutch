/**
 * Per-protocol deployment budgets, the pre-execution half of the RFP's
 * allocation limits. The modifier decrements a budget as calls consume it and
 * reverts when it is exhausted, so a compromised operator key cannot drain
 * into a protocol faster than the budget allows.
 *
 * Budgets are monthly, sized to roughly match the target allocation ratios for
 * the expected mandate, and adjusted through Easy Track motions when larger
 * price movements pull the ratios away from them. The amounts below are
 * placeholders until the mandate size is settled.
 *
 * A budget counts one token's units, so assets that do not trade roughly one
 * for one need separate keys. Sharing a key between USDC and DAI would let 1
 * DAI consume the same budget as 1 USDC, and sharing one between DAI and wstETH
 * would be far worse, so Aave has three.
 *
 * `balance` starts full and `refill` is added every `period`, capped at
 * `maxRefill`.
 */

const MONTH = 60n * 60n * 24n * 30n;

const usd6 = (amount: bigint) => amount * 10n ** 6n;
const token18 = (amount: bigint) => amount * 10n ** 18n;

/** Monthly USDC/USDT the operator may supply to Aave v3 Core. */
export const aave_supply_usdc_usdt = budget(
  "aave_supply_usdc_usdt",
  usd6(10_000_000n),
);

/** Monthly DAI/USDS the operator may supply to Aave v3 Core. */
export const aave_supply_dai_usds = budget(
  "aave_supply_dai_usds",
  token18(10_000_000n),
);

/** Monthly wstETH the operator may supply to Aave v3 Core. */
export const aave_supply_wsteth = budget("aave_supply_wsteth", token18(2_500n));

/** Monthly DAI/USDS the operator may move into the Sky savings vaults. */
export const sky_savings_dai_usds = budget(
  "sky_savings_dai_usds",
  token18(10_000_000n),
);

/** Monthly USDC the operator may deposit into the Lido earnUSD vault. */
export const earn_usd_deposit = budget("earn_usd_deposit", usd6(5_000_000n));

/** Monthly wstETH the operator may deposit into the Lido earnETH vault. */
export const earn_eth_deposit_wsteth = budget(
  "earn_eth_deposit_wsteth",
  token18(2_500n),
);

function budget(label: string, perMonth: bigint) {
  return {
    key: label,
    refill: perMonth,
    maxRefill: perMonth,
    period: MONTH,
    balance: perMonth,
    timestamp: 0n,
  };
}
