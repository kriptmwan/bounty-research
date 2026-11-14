DECISION: CAUTION — 0 findings survive; nothing filing-ready. The live Ethereum mainnet FXB system runs v1-generation code, not repo HEAD, and the v1 code withstood the full adversarial pass; the HEAD v2 code (beacon proxies, FXB_LFRAX, Ownable2Step factory) has no live mainnet deployment. Caveats: Fraxtal deployments are out of scope and unverified; factory-bypassing direct deployments cannot be fully ruled out (eth_getLogs unavailable from free RPCs); the FxbAMO operator lives in a separate repo outside this audit's scope.

# Adversarial Code Audit — Frax FXB / Frax Bonds (Option 3)

**Repo:** `frax-bonds` @ `4ef235e68c8277ad3dbc676762fffe663c9896fc` (2025-07-09), clean at conclusion
**Live code audited:** Sourcify `exact_match` v1 sources for all mainnet deployments (extracted to `work/v1-live/`; all 5 FXBs share one source hash, all 5 auctions share one source hash)
**Date:** 2026-11-14 · **Mode:** single pass, audit-only, read-only + local fork execution, no transactions, no contact with the Frax team, no gist, no submission, zero GitHub API calls
**Pipeline:** Phase 0 groundwork (0A–0D) → deterministic triage → Recon → 4 domain Hunters → Skeptic/Referee skipped (zero findings; empty artifacts preserved) → coordinator verification
**Bounty bar (impact gate — hard):** Frax reviews ONLY demonstrated theft-of-funds or permanent-freezing paths against CURRENT LIVE deployments, each with a working mainnet-fork PoC quantifying funds at risk. Theoretical issues, scanner/AI output without verified PoC, and low/medium findings are NOT reviewed. Every Hunter claim was gated on this bar; 88 sub-bar observations are recorded separately as non-qualifying.

## Verdict

**0 confirmed findings. 0 filing-ready candidates. 0 Critical, 0 High, 0 Medium, 0 Low.**

| Domain | Scope | Candidates | Non-qualifying |
|---|---|---|---|
| A — Bond mint/redeem + maturity | v1 FXB.sol, date library | 0 | 23 |
| B — SlippageAuction mechanics | SlippageAuction.sol (= HEAD), auction factory | 0 | 25 |
| C — Factory/deployment + upgrade | v1 factory (live); HEAD beacon/proxy/upgrade files (no live instance) | 0 | 25 |
| D — Access control / roles + boundary | Timelock2Step (live); OwnedV2, minter token base (no live instance) | 0 | 15 |

No 7-Question Gate was run (no candidates), no finding PoC was built (none needed), no gist adversarial self-check applies (nothing to file). The Phase 0D fork smoke test (6/6) proves the fork harness works for any future FXB PoC.

## The central scoping outcome: HEAD ≠ deployed

Phase 0B/0C independently established that the Ethereum mainnet system runs **v1-generation code**, and the repo HEAD v2.0.0 code describes deployments that do not exist on mainnet:

- Live FXBFactory: `Timelock2Step`-gated, immutable `FRAX`, deploys full FXB contracts directly; no `owner()`/`beacon()`/`token()`/`version()`. HEAD's beacon-proxy/`Ownable2StepUpgradeable` factory runs nowhere on mainnet.
- Live FXBs (5): v1.0.2 immutable ERC20s, immutable `FRAX` + maturity, constructor-deployed, no owner, no proxy, maturity-only `isRedeemable()` — the HEAD factory-owner early-burn bypass does not exist live.
- Live SlippageAuctions (5): byte-identical to HEAD `SlippageAuction.sol`; live auction factory is HEAD minus `version()` only.
- Live FXB_LFRAX / beacon / `FraxUpgradeableProxy` / `StorageSetterLFRAX`: no mainnet deployment. Fraxtal uses OZ `TransparentUpgradeableProxy` with an unverified `FXB_LFRAX` implementation — Fraxtal is out of scope for this audit.
- No proxies and no upgrade authority exist anywhere on mainnet (all EIP-1967 slots zero).

Hunters hunted the live v1 sources as primary. Every v2-only defect found was recorded as non-qualifying with the no-live-instance reason, never inflated into a finding. Auditing HEAD as if live would have misstated roles, upgradeability, and redemption gating.

## Live state (Phase 0B, blocks 26,411,500–26,411,541)

- **5 FXBs** (factory registry): 4 matured, 1 unmatured — FXB_20261231 (`0x76237BCf…`), matures 2027-01-01, holding **~6,046,780 FRAX**. Total outstanding ~6,082,680 FXB, backed exactly 1:1 by in-contract FRAX on every contract.
- **5 auctions** (auction-factory registry): all stopped + expired, **zero balances**, 33 historical runs (7,025,001.50 FXB sold, 6,466,098.30 FRAX received). Auctions are restartable by the operator, so mechanics defects would carry future-auction exposure only — stated honestly wherever relevant; no current funds at risk in any auction.
- **Roles:** Gnosis Safe `0x83182266…` (6 owners, threshold 3) is sole timelock of the factory and of the FxbAMO operator; FxbAMO (`0x452420df…`, separate repo, out of scope) is timelock of all 5 auctions and holds 1,999,230 FXB_20261231. No role transfer in flight anywhere (re-verified at block 26,411,601).
- **Missed-deployment sweep:** 171 unique repo addresses code-checked on mainnet; 0 missed FXB/auction deployments. 3 coded-but-unregistered addresses flagged and cleared by fingerprinting. Reverse gap noted: 4 of 5 FXBs and all 5 auctions never appear in the repo — registry enumeration was essential.

## Phase 0 groundwork (all closed)

| Item | Result |
|---|---|
| 0A Exclusion list | 16 entries (EX-F01–EX-F16) from ToB Oct 2023 (3), ChainSecurity Jul 2025 (7), repo docs/trust-model text (6); plus a 23-item out-of-scope section. Highest: TOB-FBSRO-3/4 (High, resolved, verified fixed at HEAD). EX-F01 (no token-recovery in FXB, Informational, unresolved) verified still present — not re-reported. See `exclusions/EXCLUSION_LIST_FXB.md`. |
| 0B Canonical addresses (on-chain only) | 301-field inventory in `fxb-addresses.json`; full narrative in `ONCHAIN-GROUNDWORK-FXB.md`. Registry completeness rests on getter + out-of-bounds + storage-length + factory-nonce agreement (all agree on 5+5) plus operator-counter arithmetic. 10 owed block-explorer follow-ups recorded. |
| 0C Deployed-bytecode correspondence | 36 addresses classified (chains 1 + 252): **0 HEAD / 12 DIFFERS / 5 UNKNOWN / 19 EXCLUDED**. 6 material DIFFERS (v1 factory + 5 FXBs); auctions cosmetic-only (semantically HEAD). Raw records in `sourcify-fxb/`. See `CORRESPONDENCE-FXB.md`. |
| 0D Fork smoke test | PASS 6/6, exit 0, pinned block 26,411,490 (`evm_version="cancun"`). Suite rewritten against the verified live v1 ABI after the HEAD-ABI suite failed 4/6 — the first proof of the v1-vs-HEAD divergence. See `poc-smoke-fxb/SMOKE-RESULTS.md`. |

## Strongest near-misses, and why they fail the bar

1. **Unchecked FRAX return values in v1 mint/burn (NQ-A, NQ-D-2 relay)** — killed by evidence, not assumption: live FRAX (`ERC20Custom`, verified source) `transfer`/`transferFrom` return `true` or revert (SafeMath + zero-address checks), no fee, exact amount, no hooks — a failed FRAX leg reverts the FXB transaction atomically. Corroborated by exact 1:1 accounting across ~8.9M minted/redeemed. Caveat: FRAX source is a partial Sourcify `match`, not `exact_match`.
2. **Reentrancy in mint/burn (NQ-A)** — killed: CEI order + FRAX `_transfer` makes no external calls + empty `_beforeTokenTransfer` + no receiver hooks in OZ `_mint`/`_burn`. No callback surface on live instances.
3. **`swapExactTokensForTokens` rounding-dust spurious revert (NQ-B-1)** — real dual-flooring effect (fuzz-verified with exact Python arithmetic, 200k samples × 2 ranges, 47% of random cases in historical ranges), but the gap is dust (mean ~539k wei, max ~3.2M wei), the effect is revert-only and workaroundable, and zero funds are at risk. Sub-bar.
4. **`_getAmountIn` denominator zero/underflow at extreme slippage (NQ-B-2/3)** — the v1.0.0 50% slippage cap is absent in live v1.0.1, but slippage only raises prices (never underprices), parameters are operator-set, effects are revert-only or overcharge-only, and the auction is stop-recoverable. Sub-bar.
5. **Direct FRAX donations subsidize the next buyer (NQ-B-5)** — real mechanism (balance-delta accounting vs stored `tokenBuyReceived`), but no flow creates donations, all excess counters are 0 over 33 runs, and exploiting it requires a victim's own donation. Sub-bar.
6. **Wednesday-maturity invariant violated (NQ-A, NQ-C-01)** — benign: no contract enforces Wednesday (`getDayOfWeek` never called); the date library was verified over all 137,331 days 1970–2345 with zero mismatches; the timelock chose 1st-of-month dates; redemption is timestamp-only. No fund consequence.
7. **`FraxBeacon.setImplementation` unchecked immediate upgrade (NQ-C-14)** — the strongest v2-only issue: single-owner, immediate, affects all beacon proxies. Killed: no beacon proxies on mainnet, Fraxtal uses OZ TUP, plus EX-F09/EX-F12.
8. **Timelock/operator renounce bricking (NQ-C-07, NQ-D-3/6/14)** — `renounceTimelock` could permanently disable future FXB creation or auction control, but requires a deliberate 2-step action by the Safe itself (Q4 centralization, EX-F12), and freezes $0 (live FXBs have no factory dependency; auctions hold $0).
9. **R-D-1 relay: `FXB_LFRAX.isRedeemable()` calls `Timelock2Step(factory).timelockAddress()` while HEAD factory exposes only `owner()`** — Fraxtal-only, no mainnet instance; and its premise is likely wrong, since 0C established the live Fraxtal factory is v1.1.0 (Timelock2Step-based), so the call likely resolves. Killed on scope + unproven premise; Fraxtal interface unverified (Sourcify 404).
10. **Permissionless auction factory + no duplicate check (NQ-B-9/10, NQ-C, R-D-3)** — intended design; grep-verified no on-chain consumer of `isAuction`/`getAuctions` exists, so no trust-anchor abuse path. Off-chain consumer risk only, undemonstrated.
11. **`StorageSetterLFRAX` arbitrary-slot-write danger (NQ-C-21)** — disproved as exposed: only fixed-slot/fixed-value `setNameAndSymbol` (correct short-string encodings) plus view getters; clear-slot functions commented out; no live proxy points at it.
12. **Flash-swap transfer-before-checks (NQ-B-15/21)** — atomic revert + `nonReentrant` make the callback ordering safe; `swap()` measures the post-callback balance delta and enforces the minimum. No drain path.

## Caveats (read before relying on "no other findings")

- **Single-pass coverage.** All 15 scannable source files were assigned and read; interfaces context-only. A second pass or a loop order could cover more, but no domain reported unread assigned files.
- **Fraxtal out of scope.** The Fraxtal FXB upgrade (FXB_LFRAX impl `0xA7c3…`, LFRAX impl `0x17Fd…` reporting a newer version than HEAD, v1.1.0 factory) was inventoried behaviorally by 0B/0C but NOT audited; all five Fraxtal implementation sources are Sourcify-404. A Fraxtal audit is a separate task needing Fraxtal RPC + Fraxscan verification (owed checks F1–F3 in `CORRESPONDENCE-FXB.md`).
- **Direct-deployment residual.** Registry completeness rests on four agreeing on-chain signals plus operator arithmetic, but `eth_getLogs` is unavailable from free RPCs (publicnode rejects even 100k-block chunks; LlamaRPC unreachable), so creation-event enumeration could not cross-check the registries. Direct constructor deployments bypassing the factories cannot be ruled out from RPC alone (owed checks in `ONCHAIN-GROUNDWORK-FXB.md` §follow-ups). Any such deployment would run the same audited v1 code, and unregistered FXBs are excluded from the only registry consumer (FxbAMO requires `isFxb`).
- **FxbAMO operator out of scope.** The operator contract (separate `frax-bonds-amo` repo, Sourcify partial match) governs all auctions and holds ~2M FXB_20261231. It was read as evidence only; its own code was not audited. A defect inside FxbAMO would not be caught by this audit.
- **Rebuild gap.** Deployed mainnet builds used optimizer 100k runs, matching neither repo profile (200 / 1M+via-IR); correspondence verdicts are source-level, not rebuild-bytecode-level (owed check B1).
- **FRAX source is a partial match.** The unchecked-return kill rests on partial-match verified source plus 2+ years of exact accounting; a bytecode rebuild was not performed.
- **Two Hunters (A, B) wrongly believed no Foundry toolchain exists** (the skill's §14 toolchain note is stale; forge 1.5.1 is installed). Immaterial to this outcome — zero findings needed no PoC — but NQ-B-1's fuzz evidence is formula replication in Python, not EVM execution, and is recorded as such.
- **Dedup limits.** Frax takes secret-gist submissions, so a prior private report of any near-miss cannot be searched. The ToB + ChainSecurity reports were read in full; no other prior FXB audit was available locally.
- **Dormancy.** All 5 auctions are stopped/expired with zero balances; the only material live exposure is the ~6.05M FRAX in unmatured FXB_20261231, whose code is the simplest in the system (fixed 1:1, no roles, no upgrade).

## Artifacts

- This report: `REPORT-fxb.md` · Joined scan report: `artifacts-fxb/scan-report.json`
- Phase 0: `exclusions/EXCLUSION_LIST_FXB.md` · `ONCHAIN-GROUNDWORK-FXB.md` · `fxb-addresses.json` · `CORRESPONDENCE-FXB.md` · `sourcify-fxb/` (36 records) · `poc-smoke-fxb/` · `work/v1-live/` (extracted live v1 sources)
- Triage/recon: `artifacts-fxb/triage.json`, `retrieval-plan.json`, `recon.json`
- Hunter: `artifacts-fxb/hunter-findings-{A,B,C,D}.json` (all `[]`) · `nonqualifying-{A,B,C,D}.md` (88 observations)
- Skeptic/Referee: `artifacts-fxb/skeptic-{A,B,C,D}.json`, `referee-{A,B,C,D}.json` (all `[]` — no findings to review)
- No `findings/` files and no `poc-fxb*/` PoC were created: zero candidates, nothing filed, no gist, no contact.
