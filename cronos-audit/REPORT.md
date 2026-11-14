# REPORT — Cronos Smart Contracts (HackenProof) / VVS Finance audit

**Date:** 2026-11-14 (evening WIB). **Mode:** audit + runnable proofs ONLY. No account, no filing, no submission, no live-mainnet testing. Local Foundry tests + read-only chain reads only.
**Scope:** the 6 HackenProof targets only — VVS WCRO, Factory, Router, Token, Workbench, Craftsman (see PRECHECK.md for the full pin, addresses, and gate record).
**Repos pinned:** `vvs-finance/vvs-farm` @ `acd79b99d88157b9d520eeac92e8c6424ae9d8de`; OpenZeppelin contracts 3.4.0 @ `fa64a1ced0b70ab89073d5d0b6e01b0778f7e7d6`; Uniswap `v2-core` @ `4dd59067c76dea4a0e8e4bfdda41877a6b16dedc`, `v2-periphery` @ `ed24991304291297c3b4a52818d02f46a17aa9a2` (reference only); `vvs-finance/swap-sdk` @ `7a8499fef3e3ec61276e25af9afee728df83a676` (address corroboration only).
**Toolchain:** forge/cast 1.5.1 (`~/.foundry/bin`), solc 0.6.12. Go absent (irrelevant — all targets are Solidity). No Docker. Target code never patched; repo checkouts verified clean at the end of the run.

## DECISION: BLOCK — do not file anything; track closed

**Reason (three independent legs, any one suffices):**

1. **Zero surviving findings.** 12 Hunter candidates were raised; all 12 were killed by the Skeptic/Referee pipeline (see §3). The two closest candidates were executed in Foundry against the verbatim deployed code and proven non-exploitable within program scope. There is nothing to file.
2. **The workflow gate blocks filing anyway.** The program excludes "reports that are suspected to be generated using automated or generative tools." This audit was agent-assisted and is NOT filing-ready. Any future finding here would need a HAND-WRITTEN report by the user, with the user independently re-verifying every claim. Do not submit agent-drafted text to this program.
3. **Unverified submission gate.** No reputation minimum is stated publicly, but HackenProof reputation gates are dashboard-gated; no account was created to check. A fresh account may not be able to submit at all. (Plus payout KYC post-validity, and a 24-hour reporting clock once a finding is discovered.)

**What would reopen this track:** (a) the verified Factory/Router/Pair source obtained via a browser agent on the current Cronos explorer, enabling a source-level pass over the one leg audited here by forensics only (§5); or (b) a material on-chain state change (e.g. `BONUS_MULTIPLIER` raised above 0, a migrator set, a new pool type added). Neither is expected; do not re-audit on a timer.

## 1. What was audited, and how strongly

| Target | Evidence strength | Basis |
|---|---|---|
| Craftsman (MasterChef fork, 344 lines) | **Source = deployed, proven.** Byte-identical runtime code modulo metadata (solc 0.6.12, optimizer runs 200). Full line-read. | `repos/vvs-farm/contracts/Craftsman.sol` |
| Workbench / BENCH (37 lines) | **Source = deployed, proven.** Same byte-identity check. Full line-read. | `repos/vvs-farm/contracts/Workbench.sol` |
| VVSToken + VVSInitMintable (17 + 58 lines) | **Source = deployed, proven.** Same byte-identity check. Full line-read. | `repos/vvs-farm/contracts/VVSToken.sol`, `VVSInitMintable.sol` |
| WCRO | Interface + behavior only. Repo file is NOT the deployed code (1,786 B vs 1,920 B deployed, first diff byte 11). Deployed interface = exact WETH9 selector set; `totalSupply()` == native balance exactly. No anomaly. | On-chain probes |
| Factory + Pair | Bytecode forensics + behavioral probes, NO source line-read (source unobtainable from this VM — see PRECHECK.md for the enumerated failures). CREATE2/init-hash, DOMAIN_SEPARATOR, fee math, revert strings all match a renamed UniswapV2 fork + Pancake-style `INIT_CODE_PAIR_HASH` getter. No deviation found in the probed surface. | On-chain probes + `uniswap-v2-core` reference |
| Router | Same forensic level as Factory. All canonical Router02 functions probed present; fee math and revert strings match renamed UniswapV2Router02. No deviation found in the probed surface. | On-chain probes + `uniswap-v2-periphery` reference |

Out of scope and NOT audited (read only as context, no findings reported): VVSVault, IGO, CraftsmanAdmin, Timelock, MockERC20, Multicall2, Tectonic, VVS V3 contracts, SmartRouter. VVSVault was read solely to settle whether BENCH has a redemption path (it does not — BENCH is a receipt token held by the vault; `balanceOf()` counts only VVS).

Pipeline artifacts (JSON, per the adversarial audit skill) live in this directory: `triage.json`, `retrieval-plan.json`, `recon.json`, `hunter-findings.json`, `skeptic.json`, `referee.json`, `verification-report.json`, `coverage.json`, `scan-report.json`. This report is derived from `referee.json` + executed PoCs.

## 2. Architecture in one paragraph (Recon summary)

VVS is a 2021 UniswapV2 + Sushi MasterChef fork on Cronos (chain 25). Users swap via the Router against Factory-created pairs (23,775 pairs; protocol fee on, `feeTo` = `0x3bc41521a7bF38b279FC5C3BD6C0DC290767b115`); LPs stake pair tokens in Craftsman (172 pools) for VVS emissions, and VVS holders stake in pool 0 (`enterStaking`/`leaveStaking`) receiving BENCH 1:1 as a receipt. Rewards are minted by Craftsman to the Workbench contract, which pays them out via `safeVVSTransfer` (capped at its balance). VVS supply halves yearly via `distributeSupply` (owner-only). Trust boundaries: owner EOA (`0x7ed52E…`) holds all admin powers (add/set pools, multiplier, migrator, supply distribution); the migrator is unset and the multiplier is 0, so the live system currently emits nothing and cannot migrate. All value movement is plain ERC20 transfers; no oracles, no signatures except pair `permit`, no upgradeability in the 6 targets.

## 3. Candidates raised and killed (Hunter → Skeptic → Referee)

All verdicts are `NOT_A_BUG` for filing. "Kill" cites the decisive evidence: executed PoC, program rule, or prior-audit duplicate. Severities below are the Hunter's initial rating, shown only to record what was considered.

### BUG-1 — `emergencyWithdraw(0)` retains BENCH (Hunter: Medium) → NOT_A_BUG
- **Mechanic (REAL, proven):** `Craftsman.emergencyWithdraw` (Craftsman.sol, emergency-withdraw function) has no `pid != 0` guard, unlike `deposit`/`withdraw`. It returns the staked VVS without calling `bench.burn`, so the exiter keeps BENCH 1:1 with the exited stake. PoC `testEmergencyWithdrawKeepsBenchButExtractsNothing` proves: VVS fully returned, BENCH retained, stake/debt zeroed, `pendingVVS` = 0.
- **Why it is not a finding:** BENCH has no redemption path anywhere in scope (Workbench exposes only owner-gated `mint`/`burn`/`safeVVSTransfer`; VVSVault never redeems BENCH; `leaveStaking` requires `user.amount`, which is 0). The PoC proves retained BENCH extracts exactly 0 VVS (`leaveStaking(1)` reverts, `leaveStaking(0)` pays 0, re-staking mints only the new amount). The only effect is BENCH supply inflation vs staked VVS — i.e. dilution of a receipt/incentive token, which the program explicitly excludes ("dilutions of protocol incentive rewards but do not result in the loss of user funds"; plus "VVS-Bench is Out of Scope"). No user funds are lost; the exiter forfeits pending rewards. **PoC-rule compliance: n/a — no fund loss, no Critical claim.**
- **Dedup:** distinct mechanism from SlowMist N2 (vault/admin interaction), but killed on impact + explicit exclusions regardless.

### BUG-2 — Reentrant double-pay of pending rewards via hook LP token (Hunter: High) → NOT_A_BUG
- **Mechanic (REAL, proven, precondition-gated):** `deposit`/`withdraw` pay pending rewards BEFORE the LP `transferFrom` and before updating `user.amount`/`rewardDebt` (CEI violation). If the pool's LP token calls back into the sender during `transferFrom` (ERC777-style hook), a reentrant `deposit(pid, 0)` pays the same pending amount a second time. PoC `testHookLpDepositDoublePaysPending` proves gain = 2× quoted pending with exact Workbench accounting; control PoC `testPlainLpDepositPaysExactlyPending` proves gain = exactly quoted pending with a plain ERC20.
- **Why it is not a finding (triple kill):** (1) **Duplicate:** SlowMist N9 reported this exact CEI pattern in `emergencyWithdraw` (same file, same principle) — "Ignored; will not use ERC777 token." (2) **Excluded precondition:** exploitation requires the owner to add a hook/malicious token as a pool LP — "attacks requiring access to privileged addresses" and "vulnerabilities that require intervention from a third party (e.g., adding a malicious liquidity pool)" are both out of scope. All 172 live pools use VVS-LP pairs or VVS, none of which has transfer hooks. (3) **Live state:** `BONUS_MULTIPLIER` = 0, so no rewards accrue to double-pay today. No PoC within program scope can demonstrate fund loss without the excluded precondition.

### BUG-3 — Pair `permit` signature malleability (Hunter: Low) → NOT_A_BUG
- **Evidence:** the deployed pair bytecode contains NEITHER the secp256k1 half-order constant nor the curve-order constant, i.e. the SlowMist N5 "Fixed" s-bound check does **not** appear in the deployed pair; `permit` behaves like canonical UniswapV2Pair (ecrecover + owner match only). Revert string `VVS: INVALID_SIGNATURE` confirmed by probe.
- **Why it is not a finding:** malleability lets an observer flip `(v, s)` to an equivalent signature for the SAME `(owner, spender, value, nonce, deadline)` — the approval lands for the same spender; the attacker gains no approval and no funds. Worst case is griefing a victim's `removeLiquidityWithPermit` (nonce consumed → victim's tx reverts; victim retries with a fresh signature) — DoS, explicitly out of scope, and no fund loss. It is also a **duplicate** (SlowMist N5) and a **previously-known Ethereum/fork behavior** (canonical UniswapV2 pairs have behaved this way since 2020), both excluded. No live testing was performed (prohibited); the conclusion rests on bytecode inspection + the well-established malleability analysis, and is recorded as such.

### BUG-4 — Pair `permit` DOMAIN_SEPARATOR chain-split replay (Hunter: Low) → NOT_A_BUG
- **Evidence:** `DOMAIN_SEPARATOR` recomputed exactly from name "VVS Finance LPs", version "1", chainId 25, verifying contract = pair. The separator is fixed at deploy (canonical UniswapV2 behavior).
- **Why it is not a finding:** replay requires a future Cronos chain split preserving chainId 25 and pair addresses — hypothetical, not "unequivocally executable." **Duplicate** of SlowMist N4 (ignored). Previously-known fork behavior, excluded.

### BUG-5 — WCRO unchecked arithmetic in Solidity 0.6.12 (Hunter: Low) → NOT_A_BUG
- The repo WCRO file (not the deployed code) and canonical WETH9 both use unchecked `+=`/`-=` in 0.6.x. Overflow requires a single balance near 2²⁵⁶, impossible: balances are bounded by the CRO supply (`totalSupply` = 6.84e26 wei « 2²⁵⁶) and every increment is backed by `msg.value` / an existing balance. Canonical WETH9 behavior, previously-known, excluded. Deployed WCRO verified fully backed (`totalSupply()` == native balance).

### BUG-6 — Owner powers: uncapped mint, multiplier, migrator, pool admin, supply distribution (Hunter: Medium) → NOT_A_BUG
- `updateMultiplier`, `setMigrator`, `add`/`set`, `distributeSupply`, and `VVSToken.mint` (owner = Craftsman) give the owner EOA sweeping powers, including inflating VVS and (via a malicious migrator) stealing staked LP. All require the privileged owner address — explicitly excluded ("attacks requiring access to privileged addresses"). **Duplicates** of SlowMist N1/N10 (excessive authority, confirmed/ignored). Live state further neuters two legs: migrator is unset, multiplier is 0.

### BUG-7 — Fee-on-transfer / deflationary LP accounting mismatch (Hunter: Medium) → NOT_A_BUG
- `deposit` credits `user.amount` with the nominal `_amount` while `safeTransferFrom` may deliver less for fee-on-transfer tokens; `lpSupply` (balance-based) and `user.amount` then diverge. **Duplicate** of SlowMist N6 (ignored — "will not use deflationary token"). Requires an owner-added fee-on-transfer pool (excluded precondition). No live pool uses such a token (all pools are VVS-LP/VVS).

### BUG-8 — Direct LP donation dilutes `accVVSPerShare` (Hunter: Low) → NOT_A_BUG
- `updatePool`/`pendingVVS` use `lpToken.balanceOf(Craftsman)` as supply, so donated LP inflates supply and dilutes per-share rewards. The donor harms only themselves (donated LP is stuck, benefiting all stakers pro-rata); no drain path exists. Known MasterChef behavior, previously-known fork issue, excluded. Rewards-dilution impact is separately excluded.

### BUG-9 — BENCH transfer self-locks a stake (Hunter: Low) → NOT_A_BUG
- `leaveStaking` burns the caller's BENCH; a staker who transfers BENCH away cannot exit until BENCH is re-acquired. PoC `testBenchRequiredToLeaveStaking` proves the revert (`ERC20: burn amount exceeds balance`) AND the recovery (transfer BENCH back → exit succeeds). Self-inflicted, recoverable via an ordinary transfer; no attacker can force it; no funds are lost. Receipt-token design, not a vulnerability.

### BUG-10 — `updatePool` division by zero if `totalAllocPoint` == 0 (Hunter: Low) → NOT_A_BUG
- Reachable only if the owner zeroes every pool's allocation (including via `set(0, 0, …)` when other pools sum to 0). Owner-only trigger (privileged, excluded); impact is a revert/DoS of reward updates until the owner fixes it (DoS excluded). No fund loss: stakes remain withdrawable via `emergencyWithdraw` (which does not call `updatePool`).

### BUG-11 — `distributeSupply` catch-up calls after a long delay (Hunter: Low) → NOT_A_BUG
- `nextDistributionTimestamp` advances by fixed 365-day windows, so after a multi-year gap the owner can call `distributeSupply` repeatedly in succession, halving `SUPPLY_PER_YEAR` each time and minting team amounts each time. Owner-only (privileged, excluded); team amounts are capped per call by the 30%-community rule (`communitySupplyPerYear >= 30%` of the halved supply). No unprivileged path.

### BUG-12 — Canonical UniswapV2 AMM issues in Factory/Router/Pair (Hunter: various) → NOT_A_BUG
- Sandwich/MEV, flash-loan price manipulation via `getReserves`/TWAP-less pricing, `skim`/`sync` griefing, first-deposit `MINIMUM_LIQUIDITY` (1000, verified) rounding, and empty-pool share inflation are all canonical UniswapV2 behaviors. Every one is a "previously known vulnerability on Ethereum (and any fork)" — excluded — and empty-pool attacks are separately excluded by name. No VVS-specific deviation was found in the probed surface (fee math 997/1000 verified; `MINIMUM_LIQUIDITY` verified; CREATE2/init-hash verified; revert strings renamed-only). A deviation hiding outside the probed surface cannot be excluded without source (§5) — stated as a coverage limit, not a finding.

## 4. PoC-rule compliance

No surviving finding exists, so no Critical PoC is offered. For the record, the two executed mechanics were tested locally in Foundry (private testnet equivalent, $0 value, no impersonation of funded wallets, no mainnet interaction) — consistent with the program's testing rules. Had BUG-2 survived, it would have FAILED the Critical PoC rules: it needs an owner-added malicious pool (staging beyond the permitted scope + privileged intervention) and its damage is rewards dilution (excluded from damage calculation). BUG-1 fails on damage: net positive value post-attack = 0.

## 5. Coverage, honestly stated

- **Fully covered (source = deployed, line-read + executed tests):** Craftsman, Workbench, VVSToken, VVSInitMintable — 456 lines + OZ 3.4.0 dependencies as used. Single pass, Hunter→Skeptic→Referee, with 4/4 Foundry tests passing.
- **Forensically covered (no source line-read):** Factory, Router, Pair, deployed WCRO. Probes: 30+ read-only calls (getters, CREATE2 reproduction, DOMAIN_SEPARATOR recomputation, fee math, revert-string fingerprinting, bytecode constant search). No source-level deviation hunt was possible. This is the audit's one material gap; closing it needs the verified source from the current Cronos explorer via a browser agent (all API routes from this VM failed — see PRECHECK.md). Given the fork's age, audit history, and the program's fork-exclusion, the expected value of that follow-up is low, but it is the only honest "unfinished" item.
- **Not covered:** VVSVault/IGO/Timelock/CraftsmanAdmin (out of scope), VVS V3, SmartRouter, Tectonic (no target row), off-chain/indexer code, governance processes. No fuzzing campaign was run (single pass; the executed tests target the exact candidate mechanics). No live-mainnet or testnet transactions were sent, per program rules.
- **Single-pass statement:** this was a single adversarial pass, not a complete-coverage loop. The "0 findings" verdict describes this pass over the stated scope and evidence levels, not a proof that no bug exists anywhere in the fork.

## 6. What would be needed before ANY filing decision (none is recommended)

1. A surviving finding — none exists. Do not manufacture one from the killed candidates above.
2. The user hand-writing the entire report (automation-suspicion exclusion) after independently re-verifying every claim.
3. A dashboard check of the HackenProof reputation gate + live submit form (requires an account; not done here).
4. A Critical PoC meeting ALL program constraints ($300 cap, single transaction, exact block number, no impersonation of funded wallets) on a private testnet — plus the 24-hour reporting clock starting at discovery.
5. Payout KYC (post-validity) with the Cronos team.

## 7. Reproduction (parent re-verification)

```bash
# Toolchain
export PATH="$HOME/.foundry/bin:$PATH"   # forge/cast 1.5.1

# 1) Kill-proof PoCs (verbatim target sources, OZ 3.4.0, solc 0.6.12)
cd ~/workspace/cronos-audit/poc && forge test
# Expect: 4 passed; 0 failed (test names + gas in poc/test-output.txt)

# 2) Deployed-bytecode identity (Craftsman/Workbench/VVSToken; WCRO differs)
# Rebuild with optimizer runs=200 in a scratch copy, fetch deployed code via
# cast code, strip the solc metadata trailer from both, compare bytes.
# (Procedure executed 2026-11-14; Craftsman/Workbench/VVSToken identical,
#  WCRO first diff at byte 11, 1,786 B compiled vs 1,920 B deployed.)

# 3) On-chain pins (read-only; RPC https://evm.cronos.org, chain 25)
cast chain-id --rpc-url https://evm.cronos.org   # 25
cast call 0x145863Eb42Cf62847A6Ca784e6416C1682b1b2Ae "factory() returns (address)" --rpc-url https://evm.cronos.org
cast call 0x145863Eb42Cf62847A6Ca784e6416C1682b1b2Ae "WETH() returns (address)" --rpc-url https://evm.cronos.org
cast call 0xDccd6455AE04b03d785F12196B492b18129564bc "BONUS_MULTIPLIER() returns (uint256)" --rpc-url https://evm.cronos.org  # 0
cast call 0xDccd6455AE04b03d785F12196B492b18129564bc "migrator() returns (address)" --rpc-url https://evm.cronos.org  # 0x0
cast call 0xDccd6455AE04b03d785F12196B492b18129564bc "poolLength() returns (uint256)" --rpc-url https://evm.cronos.org  # 172
cast call 0x3B44B2a187a7b3824131F8db5a74194D0a42Fc15 "INIT_CODE_PAIR_HASH() returns (bytes32)" --rpc-url https://evm.cronos.org
# CREATE2 check: keccak(0xff ++ factory ++ keccak(token0 ++ token1) ++ INIT_CODE_PAIR_HASH)[12:]
#   for (VVS, WCRO) == 0xbf62c67eA509E86F07c8c69d0286C0636C50270b == getPair(WCRO, VVS). Verified 2026-11-14.

# 4) Target source hashes (repo copies == PoC copies, byte-identical)
sha256sum ~/workspace/cronos-audit/repos/vvs-farm/contracts/Craftsman.sol \
          ~/workspace/cronos-audit/poc/src/target/Craftsman.sol
# e5491e06fefa9a044070322853241d9d27d0032663b347fe14d8217fa093b6d3 (both)
```

## 8. Files in this work dir

- `PRECHECK.md` — live-page verification, scope pin, gates, disclosure rule, dedup.
- `REPORT.md` — this file.
- `poc/` — Foundry project: verbatim target copies (`src/target/`), kill-proof tests (`test/CronosAudit.t.sol`), `foundry.toml`, `README.md`, `test-output.txt`. OZ 3.4.0 vendored under `poc/lib/oz-contracts/` (copy of the pinned clone, for the solc sandbox).
- `repos/` — read-only clones: `vvs-farm`, `swap-sdk`, `uniswap-v2-core`, `uniswap-v2-periphery`, `oz-3.4.0`. Never modified (verified clean).
- Pipeline JSON: `triage.json`, `retrieval-plan.json`, `recon.json`, `hunter-findings.json`, `skeptic.json`, `referee.json`, `verification-report.json`, `coverage.json`, `scan-report.json`.
