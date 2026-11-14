# Fraxlend — Dedup exclusion list (known issues, do not re-report)

**Phase 0A groundwork. Read-only. No new-bug hunting.**
**Date:** 2026-11-14 (WIB).

Every finding below was already reported in a prior audit. A candidate finding
that matches one of these entries — same contract/function and same mechanism,
even if rediscovered independently — is a **duplicate** and must not be filed
as new. Severity and fix status are as stated in the source report; "not
stated" means the report contains no fix-review section (both 2022 ToB reports
were single-delivery assessments with no fix verification appendix).

Methods: ToB Aug/Nov 2022 PDFs extracted via text fetch of the
`trailofbits/publications` copies (verbatim raw URLs from web search); the
Oct 2023 ToB PDF and the Zellic report were read locally with `pdftotext`.
An attempted sparse git checkout of `trailofbits/publications` was interrupted
by a runtime restart and abandoned — no findings were sourced from it, and the
partial clone was removed. Zero GitHub API calls were made.

**Scope tags:** `FRAXLEND` = Fraxlend pair/deployer/whitelist code;
`ADJACENT` = code that integrates with Fraxlend but is not Fraxlend core;
`OTHER-SYSTEM` = a different Frax system reviewed in the same report
(included for completeness of the ToB Fraxlend engagements; do not treat as
Fraxlend findings).

---

## A. Trail of Bits — FraxSwap, FPIController & FraxLend (Aug 3, 2022)

Audited: `FraxFinance/frax-lend` @ `ca1a39f5ad35a5a470a3eabf7df35a883d92240c`
and `FraxFinance/frax-solidity` @ `19dd2637ba17b8224173fd05ff356a58706edb82`.
6 findings. Fix status: **not stated** in the report.

| ID | Report finding | Severity | Contract / function | Mechanism (one line) | Fix status |
|---|---|---|---|---|---|
| EX-001 | TOB-FRAXSWAP-1: Risk of unexpected results when long-term swaps involving rebasing tokens are canceled `OTHER-SYSTEM` | High | `UniV2TWAMMPair.sol` / `cancelLongTermSwap` | Rebase changes pair balance without updating TWAMM accounting → over-transfer / reverting cancels. | Not stated |
| EX-002 | TOB-FRAXSWAP-2: Missing liquidity checks when initiating long-term swaps `OTHER-SYSTEM` | High | `UniV2TWAMMPair.sol`, `LongTermOrders.sol`, `ExecVirtualOrders.sol` / `performLongTermSwap` | No reserve validation before recording long-term swaps → division-by-zero bricks all pool ops. | Not stated |
| EX-003 | TOB-FRAXSWAP-3: Missing events in several contracts `OTHER-SYSTEM` | Low | `UniV2TWAMMPair.sol`, `FPIControllerPool.sol`, `CPITrackerOracle.sol` | Virtual-order execution and admin toggles emit no events → attacks/malfunctions undetectable. | Not stated |
| EX-004 | TOB-FRAXFPI-4: Unsafe integer conversions in FPIControllerPool `OTHER-SYSTEM` | High | `FPIControllerPool.sol` / `giveFRAXToAMO`, `receiveFRAXFromAMO`, `price_info` | `uint256`→`int256` casts never revert; huge amounts go negative and bypass the borrow cap. | Not stated |
| EX-005 | TOB-FRAXLEND-5: leveragedPosition and repayAssetWithCollateral do not update the exchangeRate `FRAXLEND` | High | `FraxLendCore.sol` / `leveragedPosition`, `repayAssetWithCollateral`, `isSolvent` | Debt-increasing functions skip `updateExchangeRate`, so the solvency check runs on a stale rate. | Not stated |
| EX-006 | TOB-FRAXLEND-6: Risk of hash collisions in FraxLendPairDeployer that could block certain deployments `FRAXLEND` | Medium | `FraxLendPairDeployer.sol` / `_deployFirst`, `_deploySecond`, `deploy` | Name-hash and salt uniqueness checks are front-runnable: an unauthenticated deploy can block an authenticated one. | Not stated |

## B. Trail of Bits — Fraxlend & Fraxferry (Nov 22, 2022)

Audited: `FraxFinance/fraxlend-dev` @ `2a35898ed1c303f4f878e94b61d80fcd50a3190d`
(private repo) and `FraxFinance/frax-solidity` @
`32d1cbde2baaa35c0b8296a14e56dc06e111e345`. 13 findings. Fix status:
**not stated** in the report. Note the finding-ID prefix differs from the
Aug 2022 report (`TOB-FXLEND-*` here vs `TOB-FRAXLEND-*` there).

| ID | Report finding | Severity | Contract / function | Mechanism (one line) | Fix status |
|---|---|---|---|---|---|
| EX-007 | TOB-FXLEND-1: Lack of two-step process for contract ownership changes `FRAXLEND` | Medium | OZ `Ownable.sol` via `FraxlendPairCore` / `transferOwnership` | Single-step ownership transfer; a mistyped address permanently loses ownership. | Not stated |
| EX-008 | TOB-FXLEND-2: Missing checks of constructor/initialization parameters `FRAXLEND` | Low | `FraxlendPairCore.sol` / constructor | No upper bound on `_liquidationFee`; no check that at least one oracle is set. | Not stated |
| EX-009 | TOB-FXLEND-3: Incorrect application of penalty fee rate `FRAXLEND` | Medium | `FraxlendPairCore.sol` / `_addInterest` | Penalty rate applied to the whole `deltaTime`, including the pre-maturity portion. | Not stated |
| EX-010 | TOB-FXLEND-4: Improper validation of Chainlink data `FRAXLEND` | Low | `FraxlendPairCore.sol` / `_updateExchangeRate` | `latestRoundData` return values `updatedAt`/`answeredInRound` unchecked → stale/incomplete rounds accepted. | Not stated |
| EX-011 | TOB-FXLEND-5: Risk of oracle outages `FRAXLEND` | Informational | `FraxlendPairCore.sol` (oracle integration) | Chainlink feed pauses / minAnswer circuit breakers are undetectable on-chain; needs off-chain monitoring. | Not stated |
| EX-012 | TOB-FXLEND-6: Unapproved lenders could receive fTokens `FRAXLEND` | Low | `FraxlendPairCore.sol` / `deposit`, token transfers | `approvedLender` enforced only on deposit; fToken transfers to unapproved addresses unchecked. | Not stated |
| EX-013 | TOB-FXLEND-7: FraxlendPairDeployer cannot deploy contracts of fewer than 13,000 bytes `FRAXLEND` | Medium | `FraxlendPairDeployer.sol` / `setCreationCode`, `_deployFirst` | `BytesLib.slice(...,13000)` reverts on short code; `SSTORE2.read(address(0))` panics on the missing second half. | Not stated |
| EX-014 | TOB-FXLEND-8: setCreationCode fails to overwrite _secondHalf slice if updated code size is less than 13,000 bytes `FRAXLEND` | Undetermined | `FraxlendPairDeployer.sol` / `setCreationCode` | Shrinking creation code leaves stale `contractAddress2` → deploys concatenate old bytecode. | Not stated |
| EX-015 | TOB-FXFERRY-9: Missing checks in setter functions `OTHER-SYSTEM` | Low | `Fraxferry.sol` / `setFee`, `setMinWaitPeriods` | No fee upper bound; no ≥1-hour floor on wait periods, invalidating reorg protection. | Not stated |
| EX-016 | TOB-FXFERRY-10: Risk of invalid batches due to unsafe cast in depart function `OTHER-SYSTEM` | High | `Fraxferry.sol` / `depart` | `end > 2**64` casts below `start`, breaking the `end >= start` invariant and bricking `disembark`. | Not stated |
| EX-017 | TOB-FXFERRY-11: Transactions that were already executed can be canceled `OTHER-SYSTEM` | Low | `Fraxferry.sol` / `_jettison`, `jettison`, `jettisonGroup` | `executeIndex` counts batches, not transactions, so executed transactions pass the not-executed check. | Not stated |
| EX-018 | TOB-FXFERRY-12: Lack of contract existence check on low-level call `OTHER-SYSTEM` | Medium | `Fraxferry.sol` / `execute` | Low-level `call` returns success against EOAs/destroyed contracts with no existence check. | Not stated |
| EX-019 | TOB-FXFERRY-13: Events could be improved `OTHER-SYSTEM` | Informational | `Fraxferry.sol` (events) | Missing `indexed` params and old values in setter events. | Not stated |

## C. Trail of Bits — Frax Bonds, sFRAX, frxETH Redemption Queue, Frax Oracles (Oct 27, 2023)

Audited: `frax-bonds` @ `9c4be497…`, `savings-frax-erc4626` @ `0761cf8f…`,
`frax-ether-redemption-queue` @ `868bff48…`, `frax-oracles` @
`bd56532a3c33da95faed904a5810313deab5f13c`. Only the oracle finding is
extracted here (per scope: shared oracle code relevant to Fraxlend's
dual-oracle usage). The other 4 findings (TOB-FBSRO-1/3/4/5: FXB token
recovery, SlippageAuction array/argument bugs, redemption-fee timing) concern
FXB and the redemption queue only and are **not** Fraxlend exclusions.

| ID | Report finding | Severity | Contract / function | Mechanism (one line) | Fix status |
|---|---|---|---|---|---|
| EX-020 | TOB-FBSRO-2: Oracle deployed with misconfigured base token `FRAXLEND` (shared oracle) | Low | `SfrxEthEthDualOracle.sol` (deployment config) | `BASE_TOKEN_0`/`BASE_TOKEN_1` deployed as frxETH instead of sfrxETH → mispriced collateral enables bad loans. | **Resolved** (fix-review appendix: redeployed with correct config) |

## D. Zellic — Frax (USD Stablecoin) (Feb 13, 2026, per PDF)

Scope includes the Odos Fraxlend Leverage Router (`FraxlendLeverOdos`,
`frax-flashloan` repo) alongside branded-stablecoin / Hop / FraxNet code.
Only the 2 Fraxlend-router findings are extracted; the other 8 findings
(§3.1–3.5, 3.8–3.10: custodians, cross-chain truncation, minters DoS,
`FraxNetDepositV3.recoverERC20`, GeniusDollar, CREATE2 salt entropy) are not
Fraxlend exclusions.

| ID | Report finding | Severity | Contract / function | Mechanism (one line) | Fix status |
|---|---|---|---|---|---|
| EX-021 | §3.6: Emergency shutoff and borrow-limit checks in FraxlendLeverOdos are permanently inactive `ADJACENT` | Low | `FraxlendLeverOdos.sol` / `swapExactTokensForTokens` | Shutoff/borrow-limit state variables have no setters, so both safety checks are permanently dead. | Acknowledged; fix in commit `2ecc2a7d` |
| EX-022 | §3.7: Unchecked low-level call in FraxlendLeverOdos.recoverERC20 silently fails on transfer errors `ADJACENT` | Informational | `FraxlendLeverOdos.sol` / `recoverERC20` | Unchecked low-level call return value → failed token recovery looks successful. | Acknowledged; fix in commit `12a375c1` |

---

## Skipped local reports (read for scope, findings NOT extracted)

All 14 PDFs in `repos/frax-solidity/src/audits/` were converted with
`pdftotext` and scope-checked. None was unreadable. Skips below were skipped
because their scope does not touch Fraxlend or shared code Fraxlend depends
on — **not** because they are unimportant; do not cite them as Fraxlend
dedup, and do not treat their findings as reviewed for this audit.

| Local PDF | Scope (verified from report text) | Why skipped |
|---|---|---|
| `070_Frax_Router_MultihopV2.pdf` (Codespect, Oct 2026) | `FraxswapRouterMultihopV2.sol` + plugins; 1 Medium + infos; 0 Fraxlend mentions | Pure Fraxswap router |
| `ChainSecurity_Frax_FXB_sfrxUSD_Upgrade_Audit.pdf` (Jul 2025) | FXB + sfrxUSD upgrade; 10 Low, 0 Critical/High/Medium; 0 Fraxlend mentions | FXB/sfrxUSD only; its oracle items concern `SfrxUsd2OracleImplementation`, not Fraxlend dual oracles |
| `Curve AMO Audit Report - Frax Security Cartel - May 2024.pdf` | Curve AMO for frxETH V2; 31 findings (2 High) | frxETH V2 AMO, not Fraxlend/shared code |
| `FPISLocker + FraxtalERC4626MintRedeemer … - May 2024 - Frax Security Cartel.pdf` | FPISLocker + Fraxtal sFRAX MintRedeemer; 15 findings (5 High) | veFPIS/Flox/sFRAX; its oracle-sandwich finding is MintRedeemer-specific |
| `Frax - Zellic Audit Report.pdf` (FraxNet, Jul 2025) | `FraxNetDeposit[V2]`, `FrxUSDCustodian`, frxUSD; 8 findings | Pure FraxNet |
| `Frax-Certora (Bamm) report - Final.pdf` (Oct 2024) | BAMM (separate lending-AMM system); M-01–M-03, L-01–L-08, … | BAMM ≠ Fraxlend |
| `Frax0 Mesh - Zellic Audit Report.pdf` (Sep 2025) | OFT adapters + RemoteHop/Hop mesh; 8 findings; 0 Fraxlend mentions | Bridge mesh, not Fraxlend |
| `Fraxchain (Fraxtal) - Trail of Bits - Jan 2024.pdf` | Fraxtal chain contracts | Chain infra, not Fraxlend |
| `Fraxtal Audit - April 2024 - Frax Security Cartel.pdf` | Fraxtal + VestedFXS + Flox; 19 findings (1 Critical) | Pure Flox/Fraxtal |
| `Fraxtal North Star Audit Report.pdf` (Mar 2025) | Fraxtal North Star; 10 findings (2 Critical) | Fraxtal, not Fraxlend |
| `frxETH V2 Audit Report - Frax Security Cartel - March 2024.pdf` | frxETH V2 (ValidatorPool, EtherRouter, redemption-queue-v2); 26 findings (2 Critical) | Pure frxETH V2 |
| `frxUSD Ecosystem - Zellic Audit Report.pdf` (Oct 2026, 505 pp.) | Custodians, OFT adapters, Fraxswap router, frxUSD; 20 findings; 0 Fraxlend mentions | Pure frxUSD ecosystem |

Partially extracted (see §§C–D): the Oct 2023 ToB report (1 of 5 findings)
and the Zellic USD Stablecoin report (2 of 10 findings).

## Unretrieved sources — DEDUP GAP (do not treat as "no findings")

| Source | What was tried | Result |
|---|---|---|
| **Trail of Bits — Fraxlend & veFPIS (Jan 2023)** | (1) `git ls-tree` of `trailofbits/publications` — no matching file under `reviews/`; (2) docs.frax.com audits page — the Jan 2023 entry is the **only** entry with no link; (3) ToB library page for the engagement — "Open Original" points to `frax.finance` (dead, no content); (4) four web searches for the PDF/findings — no copy found. | **PDF NOT RETRIEVED. Its findings are UNKNOWN and are NOT in this exclusion list.** Any Fraxlend finding from the Jan 2023 review remains a live duplicate risk. Before filing anything touching pre-v3 code paths, re-attempt retrieval (e.g. from the Frax team at submission time, or via archive sources) and re-check. |

## Totals

- **Exclusion entries: 22** (EX-001 … EX-022)
  - ToB Aug 2022: 6 (2 Fraxlend, 4 other-system)
  - ToB Nov 2022: 13 (8 Fraxlend, 5 Fraxferry)
  - ToB Oct 2023 (oracle only): 1
  - Zellic USD Stablecoin (Fraxlend router only): 2
- **Fraxlend-core entries: 11** (EX-005, EX-006, EX-007–EX-014, EX-020).
- **Unread sources: 0** local PDFs unread; **1** remote report unretrieved
  (Jan 2023 ToB — see gap note above).
