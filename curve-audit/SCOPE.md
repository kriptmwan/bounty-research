# Curve Bug-Bounty — Audit Scope Preparation

**Date:** 2026-11-13 (ordered "Gas" 13:28 WIB, in reply to "Mau saya siapkan scope-nya?")
**Status:** SCOPING ONLY. No vulnerability hunting was performed, no audit started, nothing installed, nothing run.
**Next step:** user picks a scope → audit is a SEPARATE order (toolchain install is also a separate order).

## Program recap (verified from docs.curve.finance)

- **Payout matrix** (likelihood × severity): Almost Certain $10k / $50k / **$250k**; Possible $1k / $10k / $50k; Unlikely $250 / $1k / $5k.
- **Scope:** issues leading to substantial loss of money, broken liveness, or irreversible loss of funds.
- **Reporting:** email + responsible disclosure (reasonable fix time before any disclosure).
- **Exclusions:** already-known vulnerabilities; frontend-only issues.
- **Eligibility:** first reporter; must verify a signature from the same address; enough information.
- Code fully public (Vyper + a little Solidity), under github.com/curvefi. There is NO `curve-contracts` repo anymore — the codebase was split into per-product repos (verified: API 404).

## Repo map (cloned shallow, HEADs verified 2026-11-13)

| Repo | HEAD | Date | Language / Vyper | Core LOC* | Commits last 6mo† | Notes |
|---|---|---|---|---|---|---|
| curve-stablecoin | `81b3bea` | 2026-11-12 | Vyper 0.4.3 (pin), legacy files 0.3.10 | 21,107 | 300+ | crvUSD + LlamaLend v1/v2 + oracles + policies + zaps. Hottest repo. |
| stableswap-ng | `3332cd4` | 2026-10-08 | Vyper 0.4.3 | 7,778 | 18 | StableSwap NG pools + factory + NEW LP oracle (2026). |
| tricrypto-ng | `ecaa816` | 2026-03-20 | Vyper 0.3.10 | 7,906 | 0 | Dormant. Math frozen. |
| twocrypto-ng | `89c8dfb` | 2026-11-05 | Vyper 0.3.10 | 4,262 | 1 | Near-dormant. |
| curve-core | `4e4b53f` | 2026-09-21 | Vyper (mixed) | 23,968 | 77‡ | Vendored copies of pool code + gauge/governance/registries. ‡All recent commits are RPC/explorer/deployment config chores — 0 contract-path commits. |
| scrvusd | `95a1208` | 2024-12-13 | Vyper | 3,247 | 0 | Savings-crvUSD. Unchanged since its Dec 2024 audit. |
| curve-xchain-factory | `8e95722` | 2025-04-18 | Vyper | 2,808 | 0 | Cross-chain gauge factories + bridgers. Quiet. |
| curve_gauge_factory | `7abc476` | 2026-07-07 | Vyper | 1,040 | 14 | Gauge factory. Small. |
| curve-router-ng | `2d49362` | 2026-08-17 | Vyper | 2,908 | 3 | Router. Quiet. |

\* Core LOC = `.vy` lines excluding tests/mocks/old/experimental/zksync/testing dirs (curve-core figure includes its vendored pool copies).
† Commits since 2026-05-13 via GitHub API (curve-stablecoin hit the 300-commit pagination cap — actual count is higher).

Not in the map: `curve-frontend`/`curve-js` (frontend — EXCLUDED from bounty), `docs`, dashboards, subgraphs, `fast-bridge` (audited by ChainSecurity; small, quiet), Stellar deployment (non-EVM, separate codebase — out of fit, FXSwap audit still pending per Curve's own announcement).

## Audit history (Curve docs security page + dated sources)

| Scope | Auditor | Date | Source |
|---|---|---|---|
| Curve DAO contracts | Trail of Bits | 10 Jul 2020 | Docs + press |
| Curve DAO / voting | MixBytes, Quantstamp | (undated on page) | Docs security page |
| FeeSplitter.vy, cross-chain governance | ChainSecurity | (undated on page) | Docs security page |
| Metapools | Quantstamp | (undated on page) | Docs security page |
| ETH/sETH pool | ChainSecurity | 27 Sep 2021 | Docs source markdown |
| Stableswap-NG | MixBytes | 27 Sep 2021 | Docs source markdown |
| Tricrypto, Tricrypto-NG, Twocrypto | ChainSecurity | (undated on page) | Docs security page |
| FastBridge (cross-chain crvUSD) | ChainSecurity | (undated on page) | Docs security page |
| crvUSD infrastructure | MixBytes | 5 Jun 2023 | Docs source markdown |
| crvUSD infrastructure | ChainSecurity | 24 Jan 2024 | Docs source markdown |
| crvUSD infrastructure (incl. lending v1 reviews) | ChainSecurity | 21 Feb 2025 | Docs source markdown |
| PegKeeperV2 | ChainSecurity | 12 Dec 2023 | Docs source markdown |
| Curve Lending (v1) | StateMind | 2 Feb 2024 | Docs source markdown |
| Curve Lending (v1) | MixBytes | Feb–Jul 2024 | Risk-report read of source |
| Savings-crvUSD (scrvUSD) | ChainSecurity | 3 Dec 2024 | Docs source markdown |
| **LlamaLend v2 (LendController/Vault/LendFactory/AMM/controller)** | **ChainSecurity** | **H1 2026 (before Jun 2026 Optimism launch; ETH mainnet 13 Aug 2026)** | H1 2026 progress report + press; report NOT on Curve's public audit page as of 7 Nov 2026; remediation commits tagged `CS-CURVE-LLV2-xxx` still landing in the repo |

**Audit gaps found (no audit located):** Lending Owner Proxy (`factory/OwnerProxy.vy`, now admin of both lending books + ControllerFactory per DAO vote 1510); `price_oracles/v2` adapters and `mpolicies/v2` rate calculators (all 2026 additions); `TransientLeverageZap` (2026); StableSwap NG LP oracle (2026); cross-chain governance adapters (per H1 2026 report: "await audit", production targeted late Q3/Q4 2026).

## Known incidents (EXCLUDED from rewards — do not re-report)

- **Jul 2023 Vyper compiler bug** (reentrancy locks ineffective in Vyper 0.2.15/0.3.0/0.3.1): ~$52M stolen across pools. Compiler-level, long patched.
- **Mar 2026 sDOLA oracle attack:** oracle manipulation liquidated all 27 positions in the sDOLA-long2 LlamaLend market (~822,475 crvUSD equity loss). Root cause was a per-market oracle helper OUTSIDE the audited core — the pattern that makes oracle adapters the highest-yield target class.
- **Oct 2025 CRV-long bad debt:** lenders unable to withdraw in full since Oct 2025 (market/utilization issue, still open per Nov 2026 reporting) — market-risk, not a code finding.
- Resupply's Jun 2025 $9.6M donation-attack loss is a SEPARATE protocol, not Curve.

## Churn inside curve-stablecoin (commits since 2026-05-13, per path)

| Module | Commits | Character of recent work |
|---|---|---|
| `price_oracles/v2` | 42 | NEW adapters: wstGBP FX pricing, Chainlink EMA adapters, NAV readers — new collateral pricing paths |
| `zaps` | 22 | NEW TransientLeverageZap (transient-storage leverage zap) + LeverageZap hardening (approval revoke, dust cleaning) |
| `mpolicies/v2` | 14 | NEW HyperbolicMP / HyperbolicDynamicMP + per-asset rate calculators (wstETH, syrupUSDC, sDOLA, sfrxUSD) |
| `lm_callback` | 13 | Liquidity-mining callback changes |
| `controller.vy` | 12 | Controller changes (post-audit delta) |
| `lending` | 11 | ChainSecurity LLV2 remediation (`CS-CURVE-LLV2-xxx` fixes) + Configurator getter |
| `AMM.vy` | 5 | Small delta |
| `stabilizer`, `flashloan`, `factory` | 0 | Quiet — PegKeeperV2/flashloan/factory code unchanged in 6 months |

## Value at risk (context, Nov 2026)

- Curve DEX TVL ≈ **$1.2B** (DefiLlama, verified 2026-11-13: Ethereum ~$983M + staking ~$193M + other chains). Note: DEX pools are largely immutable once deployed — new findings apply to future deployments/factories more than live pools.
- LlamaLend v2 deposits **$34.37M** (risk report, 7 Nov 2026). v1 markets being phased out.
- crvUSD supply: not verified from a primary source in this pass (DefiLlama stablecoin endpoint 404'd on the slug tried); Nov 2026 risk reporting describes supply shrinking ~$50M as PegKeepers unwound to zero. Treat as order-of-$100M, unverified.

## Ranked scope options

### Option 1 (RECOMMENDED) — LlamaLend v2 periphery: new oracles + rate policies + transient zaps + owner proxy

- **Paths** (`curve-stablecoin`, HEAD `81b3bea`): `curve_stablecoin/price_oracles/v2/**`, `curve_stablecoin/mpolicies/v2/**`, `curve_stablecoin/zaps/transient_leverage_zap/**`, `curve_stablecoin/factory/OwnerProxy.vy`, `curve_stablecoin/Configurator.vy`, `curve_stablecoin/ControllerView.vy`. Lending core (`lending/`, `AMM.vy`, `controller.vy`) as read-only context — already ChainSecurity-audited, do not duplicate that audit.
- **Size:** ~3,850 LOC in scope (oracles v2 + policies v2 = 1,870; transient zaps = 757; OwnerProxy 337 + Configurator 281 + ControllerView 598).
- **Language/version:** Vyper 0.4.3 (repo pin; new files carry no `@version` pragma).
- **Last audit:** none found for these files. Core audited by ChainSecurity H1 2026 (report unpublished; remediation still landing). Owner Proxy: no audit found (flagged by independent risk reporting).
- **Recent activity:** heaviest churn in the org (42 + 14 + 22 commits in 6 months) — all 2026-new code.
- **Why:** (1) Newest, least-reviewed code holding real money ($34.37M v2 deposits + every market using these oracles). (2) Oracle/rate paths are Curve's proven loss vector (Mar 2026 sDOLA attack was exactly this class: a per-market oracle helper). (3) Admin proxy is single-point-of-control over both lending books — access-control findings here are High-shaped. (4) Bounded size, single repo, single toolchain.
- **Estimated effort:** medium — 2–4 days adversarial review (Hunter→Skeptic→Referee) + titanoboa POCs for survivors.
- **Testing needs:** static review first; POCs via titanoboa (local, no fork needed for most paths). Oracle-adapter POCs may want forked mainnet state for Chainlink/pool reads — read-only fork via public RPC, no transactions.

### Option 2 — crvUSD core second look: LLAMMA + controller + PegKeeper + flashloan

- **Paths** (`curve-stablecoin`): `curve_stablecoin/AMM.vy` (1,691), `controller.vy` (1,598), `Stablecoin.vy` (316), `stabilizer/**` (1,533), `flashloan/**` (93), `lm_callback/**` (572).
- **Size:** ~5,800 LOC.
- **Language/version:** mixed Vyper 0.3.10 (stabilizer) + 0.4.3 (core) — two compiler versions needed.
- **Last audit:** MixBytes Jun 2023; ChainSecurity Jan 2024 and Feb 2025; PegKeeperV2 ChainSecurity Dec 2023. The Feb 2025 ChainSecurity report is the freshest full-core review.
- **Recent activity:** low (AMM 5, controller 12, stabilizer/flashloan 0 commits in 6 months) — mostly stable, with a small post-audit delta to diff.
- **Why:** the heart of crvUSD; any finding here is maximum-severity-shaped. Best framed as a post-audit-delta review: diff the 12 controller + 13 lm_callback commits since the last audit, plus a deep invariant review of LLAMMA band math.
- **Honest downside:** lowest expected yield of NEW findings — three professional audits + 3 years of production. Most likely outcome is confirmation, not a payout.
- **Estimated effort:** large — 4–6 days (LLAMMA math is the hardest code in the org to review well).
- **Testing needs:** titanoboa POCs; LLAMMA invariant checks benefit from property-style tests; fork testing optional.

### Option 3 — StableSwap-NG LP oracle + factory delta

- **Paths** (`stableswap-ng`, HEAD `3332cd4`): `contracts/main/StableSwapNGLPOracle.vy` (132, NEW 2026), `contracts/main/CurveStableSwapFactoryNG.vy` + `CurveStableSwapFactoryNGHandler.vy`, plus `curve-stablecoin` `price_oracles/lp-oracles/**` (273) and `price_oracles/StableSwapNGAdapter.vy`. Pool math (`CurveStableSwapNG.vy`, `CurveStableSwapNGMath.vy`, ~7.6k LOC total in `contracts/main`) as read-only context.
- **Size:** ~400 LOC primary (oracles) + factory/handler; ~7.6k LOC context.
- **Language/version:** Vyper 0.4.3.
- **Last audit:** MixBytes Stableswap-NG (Sep 2021) for the pool; the LP oracle is new 2026 code with no audit found (landed via PR #67 `feat/lp-oracle`).
- **Recent activity:** 18 commits in 6 months, dominated by the LP-oracle feature + chores.
- **Why:** smallest, most bounded scope; the oracle feeds lending/valuation decisions (mispricing = fund-loss-shaped); factory/handler code governs all future NG pool deployments on the $1.2B DEX. Good starter scope if Option 1 feels too broad.
- **Honest downside:** the oracle itself is only 132 lines — a thin target; most of the value is in how consumers (lending oracles, adapters) trust its output, which overlaps Option 1.
- **Estimated effort:** small-medium — 2–3 days including consumer-trust review.
- **Testing needs:** titanoboa POCs; LP-oracle correctness checks need pool-state fixtures (local deploy or fork read).

## NOT recommended

- **tricrypto-ng / twocrypto-ng:** dormant (0–1 commits/6mo), ChainSecurity-audited, math frozen. Re-review has minimal expected yield.
- **scrvusd:** unchanged since Dec 2024, ChainSecurity-audited. Nothing new to find.
- **curve-core (as a whole):** mostly vendored copies of the -ng pool implementations — auditing it duplicates Options 2–3. Its unique parts (governance relayers 615 LOC, registries 2,360, gauge 3,083, helpers 1,693) had ZERO contract commits in 6 months and sit under the DAO/governance audits; consider only as a follow-up scope.
- **curve_gauge_factory / curve-xchain-factory / curve-router-ng:** small, quiet, gauge/router infra already covered by DAO + cross-chain audits.
- **Stellar deployment:** non-EVM codebase, different language/toolchain, FXSwap audit pending — wrong fit for this workflow.
- **Frontend (curve-frontend, curve-js):** explicitly EXCLUDED from the bounty.

## Toolchain gaps (this VM, verified 2026-11-13)

- **vyper: ABSENT.** Needed: **0.4.3** (curve-stablecoin, stableswap-ng, all 2026-new code) AND **0.3.10** (twocrypto-ng, tricrypto-ng, legacy files incl. stabilizer). Mixed-version environment required for Option 2; Option 1/3 need 0.4.3 only.
- **titanoboa: ABSENT.** Needed at repo-pinned git revs (curve-stablecoin pins `ed81f209`; twocrypto-ng pins `40e85c60`; stableswap-ng needs `>=0.2.8` + `titanoboa-zksync`). Titanoboa is the test/POC harness — no POCs possible without it.
- **forge/cast/solc: ABSENT** (forge is being installed for the separate Plether sprint; irrelevant for Vyper except `boa-solidity` interop in curve-stablecoin's dev deps).
- **No installs were made** (per task boundaries). Installing vyper + titanoboa needs a separate user order.
- **Fork testing:** titanoboa supports fork mode; public Ethereum RPC reads are feasible for oracle/pool-state fixtures. No transactions, no mainnet testing — local/fork only, per responsible disclosure.

## Suggested audit workflow (when ordered)

1. Install toolchain (separate order): vyper 0.4.3 (+ 0.3.10 if Option 2), titanoboa at the repo's pinned rev, project dev deps via `uv`.
2. Read the exclusion set FIRST: the ChainSecurity Feb 2025 crvUSD report + StateMind lending report + all `CS-CURVE-LLV2-xxx` remediation commits (these are known issues — re-reporting them pays $0).
3. Adversarial pipeline (adversarial_code_audit + triage_validation skills): Hunter → Skeptic → Referee, fail-closed; every surviving finding needs a runnable titanoboa POC.
4. Filing (separate order): email report + signature verification from the reporting address + POC. No filing without an explicit order.
