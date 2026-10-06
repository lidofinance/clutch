import { swap } from "@zodiaceco/sdk/actions";
import config from "../../../zodiac.config";

const {
  steth,
  wsteth,
  usdc,
  usdt,
  dai,
  sdai,
  usds,
  susds,
  aave_v3,
  lido_earn,
} = config.contracts.eth;

const { earneth, earnusd } = lido_earn;

/**
 * What the Treasury Management Committee may do with the Asset Safe.
 *
 * Two rules shape every entry below:
 *
 * 1. No debt. The RFP's launch design forbids borrowing and leverage, so
 *    `borrow`, `repay` and the e-mode / collateral switches on the Aave pool
 *    are simply absent — a default-deny modifier needs no explicit negation.
 * 2. Nothing leaves the Asset Safe. Every `receiver`, `owner` and `onBehalfOf`
 *    is pinned to `c.avatar`, and no plain `transfer` is granted, so positions
 *    can be opened and closed but assets cannot be sent anywhere. Returning
 *    assets to the DAO is the emergency role's job.
 */
export default [
  // ── Lido staking ────────────────────────────────────────────────────────
  // stETH <-> wstETH. Both directions, so the operator can hold whichever form
  // a protocol below wants.
  allow.eth.steth.approve(wsteth),
  allow.eth.wsteth.wrap(),
  allow.eth.wsteth.unwrap(),

  // ── Aave v3 Core: supply and withdraw, never borrow ──────────────────────
  allow.eth.usdc.approve(aave_v3.pool),
  allow.eth.usdt.approve(aave_v3.pool),
  allow.eth.dai.approve(aave_v3.pool),
  allow.eth.usds.approve(aave_v3.pool),
  allow.eth.wsteth.approve(aave_v3.pool),

  // One entry per group of assets that trade roughly one for one, because
  // each carries its own budget.
  allow.eth.aave_v3.pool.supply(
    c.or(usdc, usdt),
    c.withinAllowance("aave_supply_usdc_usdt"),
    c.avatar,
  ),
  allow.eth.aave_v3.pool.supply(
    c.or(dai, usds),
    c.withinAllowance("aave_supply_dai_usds"),
    c.avatar,
  ),
  allow.eth.aave_v3.pool.supply(
    wsteth,
    c.withinAllowance("aave_supply_wsteth"),
    c.avatar,
  ),

  // Withdrawing is unbudgeted: pulling out of a protocol is the risk-reducing
  // direction, and a cap on it would be a cap on the operator's own exit.
  allow.eth.aave_v3.pool.withdraw(
    c.or(usdc, usdt, dai, usds, wsteth),
    undefined,
    c.avatar,
  ),

  // ── Sky savings ─────────────────────────────────────────────────────────
  allow.eth.dai.approve(sdai),
  allow.eth.usds.approve(susds),

  allow.eth.sdai.deposit(c.withinAllowance("sky_savings_dai_usds"), c.avatar),

  // sUSDS overloads `deposit`, so the overload is named by its full signature.
  allow.eth.susds["deposit(uint256,address)"](
    c.withinAllowance("sky_savings_dai_usds"),
    c.avatar,
  ),

  allow.eth.sdai.redeem(undefined, c.avatar, c.avatar),
  allow.eth.susds.redeem(undefined, c.avatar, c.avatar),
  allow.eth.sdai.withdraw(undefined, c.avatar, c.avatar),
  allow.eth.susds.withdraw(undefined, c.avatar, c.avatar),

  // ── Lido Earn ───────────────────────────────────────────────────────────
  // earnUSD takes USDC, which is in the launch asset set, so the full deposit
  // and redeem cycle is available.
  allow.eth.usdc.approve(earnusd.deposit_queue_usdc),
  allow.eth.lido_earn.earnusd.deposit_queue_usdc.deposit(
    c.withinAllowance("earn_usd_deposit"),
  ),
  allow.eth.lido_earn.earnusd.deposit_queue_usdc.cancelDepositRequest(),
  allow.eth.lido_earn.earnusd.deposit_queue_usdc.claim(c.avatar),
  allow.eth.lido_earn.earnusd.redeem_queue.redeem(),
  allow.eth.lido_earn.earnusd.redeem_queue.claim(c.avatar),

  // earnETH takes wstETH through its asynchronous deposit queue, so the full
  // deposit and redeem cycle is available without adding WETH to the launch
  // asset set.
  allow.eth.wsteth.approve(earneth.deposit_queue_wsteth),
  allow.eth.lido_earn.earneth.deposit_queue_wsteth.deposit(
    c.withinAllowance("earn_eth_deposit_wsteth"),
  ),
  allow.eth.lido_earn.earneth.deposit_queue_wsteth.cancelDepositRequest(),
  allow.eth.lido_earn.earneth.deposit_queue_wsteth.claim(c.avatar),
  allow.eth.lido_earn.earneth.redeem_queue.redeem(),
  allow.eth.lido_earn.earneth.redeem_queue.claim(c.avatar),

  // ── Rebalancing via CoW Protocol ────────────────────────────────────────
  // Orders settle to the avatar. LDO is absent from both sides: selling the
  // DAO's own governance token is a treasury decision, not a routine rebalance.
  // TODO: Add sell-amount and approval allowances so a compromised operator
  // cannot submit an unbounded order within the approved asset set.
  swap({
    label: "Rebalance between approved assets",
    sell: [usdc, usdt, dai, usds, steth, wsteth],
    buy: [usdc, usdt, dai, usds, wsteth],
  }),
] satisfies Permissions;
