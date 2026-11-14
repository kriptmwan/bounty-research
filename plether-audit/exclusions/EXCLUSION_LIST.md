# Exclusion List — Immunefi Plether Audit Competition

**Purpose:** every finding/limitation whose overlap EXCLUDES a new competition report, so hunters do not waste effort on duplicates. A candidate finding must be checked against this list (root cause, not just title) before drafting.

**Sources used (all read; report texts treated as untrusted data, analyzed only):**

| # | Source | Date / commit | Entries |
|---|---|---|---|
| S1 | Cecuro AI audit report (`plether-ai-audit-report-2026-10-26.txt`, 9289 lines; PDF in repo `audits/`) | 16 Oct 2026 (file dated 26 Oct), commit `6d6622f2`, 129 files | 113 (§1) |
| S2 | SC Audit Studio pre-audit report (`plether-pre-audit-report.txt`, 1675 lines) | 4 May 2026, commit `fc5f03ba`, resolution `86263b00` | 22 (§2) |
| S3 | AI scan (`scan-plether-fi-plether-core-d4541b49.md`, 1915 lines) | 15 Oct 2026 | 33 (§3) |
| S4 | `packages/perps/SECURITY.md` — "Known Limitations" + the two standalone limitation sections | pinned commit `a82d4fef` | 50 (§4) |
| S5 | Immunefi competition page known-issues list (26 Oct 2026), as supplied in the task | — | cross-refs (§5, not additive) |
| S6 | Root `SECURITY.md` — "Known Limitations" | pinned commit | 24, **spot-scope, separate** (§6) |

**Totals: 168 prior-report findings (113 + 22 + 33) + 50 perps SECURITY.md limitations = 218 perps exclusion entries.** Root SECURITY.md items (§6) are counted separately because that document covers the spot/InvarCoin system, not perps (see §6 warning). Two further reports present in `exclusions/` (collaborative audit, Cantina review) are spot-scope and NOT named in the exclusion set — summarized in the Appendix for completeness; confirm with the coordinator whether they count.

## §0 — The ONE exception: HIGH-1 (Arbitrum/Pyth clock alignment)

**HIGH-1 / SECURITY.md §"Arbitrum and Pyth clock alignment"** — commit time is the Arbitrum block timestamp, which can trail an already-published Pyth price; a trader may commit after seeing a price and be filled at it.

- A new report on this root cause is **valid ONLY with a POC proving repeatable, net-profitable extraction from LPs** beyond the stated limitation (Immunefi page wording). The Cecuro report itself did not establish extraction; the team adjusted HIGH-1 to Informational on exactly that ground, and the comment explicitly states the acknowledgment "does not claim that the timing concern has been remediated or that exploitation is impossible."
- Without such a POC, any clock-alignment / known-tick / post-commit-ordering report is excluded. A POC must show the timing window is practically usable and yields net profit after gas + oracle fees + carry/fees, repeatably — not a single favorable close (ordinary trading PnL is not extraction).

## How to use this list / caveats

1. **Overlap is by root cause.** The Immunefi wording excludes findings "overlapping" the prior reports / known issues / SECURITY.md limitations — including accepted-risk and acknowledged sections. A new variant of the same root cause (different function, same mechanism) should be treated as excluded unless it demonstrates a materially distinct root cause. When in doubt, flag for the coordinator before writing up.
2. **"Addressed"/"Fixed" in a prior report does NOT remove the exclusion.** Many Cecuro entries carry team comments claiming a fix (with commit links), and most pre-audit entries were fixed in PRs #9–#29. The competition page excludes *all* findings in these reports. This list records the stated disposition for context only; it does **not** verify any fix against the pinned commit. (If a claimed fix demonstrably regressed in the pinned commit, that is a judgment call for the coordinator — do not assume it is reportable.)
3. **Stale code references.** Prior reports audit older commits (`6d6622f2`, `fc5f03ba`) and call the settlement token USDC; the pinned code uses USDG and has renamed/restructured code since. "Primary file" below is the first file listed in the report's Locations (Cecuro) or the file named in the finding (scan/pre-audit); line numbers from reports are omitted as stale. Function names are given only where the report states them.
4. **Severity labels are the reports' own.** Cecuro severities were adjusted by the team after delivery (1 reclassified: HIGH-1 → Info; 3 marked invalid: MED-31, MED-32, LOW-74). The overview table in the Cecuro text shows 30 Medium / 73 Low / 7 Info after adjustment vs 32/74/6 original. This list uses original IDs throughout.
5. **Titles are the reports' one-line descriptions.** Cecuro titles are full-sentence issue statements; scan "Claim" first sentences and pre-audit summaries are condensed to one line each. PDF-extraction hyphenation artifacts were cleaned (e.g. "re-funds" → "refunds"); wording is otherwise verbatim in substance.

---

## §1 — Cecuro AI audit report (S1): 113 findings

Scope: 129 files — `packages/perps/src/**` plus spot (`SyntheticSplitter`, `StakedOracle`), options (`MarginEngine`), and `script/DeployToMainnet.s.sol`. Three findings are non-perps scope (MED-31, MED-32, LOW-74) and are marked as such; they remain listed because the exclusion covers the whole report.

Status key: **Ack** = overview status Acknowledged; **Inv** = team-marked Invalid; **Open** = overview status Open. "Team:" = disposition claimed in the finding's team Comment in the report detail section (unverified here).

| ID | Sev | Title / one-line description | Primary file | Status |
|---|---|---|---|---|
| MED-1 | Medium | Owner can release pending claimant reserves to LPs using a mark older than the engine limit (`finalizePoolConfig` freshness gate looser than PoolReconcile policy) | `HousePool.sol` | Ack; team: Addressed |
| MED-2 | Medium | Owner can miswire settlement tokens and leave traders with unbacked or stuck balances (Engine/clearinghouse/pool token mismatch) | `CfdEngine.sol` | Ack; team: Addressed |
| MED-3 | Medium | Anyone can block governance from rotating the protocol treasury (dust balance in old treasury blocks rotation) | `CfdEngine.sol` (`CfdTreasury`) | Ack; team: Addressed |
| MED-4 | Medium | Attacker can make later traders miss execution windows by filling the FIFO with stale orders | `OrderRouterExecutionSidecar.sol` | Ack; team: Addressed (bounded permissionless cleanup) |
| MED-5 | Medium | Final refund claimant can lock redemption refunds for bootstrap LPs | `HousePool.sol` | Ack; team: Addressed |
| MED-6 | Medium | Protocol treasury can spend LP withdrawal reserves on fee top-ups | `CfdEngineSettlementSidecar.sol` | Ack; team: Addressed |
| MED-7 | Medium | Keeper can settle traders and LPs on selectively updated basket components (older valid signed component per feed) | `PletherOracle.sol` | Ack; team: Partially mitigated, residual acknowledged; **Immunefi: partly fixed**. Overlaps §4 KL-P-49 (live basket selection). |
| MED-8 | Medium | Trader can be blocked from triggering protection because later L2 blocks reuse the same block number | `PositionProtectionBook.sol` | Ack; team: Addressed (execution-chain block number) |
| MED-9 | Medium | Keepers can retry protection closes without the trader's financial limits | `OrderLiquidationBatchLogic.sol` | Ack; team: Addressed (retained close ceilings) |
| MED-10 | Medium | Liquidator can liquidate short traders at prices below the configured cap-adjusted mark | `PletherOracle.sol` | Ack; team: Addressed (directional adjustment before clamp) |
| MED-11 | Medium | Senior redeemer can leave remaining senior principal unprotected (HWM not reduced with principal) | `HousePoolWaterfallAccountingLib.sol` | Ack; team: Addressed |
| MED-12 | Medium | Mixed recovery inflows can strand LP revenue in ownerless pool assets | `HousePool.sol` | Ack; team: Addressed |
| MED-13 | Medium | Governance can retarget armed stop-losses after oracle rotation (armed thresholds evaluated under the new oracle) | `PositionProtectionBook.sol` | Ack; team: Accepted design, no change. **Immunefi-listed.** |
| MED-14 | Medium | Trader can be blocked from queueing an open behind their closing order | `OrderLiquidationBatchLogic.sol` | Ack; team: Addressed (projected-position admission) |
| MED-15 | Medium | Triggered SHORT protection can get stuck and leave a user unprotected (zero adjusted quote treated as valid close) | `OrderLiquidationBatchLogic.sol` | Ack; team: Addressed |
| MED-16 | Medium | Traders can enqueue invalid opens when the cached mark is stale (incl. opposing-side invalidity) | `OrderLiquidationBatchLogic.sol` | Ack; team: Addressed for price-independent part. **Immunefi-listed (with LOW-57).** |
| MED-17 | Medium | Oracle lag can block traders from triggering protections (wall-clock arming baseline) | `PositionProtectionBook.sol` | Ack; team: Addressed (armed publish time) |
| MED-18 | Medium | Keeper can rewrite the engine mark at the same timestamp and change liquidation and LP settlement prices | `CfdEngine.sol` | Ack; team: Addressed (equal-time consistency) |
| MED-19 | Medium | Senior depositor can block others by cycling refundable reservations | `TrancheVault.sol` | Ack; team: Addressed (firm Senior commitment) |
| MED-20 | Medium | Frozen close orders can be blocked by live publish-time divergence limits | `PletherOracle.sol` | Ack; team: Addressed (frozen-policy divergence limit) |
| MED-21 | Medium | Admin can rotate in a zero-weight feed that still bricks the oracle | `PletherOracle.sol` | Ack; team: Addressed (zero-weight rejected) |
| MED-22 | Medium | Trader can avoid paying LP carry by checkpointing early (carry rounds down, checkpoint advances, fraction discarded) | `PositionRiskAccountingLib.sol` | Ack; team: Accepted rounding limitation. **Immunefi-listed.** Overlaps §4 KL-P-36. |
| MED-23 | Medium | Mixed-time basket can block trader protections during valid mark updates | `PletherOracle.sol` | Ack; team: Addressed |
| MED-24 | Medium | LP can delay other redeemers with zero-payout refund epochs (bounded settlement work consumed) | `HousePool.sol` | Ack; team: Accepted bounded-work limitation. **Immunefi-listed.** |
| MED-25 | Medium | Arbitrum block numbering can delay every later trader in the FIFO queue | `OrderRouter.sol` | Ack; team: Addressed (ArbSys block number) |
| MED-26 | Medium | Owner can activate trading against ownerless pool assets | `HousePool.sol` | Ack; team: Addressed (initial activation gate) |
| MED-27 | Medium | Owner can change senior rate while junior LP accounting is stale | `HousePool.sol` | Ack; team: Addressed |
| MED-28 | Medium | Trader can arm a new protection from a stale engine mark after oracle state already crossed it | `PositionProtectionBook.sol` | Ack; team: Addressed (accepted-observation geometry check) |
| MED-29 | Medium | Small redeemers can lose funded withdrawal value to the pool and seed account (funded-share entitlement floors to zero) | `TrancheVault.sol` | Ack; team: Accepted tiny-share allocation limitation. **Immunefi-listed.** |
| MED-30 | Medium | Trader can lose stop-loss automation during routine frozen markets (no automatic frozen-market trigger) | `PositionProtectionBook.sol` | Ack; team: Addressed with atomic manual exit; auto-trigger intentionally unavailable. **Immunefi: partly fixed.** |
| MED-31 | Medium | Coordinated zaps transfer value between BEAR and BULL DOVs | `DOVZapRouter.sol` (non-perps) | **Inv** (team); no team comment |
| MED-32 | Medium | Settled BULL collateral regains borrowing power below CAP | `MorphoOracle.sol` (non-perps) | **Inv** (team); no team comment |
| LOW-1 | Low | Indexer can misattribute tranche deposit lifecycle to the wrong account (owner vs controller event labels) | `TrancheVault.sol` | Ack; team: Addressed |
| LOW-2 | Low | Unset mark can block valid first opens (synthetic 1e8 fallback) | `OrderLiquidationBatchLogic.sol` | Ack; team: Addressed (explicit mark init) |
| LOW-3 | Low | LP can have smaller share claims revert on a funded deposit (partial-claim rounding) | `TrancheVault.sol` | Ack; team: Accepted partial-claim rounding |
| LOW-4 | Low | LP can have smaller withdrawal claims revert on a funded redeem (partial-claim rounding) | `TrancheVault.sol` | Ack; team: Accepted partial-claim rounding |
| LOW-5 | Low | LP can have small deposit claims revert below maxDeposit (asset claim rounds to zero shares) | `TrancheVault.sol` | Ack; team: Accepted min-claim-size limitation |
| LOW-6 | Low | User can permanently strand tokens in MarginClearinghouse (direct transfers uncredited) | `MarginClearinghouse.sol` | Ack; team: non-settlement addressed (`rescueToken`); settlement-token limitation accepted. Overlaps §4 KL-P-47. |
| LOW-7 | Low | Integrator can misclassify zero add-margin attempts (wrong error) | `CfdEngine.sol` | Ack; team: Addressed |
| LOW-8 | Low | Integrators can underquote required open collateral for small positions (min-bounty docs) | `OpenAccountingLib.sol` | Ack; team: Not retained as current doc defect |
| LOW-9 | Low | Integrators can misread immediate close cash from previews (payout/claim split) | `CfdEngineLens.sol` | Ack; team: Addressed |
| LOW-10 | Low | ABI consumers can miss the public self-redeem-cancel selector advertised by the vault id | `TrancheVault.sol` | Ack; team: Addressed |
| LOW-11 | Low | Integrator can misread risk-off cutoff and misclassify unaffected close orders | `IOrderRouterEmergencyAdmin.sol` | Ack; team: Not retained as current defect |
| LOW-12 | Low | Operator can treat a stale cached mark as an execution blocker on the atomic settlement route | `SettlementMonitorLens.sol` | Ack; team: Addressed |
| LOW-13 | Low | LP claimants can lose async rounding dust to other tranche holders | `TrancheVault.sol` | Ack; team: Accepted deterministic dust allocation |
| LOW-14 | Low | Integrators can overestimate request capacity because maxRequestDeposit ignores controller | `IAsyncTrancheVault.sol` | Ack; team: Addressed |
| LOW-15 | Low | Product consumers can miss router risk-off in protocol status | `ICfdEngine.sol` | Ack; team: Addressed |
| LOW-16 | Low | LP integrators can overestimate withdrawal readiness after an epoch rolls | `IHousePool.sol` | Ack; team: Addressed (docs) |
| LOW-17 | Low | Integrators can overquote redeem dust that the vault will still reject | `IHousePool.sol` | Ack; team: Addressed (estimate semantics) |
| LOW-18 | Low | Keeper API docs can hide protection bounty forfeiture from liquidation callers | `IPerpsKeeper.sol` | Ack; team: Addressed (docs) |
| LOW-19 | Low | Integrator can overstate trader settlement after liquidation (preview field semantics) | `CfdEnginePlanLib.sol` | Ack; team: Addressed (docs) |
| LOW-20 | Low | Monitor callers can see preview accounting as available while terminal deficit data is invalid | `SettlementMonitorViewTypes.sol` | Ack; team: Addressed (independent availability flags) |
| LOW-21 | Low | Monitor can block complete observations for cached settlement when the oracle view is unreadable | `SettlementMonitorViewTypes.sol` | Ack; team: fail-closed behavior retained |
| LOW-22 | Low | Governance cannot use the documented non-dilutive recapitalization path | `HousePool.sol` | Ack; team: Addressed (`recapitalizePool`) |
| LOW-23 | Low | Integrators can misread senior withdrawal capacity during settlement holds | `HousePool.sol` | Ack; team: Addressed (docs) |
| LOW-24 | Low | Pauser can brick emergency pause when no order has ever been committed (cutoff underflow) | `OrderRouterAdmin.sol` | Ack; team: False positive |
| LOW-25 | Low | Receipt verifiers can reject expired and config-mismatch evidence (no-price receipt context) | `IOrderLifecycleBook.sol` | Ack; team: Clarified/fixed |
| LOW-26 | Low | Trader can be blocked from opening by underfunded protocol fee top-ups | `CfdEnginePlanLib.sol` | Ack; team: Addressed (partial funding projection) |
| LOW-27 | Low | Anyone can force zero-share junior fee accrual to permanently skip completed hours | `TrancheVault.sol` | Ack; team: Accepted rounding behavior. Overlaps §4 KL-P-37. |
| LOW-28 | Low | Liquidation preview callers can misclassify risk-off-refunded accounts | `CfdEngineLens.sol` | Ack; team: Addressed |
| LOW-29 | Low | Keeper tooling can misclassify stale trigger data as same-block protection failure | `IOrderRouterErrors.sol` | Ack; team: Addressed (separate errors) |
| LOW-30 | Low | Lens caller can receive stale post-VPI accrual in invalid open previews | `CfdEngineLens.sol` | Ack; team: Partial invalid-preview diagnostics retained |
| LOW-31 | Low | Trader can lose a capped bounty on undersized opens before the first mark update | `OrderLiquidationBatchLogic.sol` | Ack; team: Dismissed; mismatch accepted |
| LOW-32 | Low | Preview callers can misread partial close failures (legacy reason value) | `CfdTypes.sol` | Ack; team: Addressed (docs) |
| LOW-33 | Low | Deployer can brick the router by binding a non-contract engine lens or house pool | `OrderOracleExecution.sol` | Ack; team: Addressed (code checks) |
| LOW-34 | Low | Integrators can overstate close carry because the evaluator reports pending carry after collection | `CfdOrderPolicyEvaluatorBase.sol` | Ack; team: Addressed (docs) |
| LOW-35 | Low | Integrator can misread trader account equity from the public view interface | `IPerpsTraderViews.sol` | Ack; team: Addressed (docs) |
| LOW-36 | Low | Trader or keeper can use inverted feeds to bypass the basket confidence cap | `PletherOracle.sol` | Ack; team: Addressed (transformed-endpoint confidence) |
| LOW-37 | Low | Integrator can receive wrong side-margin totals from planner (memory-reference aliasing claim) | `CfdEnginePlanLib.sol` | Ack; team: Not confirmed |
| LOW-38 | Low | Owner can temporarily disable oracle-backed operations by rotating to an oracle with a non-contract Pyth endpoint | `PletherOracle.sol` | Ack; team: Addressed (code checks) |
| LOW-39 | Low | Front-runner can block third-party vault share claims by dusting the receiver | `TrancheVault.sol` | Ack; team: Addressed (`receiver == controller`) |
| LOW-40 | Low | Controller can force a zero-balance receiver into LP cooldown | `TrancheVault.sol` | Ack; team: Addressed (`receiver == controller`) |
| LOW-41 | Low | Integrator can see live status before engine wiring is complete | `PerpsPublicLens.sol` | Ack; team: Addressed (dependency checks) |
| LOW-42 | Low | Governance can misclassify protocol-driven close failures as user faults in receipts | `CfdEnginePlanLib.sol` | Ack; team: Not retained for reported path |
| LOW-43 | Low | Integrator can query wrong async vault limits through IERC7575 | `IERC7575.sol` | Ack; team: Addressed (docs) |
| LOW-44 | Low | Governance can set a minimum order size that partial closes ignore | `IOrderRouterAdminHost.sol` | Ack; team: Addressed (partial-close notional floor) |
| LOW-45 | Low | Expiring keeper can finalize receipts with a zero observed config hash | `OrderRecoverySidecar.sol` | Ack; team: Addressed |
| LOW-46 | Low | Trader can have orders stuck until expiry when terminal book is missing | `OrderLifecycleBook.sol` | Ack; team: Addressed |
| LOW-47 | Low | Keepers can lose mark context from mismatch receipts | `OrderRouterExecutionSidecar.sol` | Ack; team: Addressed |
| LOW-48 | Low | LP receipts can report gross pool depth instead of net economic depth | `OrderRouterExecutionSidecar.sol` | Ack; team: Addressed (defined semantics) |
| LOW-49 | Low | Trader can open with equity exactly at the initial-margin threshold (equality accepted) | `PositionRiskAccountingLib.sol` | Ack; team: Addressed (strict `>`) |
| LOW-50 | Low | Reservation mismatch cleanup can strip a surviving position's protection | `OrderRouterExecutionSidecar.sol` | Ack; team: Addressed (relatch handling) |
| LOW-51 | Low | Integrator can understate active maintenance during FAD windows (invalid previews) | `CfdEngineLens.sol` | Ack; team: Addressed |
| LOW-52 | Low | Keeper can underfund liquidation batch item calls (gas reservation) | `OrderLiquidationBatchLogic.sol` | Ack; team: Addressed |
| LOW-53 | Low | Trader previews can overstate committable margin (previews exclude Router bounty/admission) | `OrderLiquidationBatchLogic.sol` | Ack; team: Engine-preview scope retained |
| LOW-54 | Low | Senior redeemers can leave dust high-water mark by splitting withdrawals | `HousePoolWaterfallAccountingLib.sol` | Ack; team: healthy case addressed via MED-11; impaired rounding accepted. Overlaps §4 KL-P-35. |
| LOW-55 | Low | Integrator can be misled by close preview accepting uncommittable client ids | `OrderLiquidationBatchLogic.sol` | Ack; team: Addressed |
| LOW-56 | Low | Integrators can mis-handle rejected deposits because the lens says they stay pending | `PerpsPublicLens.sol` | Ack; team: Not confirmed |
| LOW-57 | Low | Trader can underpay open-order keeper bounty by committing against a stale mark | `OrderLiquidationBatchLogic.sol` | Ack; team: Accepted limitation, won't fix. **Immunefi-listed (with MED-16).** Overlaps §4 KL-P-11. |
| LOW-58 | Low | Governance can make withdrawable-margin views revert for traders (staleness addition overflow) | `CfdEngineAccountLens.sol` | Ack; team: Addressed |
| LOW-59 | Low | Owner can leave emergency recovery ownerless (ownership renounce) | `OrderRouterAdmin.sol` | Ack; team: Addressed (`renounceOwnership` reverts) |
| LOW-60 | Low | Lens callers can crash max-open quotes with oversized margin inputs | `CfdEngineOpenQuoter.sol` | Ack; team: Addressed |
| LOW-61 | Low | PoolReconcile reads can enforce the order skew limit instead of the pool policy (divergence docs) | `IPletherOracle.sol` | Ack; team: Addressed (docs) |
| LOW-62 | Low | Contract caller can permanently lock deferred ETH refunds | `OrderExecutionHandler.sol` | Ack; team: Addressed (`claimBalanceTo`/`claimEthRefundTo`) |
| LOW-63 | Low | Partial LP settlement can round dust away from redeemers (multi-pass pricing) | `HousePool.sol` | Ack; team: Accepted partial-settlement rounding. Overlaps §4 KL-P-32. |
| LOW-64 | Low | Integrator can mis-handle settlement debits because `settleUsdc` documents the wrong limit | `IMarginClearinghouse.sol` | Ack; team: Addressed (docs) |
| LOW-65 | Low | Owner can misroute ownerless pool assets to the junior seed receiver | `HousePool.sol` | Ack; team: Addressed (reconcile-before-seed + quarantine) |
| LOW-66 | Low | Integrator can misread live position margin from engine views (pledge ownership docs) | `CfdTypes.sol` | Ack; team: Addressed (docs) |
| LOW-67 | Low | Same-window redeemer can burn a small LP's shares for no assets (full-balance dust exit) | `TrancheVault.sol` | Ack; team: Accepted full-balance dust-exit behavior. Overlaps §4 KL-P-34. |
| LOW-68 | Low | Broken oracle payloads can be misreported as unavailable history | `PletherOracle.sol` | Ack; team: Addressed (exact-error classification) |
| LOW-69 | Low | Integrators can misread applyOpenCost return value and overestimate pledged margin | `IMarginClearinghouse.sol` | Ack; team: Return semantics retained (docs) |
| LOW-70 | Low | Keeper cannot use single-order execution to preserve progress on unavailable history | `OrderRouterExecutionSidecar.sol` | Ack; team: Addressed (`Pending/HistoricalPriceUnavailable`) |
| LOW-71 | Low | Protocol lens can understate pool assets by subtracting treasury credits that never leave the pool | `CfdEngineProtocolLens.sol` | Ack; team: Addressed |
| LOW-72 | Low | Pending depositor can receive impossible share quotes for a wiped tranche | `TrancheVault.sol` | Ack; team: Addressed |
| LOW-73 | Low | Trader cannot add new stop-loss protection while degraded mode is active | `PositionProtectionBook.sol` | Ack; team: Addressed |
| LOW-74 | Low | Exercise can pay collateral again after the 90-day sweep | `MarginEngine.sol` (options scope) | **Inv** (team); no team comment |
| HIGH-1 | High→Info | Trader can close positions at already-known oracle ticks against LPs (sequencer timestamp trails Pyth publish time) | `OrderRouter.sol` / `PletherOracle.sol` / `OrderRouterExecutionSidecar.sol` | Ack; team-adjusted to Informational. **EXCEPTION — see §0: valid ONLY with POC of repeatable net-profitable LP extraction.** |
| INFO-1 | Info | Caller can strand its own ETH refund by using an unclaimable recipient | `PletherOracle.sol` | **Open**; no team comment |
| INFO-2 | Info | Owner can cancel pool config without an event | `IHousePool.sol` | **Open**; no team comment |
| INFO-3 | Info | Router can return a misleading oracle rotation error | `IOrderRouterErrors.sol` | Ack; team: Addressed |
| INFO-4 | Info | Integrator can misread settlement buffer checks from stale evaluator docs | `CfdOrderPolicyEvaluatorBase.sol` | Ack; team: Addressed |
| INFO-5 | Info | Integrator can misclassify open-order failures in planner policy tooling | `ICfdEnginePlanner.sol` | Ack; team: Addressed |
| INFO-6 | Info | Operators can misread recovery-sidecar failures as execution-sidecar failures (error namespace) | `OrderRecoverySidecar.sol` | Ack; team: Addressed |


## §2 — SC Audit Studio pre-audit report (S2): 22 entries

Pre-audit consultation, 14 Apr–4 May 2026; 4 core contracts + libraries + vault at commit `fc5f03ba`. Header claims "High 2 / Medium 7 / Low 1 / Info 18", but the body contains only 2 `SC-I` findings — the "18" cannot be reconciled from the extracted text (10 Q/A items + 2 Info = 12; no further Info items appear in the 1675-line text, which ends at SC-I2). Numbering skips SC-Q7 entirely (Q1–Q6, Q8–Q11 present). Both discrepancies are flagged, not resolved — the exclusion covers the report as published, so treat the header count as unreliable and the 22 listed items as the extracted set. "Response" = team's recorded response in the report (PR numbers as stated, unverified).

### Code-quality / design items (SC-Q)

| ID | Title / one-line description | Affected contract(s) | Status (response) |
|---|---|---|---|
| SC-Q1 | Naming inconsistent across the codebase (HousePool called "vault"; "module" = both inherited abstract and deployed contract; "carry" vs "funding") | `CfdEngine`, `OrderRouter`, `HousePool` | Implemented in PR #10 |
| SC-Q2 | Move oracle logic from OrderRouter to a dedicated oracle contract (`updatePrice`/`getLatestPrice` in `PletherOracle`) | `OrderRouter` → `PletherOracle` | Implemented in PR #15 |
| SC-Q3 | Shared state should be defined in the parent of the inheritance tree; replace numeric-code error families with one named error per failure mode | `OrderRouter` + abstract bases | Implemented in PR #18 |
| SC-Q4 | Rework HousePool: double-accounting deposits via ERC-4626-shaped vaults without native vault accounting; fixed senior yield vs unpredictable trading yield | `HousePool`, `TrancheVault` | Acknowledged |
| SC-Q5 | Move custom errors, events, externally-visible structs into the relevant interfaces (ABI source of truth) | `HousePool`, `CfdEngine`, `OrderRouter` | Implemented in PR #20 |
| SC-Q6 | Remove internal getter functions in `MarginClearinghouseAccountingLib` (single-line field reads) | `MarginClearinghouseAccountingLib` | Implemented in PR #10 |
| SC-Q8 | Improve folder/file structure: split interfaces/types/libraries; one interface per contract | All contracts | Acknowledged |
| SC-Q9 | Rework credit and deferred-payout logic for bounties: fragmented bounty accounting across Engine/Router/escrow; bounties as internal margin transfers; liquidation bounties must not touch the vault | `CfdEngine`, `OrderRouter`, escrow accounting | Acknowledged (response recorded at Q9's section; see note) |
| SC-Q10 | Rework Router structure (inheritance: `OrderExecutionOrchestrator`, `OrderEscrowAccounting`, `OrderOracleExecution`, `OrderQueueBook`) | `OrderRouter` | Implemented in PR #9 |
| SC-Q11 | Test suite should follow a clear structure | Tests | (response in report: implemented — see note) |

Note: the extracted text interleaves Q9/Q10/Q11 responses awkwardly (one "Acknowledged" and one "Implemented in #9" adjacent to Q8–Q11 boundaries). Q9's response is recorded as Acknowledged in the Q8-adjacent block and Q10's as Implemented in #9; Q11's response text was not cleanly separable in extraction. Treat all three as excluded regardless of disposition.

### Security findings (SC-H/M/L/I)

| ID | Sev | Title / one-line description | Affected contract/function | Status (response) |
|---|---|---|---|---|
| SC-H1 | High | Deposit before yield is accrued allows dilution of yield: senior yield recorded as `unpaidSeniorYield` then synced to principal lets a frontrunning deposit dilute prior depositors | `HousePool` senior-yield accrual | Senior rewrite in PR #23; "requires a second audit" |
| SC-H2 | High | Zero-amount withdraw/redeem can perpetually reset TrancheVault cooldown and lock funds: `withdraw(0)`/`redeem(0)` reset `lastDepositTime` without allowance (zero-spend passes) | `TrancheVault._withdraw` | Fixed in PR #21 |
| SC-M1 | Medium | Frozen-window liquidations can revert on live basket timestamp divergence: frozen staleness relaxed to `fadMaxStaleness` but divergence check uses stricter live `liquidationStalenessLimit` | `OrderOracleExecution` / basket resolution | Confirmed still fixed after oracle rewrite, PR #15 |
| SC-M2 | Medium | Valid same-side increases rejected as dust orders: liquidation-bounty floor applied to incremental notional instead of resulting position notional (`POSITION_TOO_SMALL`) | `OpenAccountingLib.buildOpenState` / `CfdEnginePlanLib.planOpen` | Fixed in PR #28 (+ #24) |
| SC-M3 | Medium | Fresh negative `vpiAccrued` omitted from post-open IMR projection: rebate-backed opens settle immediately below live initial margin | `CfdEnginePlanLib._buildPostOpenRiskState` | Fixed in PR #22 |
| SC-M4 | Medium | Risk-free option in 60s oracle window: dual BULL/BEAR orders + keeper-selected ticks within `orderExecutionStalenessLimit` + SOLVENCY_EXCEEDED→RefundUser via LP depth manipulation = costless directional option | `OrderRouter` / oracle window / solvency refund path | Fixed in PR #24; "large fix, requires a full audit" |
| SC-M5 | Medium | Plain stale reconcile intervals back-accrue senior yield: stale `reconcile()` skips yield but doesn't advance `lastSeniorYieldCheckpointTime`, so the next fresh reconcile accrues across the stale interval | `HousePool._reconcile` | No longer exists after senior rewrite, PR #23 |
| SC-M6 | Medium | If price cap is reached protocol becomes unusable: immutable `CAP_PRICE = 2e8`, all prices clamped, no admin path to change it | `CfdEngine`, `OrderOracleExecution` (clamps) | Acknowledged |
| SC-M7 | Medium | Order Router can be DoSed by creating worthless withdraw (close) orders: dust closes (1 wei) occupy FIFO slots; keeper gas exceeds flat close bounty; per-account cap bypassed via multiple wallets | `OrderRouter` FIFO / close orders | Fixed in PR #27 (partial-close notional floor; full residual closes still allowed) |
| SC-L1 | Low | Permissionless zero-value senior withdraw can persist overstated HousePool tranche principal: pending claimant buckets applied without MTM/liability cap; zero withdraw skips final reconcile | `HousePool._reconcile` / `_applyPendingClaimantBucketsLive` | Fixed in PR #29 (settleable cap); zero-withdraw trigger blocked in #23 |
| SC-I1 | Info | Remove dead code from HousePool: uncalled `_distributeRevenue`/`_absorbLoss` + dead `Reconciled` event | `HousePool` | Done in PR #19 |
| SC-I2 | Info | Missing order cancellation mechanism: no user-cancel; funds locked until keeper execution or expiry; `maxOrderAge = 0` disables expiry | `OrderRouter.commitOrder` / expiry | Acknowledged. Overlaps §4 KL-P-08. |

## §3 — AI scan findings (S3): 33 entries

Scan finished 15 Oct 2026: "Critical: 0 · High: 0 · Medium: 1 · Low: 12 · Info: 20 · Total: 33". The scan file states **no dispositions** (no fixed/acknowledged/accepted-risk sections in the text) — the Immunefi page excludes "all findings in the AI scan findings, including accepted-risk and acknowledged sections," so all 33 are excluded regardless. IDs below are scan-local (`SCAN-01…33`, assigned here in file order — the scan file itself uses titles only, no IDs). Category = the scan's own classifier tag.

| ID | Sev / category | Title / one-line description | Evidence files (as cited) |
|---|---|---|---|
| SCAN-01 | Medium / accounting_error | Checkpoint frequency compounds a configured simple senior coupon: coupon capitalized into principal/HWM each reconcile, so more checkpoints → more coupon (up to ~171.8% vs 100% at max rate), drainable by forcing hourly settlements | `IHousePool`, `HousePoolWaterfallAccountingLib`, `HousePool` |
| SCAN-02 | Low / denial_of_service | Close-only-ineligible open at FIFO head blocks all later risk-reducing closes (`Pending(CloseOnly)` head stalls batch + single execution until expiry) | `OrderLiquidationBatchLogic`, `OrderRouterExecutionSidecar` |
| SCAN-03 | Low / accounting_error | Claim-reserved pool cash dilutes carry utilization (carry denominator uses gross `totalAssets` without deducting senior trader claims) | `CfdEngine`, `PositionRiskAccountingLib` |
| SCAN-04 | Low / accounting_error | Deferred trader claims inflate open skew capacity and reduce VPI (gross assets as depth; claim settlement doesn't change effective depth) | `CfdEngine`, `CfdMath`, `CfdOrderPolicyEvaluator`, `CfdEnginePlanLib` |
| SCAN-05 | Low / accounting_error | Frequent position checkpoints discard fractional carry (floor to whole atoms + index advance even at zero charge; `addMargin` repetition) | `CfdEngine`, `PositionRiskAccountingLib`. Overlaps MED-22 / KL-P-36. |
| SCAN-06 | Low / oracle_manipulation | Live oracle paths allow component skew up to staleness limits instead of the configured divergence limit (subset payloads + older stored legs accepted) | `PletherOracle`. Overlaps MED-7 / KL-P-49. |
| SCAN-07 | Low / logic_error | Observable settlement config digest does not commit to FAD override-calendar changes (hashes `fadRunwaySeconds` but not override-day set or admin version) | `CfdEngineAdmin`, `SettlementMonitorLensSidecar`, `ICfdEngineAdminHost` |
| SCAN-08 | Low / denial_of_service | Ordinary close orders are forced to carry no execution bounty (zero-bounty closes occupy FIFO; keepers uncompensated) | `OrderRouter`, `OrderRouterAdmin`, `OrderLiquidationBatchLogic`, `OrderQueueBook`, `OrderRouterBase`. Overlaps KL-P-12. |
| SCAN-09 | Low / logic_error | Permissionless frozen-state settlement can apply an unsnapshotted redemption fee (request made live, settled while frozen, fee not committed at request) | `HousePool`, `TrancheVault` |
| SCAN-10 | Low / logic_error | Protection trigger bounty is paid before a zero-bounty close is executed (trigger reward collected at queueing; retries unpaid) | `OrderRouter`, `PositionProtectionBook`, `OrderLiquidationBatchLogic` |
| SCAN-11 | Low / accounting_error | Redeem allocation dust returned to the pool is not restored to pool accounting (`assetDust` → raw balance without `accountedAssets`) | `HousePool`, `TrancheVault`. Overlaps KL-P-34. |
| SCAN-12 | Low / denial_of_service | Refundable senior reservations allow temporary capacity denial (request consumes capacity, cancellable pre-maturity at no fee) | `HousePool`, `TrancheVault`, `HousePoolSeniorCapacityLib`. Overlaps MED-19. |
| SCAN-13 | Low / denial_of_service | Stale cached marks can underfund open-order bounties and global FIFO cleanup (commit against stale mark / 1e8 fallback) | `OrderCommitHandler`, `OrderLiquidationBatchLogic`, `OrderReservationAccounting`. Overlaps MED-16/LOW-57 / KL-P-11. |
| SCAN-14 | Info / price_manipulation | Current pool depth is applied retroactively to the full carry interval (`_advanceAllCarryIndexes` uses one instantaneous `totalAssets()`; `checkpointCarryIndexes` permissionless) | `CfdEngine`, `PositionRiskAccountingLib` |
| SCAN-15 | Info / denial_of_service | Direct expiry omits the accounting mark required to pay a nonzero keeper bounty (`expireOrder` leaves bounty-accounting price/time zero) | `OrderRecoverySidecar`, `OrderRouter`, `OrderRouterExecutionSidecar`, `OrderLiquidationBatchLogic` |
| SCAN-16 | Info / accounting_error | Failed protection attempts unconditionally pay the bounty instead of retaining it for retry (`_settleTerminalBounty` removes reservation after relatch) | `OrderRecoverySidecar`, `OrderRouter`, `OrderV3Types`, `IOrderRouterExecutionHost`, `OrderLiquidationBatchLogic` |
| SCAN-17 | Info / denial_of_service | Later mark refresh can make live historical-price orders permanently out of order (permissionless `updateMarkPrice` after settlement window, before execution deadline) | `OrderRouter`, `OrderRouterExecutionSidecar`, `PletherOracle`, `OrderLiquidationBatchLogic` |
| SCAN-18 | Info / denial_of_service | Lifecycle commitment validation rejects every pledge-funded close bounty (free/pledge-funded `CloseCommitment` handling) | `OrderLifecycleBook`, `OrderRouter`, `IOrderRouterErrors`, `OrderLiquidationBatchLogic`, `OrderRouterBase` |
| SCAN-19 | Info / logic_error | Observable settlement config digest omits a pool-reconcile oracle policy field (`maxComponentPublishTimeDivergence` not committed) | `SettlementMonitorLensSidecar`, `IPletherOracle` |
| SCAN-20 | Info / logic_error | Open previews invert long and short liquidation-price search directions (`_findLiquidationPrice` uses opposite-side logic) | `CfdEngineLens` |
| SCAN-21 | Info / denial_of_service | Open quote pruning underflows when costs reduce existing position margin (`_maxAffordableMargin` subtraction) | `CfdEngineOpenQuoter`, `CfdEnginePlanLib` |
| SCAN-22 | Info / oracle_manipulation | Order execution accepts oracle updates older than the engine's cached mark (`_processOrder` doesn't reject `publishTime < lastMarkTime`) | `CfdEngine`, `ICfdEngine`, `CfdEnginePlanLib` |
| SCAN-23 | Info / logic_error | Partial redemption claims can be classified as queue corruption (monitor treats queued epoch as valid only while `fundingBasisClaimed == 0`) | `SettlementMonitorLens`, `SettlementMonitorLensSidecar`, `PerpsViewTypes` |
| SCAN-24 | Info / accounting_error | Pool payouts are credited at nominal value without verifying settlement-token receipt (action rebate: `payOut` then `settleUsdc` at nominal; no balance-delta check) | `CfdEngineSettlementSidecar`, `MarginClearinghouse` |
| SCAN-25 | Info / logic_error | Protection can match a later position with the same side and size (no `positionEpoch`/instance id; `afterOrderTerminal` ignores ordinary close ids) | `CfdEngine`, `PositionProtectionBook` |
| SCAN-26 | Info / accounting_error | Self-deposit paths credit nominal rather than received settlement tokens (`_deposit` credits requested amount without balance-delta check; fee-on-transfer token risk) | `MarginClearinghouse` |
| SCAN-27 | Info / logic_error | Settlement health reads side state with a mismatched selector width (`sides(uint256)` vs canonical `uint8` getter) | `CfdEngineLens`, `CfdEngineProtocolLens`, `SettlementMonitorLensSidecar` |
| SCAN-28 | Info / logic_error | Settlement oracle monitoring rejects valid close-only snapshots (every `closeOnly == true` PoolReconcile snapshot = Oracle dependency failure) | `SettlementMonitorLens`, `SettlementMonitorLensSidecar`, `IPletherOracle` |
| SCAN-29 | Info / logic_error | State-driven VPI increases are classified as user-invalid margin failures (open valid at commit, fails `MARGIN_DRAINED_BY_FEES` from others' skew/depth changes) | `CfdEngine`, `CfdEnginePlanLib`, `OpenAccountingLib` |
| SCAN-30 | Info / price_manipulation | Temporary pool liquidity can reduce a skew-increasing close charge (close VPI from single execution-time `poolAssetsUsdc` denominator) | `CfdMath`, `CfdEnginePlanLib`, `CloseAccountingLib` |
| SCAN-31 | Info / price_manipulation | Temporary pool-liquidity reduction can amplify a skew-reducing close rebate (same denominator mechanism, rebate side) | `CfdMath`, `CfdOrderPolicyEvaluator`, `CfdEnginePlanLib`, `CloseAccountingLib` |
| SCAN-32 | Info / denial_of_service | Unbounded per-account order queue can make liquidation exceed the block gas limit (`_commitOrder` has no per-account count limit despite `pendingOrderCounts`/`TooManyPendingOrders`) | `IOrderRouterErrors`, `OrderBountyAccounting`, `OrderLiquidationBatchLogic`, `OrderLiquidationHandler`, `OrderReservationAccounting` |
| SCAN-33 | Info / validation_bypass | Uncapped slippage check can admit a LONG open below its target price (`targetPrice > CAP_PRICE` passes raw-price check, settles at clamped price; check SHORT closes too) | `CfdEngine`, `CfdEnginePlanLib`, `OrderValidationLib` |

## §4 — `packages/perps/SECURITY.md` Known Limitations (S4): 50 entries

IDs `KL-P-01…50` assigned here in document order (SECURITY.md numbers nothing). Status for all: **stated/accepted limitation** (documented behavior, not a defect per the project). The Immunefi page excludes "SECURITY.md: Known limitation: live basket component selection", "Router and keeper limitations", and "Known Limitations" generally — i.e. this whole section plus the two standalone limitation sections (§4, KL-P-49/50).

### Oracle and market-closure limitations

| ID | Limitation (one line) |
|---|---|
| KL-P-01 | Frozen-oracle windows prioritize close liveness over live-market-style freshness guarantees. |
| KL-P-02 | Oracle-frozen voluntary close/reduce applies normal signed VPI plus a fixed LP-owned notional spread; live/FAD-only closes apply signed VPI without that spread. |
| KL-P-03 | The fixed frozen spread deliberately does not increase with mark staleness inside the permitted frozen window. |
| KL-P-04 | Full-close liveness takes priority over collecting an otherwise uncollectible spread; partial closes keep all-or-nothing rules for required charges but do not fail solely on uncollateralized price loss above the PnL cap. |
| KL-P-05 | The recurring FX calendar follows New York DST transitions on-chain; unscheduled provider closures and holiday hours still require governance-configured UTC-day overrides. |
| KL-P-06 | The post-2007 US DST rule is compiled into the planner; a future legal/provider schedule change at an intraday boundary requires a coordinated engine/planner/oracle deployment. |
| KL-P-07 | Execution remains dependent on fresh keeper infrastructure and oracle publication outside frozen windows. |

### Router and keeper limitations

| ID | Limitation (one line) |
|---|---|
| KL-P-08 | Users cannot manually cancel queued intents. (Overlaps SC-I2.) |
| KL-P-09 | Account-scoped client ids are permanent; a terminal or config-invalidated id cannot be reused for a replacement request — clients must generate/persist unique ids. |
| KL-P-10 | Bounded cleanup means heavily expired queues may take multiple keeper calls to clear. |
| KL-P-11 | Stale cached marks can understate opening notional and execution bounties at commitment; bounty floor/cap, trader bound, and per-account cap limit individual commitments but cannot guarantee profitable cleanup; commitment does not require a fresh stored mark. (Overlaps MED-16, LOW-57, SCAN-13.) |
| KL-P-12 | Ordinary failed closes require unpaid cleanup; the protocol keeper must fund gas for permissionless oracle-free expiry; bounded deadlines/queues do not guarantee positive keeper incentive or prevent repeated fresh invalid submissions. (Overlaps SCAN-08.) |
| KL-P-13 | Failed protection-attempt cleanup is deliberately unpaid; each retry creates a fresh zero-bounty close record; trigger reward paid once on the original trigger; liveness depends on keepers processing the terminal attempt + separately appending a retry; operators must alert on prolonged `Latched` state. |
| KL-P-14 | Per-account pending-order caps bound each account's queue; liquidation cleanup traverses that local queue. |
| KL-P-15 | Router + predeployed lifecycle Book + constructor-created protection Book + fixed sidecars form one non-upgradeable stack reviewed together; externalizing the Book/keeper/execution paths saves bytes but increases review coupling (direct-call rejection, getter assumptions, caller/event context, EIP-170/EIP-3860 sizes must be rechecked on any change). |
| KL-P-16 | Known typed planner/policy failures, slippage, expiry, and config mismatch are terminal; a registered protection attempt may relatch when the exact position remains; other orders have no terminal retry lane, while uncertain dependency failures deliberately retain the FIFO head and can block later orders until retry/expiry/risk-off/liquidation. |
| KL-P-17 | Complete terminal economics are event-backed; on-chain storage retains only the compact outcome + receipt hash, so historical consumers require reliable log indexing. |
| KL-P-18 | The lifecycle Book has no migration or repair authority; a binding/invariant fault requires containment + a fresh compatible stack. |
| KL-P-19 | Changes to the Router-created protection Book require a fresh compatible stack + updated client/keeper/indexer bindings; deployment scripts do not migrate old protection or order-attempt state. |

### LP accounting limitations

| ID | Limitation (one line) |
|---|---|
| KL-P-20 | Exact terminal NAV is only as current as its authenticated mark; live open-position epoch settlement requires an atomically validated post-boundary mark, while frozen exits deliberately use the cached stale-window mark. |
| KL-P-21 | A positive marked receivable is not cash, so share NAV can exceed immediately redeemable liquidity. |
| KL-P-22 | `TerminalNavBookV2` is intentionally non-upgradeable with no owner repair path; a book/Engine invariant failure requires containment + fresh-stack deployment, not an in-place edit. |
| KL-P-23 | `oracleFrozen` keeps eligible synchronized LP settlement live under fixed tranche-local frozen fees rather than a separate stale-action gate for exits; redemption funding proceeds while entry activation is deferred. |
| KL-P-24 | Each bounded live backlog pass pays a Pyth update fee and may use a later valid post-boundary mark than the previous pass; atomicity binds one call, not an arbitrarily large backlog. |
| KL-P-25 | Senior coupon payments are capped by available junior principal. |
| KL-P-26 | Governance can prospectively reduce senior limits below live exposure, closing new senior entry and potentially reducing Junior redemption-funding capacity until cured; it cannot force existing Senior capital out. |
| KL-P-27 | Accepted senior reservations are grandfathered against later cap/accounting changes; an explicit settlement hold, projected terminal wipe, Senior impairment, or epoch rejection allows escrow recovery. |
| KL-P-28 | Wallet shares are governed by the latest applicable activation timestamp, so combining a newer lot with an older wallet balance preserves the newer lot's remaining cooldown; admin claims manufacture no claim-time delay; direct routing can consume an independently aged lot; redemption cancellation/terminal refund starts a new cooldown when shares return to a wallet. |

### LP claim and allocation limitations

| ID | Limitation (one line) |
|---|---|
| KL-P-29 | Deposit/mint share claims, redemption cancellations, and refundable-share claims require `receiver == controller`, including zero-share acknowledgements (approved operator may act); funded USDG claims and pending-deposit USDG refunds have separate receiver rules. |
| KL-P-30 | Partial deposit claims or funded-redemption claims can revert at rounding boundaries even when the full remainder is claimable; a tiny asset-denominated deposit claim can round to zero shares. (Overlaps LOW-3/4/5.) |
| KL-P-31 | Per-controller flooring can produce zero entitlement for a dust-sized request; a full-balance redemption bypasses the minimum request size and can burn shares for zero assets if its allocation rounds to zero. |
| KL-P-32 | Funding an epoch in several passes can produce rounding differences and residual share refunds vs one pass; unfunded shares keep participating in tranche P&L/fees between calls. (Overlaps LOW-63.) |
| KL-P-33 | Zero-payout epochs can consume bounded settlement work and delay later epochs; regular keeper processing still required; insufficient cash or persistent Senior demand can independently defer Junior funding. (Overlaps MED-24.) |
| KL-P-34 | Terminal allocation dust follows fixed ownership rules: deposit-share dust burned, funded-asset dust returns to HousePool as excess, refundable-share dust goes to the seed receiver; never awarded to the final caller. (Overlaps LOW-13/67, SCAN-11.) |
| KL-P-35 | An impaired Senior withdrawal may retain less than one extra USDG atom of HWM protection per funded pass due to conservative rounding; can accumulate across passes; not a universal bound on all LP allocation dust. (Overlaps LOW-54.) |

### Rounding limitations

| ID | Limitation (one line) |
|---|---|
| KL-P-36 | **Position carry rounding:** carry-index delta → 6-decimal USDG rounds down; checkpoint advances even at zero without retaining the fractional remainder; each conversion can discard < 1 USDG atom; user-triggered checkpoints (incl. zero-amount withdrawals) can reduce LP carry revenue; no fractional carry persisted. (Overlaps MED-22, SCAN-05.) |
| KL-P-37 | **Zero-share Junior maintenance-fee checkpoints:** with nonzero fee rate + small raw Junior supply, the fee for completed hours can round to zero shares while the checkpoint boundary advances (hours don't accumulate); mint/burn can trigger checkpoints; no fractional fee shares retained/deferred. (Overlaps LOW-27.) |

### VPI limitations

| ID | Limitation (one line) |
|---|---|
| KL-P-38 | Liquidation does not compute a fresh VPI delta, but the gross negative accrued VPI clawback is settled from its dedicated reserve or equivalent withheld trader gain before residual planning. |
| KL-P-39 | VPI depends on live canonical assets net of outstanding trader claims; claim payment alone cannot change depth. |
| KL-P-40 | Zero economic depth blocks opens/increases after projected carry collection; protective closes create no fresh VPI charge/rebate at zero depth but retain the lifetime clamp + recovery of previously accrued negative VPI. |
| KL-P-41 | Voluntary closes use the same signed VPI curve + lifetime rebate clamp in live, FAD-only, and oracle-frozen regimes. |
| KL-P-42 | Frozen-market stale-price protection is a fixed notional spread leaving VPI unchanged, replacing (not compounding with) the Pyth adverse-confidence shift for oracle-frozen voluntary closes only. |
| KL-P-43 | The lifetime clamp intentionally zeroes otherwise extractable rebate-only round trips. |
| KL-P-44 | Partial-close VPI release is a bounded linear approximation. |

### Clearinghouse limitations

| ID | Limitation (one line) |
|---|---|
| KL-P-45 | Settlement uses USDG only; each account has one directional position and separate typed collateral buckets. |
| KL-P-46 | Owner may rescue accidentally transferred non-settlement ERC-20s via `rescueToken`; settlement USDG always excluded (incl. uncredited direct transfers); rescue alters no account balances/margin. |
| KL-P-47 | **Settlement-USDG recovery limitation:** direct USDG transfers outside deposit APIs do not credit a margin account and remain unrecoverable through current APIs, including by the owner; not allocated to HousePool/LPs; no aggregate credited-balance counter exists to distinguish recoverable surplus. Integrations must use `deposit`/`depositMargin`/`depositFor`. (Overlaps LOW-6.) |
| KL-P-48 | Non-USDG collateral pricing and staleness policy are intentionally out of scope. |

### Standalone limitation sections (outside "Known Limitations", explicitly excluded by the Immunefi page)

| ID | Limitation (one line) | Status |
|---|---|---|
| KL-P-49 | **Live basket component selection:** the oracle cannot establish that each supplied component is the newest Pyth report available off-chain; a caller may choose an older still-valid signed component within the allowed window and obtain a different basket mark (live mark refresh, liquidation, LP settlement; historical execution has its separate post-commit parse + 5s gap limit). Tightening the window reduces but does not eliminate caller choice. | Stated limitation. Overlaps MED-7 (partly fixed per Immunefi), SCAN-06. |
| KL-P-50 | **Arbitrum and Pyth clock alignment:** `commitTime` = Arbitrum `block.timestamp`; first eligible Pyth basket after that timestamp may already have been publicly observable; no fixed delay compensates; "post-commit" describes the timestamp rule, not a guarantee the price was unknown at submission. | Stated limitation. **HIGH-1 exception applies — see §0.** |

### §4b — Other accepted limitations stated in SECURITY.md body sections (not in "Known Limitations"; listed so hunters don't re-report them as novel)

These are stated design trade-offs in the body of SECURITY.md. They are NOT counted in the §4 total of 50, but overlap with them should be treated as excluded on the same root-cause basis. Cross-refs only — see the named sections for full text.

| Ref | Statement |
|---|---|
| Body-1 | Basket-only confidence gate favors liveness over a per-feed hard ceiling: a low-weight component with wide confidence can pass if its weighted contribution keeps aggregate confidence within the limit. (Pyth trust assumptions.) |
| Body-2 | Exponent normalization truncates on scale-down. (Pyth trust assumptions.) |
| Body-3 | USDG blacklist/upgrade/centralization risk: no mitigation inside core perps design. |
| Body-4 | Senior coupon arithmetic floors independently at each settlement advancing real work; sub-micro-USDG rounding remains execution-frequency dependent; hourly aggregation bounds the residual rather than making accrual remainder-exact. (Overlaps SCAN-01's compounding claim in part — SCAN-01's forced-checkpoint extraction mechanism is separately excluded as a scan finding.) |
| Body-5 | Guardian containment is not repair; release restores eligibility only. No global freeze, no redemption-request-off, no corrupted-queue quarantine, no emergency pricing exists by design. |
| Body-6 | One-time wiring setters (`setOrderRouter`, `setEngine`, vault setters, planner in `setDependencies`) do not all validate reciprocal bindings — deployment responsibility; wrong addresses cannot be repaired later. |
| Body-7 | Monitoring/lens outputs are advisory and unauthenticated; `SettlementMonitorLens` cannot prove per-account curve parity or authorize settlement/repair. |
| Body-8 | Full liquidation only (no partial-liquidation recovery path); liquidation charge capped by the dedicated reserve with no pool-funded bounty subsidy. |

## §5 — Immunefi known-issues list (S5): mapping to entries above

The competition page's known-issues list (26 Oct 2026) is the authoritative exclusion trigger; each bullet maps as follows. Nothing in this section adds entries beyond §§1–4.

| Immunefi bullet | Maps to |
|---|---|
| Cecuro MED-24 and MED-29: LP refund epochs and redemption rounding | MED-24, MED-29 (§1); KL-P-33/34/35 (§4) |
| All findings in the AI scan findings (Oct 15, 2026), including accepted-risk and acknowledged sections | SCAN-01…33 (§3) |
| All findings in the SC Audit Studio pre-audit report, including accepted-risk and acknowledged sections | SC-Q1…Q11 (excl. absent Q7), SC-H1/H2, SC-M1…M7, SC-L1, SC-I1/I2 (§2) |
| All findings in the Cecuro AI audit report, including accepted-risk and acknowledged sections | MED-1…32, LOW-1…74, HIGH-1, INFO-1…6 (§1) |
| SECURITY.md: Known limitation: live basket component selection | KL-P-49 (§4) |
| SECURITY.md: Router and keeper limitations | KL-P-08…19 (§4) |
| SECURITY.md: Known Limitations | KL-P-01…48 (§4) |
| Arbitrum and Pyth clock alignment (HIGH-1) — valid only with POC of repeatable net-profitable LP extraction | HIGH-1 (§1), KL-P-50 (§4); exception rule in §0 |
| Cecuro MED-30 (partly fixed): stop-losses have no automatic frozen-market trigger | MED-30 (§1) |
| Cecuro MED-22: carry rounding | MED-22 (§1); KL-P-36 (§4) |
| Cecuro MED-16 and LOW-57: opens committed against a stale cached price, and the keeper bounty sized from it | MED-16, LOW-57 (§1); KL-P-11 (§4) |
| Cecuro MED-13: a governance oracle rotation retargets armed stop-losses | MED-13 (§1) |
| Cecuro MED-7 (partly fixed): a caller can still pick an older valid signed price per feed | MED-7 (§1); KL-P-49 (§4) |

## §6 — Root `SECURITY.md` Known Limitations (S6): spot-scope — DO NOT conflate with perps exclusions

**Warning:** the repository-root `SECURITY.md` documents the **spot system** (SyntheticSplitter, SyntheticToken plDXY-BEAR/BULL, BasketOracle/Chainlink, Curve pools, Morpho, InvarCoin, StakedToken, RewardDistributor, routers). Its "Known Limitations" section (§"Known Limitations", lines ~216–565) concerns those contracts, **not** `packages/perps`. A perps finding is NOT excluded merely because a similar-sounding limitation exists here, and a spot finding is out of the stated perps target. These 24 entries are recorded because the task required reading this section; they are counted separately and must not be cited as perps exclusions without coordinator confirmation that spot scope applies.

| ID | Limitation (one line) | Spot contract(s) |
|---|---|---|
| KL-R-01 | Zero/negative oracle prices: `OracleLib` reverts; all state-changing ops halt (protective default) | `OracleLib` |
| KL-R-02 | Price volatility between preview and execution: `previewMint`/`previewBurn` may differ at execution; users set slippage | Splitter previews |
| KL-R-03 | Oracle/market deviation: BasketOracle reverts if Chainlink-vs-Curve-EMA deviation > 2%; minting/leverage/Morpho liquidations halt; `withdraw`/`lpWithdraw` stay live | `BasketOracle` |
| KL-R-04 | Burn during liquidation: users can still burn/redeem after liquidation triggers (intentional exit); only minting blocked | `SyntheticSplitter` |
| KL-R-05 | No partial liquidation: price ≥ CAP ⇒ whole protocol SETTLED; all positions affected equally | Splitter/CAP |
| KL-R-06 | Minimum/maximum amounts table (mint 1 wei+, burn = balance, leverage ~$1+, flash mint per ERC-3156) | Splitter |
| KL-R-07 | Rounding: mint rounds UP, burn rounds DOWN (both favor protocol; anti-arbitrage rationale) | Splitter |
| KL-R-08 | Buffer management: 10% local buffer, 90% adapter; burns beyond buffer need adapter withdrawal (may revert if Morpho Vault illiquid); ratio enforced at mint only, no auto-rebalance | Splitter/adapter |
| KL-R-09 | Protocol fees: zero user-operation fees; performance fee on yield only (caller 0.1%, treasury 20%, staking 79.9%; 100% to treasury if staking unset; hardcoded) | `harvestYield` |
| KL-R-10 | Morpho token rewards: two-level claiming (curator → vault share price; owner `claimRewards` to adapter with forbidden targets); timing depends on curator/distributor | `VaultAdapter` |
| KL-R-11 | Flash mint capability: ERC-3156, zero fee, unlimited; tokens must return same-tx; complex-vector risk noted, price validation independent | `SyntheticToken` |
| KL-R-12 | Decimal handling: critical conversions documented (see root doc table) | Throughout spot |
| KL-R-13 | RewardDistributor price manipulation for reward skew (see root doc §RewardDistributor Security) | `RewardDistributor` |
| KL-R-14 | RewardDistributor stale-EMA frontrunning (see root doc) | `RewardDistributor` |
| KL-R-15 | StakedToken reward-sniping protection: streaming over 1h, `_decimalsOffset() = 3` inflation protection | `StakedToken` |
| KL-R-16 | StakedToken griefing protection: proportional stream extension prevents zero-amount timer resets | `StakedToken` |
| KL-R-17 | InvarCoin oracle model: mode-dependent stale-oracle behavior (see root doc table) | `InvarCoin` |
| KL-R-18 | InvarCoin dual LP pricing: context-dependent pricing rationale (see root doc) | `InvarCoin` |
| KL-R-19 | InvarCoin `withdraw()` ignores loose BEAR; single-sided withdrawal returns USDC only; use `lpWithdraw()`/`minUsdcOut` for fair value | `InvarCoin` |
| KL-R-20 | InvarCoin single-sided withdrawal slippage: caller `minUsdcOut` passed to Curve, no protocol EMA floor (liveness-preserving; frontends must set it thoughtfully) | `InvarCoin` |
| KL-R-21 | InvarCoin `lpWithdraw()` during emergency with bricked Curve: reverts on `remove_liquidity` until `forceRemoveGauge()` writes off gauge LP | `InvarCoin` |
| KL-R-22 | InvarCoin keeper/solver incentives: `harvest()` has no on-chain caller reward; rebalancing via permissionless solver fills with spread; infrequent harvest ⇒ lumpy INVAR minting (not exploitable, real VP growth) | `InvarCoin` |
| KL-R-23 | Curve pool configuration: indices verified at deployment, pool immutable; BasketOracle pool updatable via 7-day timelock | `BasketOracle`/Curve |
| KL-R-24 | Router architecture: shared validation, 1% max slippage, flash-loan callbacks validate lender/initiator, Morpho authorization model, EIP-2612 permit support | Routers |

## Appendix — Two further reports in `exclusions/` NOT named in the exclusion set (spot-scope; verify with coordinator)

These files exist in `~/workspace/plether-audit/exclusions/` but are **not** among the three reports named in the task/Immunefi list. Per root `SECURITY.md` §Audit Status, both audit **spot** contracts only. They are summarized here from the root SECURITY.md summaries (not fully extracted) so the coordinator can decide; do not treat them as perps exclusions unless confirmed.

- **Collaborative audit, 12 May 2026** (`plether-collaborative-audit-report-2026-05-12.txt`, 1191 lines; review 19–24 Mar 2026; commit `e54cabc3`). Scope: `InvarCoin.sol`, `OracleLib.sol`, `StakedToken.sol`. 9 findings: 1 High + 2 Medium (all resolved: stale-EMA slippage sandwich; missing `lpWithdraw` receiver; BasketOracle deviation freeze), 6 Low/Info (2 resolved, 4 acknowledged: 24h heartbeat timing, gauge assumptions, 1-wei vesting rounding, withdraw EMA floor precision).
- **Cantina managed review, Jan 2026** (`report-cli-cantina-plether-0126.txt`, 242 lines; commit `596b0179`). Scope: `SyntheticSplitter`, `SyntheticToken`, `MorphoAdapter` (removed), `BasketOracle`. 8 findings: 2 Medium fixed (basket weights unconstrained; adapter interest accrual), 5 Low (4 fixed, 1 acknowledged: duplicate event emissions), 1 Informational fixed.

## Counts reconciliation

| Set | Count |
|---|---|
| Cecuro (§1): 1 High + 32 Medium + 74 Low + 6 Info | 113 |
| SC Audit Studio pre-audit (§2): 10 Q + 2 High + 7 Medium + 1 Low + 2 Info | 22 |
| AI scan (§3): 1 Medium + 12 Low + 20 Info | 33 |
| **Prior-report subtotal** | **168** |
| Perps SECURITY.md Known Limitations bullets (§4: 7+12+9+7+2+7+4) | 48 |
| Perps SECURITY.md standalone limitation sections (§4: KL-P-49/50) | 2 |
| **Perps exclusion entries total** | **218** |
| Root SECURITY.md spot limitations (§6, separate) | 24 |
| Body-section accepted limitations (§4b, cross-refs, not additive) | 8 |
