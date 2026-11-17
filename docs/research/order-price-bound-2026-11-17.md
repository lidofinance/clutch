---
type: Research Note
title: A price bound on chain for like-for-like orders, without an outside price feed, 2026-11-17
description: "A custom condition of the Roles modifier can hold an operator's order to par inside one class of tokens, and a motion can install it; an order of two classes stays free, so the bound stops slips and not a hostile signer."
tags: [orders, roles, security, research, evidence]
status: stable
review_status: slop
valid_as_of: 2026-11-17
stale_after: 2027-02-28T00:00:00Z
generated:
  by: claude-code/mythos-5.2
  at: 2026-11-17T20:53:17Z
verified: []
sources:
  - id: s1
    resource: "https://repo.sourcify.dev/contracts/full_match/1/0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5/"
    title: The Roles mastercopy that the vault's modifiers use, verified source — the Custom operator, the custom-condition interface and the integrity rules
  - id: s2
    resource: urn:clutch:source:order-price-bound-probe
    title: test/research/LikeForLikeBound.sol and test/research/OrderPriceBound.t.sol — the prototype condition and its five fork tests
  - id: s3
    resource: urn:clutch:evidence:2026-11-17:curve-par-reads
    title: Curve's stETH pool and 3pool read at blocks of May 2022 to May 2023, with the commands of this note
  - id: s4
    resource: /adr/007-swapping-through-an-orders-account.md
    title: ADR 007 — the order signer's pins, no price bound on chain, and no price feed in the swap path
  - id: s5
    resource: /adr/009-budgets-caps-reporting-and-monitoring.md
    title: ADR 009 — the orders budgets and the orders detector
  - id: s6
    resource: /research/roles-module-drain-2026-11-16.md
    title: A Safe drained through its Roles module on 2026-11-16 — a free minimum output
  - id: s7
    resource: /registers/decision-log.md
    title: Decision log — OD-154, and EM's request of 2026-11-17 for this research
---

# A price bound on chain for like-for-like orders, without an outside price feed, 2026-11-17

EM chose no price bound on chain for operator orders at launch, and asked for research on one kind of bound: a custom condition with no outside feed, for like-for-like pairs only, stablecoin to stablecoin and ETH-class to ETH-class (OD-154) [s7]. The agent read the Roles mastercopy's verified source, built a prototype, and ran it on the rehearsal's fork against the vault's own modifiers. It also read two Curve pools at past blocks.

## Answer

1. **It works, and it is small.** The modifier calls a custom condition with the whole calldata of the role's call. A contract of 1,688 bytes holds an order to par inside a class of tokens. One motion installs it; no vote is needed [s1][s2].
2. **It bounds 12 of the 30 ordered pairs.** The six order tokens make two classes of three. An order of two classes, such as USDC for WETH, stays free, because no contract can price it without a market price [s2].
3. **So it does not stop a hostile signer.** A signer who wants a bad price signs an order of two classes. The bound stops slips inside a class, such as a bought amount in the wrong decimals. What bounds a hostile signer's loss without a feed is what the design already has: the orders budgets [s5].
4. **Par is a strong assumption in a crisis.** stETH traded at 0.935 ETH on Curve on 2022-06-13, and USDC at 0.906 USDT on 2023-03-11. A bound with a small tolerance refuses an operator's order at those prices [s3].

## How the modifier calls a custom condition

- The operator `Custom` takes a parameter of any type. Its comparison value is 32 bytes: the condition contract's address, and 12 bytes that the modifier passes on unchanged [s1].
- The modifier calls `check(to, value, data, operation, location, size, extra)`. `data` is the role call's whole calldata, and `location` is the place of the parameter that carries the condition. The interface is a view, so the contract cannot change state [s1].
- A refusal comes back as a condition violation with the contract's own reason [s1][s2].

## The prototype

`LikeForLikeBound` sits on the sold amount of the order. CoW's order and a TWAP order's data start with the same five fields: the sold token, the bought token, the receiver, the sold amount and the bought amount. So one contract reads both [s2].

- **Classes.** Dollar stablecoins: USDC, USDT and USDS. ETH and its Lido tokens: WETH, stETH and wstETH. The six addresses are fixed at deployment.
- **Value.** Inside a class each token counts at par, with its decimals. wstETH counts at `stEthPerToken()`, which the token itself answers. That is Lido's own rate, not a market price.
- **Rule.** For two tokens of one class, the bought value is at least the sold value less the tolerance. The tolerance is the 12 bytes of the comparison value, in basis points, so the policy holds it and a motion changes it.
- **No owner, no storage, no upgrade.** A new order token needs a new contract and a motion.

## What the fork shows

The tests run on the rehearsal's vault, with the committed policy and the live Easy Track [s2].

| Case | Result |
|---|---|
| Before the bound: 4,000 USDC for 2,000 USDT | The operator signs it |
| One motion of the orders modifier's governance role writes the tree with the condition | Enacted: 1 write, 1,260,639 gas; the tree keeps its 28 nodes |
| The same order after the motion | Refused, with the reason `below par` |
| 2,000 USDC for 1,980 USDT, at the tolerance of 1% | Signed; one unit less is refused |
| 1,000 USDC for 995 USDS, and for 995 units of USDS in six decimals | The first is signed; the slip of twelve digits is refused |
| A buy order: 1,010 USDC at most for 1,000 USDT; then 2,000 at most | The first is signed; the second is refused |
| 10 stETH for 9.95 WETH, and for 9 WETH | The first is signed; the second is refused |
| 10 wstETH for WETH at its rate less 0.5%, and for 10 WETH | The first is signed; the second, a fifth below the rate, is refused |
| 1,000,000 USDC for 1 wei of WETH; 100 WETH for 1 unit of USDC | Signed: two classes |
| The emergency role's recovery order at any price | Signed: the bound is on the operator's tree only (OD-48) |
| An order to another receiver, or in a token off the lists | Refused, as before |
| A TWAP order: parts of 1,000 USDC for 990 USDT, and for 500 | The first is created; the second is refused; the tree has 53 nodes and two conditions |

The check itself costs 3,994 gas for a stablecoin pair and 11,412 gas when it reads the wstETH rate, on warm accounts [s2].

## Par in two past events

Each line is one read of a Curve pool at the block nearest to the time [s3].

| Time (UTC) | Read | Result |
|---|---|---|
| 2022-05-12 12:00, block 14760959 | 100 stETH to ETH | 0.980 ETH per stETH |
| 2022-06-13 12:00, block 14955879 | 100 stETH to ETH | 0.935 |
| 2022-06-18 12:00, block 14984848 | 100 stETH to ETH | 0.936 |
| 2022-09-15 12:00, block 15538957 | 100 stETH to ETH | 0.984 |
| 2023-03-11 06:00, block 16802921 | 100,000 USDC to USDT | 0.929 USDT per USDC |
| 2023-03-11 12:00, block 16804701 | 100,000 USDC to USDT | 0.906 |
| 2023-03-12 12:00, block 16811806 | 100,000 USDC to USDT | 0.952 |
| 2023-03-14 12:00, block 16826046 | 100,000 USDC to USDT | 0.995 |

```sh
cast call 0xDC24316b9AE028F1497c275EB9192a3Ea0f67022 "get_dy(int128,int128,uint256)(uint256)" 1 0 100000000000000000000 --block 14955879
cast call 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7 "get_dy(int128,int128,uint256)(uint256)" 1 2 100000000000 --block 16804701
```

A tolerance of 1% refuses an operator's sale of stETH for WETH on every date of 2022 in the table, and a sale of USDC for USDT on 11 and 12 March 2023. A tolerance of 10% lets those through, and then lets a hostile order lose 10% inside a class. During such an event the operator still has an order of two classes, and the emergency role still has its recovery order.

## What the bound is worth

- **Against a slip.** It refuses a bought amount in the wrong decimals, a wstETH amount counted as stETH, and a swapped pair of amounts, inside a class. Before the screening guard is set, nothing else on chain does.
- **Against a hostile signing quorum.** Nothing. The quorum signs an order of two classes, which the bound lets through. The orders budgets bound what such an order can sell: tokens reach the orders account only within a budget for 30 days, and the proceeds of a fill go to the Asset Safe [s5].
- **Against the pattern of the drain of 2026-11-16.** The policy already refuses its free route. The free minimum output stays for orders of two classes [s6].

## What it costs

- **A new contract to audit**, small and without state.
- **One more call in the signing path.** If the contract or the wstETH rate call reverts, the operator signs no order of the bounded kind. It cannot move funds: the modifier calls it as a view.
- **Tooling.** The pinned Roles SDK has no helper for a custom condition of one's own; the constellation writes the node as raw data, as it writes `Nor`. The compiler's rule on free parameters takes the node as a pin. The round-trip check compares it like any node. The agent did not try the hosted Zodiac app with such a node.
- **A crisis rule to write.** The tolerance decides whether the operator can still sell a token that left par.

## What would bound an order of two classes without a feed

The agent did not build these. Each needs its own research.

- **A corridor as policy data:** a floor and a ceiling for ETH-class against dollars, which a motion moves. It caps a hostile order's loss at the distance to the floor. It refuses the operator's sales when the market falls through the floor faster than a motion's 72 hours.
- **A budget on what the operator signs** in orders of two classes, for each period. It caps the amount and not the price, as the orders budgets already do, and a cancelled order still spends it.
- **An on-chain market reading**, such as a pool's time-weighted price. It is no feed that someone posts, but it is an outside market in the swap path, which the design keeps out (OD-45) [s4].

## Limits of this note

- The prototype is test code under `test/research/`. Nobody audited it.
- The agent measured gas inside a fork test, not in a transaction.
- The Curve reads are single quotes for one size. They are not a history of prices.
- The classes follow the six order tokens of today. A seventh token changes the count of pairs.
