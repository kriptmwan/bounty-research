DECISION: CAUTION — 0 findings survive; nothing filing-ready; the Jan 2023 ToB report could not be retrieved, so pre-v3 dedup is incomplete — re-attempt retrieval before any future filing touching pre-v3 code paths.

# Adversarial Code Audit — Frax Fraxlend (Option 1)

**Repo:** `FraxFinance/fraxlend`, pinned HEAD `2bed49d4dcc6702d92dede825c3424893517d841` (2025-11-12)
**Date:** 2026-11-14 · **Mode:** single pass, local only + read-only mainnet calls, no transactions, no contact with the Frax team, zero GitHub API calls
**Pipeline:** Phase 0 groundwork → deterministic triage → Recon → 4 domain Hunters → Skeptic/Referee (skipped: zero findings per domain, empty artifacts preserved) → parent verification
**Bounty bar (impact gate):** Frax reviews ONLY demonstrated theft-of-funds or permanent-freezing paths on CURRENT LIVE deployments, each with a working mainnet-fork PoC quantifying funds at risk. Theoretical issues, scanner/AI output without verified PoC, and low/medium findings are NOT reviewed. Every Hunter claim was gated on this bar; 52 sub-bar observations are recorded separately as non-qualifying.

## Verdict

**0 confirmed findings. 0 filing-ready. 0 Hunter candidates across all four domains.**

Four domain Hunters read all 16 implementation files in full (~3,164 LOC core + deployed-only rate/oracle/registry sources), deduped against a 22-entry exclusion list, and checked the sharpest leads against live on-chain state. Every suspicious pattern died by dedup, by a checked defense, by a privileged-only precondition (bounty-excluded), or by quantitative unreachability on live deployments. This is a "no findings" report, not a clean bill of health: single-pass coverage, the Jan 2023 ToB dedup gap (below), and the stated caveats apply.

No PoCs were built — none were required with zero survivors. Fork infrastructure was proven working (smoke test PASS), so any future candidate can be PoC'd immediately.

## Phase 0 groundwork (all closed)

| Item | Result |
|---|---|
| Delta vs Jan 2023 audit | Baseline `c50cc7c` (2022-09-14, last public commit before 2023-02-01) — a public proxy, NOT the audited code (ToB reviewed private snapshots). 5 commits baseline→HEAD; nearly all change in one v3 squash `f474378` (2023-06-16); zero commits in 2024; 2025 commits are interface additions + exactly 3 logic changes. See `DELTA-2023-2025.md`. |
| Exclusion list | 22 entries (EX-001…EX-022): ToB Aug 2022 (6), ToB Nov 2022 (13), ToB Oct 2023 oracle (1), Zellic router (2). All 14 local PDFs read. See `exclusions/EXCLUSION_LIST.md`. |
| Canonical deployer/registry | Deployer `0xF767A82a188305461b6f01a7706f7Bc0ba941ffF` VERIFIED (Sourcify exact, v5.0.0 = HEAD, registry-authorized). Registry `0xD6E9D27C75Afd88ad24Cd5EdccdC76fd2fc3A751` (71 pairs, owner = timelock). Legacy deployer `0x5d6e79…` is genuine but superseded/deauthorized. See `ONCHAIN-GROUNDWORK.md`. |
| Reference pair | `0xaB3cb84c310186B2Fa4B4503624A5D90b5DcB22D` (ffrxUSD(sfrxETH)-58, v3.1.0): 4,592,962.53 frxUSD supplied, 3,424,868.50 borrowed, 4,329.78 sfrxETH collateral, maxLTV 75%, unpaused, unlimited limits. Oracle `0x4355903F610D0F94ee476df6e3227811ff7efeE1` (SfrxEthUsdTripleOracle v3.0.0); rate contract `0x987a96c6637cF7E7B369BA7C1110d5fB69fb2d17` (VariableInterestRateSettable v3.0.0). |
| Deployment correspondence | Deployer MATCH (byte-identical). Reference pair PARTIAL — 7/8 files identical; `FraxlendPairCore.sol` has exactly 3 deltas (version 3.1.0, fee default 10_000, `_isSolvent` LTV reorder). Registry MISMATCH (deployed = older `Ownable` version). Rate calculator + oracle main file NO-RECORD in any public repo — audited from preserved Sourcify sources. |
| Fork smoke test | PASS (pinned block 26,410,483, 13s). Standing requirement: `evm_version = "cancun"` or frxUSD interactions revert with `NotActivated` (PUSH0). See `poc-smoke/`. |

## Hunter coverage

| Domain | Files | Candidates | Non-qualifying |
|---|---|---|---|
| A — pair core accounting/interest/solvency | FraxlendPairCore.sol (1,277 lines) + VaultAccount.sol | 0 | 9 (`nonqualifying-A.md`) |
| B — ERC-4626/admin/pauses/fees | FraxlendPair.sol + AccessControl + Constants + Errors | 0 | 14 (`nonqualifying-B.md`) |
| C — rate engine + oracles (incl. deployed-only) | Variable/LinearInterestRate, DualOracleChainlinkUniV3, deployed Settable rate + Triple Oracle + abstracts | 0 | 17 (`nonqualifying-C.md`) |
| D — deployer/registry/whitelist/timelock | Deployer, deployed registry, Whitelist, Timelock2Step | 0 | 12 (`nonqualifying-D.md`) |

## Strongest near-misses, and why they fail the bar

1. **VaultAccount `toAmount` round-up division-by-zero** (`VaultAccount.sol:29-35`): when `total.amount == 0` and `total.shares > 0`, the round-up branch divides by `total.amount`. Parent re-read and confirmed the code shape. Killed on reachability: reaching that state requires a write-off larger than all accrued interest (~310k frxUSD on the reference pair, via privileged/liquidation paths), and any permissionless borrow heals the state (`toShares` returns `shares = amount` when `amount == 0`). Not permanent, not attacker-reachable. Dedup-uncertain (pre-v3 code; Jan 2023 gap). (NQ-A-1)
2. **`_calculateInterest` silently skips accrual on uint128 overflow — but advances time** (`FraxlendPairCore.sol:353-408` + `_addInterest`). Parent re-read and confirmed: the overflow guard skips the accrual while `isInterestUpdated` stays true, so `lastTimestamp` advances and that period's interest is skipped. Killed quantitatively: requires interest pushing totals past `type(uint128).max` (~3.4e38 units) — unreachable. (NQ-A-3)
3. **Bad-oracle data stored; liquidation ignores the deviation gate** (`_updateExchangeRate` warn-don't-revert; `liquidate` uses the low rate). No standalone pair-core trigger — exploitability depends entirely on manipulating the live Triple Oracle, which Hunter C killed quantitatively (EMA clamp [0.9, 1.0], raw 0.9976, max favorable manipulation ~0.24%; 900s TWAP over a deep pool; live deviation ~0.2% vs the 5% gate; all feeds fresh). (NQ-A-6, NQ-C-6/8/9)
4. **Triple Oracle reverts (instead of `isBadData`) on negative/zero feed answers.** Real robustness gap, but requires a Chainlink/Redstone feed malfunction an attacker cannot cause. (NQ-C-5)
5. **Unbounded privileged setters** (`setMaxLTV` incl. 0 → `_isSolvent` always true, `setOracle`, `setRateContract`, `setLiquidationFees`, `setVertexRatePercent`): all timelock/owner-gated; the bounty excludes issues requiring privileged keys. SETTER_ROLE on the live rate contract is held only by the timelock (verified on-chain; historical enumeration blocked by archive 403). (NQ-A-7, NQ-B-1…4, NQ-C-3)
6. **Share-price donation/inflation:** disproved — share math uses accounting totals, not token balances, and deposit/mint accrue interest before pricing, matching previews. (Hunter B killed lead)
7. **Permissionless pause via deployer:** disproved — `globalPause` is circuit-breaker-only with no in-repo permissionless forwarding. (Hunter B killed lead)
8. **Registry poisoning via fake pairs:** fails three ways — `deploy()` is whitelist-gated (owner-only membership), no live pair reads the registry (grep-verified), and a hypothetical future fake pair has $0 at risk today. (NQ-D-1)

## Parent-verified live observation (non-qualifying)

Hunter C reported 4 dust pairs whose oracles currently revert on `getPrices()`. The parent verified one on-chain: the ezETH oracle `0x05D95C1fCB2C2ef1553De5e208D268002724c278` (pair fFRAX(ezETH)-33, 5 FRAX supplied, 0 borrows) reverts with panic division-by-zero (`0x12`). This proves the "reverting oracle bricks borrow/liquidate paths" pattern exists live — but combined funds at risk across the dust pairs are ~$15–25 with zero borrows, the cause is feed malfunction (not attacker-triggerable), and no theft path exists. Recorded as an observation, not a finding. The other three oracle addresses were reported truncated and were not individually re-verified.

## No-live-deployment notes

- `DualOracleChainlinkUniV3.sol`: zero deployments found across all 49 distinct v3 pair oracles.
- `LinearInterestRate`: none of the 7 registry rate contracts is this contract (5× Variable V2/V3, 2× V1 Time-Weighted).
- Findings in either file would not be filing-ready without a live deployment.

## Caveats (including unresolved §5 gaps)

1. **Jan 2023 ToB Fraxlend & veFPIS report UNRETRIEVED** — absent from `trailofbits/publications` (verified via `git ls-tree`), unlinked on the docs audits page, ToB library link dead, 4 web searches found no copy. Its findings are unknown and NOT in the exclusion list. Any future candidate touching pre-v3 code paths must re-attempt retrieval first.
2. **v3.2.0 pair sources not diffed.** Four live pairs (incl. #4/#5/#8 by TVL) run v3.2.0; only the v3.1.0 reference pair was source-compared. A finding claimed against a v3.2.0 pair needs its Sourcify source diffed first.
3. **Whitelist membership not enumerated** (mapping + historical events); Hunter D's verdict assumes members are trusted Frax operators.
4. **SETTER_ROLE historical holders not enumerated** — publicnode archive `eth_getLogs` returns 403. Current holders verified (timelock only).
5. **V1 pairs out of scope** (notably WBTC/FRAX, 1.28M FRAX supplied) — substantially older code, not audited in this pass.
6. **Registry pairs beyond the reference pair were inventoried, not individually audited.** A pair-specific finding (e.g., a different oracle/rate configuration) would need that pair's contracts verified the same way.
7. **Deployed-vs-HEAD compiler settings differ** (optimizer runs 832 deployed vs 200 in repo `foundry.toml`) — settings-only difference; Sourcify exact matches are unaffected.
8. **7-Question Gate: not applicable** — no Referee-confirmed findings exist to gate. Any future survivor must pass `triage_validation` before any report is written or filed.
9. **Adversarial self-check (frontier model asked to disprove) is a FILING step** — pending; not applicable with zero findings. It must be budgeted into any future filing, with the full prompt + complete response embedded in the gist.

## Artifacts

- `SCOPE.md` (scoping), `DELTA-2023-2025.md`, `exclusions/EXCLUSION_LIST.md` (22 entries), `ONCHAIN-GROUNDWORK.md` + `pairs-enumeration-block26410499.json`, `sourcify/sources/` (95 deployed source files), `poc-smoke/` (passing fork smoke test)
- `artifacts/triage.json`, `artifacts/retrieval-plan.json`, `artifacts/recon.json`, `artifacts/hunter-findings-{A,B,C,D}.json` (all `[]`), `artifacts/nonqualifying-{A,B,C,D}.md` (52 items), `artifacts/skeptic.json` (`[]`), `artifacts/referee.json` (`[]`), `artifacts/coverage.json`, `artifacts/verification-report.json`, `artifacts/scan-report.json`
- Source integrity: HEAD `2bed49d4` verified matching and tree clean at dispatch, mid-run, and before concluding. No target code was modified; no commits were created in the target checkout.

## Files for a future filing (none — nothing to file)

No `findings/` or `poc/` directories were created: with zero surviving findings there is nothing to draft, and no gist, contact, or submission was made or attempted.
