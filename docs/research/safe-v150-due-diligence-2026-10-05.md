---
type: Research Note
title: Safe v1.5.0 due diligence, 2026-10-05
description: The evidence behind OD-17 — what the two audits of Safe v1.5.0 cover, the advisory and bug-bounty records, the changes after the release, how much use and value v1.5.0 has had on Ethereum mainnet, the incidents at Safe accounts, and the Safe paths that the vault uses.
tags: [safe, audit, incidents, evidence]
status: stable
review_status: slop
valid_as_of: 2026-10-05
stale_after: 2027-01-31T00:00:00Z
generated:
  by: claude-code/opus-5.5
  at: 2026-10-05T14:04:03Z
verified: []
sources:
  - id: s1
    resource: "https://github.com/safe-fndn/safe-smart-account/releases"
    title: Safe smart account releases — v1.5.0, published 2025-07-03 at dc437e8, is the latest release on 2026-10-05
  - id: s2
    resource: "https://github.com/safe-fndn/safe-smart-account/blob/dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be/docs/Safe_Audit_Report_1_5_0_Certora.pdf"
    title: Certora report on Safe v1.5.0, at the release tag — scope, findings and formal verification, commits 834e798 to 1c8b24a
  - id: s3
    resource: "https://github.com/safe-fndn/safe-smart-account/blob/dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be/docs/Safe_Audit_Report_1_5_0_Ackee.pdf"
    title: Ackee report on Safe v1.5.0, at the release tag — findings, fuzzing, and the fix review at 5d26505
  - id: s4
    resource: "https://github.com/safe-fndn/safe-smart-account/compare/5d26505388e9ee014ad9ac497aa48e3a13426eb1...dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be"
    title: Safe smart account — the changes from Ackee's fix-review commit to the v1.5.0 tag
  - id: s5
    resource: "https://github.com/safe-fndn/safe-smart-account/blob/f8fc2f2e75b650d63276aaa12cd3a455a5f5a990/CHANGELOG.md"
    title: Safe changelog on main at f8fc2f2 — the unreleased change, and the v1.5.0 changes and addresses
  - id: s6
    resource: "https://github.com/safe-fndn/safe-smart-account/pull/1115"
    title: Safe pull request 1115, merged 2026-06-05 — contract-signature reverts no longer propagate, and the return data is checked strictly
  - id: s7
    resource: "https://github.com/safe-fndn/safe-smart-account/pull/1123"
    title: Safe pull request 1123, merged 2026-09-24 — the revert length of simulate, reported through the bug bounty and ruled out of scope
  - id: s8
    resource: "https://github.com/safe-fndn/safe-smart-account/security/advisories"
    title: Safe smart account security advisories — none published on 2026-10-05
  - id: s9
    resource: "https://github.com/advisories?query=ecosystem%3Anpm+safe-global"
    title: GitHub Advisory Database — no advisory for the Safe contract packages on 2026-10-05
  - id: s10
    resource: "https://osv.dev/list?ecosystem=npm&q=safe-global"
    title: OSV database — no record for the Safe contract packages on 2026-10-05
  - id: s11
    resource: "https://docs.safefoundation.org/security/bug-bounty"
    title: Safe bug-bounty programme — versions in scope and rewards, read 2026-10-05
  - id: s12
    resource: "https://docs.safefoundation.org/security/past-bounties"
    title: Safe past bounties — seven paid reports, read 2026-10-05
  - id: s13
    resource: "https://safe.global/blog/safe-contract-version-1-5-0"
    title: Safe{Wallet} blog, 22 September 2026 — new Safes run v1.5.0, and Safe recommends upgrading
  - id: s14
    resource: "https://github.com/safe-fndn/safe-smart-account/blob/dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be/contracts/Safe.sol#L323-L328"
    title: Safe v1.5.0 checkNSignatures — a type-1 signature passes if the owner sent the transaction or approved its hash
  - id: s15
    resource: "https://github.com/safe-fndn/safe-smart-account/blob/dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be/contracts/Safe.sol#L270"
    title: Safe v1.5.0 — the contract-signature check through isValidSignature(bytes32,bytes)
  - id: s16
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/src/policy/SafeExec.sol#L18-L29"
    title: Kit SafeExec at 370e20a — the owner approves the hash, then the Safe executes on a type-1 signature
  - id: s17
    resource: "https://github.com/lidofinance/clutch/blob/370e20a21883c5ded9f20b4122fdb79eca2eb28e/script/DeployDryRun.s.sol#L73-L77"
    title: Kit deployment script at 370e20a — the Asset Safe is set up with no fallback handler
  - id: s18
    resource: "https://etherscan.io/block/26126347"
    title: Ethereum block 26126347, used for every chain read on this page
  - id: s19
    resource: "https://www.sygnia.co/blog/sygnia-investigation-bybit-hack/"
    title: Sygnia, 2025-03-16 — the Bybit theft of 2025-02-21
  - id: s20
    resource: "https://wazirx.com/blog/wazirx-cyber-attack-day-wise-report/"
    title: WazirX day-wise report — the multisig theft of 2024-07-18
  - id: s21
    resource: "https://crypto.news/post-mortem-reveals-stealthy-malware-injection-led-to-50m-radiant-capital-exploit/"
    title: crypto.news, 2024-10-18 — Radiant Capital's post-mortem of the breach of 2024-10-16
  - id: s22
    resource: "https://crypto.news/flashloopadapter-exploit-drains-305k-from-aave-linked-safe-wallets/"
    title: crypto.news, 2026-10-02 — the FlashLoopAdapter exploit of 2026-10-01
  - id: s23
    resource: "https://cryptoticker.io/en/base-vault-whitelist-multisig-hack-october-2026/"
    title: cryptoticker, 2026-10-05 — the theft from a vault on Base, 2026-10-04
  - id: s24
    resource: "https://etherscan.io/address/0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c"
    title: Aragon Agent — its EIP-1271 answers and its designated signer, read at block 26126347
  - id: s25
    resource: /research/safe-v150-guard-compatibility-2026-10-02.md
    title: Safe v1.5.0 and the screening guard, 2026-10-02 — the committee's owners and the Lido Safes checked
  - id: s26
    resource: "https://github.com/safe-global/safe-deployments/blob/7b1fb6d615ab2d2999550ec9166554b180e813e5/src/assets/v1.5.0/multi_send_call_only.json"
    title: Safe deployment record — MultiSendCallOnly v1.5.0, canonical address and code hash
---

# Safe v1.5.0 due diligence, 2026-10-05

EM asked for due diligence on the audits and the incident history of Safe v1.5.0 before ADR 005 and ADR 010 are accepted (OD-17). An agent did every step on this page on 2026-10-05. Safe's repository moved from `safe-global` to `safe-fndn` on GitHub, and the old links redirect.

## Summary

- Two audits cover the released code. Formal verification covers the vault's main Safe paths: transaction execution, `approveHash` and module execution [s2][s3][s4].
- No advisory and no paid bounty concerns Safe v1.5.0 [s8][s9][s10][s12].
- Safe v1.5.0 has a short record. Before March 2026, 57 Safes were created on it through Safe's factory. Safe{Wallet} made it the version of new Safes on 2026-09-22 [s13][s18].
- The large losses at Safe accounts came from signing interfaces, a third-party module and signers' own permission changes, not from Safe's contracts [s19][s20][s21][s22][s23].

## Release

- Safe released v1.5.0 on 2025-07-03 at commit `dc437e8`. On 2026-10-05 it is still the latest release [s1].
- Its main changes are the module guard, the current EIP-1271 function in the signature check, the extensible fallback handler, internal revert messages, and the removal of `createProxyWithCallback` [s5].

## Audits

| Audit | Period | Commits | Findings | Status |
|---|---|---|---|---|
| Certora [s2] | 2024-12-10 to 2025-01-14 | `834e798` to `1c8b24a` | 1 medium, 5 low, 3 informational | The medium and four lows are fixed. One low is "won't fix", because only the Safe itself can cause it |
| Ackee [s3] | 2025-04-14 to 2025-05-12; fix review 2025-05-20 to 2025-05-27 | `b115c4c`, and `d89d156` for the fallback handler; fix review at `5d26505` | 19: no critical or high, 1 medium, 2 low, 7 warnings, 9 informational | 17 fixed; 2 informational acknowledged |

- **Formal verification.** Certora's prover verified these properties, with each loop unrolled at most three times [s2]:
  - The Safe calls the transaction guard and the module guard as specified.
  - A successful module call comes from an enabled module. The internal `execute` runs only from `execTransaction` or from module execution.
  - Every executed transaction meets the threshold.
  - Only an owner changes its own approved hashes, and `approveHash` sets one.
  - Setup runs only once.
  The proof that two transactions cannot have the same hash ran on modified code, because the prover cannot read memory that is not aligned.
- **The medium findings.** Certora's M-01 was about ERC-777 support in the fallback handler, and it is fixed. Ackee's M1 let a front-runner deploy a Safe without the callback of `createProxyWithCallback`. It also affected the factories that were already deployed. Safe v1.5.0 removed the function [s3][s5].
- **What each audit saw.** From Ackee's fix-review commit to the release tag, one comment moved in `Safe.sol`, and the retired `SafeToL2Migration` contract was deleted [s4]. The release is therefore the code that Ackee reviewed. Certora's review ended before the later changes to the compatibility fallback handler and to the revert helpers, so only Ackee reviewed those [s2][s3].
- Ackee notes that Safe v1.5.0 is not compatible with EIP-7702 accounts, which are accounts that delegate their code to the Safe singleton [s3]. The vault's Safes are proxies, so this does not apply to them.

## Advisories and the bug bounty

- Safe's repository has no published security advisory [s8].
- The GitHub Advisory Database and the OSV database have no record for `@safe-global/safe-smart-account`, `@safe-global/safe-contracts` or `@gnosis.pm/safe-contracts` [s9][s10].
- Safe's bug bounty covers v1.5.0. It pays up to $1,000,000 for a high finding [s11].
- Safe lists seven paid bounties. None of them concerns v1.5.0 [s12].

## Changes after the release

Safe's main branch holds changes that no release contains yet [s5]:

- **Contract-signature reverts** (pull request 1115, 2026-06-05). A reverting `isValidSignature` call no longer passes its revert data up, and the return data is checked strictly. This changes only the path where an owner signs as a contract [s6].
- **The revert length of `simulate`** (pull request 1123, 2026-09-24). The fallback handler's `simulate` added 32 bytes to every error that it passed on. A bug-bounty report raised it, and Safe ruled it out of scope [s7].
- The other changes are documentation, self-ownership for EIP-7702 Safes, and P-256 signers [s5].

None of these changes is published as an advisory [s8].

## Use and value on Ethereum mainnet

The reads use block 26126347, hash `0x5c6fee319c014e74f050a59ce687539a00d178472237883da2c9c5259786c2f4`, time 2026-10-05T13:04:23Z [s18]. Months use each log's block time.

- **Created on v1.5.0.** Safe's v1.5.0 factory created 129,416 Safes on the two v1.5.0 singletons from 2025-07-03 to the block. 57 of them came before March 2026. From March 2026, between 12,021 and 30,910 came in each full month.
- **One deployer.** In a random sample of 40 of these creations, one externally owned account sent all 40 transactions. Five of its Safes that the agent checked had two owners, that account and one other, no fallback handler, and no ETH. The agent did not identify the deployer.
- **Upgraded to v1.5.0.** 783 older Safes moved to v1.5.0, in 793 `ChangedMasterCopy` logs. 306 of the logs came before 2026-09-22 and 487 on or after it. All 783 Safes were still on v1.5.0 at the block.
- **The default.** Safe{Wallet} made v1.5.0 the version of new Safes on 2026-09-22, and Safe recommends that existing Safes upgrade [s13].
- **Value.** The table gives, for each asset, how many of these Safes hold any, and the two largest single holdings. The page gives no totals and no prices.

| Asset | Created on v1.5.0: holders | Created: two largest | Upgraded to v1.5.0: holders | Upgraded: two largest |
|---|---|---|---|---|
| ETH | 617 | 1,680.01; 1,410.75 | 124 | 621.88; 230.47 |
| USDC | 318 | 31,357,447.02; 846,501.06 | 54 | 1,545,623.77; 500,000.90 |
| USDT | 157 | 5,000,030.00; 4,000,030.02 | 28 | 1,097,361.55; 139,282.10 |
| stETH | 11 | 303.18; 5.10 | 34 | 428.91; 278.46 |
| wstETH | 7 | 86.34; 0.01 | 4 | 550.00; 100.03 |
| WETH | 17 | 1.01; 0.12 | 35 | 10.00; 4.43 |
| DAI | 5 | 0.70; 0.48 | 9 | 30,707.21; 2,010.54 |

In the created set, one Safe holds 31,357,447.02 USDC, and no other holds more than 846,501.06 USDC. Most of the upgraded Safes came to v1.5.0 recently: 780 of the 793 upgrade logs are from September and October 2026.

## Incidents at Safe accounts

No loss in this list came from a defect in Safe's contracts.

| Date | Incident | Loss | How it happened |
|---|---|---|---|
| 2024-07-18 | WazirX | more than $230 million | The signers approved what a custody provider's web interface showed them. Their hardware wallets could not show the details [s20] |
| 2024-10-16 | Radiant Capital | more than $50 million | Malware on at least three developers' devices showed legitimate data while they signed `transferOwnership` of the lending pools [s21] |
| 2025-02-21 | Bybit | more than 400,000 ETH | The wallet interface was changed to turn one transaction into a delegatecall that replaced the wallet's implementation. Sygnia found no defect in Bybit's or Safe's contracts [s19] |
| 2026-10-01 | FlashLoopAdapter, a third-party Safe module | about $305,000 | The module trusted any caller that answered `isModuleEnabled`, and a fake Safe passed that check [s22] |
| 2026-10-04 | A vault on Base | about $6 million | Its Safe, three of seven, removed an attacker's contract from the vault's permission list and added it again one minute later, both times with valid signatures [s23] |

## What the vault uses

- **Asset Safe.** The Aragon Agent approves the transaction hash with `approveHash`, and the transaction runs on a type-1 signature: the owner sent the transaction or approved its hash [s14]. The kit does exactly this [s16]. The two modifiers call the Safe through module execution. Certora's formal verification covers both paths [s2].
- **The contract-signature path.** Safe v1.5.0 changed this path [s5][s15], and the next release changes it again [s6]. The Aragon Agent implements both EIP-1271 functions. At block 26126347, both return `0x00000000` for an unknown hash, and its designated signer is the zero address [s24]. A DAO vote could still pre-sign a hash for the Agent. Only a rule keeps the Asset Safe off this path.
- **The fallback handler.** The kit sets up the Asset Safe without a fallback handler [s17]. The compatibility fallback handler holds most of the code that only Ackee reviewed, and the `simulate` fix [s2][s7].
- **Operator Safe and emergency Safe.** Their owners are the committee's seven externally owned accounts, which sign with their own keys [s25]. A change to the contract-signature path does not affect them.
- **Delegatecall.** At Bybit, one signed delegatecall replaced the wallet's implementation [s19]. A Safe emits no event of its own for such a change. Safe's MultiSendCallOnly v1.5.0, the library that batches calls by delegatecall, is at `0xA83c336B20401Af773B6219BA5027174338D1836`. At block 26126347 its code hash is `0xcdbdcec38d2f1c7d961b0029ff8416b7e86e9974d6f0e9c9580c7d17fcfb6663`, as in Safe's deployment record [s26].

## How to reproduce

Set `ETHERSCAN_API_KEY` and `ETH_RPC_URL` in your shell. The scripts read them from the environment. Never write them into a file. Block 22838493 created the v1.5.0 singleton.

```sh
B=26126347
python3 scripts/research/safe_v150_logs.py 22838493 $B /tmp/od17 --sample 40
uv run --with eth-abi python3 scripts/research/safe_v150_balances.py /tmp/od17/safe_v150_creations_22838493_$B.tsv $B --top 2
uv run --with eth-abi python3 scripts/research/safe_v150_balances.py /tmp/od17/safe_v150_migrations_22838493_$B.tsv $B --top 2
cast call <safe> 'getOwners()(address[])' --block $B         # the five sampled Safes
AGENT=0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c
cast call $AGENT 'isValidSignature(bytes32,bytes)(bytes4)' 0x$(printf '11%.0s' {1..32}) 0x --block $B
cast call $AGENT 'isValidSignature(bytes,bytes)(bytes4)' 0x11 0x --block $B
cast call $AGENT 'designatedSigner()(address)' --block $B
cast codehash 0xA83c336B20401Af773B6219BA5027174338D1836 --block $B   # MultiSendCallOnly v1.5.0
curl -sL https://api.github.com/repos/safe-fndn/safe-smart-account/security-advisories
curl -s 'https://api.github.com/advisories?ecosystem=npm&affects=@safe-global/safe-smart-account'
curl -s -X POST https://api.osv.dev/v1/query -d '{"package":{"name":"@safe-global/safe-smart-account","ecosystem":"npm"}}'
git diff 5d26505 v1.5.0 -- contracts                          # in a clone of safe-fndn/safe-smart-account
```

The run of 2026-10-05 wrote a creations file with sha256 `76198f484daaaf7e1a7a1bd6a4cae19c4497c2796f9ef460da84845824f038a7` and a migrations file with sha256 `c1e9e0ed7e23361b0ac8d32fd123d024fff61e3d36cb827903c8d29bdb57be62`.

## Limits

- The counts cover Safe's v1.5.0 factory and its migration contract. A Safe that was created or upgraded another way is not counted.
- The value reads cover seven assets and no DeFi positions, and they give no prices.
- The incident list holds the large and recent cases at Safe accounts that the agent found. It is not complete, and three of its sources are news reports.
- The deployer sample has 40 transactions.
- This page records evidence. EM's decision is in the [decision log](/registers/decision-log.md).
