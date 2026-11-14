# Relay Bug Bounty — Scoping Report

**Date:** 2026-11-13 (WIB). **Scope of this document:** read-only scoping only. No testing, no accounts, no emails, no filing. No code was run against live chains; no exploit/POC code was copied anywhere.
**Program:** Relay bug bounty — https://docs.relay.link/security/bounties (page re-verified 2026-11-13, "Updated: 2026-10-19T18:39:13.879Z").

---

## 1. Public code (GitHub org `relayprotocol`)

Clones live in `~/workspace/relay-audit/repos/` (git protocol only; zero GitHub REST API calls — the API was rate-limited on this VM's shared egress IP earlier in the day). All repos default branch `main`.

| Repo | HEAD (full hash) | HEAD date | HEAD subject | License | Status |
|---|---|---|---|---|---|
| relay-settlement | `b2f3e0e5fba9381293f030ef340ffb4872687fcf` | 2026-09-11 | chore: publish v0.0.7 | SPDX MIT in sources; no root LICENSE file | **Canonical settlement monorepo** |
| relay-protocol-oracle | `55b22de6358c212c22eebb48d2df5b793a16e863` | 2026-08-12 | chore: publish v0.0.6 | MIT (package.json); no root LICENSE | Off-chain oracle service (TypeScript) |
| relay-depository | `458a64c310a3504aaf37e112af9a8707c9eb11ad` | 2026-08-13 | feat: remove rari chain (#49) | SPDX MIT in sources; no root LICENSE | **ARCHIVED** — README says content merged into settlement-protocol (i.e. relay-settlement) |
| relay-periphery | `e221935f54df03f9f73f2645ff688370a87033d8` | 2026-11-09 | fix: sweep ERC20 residue … (DEC-2400) (#77) | SPDX MIT in sources; no root LICENSE | Router / ApprovalProxy / Receiver (Foundry) |
| relay-docs | `edde88b279ceebcefde9abb58d2f54b35521f5c1` | 2026-11-12 | docs(deposit-addresses)… #545 | n/a (docs) | Source of docs.relay.link |
| relay-vaults | `70f7864865f3a61a24002ec002d399e4e1e4d8c1` | 2026-09-28 | final snapshot + archive notice | AGPLv3 | **OUT OF BOUNTY SCOPE** (winding down; LPs withdraw until 2026-12-31) |

**"settlement-protocol" as a literal repo name does not exist** (`git ls-remote` fails; retried 2026-11-13). The docs use it as a display name linking to `relay-settlement` (proven by grep: `allocator.mdx:122`, `hub.mdx:83`, `oracle.mdx:101`, `security.mdx:77`). Also probed and nonexistent/private: `settlement`, `relay-chain`, `relay-hub`, `relay-oracle`, `oracle`, `relay-solver`, `relay-sdk`, `sdk`, `core`, `protocol`, `depository`, `periphery`, `relay-link`, `relay`, `vaults`, `relay-protocol`, `relay-contracts`. The org profile page still says Relay Hub / Relay Allocator "To be announced..." — stale; the code IS in relay-settlement.

### 1a. In-scope code inventory (measured 2026-11-13)

**relay-settlement `smart-contracts/contracts/` — 14,645 LOC** (Solidity, solc 0.8.28, Foundry, optimizer 200 runs; excludes mocks/test-utils; `packages/abis` mirrors contracts via symlinks — counted once). Largest files:

| File | LOC | File | LOC |
|---|---|---|---|
| BitcoinVmPayloadBuilder.sol | 812 | RelayOracleV2.sol | 457 |
| RelayPriceOracle.sol | 772 | RelayAllocator.sol | 410 |
| RelayFundingPool.sol | 725 | RelayExecutor.sol | 401 |
| HederaVmPayloadBuilder.sol | 589 | PoolResolverBase.sol | 501 |
| RelayHub.sol (ERC-6909) | 555 | TonVmPayloadBuilder.sol | 471 |
| HyperliquidVmPayloadBuilder.sol | 521 | + others (rate limiter, fee calculator, deposit-address manager, multisig, idempotency store, more payload builders) | ~rest |

Raw `.sol` total incl. tests/scripts/mirrors: 43,969 lines.

**Depositories (EVM):** relay-settlement `packages/depository/packages/ethereum-vm/src/` = **743 LOC** (`RelayDepository.sol` 271 + `RelayGatewayDepository.sol` 424 + structs 48). Standalone relay-depository src = 313 LOC. The two `RelayDepository.sol` copies differ formatting-only plus one slither-disable comment (whitespace-insensitive diff verified); structs identical. Canonical = relay-settlement copy.

**Depositories (non-EVM):** Solana Rust 2,094 LOC (3 programs incl. deposit-address) in relay-settlement; 1,329 LOC (2 programs) in the archived relay-depository copy. Sui Move `escrow.move` 284 LOC (archived repo only — no sui-vm package in relay-settlement). TON FunC `relay_escrow.fc` 1,236 LOC incl. stdlib import (archived repo only).

**relay-periphery `src/` — 2,004 LOC** (Solidity, solc 0.8.28, via_ir): `RelayApprovalProxy.sol` 699, `RelayRouter.sol` 457, `RelayRouter_NonTstore.sol` 462, `RelayReceiver.sol` 80, rest common/interfaces. Router `VERSION = "3.2"`, ApprovalProxy `VERSION = "3.1"`. Router 3.2 built with optimizer_runs 1,000,000; 3.0/3.1 at default 200 runs. Foundry tests present.

**relay-protocol-oracle `src/` — 18,129 LOC** TypeScript (69 files), Dockerized HTTP service, zero `.sol` files.

### 1b. Architecture split: old vs current

- **Old model (still live on destination chains):** per-chain `RelayDepository` (holds user deposits, executes allocator-signed `CallRequest`s) + `RelayRouter`/`RelayApprovalProxy` periphery (user-facing entry points that pull funds and multicall). Depositories are non-upgradable; single allocator path; no admin withdrawal (docs `security.mdx`).
- **Current model (Relay Chain, chain ID 537713):** `RelayHub` (ERC-6909 balances per chain/token) ← `RelayOracleV2` (thin verification layer trusting a configured signer: EOA or EIP-1271 `RelayOracleMultisig`) ← off-chain oracle service (attests deposits) → `RelayExecutor` → `RelayAllocator` (+ MPC chain signatures via NEAR, Security Council governed, replay-protected) → VM payload builders → Lit/multisig signer → destination depository. Plus `RelayPriceOracle`, `RelayFundingPool`, deposit-address manager, rate limiters, fee calculators.
- **Gap:** `RelayAllocatorSpender` — described in docs as the current production withdrawal gate on Aurora (oracle-gated, balance-bounded) — has **zero hits (no file, no reference) in any cloned repo**. Its source is not public in these repos; it cannot be audited from public code.
- Flow per settlement README: Depository → oracle → RelayOracleV2 + RelayHub → RelayExecutor → RelayAllocator → VM payload builder → Lit/multisig signer → destination depository.

---

## 2. Deployments (from official docs + repo deployment files; NO chain reads performed)

### Relay Chain (chain ID 537713) — docs `addresses.mdx`
- Hub: `0xDDD361727C22A01EB137880678A20b0BEaE69318`
- Oracle: `0xd4b9fdB83C723c096d7fBE72da252aa23f1387aa`

### Aurora — docs `addresses.mdx`
- Allocator: `0x7EdA04920F22ba6A2b9f2573fd9a6F6F1946Ff9f`
- Security Council multisig: `0xb538ee6515F9d16eBD0BACD0503733815c9b070c`

### relay-settlement `smart-contracts/deployments/contracts/prod.json` (chainId 537713)
- hub `0xddd361727c22a01eb137880678a20b0beae69318` — **matches docs**.
- oracle `0xd180dc3b8cb71b185c563b6e4857592ca93dacaf`, oracleMultisig `0x2a72eb8cf0233a3dc6198683c83b1078de6fa2b0`
- allocator `0x613d3c588f6b8f89302b463f8f19f7241b2857e2`, executor `0x6747c7e64b90dccc0d54f865cbd9513156adbc0c`
- + config, withdrawGasPayer, protocolSafe, feeCalculator (bps), rateLimiter (usd), 10 payload builders, depositAddressManager, pricing-oracle set (stork adapter, priceOracle, signedPricingOracle), uniswap set, utils, safe set, multicallRouters `0xab86c681c081c9125be8ef3af374d3b409e4484f` (same address across listed chains).

**UNRESOLVED DISCREPANCY — do not pick one side:** docs Oracle `0xd4b9fdB8…` ≠ prod.json oracle `0xd180dc3b…`; docs Aurora Allocator `0x7EdA0492…` ≠ prod.json allocator `0x613d3c58…`. May be different contracts (e.g. RelayAllocatorSpender on Aurora vs RelayAllocator on Relay Chain) or stale records. Component `.mdx` pages contain no hardcoded addresses. Staging/test/dev deployment files differ again. **An audit must resolve which addresses are live before asserting impact.**

### Depositories — Chains API `https://api.relay.link/chains` (fetched 2026-11-13, 58 chains; docs `addresses.mdx` live-fetches this same API, no static list)
- Canonical EVM depository `0x4cd00e387622c35bddb9b4c962c136462338bc31` (CREATE2): **45 chains**.
- Variant `0x59916da825d2d2ec1bf878d71c88826f6633ecca`: cronos, metis, mantle, linea (4 chains).
- Hyperliquid: `0x66cf0aace1b4e562593bec10ec7868fba9932224`.
- Non-EVM: solana + eclipse `99vQwtBwYtrqqD9YSXbdum3KBdxPAVxYTaQ3cfnJSrN2` (+ depositoryVault), ton `EQCrdGsDTqA2t6xRR4N6V4J705F7w_VQbUdHnofsh-8lVIPs`, tron `TXtEs6t2oUWQsNos7m68gbHdE9Q5n6x2oN`, xrp `rJBdWA9p5KwBoqSQTyMdg3UHLsJVzGVu5m`, bitcoin `bc1qzmtn0q92ayejt2hpffvlktcpmyy7vvsd06sefu`, lighter `731033`, robinhood-lighter `33627`.

### Periphery — `deployments/v3/addresses.json` (84 chains)
- Router: `0x0729e2a4716d9f7dd17858d5d504426d228697f7` (48 chains, optimizerRuns 1,000,000 = v3.2), `0xB92fe925dc43a0ecde6c8b1a2709c170ec4fff4f` (22 chains, no optimizerRuns field = 200 runs = v3.0/3.1), `0xe6b730e58088884704cdf11cbe95c224d4d34154` (7). NonTstore router: `0x6328ea02d28131e58b28e55c6258258a30d90e05` (5) + 2 singletons.
- ApprovalProxy: `0x5567954cd026cebfe486062cb75848e0f1c12e58` (48), `0xccc88a9d1b4ed6b0eaba998850414b24f1c315be` (22), `0xe4dfbd5e6784db1058124e2c87554c0591f0fb7b` (5), `0x5a0fa369d634f49c76b08dc6c299800c1a2af977` (7) + 2 singletons.
- Canonical proxy owner `0x463cB782c8dd0a1887b77336DfF74D60F006F56E` (CREATE2 input). Proxy "stays at 3.1, no code change" but was redeployed at a new address because the router address is a constructor arg in the CREATE2 input (per `instructions.md`). Router 3.2 changes the `SolverCallExecuted` event (dataHash instead of calldata) — the oracle must decode both shapes first.
- **Unverified:** deployed-bytecode equivalence between these addresses and the cloned source was NOT checked (no chain reads in scoping). Any audit must verify bytecode matches the pinned source before claiming a finding affects a live deployment.

---

## 3. Audit history = EXCLUSION LIST

All reports below were read from PDFs inside the official org repos (`relay-settlement/docs/audits/`, `relay-depository/audit-reports/`, `relay-docs`). The `relayybridge.com` mirror was NOT used. The audits index `relay-settlement/docs/audits/README.md` warns each report covers ONLY the listed commits/files.

### 3.1 Cantina Managed 0203 — Apr 25, 2025 (review Feb 4–13, 2025; Kaden + Sujith Somraaj)
Scope: relay-monorepo @ `2981c5e1`. **31 issues: 1 Critical / 4 High / 9 Medium / 7 Low / 3 Gas / 7 Info** (27 fixed, 4 acknowledged). Mostly Vaults (RelayPool/Bridge/TokenSwap — OUT of bounty scope). In-scope-adjacent exclusions:
- 3.3.5 CallRequest hashing not EIP712 compliant (Medium, fixed)
- 3.3.6 Malicious solver can steal funds in permit2TransferAndMulticall (Medium, fixed)
- 3.4.5 CallRequest digests same across accounts → DoS (Low)
- 3.6.5 ETH may be accidentally refunded to the ApprovalProxy (Info)

### 3.2 Cantina re-review 0310 — Apr 22, 2025 (Sujith Somraaj)
**VAULTS-ONLY** (RelayPool/BridgeProxy/TokenSwap) — entirely OUT of bounty scope. 1 Critical (fixed), 1 High (fixed), 4 Medium (3 fixed, 1 ack), 4 Low, 1 Gas, 18 Info (16 fixed, 2 ack).
**Docs discrepancy (record plainly):** `security.mdx` labels this row "February 2025 | Relay Depository (EVM) | Spearbit" but the linked PDF is a Cantina Managed review dated April 22, 2025 covering Vaults contracts. No Spearbit report was found in any cloned repo.

### 3.3 Certora — Relay Depository/Escrow, June 6–13, 2025 (commit `91b182a`)
Scope: **Solana only** — `relay-escrow` + `relay-forwarder` `lib.rs`. 9 findings, ALL Fixed:
- C-01 anyone can initialize escrow / become owner-allocator (Critical); C-02 transfer recipient changeable → complete drainage (Critical); H-01 signer mistaken for forwarder (High); M-01 no Token2022 support; M-02 arbitrary vault token account → fake deposits; L-01 token rent stealable; L-02 vault auto-closure blocks transfers; I-01 hard-coded space calculation; I-02 missing PDA constraints.
- PDF md5 `5daf5915f4c4ab9efba4d47975de698a` identical in all 3 repo locations.

### 3.4 Zellic — Settlement Protocol, Nov 21, 2025 (PDF created Jan 12, 2026; 4 person-weeks, 3 consultants)
Scope: relay-depository @ `aec671d3e3e7b72135cf2d570eb6cc59e757908b` (ethereum-vm.sol, solana-vm relay-depository + relay-forwarder.rs, sui-vm.move, ton-vm.fc) + "decentralized-protocol" (old repo name) @ `15ba05ba0ae1e65e1d72c4ddeb18312568802f45` (ChainSignatures, RelayAllocator, Utils, PayloadBuilders Bitcoin/EVM/Solana/Sui/Hyperliquid, RelayMultisigSigner).
Report summary counts: **1 critical / 2 high / 5 medium / 2 low / 1 informational**. NOTE: the body's "Severity" column values do not reconcile with the summary counts (3.1/3.2/3.3 all show Severity Critical in layout; 3.2 is marked out-of-scope with Impact Informational). Per-finding Likelihood/Impact as printed:

| # | Title | Likelihood / Impact | Status |
|---|---|---|---|
| 3.1 | Domain separator missing in Solana relay depository | Medium / Critical | Fixes PRs #32/#33/#203 |
| 3.2 | RelayHub allows arbitrary token transfers | High / Informational | OUT OF SCOPE note; fix PR #171 |
| 3.3 | Critical variables not signed in signWithdrawPayloadHash | High / High | **Acknowledged ONLY, no fix** |
| 3.4 | DoS by parking nonces | High / High | PR #173 |
| 3.5 | DoS by pushing signature time into future | High / Medium | PR #174 |
| 3.6 | Missing nonce lifetime validation for Hyperliquid withdrawals | Low / Medium | PR #186 |
| 3.7 | ECDSA signature replay, RelayMultisigSigner | Low / Medium | PR #176 |
| 3.8 | Withdrawer may create multiple signatures for one withdrawal | Low / Low | PR #198 |
| 3.9 | Insufficient test coverage | N/A / Medium | Acknowledged only |
| 3.10 | Block producers may reassign deposit credit, RelayDepository | Low / Low | Acknowledged only |
| 3.11 | Missing commitments to chain/contract may allow replay, TON relay_escrow.fc | Low / Medium | PR #35 |

Discussion 4.1–4.4 (address(0) check for payload builder; TON escrow practices/ordering/features). PR numbers' repos ambiguous as printed. Zellic: "additional review would be beneficial."
**NOT in this audit's scope list:** RelayOracleV2, RelayExecutor, RelayPriceOracle, funding pools, deposit addresses, ERC20View (except via 3.2), rate limiters, fee calculators — key fresh-angle note.

### 3.5 Zellic — Oracle (Web Application Security Assessment), Apr 15, 2026
Scope: relay-protocol-oracle @ `7dbe806a9ee9bbc0f32df8bc7e0b6da1de253799` (commit dated 2026-03-11), `src/**/*.ts`. **10 findings**; text counts 2 critical / 3 high / 3 medium / 1 low (= 9 categorized; the 10th is 3.10 Severity Indeterminate — note the arithmetic):

| # | Title | Severity | Status |
|---|---|---|---|
| 3.1 | Solana/Sui attestors attest reverted deposit txs | Critical (High/Critical) | Fix commit `7f973aa8` |
| 3.2 | Sui attestor does not check DepositEvent origin | Critical (High/Critical) | **Acknowledged only** |
| 3.3 | Too short finalization window, Ethereum/Bitcoin attestors | High (Medium/High) | Multi-commit fix |
| 3.4 | Ethereum/Tron/Bitcoin attestors do not ensure finalization in getDepositoryWithdrawalMessage | High (Medium/High) | Multi-commit fix |
| 3.5 | Multiple attestors incorrectly check orderId in getSolverPaidAmount, Lighter/Hyperliquid | High (Medium/High) | Multi-commit fix |
| 3.6 | Sui attestor does not check origin/sender of MemoEvent | High (Low/Medium) | **Acknowledged only** |
| 3.7 | verifySolverCalls does not check call order | Medium | Fix `6fa5e950` |
| 3.8 | Sui attestor mishandles multiple deposits in one tx | Medium | **Acknowledged only** |
| 3.9 | Loss of precision via mishandled currency type, Hyperliquid | Low | Fix `870f0989` |
| 3.10 | Bitcoin attestor does not check withdrawal amount/address | Indeterminate | **Acknowledged only** |

Multi-commit fix hashes seen (per-finding mapping not fully pinned): `18a05acf`, `c52198f1`, `35ad4cde`, `ea8f995c`, `f76e7af0`, `6ec03874`, `8eb24981`, `5395289f`. Discussion 4.1–4.2 (ERC-20 compatibility; order-ID heuristic false positives → temporary fund lock). Zellic recommended a comprehensive reassessment after remediation (recurring attestation patterns).

### 3.6 Coverage check — periphery
Grep across all four non-Cantina texts: ZERO mentions of RelayRouter/ApprovalProxy in Zellic Settlement, Zellic Oracle, Certora, or Cantina re-review. Cantina 0203 has 8 mentions (the findings in §3.1). **Current periphery code (Router 3.2 / Proxy 3.1) has NO dedicated audit** — fresh-angle note, with the Feb 2025 Cantina partial coverage as exclusion. No other audits/competitions were found in the cloned repos or docs.

### 3.7 Acknowledged-only findings — handling rule for any audit
Zellic 3.3/3.9/3.10 (Settlement) and 3.2/3.6/3.8/3.10 (Oracle) were acknowledged without a fix. Acknowledged ≠ eligible: re-reporting the same root cause is a known issue under the bounty terms. They are worth re-checking ONLY for genuinely new root causes or variants that the original finding did not cover, with the prior finding cited and distinguished.

---

## 4. Public issue: relayprotocol/relay-settlement #2 (opened 2026-07-23, by yossweh)

**Titles ONLY — no exploit/POC code was copied into the workspace or this document.** The issue claims 7 critical/high vulnerabilities. It is PUBLIC on GitHub (despite a "0-day — No public disclosure" header in its body) → known/disclosed → EXCLUDED under the bounty duplicate/known-issue rules regardless of merit.

| Claim | Title (as claimed) | Affected (as claimed) |
|---|---|---|
| C-01 | Single EOA allocator key compromise → total TVL drain (Critical) | Allocator EOA `0x63C1d3E9C646184529C5694630a01C00dF171b56` |
| C-02 | Missing chainId in EIP-712 domain → cross-chain replay (Critical) | RelayDepository |
| C-03 | depositErc20 overload reads allowance at execution (Critical) | RelayDepository |
| C-04 | depositNative accepts arbitrary depositor (Critical) | RelayDepository |
| H-01 | Public cleanupErc20s/cleanupNative in Router (High) | RelayRouterV3 |
| H-02 | 5% app fee to single EOA (High) | Fee recipient EOA `0xa40402C86F4df5DF98302F9739723dc8B2E7c804` |
| H-03 | Solana/Tron/Bitcoin bridges off-chain trust only (High) | Non-EVM bridges |

Claimed contract addresses: RelayDepository `0x4cD00E387622C35bDDB9b4c962C136462338BC31`; RelayRouterV3 `0xB92fe925dc43a0ecde6c8b1a2709c170ec4fff4f`; RelayApprovalProxyV3 `0xccc88a9d1b4ed6b0eaba998850414b24f1c315be`.

### Match analysis (against evidence in §1–§2, not against the issue's own claims)
- **Depository address = live canonical address.** `0x4cd0…bc31` is the depository on 45 chains per the Chains API (§2). The claim targets a live deployment, not a dead one.
- **Router/Proxy addresses = older generation, still deployed.** `0xB92f…` / `0xccc8…` are the 200-run (v3.0/3.1) deployments still listed on 22 chains. Current source is newer (Router 3.2 on 48 chains; Proxy 3.1 redeployed). Version-level diff work would be needed to say whether each claimed bug exists in current code — that is audit work, not scoping — and any variant must be distinguished from the disclosed claims.
- **C-01 conflicts with current documented architecture** (MPC chain signatures, no single key holder, Security Council governance, RelayAllocatorSpender gating). Whether the claimed EOA is still the configured allocator on live depositories is UNVERIFIED (would need chain reads). Separately, "issues requiring … a compromised private key" are explicitly OUT of scope in the bounty terms — C-01 and H-02 fall in that category as framed.
- **C-02 is contradicted by current source:** `RelayDepository.sol` inherits Solady `EIP712` and hashes via `_hashTypedData` (domain separator binds chainId). Whether DEPLOYED bytecode matches current source is unverified. Thematically overlaps Cantina 3.3.5 (fixed) and Zellic 3.11.
- **C-03/C-04 overlap Zellic 3.10's root-cause family** (deposit-credit assignment / depositor attribution) — already known by root cause. Any new variant must be distinguished from both the issue and Zellic 3.10.
- **H-01 is documented intended behavior in current source:** `RelayRouter.sol` NatSpec states the `cleanup*` functions "are intentionally permissionless (they sweep stranded dust; there is nothing to steal in normal operation)". Intended behavior + publicly disclosed = excluded.
- **H-03 is a trust-model design statement** about off-chain/non-EVM components; no code-level root cause is asserted that a code audit could newly claim without distinguishing it from the disclosure.
- **Whole issue recorded as KNOWN/DISCLOSED (excluded).** Do not re-report any of the 7 claims. New work must cite the issue and distinguish any finding from it by root cause, affected version, and deployment.

---

## 5. Program terms (re-verified from the bounty page, 2026-11-13)

- **Submission:** FREE email to `support@relay.link`, one email per vulnerability, clear subject naming component + issue (example given: "Vulnerability report: Approval Proxy signature replay" — implies periphery is in scope). No platform, no fee, no sign-in. All material in the first email; report incomplete without required material. Ack aimed within 2 business days (receipt only); initial review update aimed within 7 calendar days of a complete report.
- **Payout matrix (S1–S4 × L1–L3), floor $500, cap $100,000, rounded to nearest $500:** S4: $100k/$50k/$20k; S3: $30k/$15k/$7.5k; S2: $10k/$5k/$2k; S1: $2k/$1k/$500. Modifiers ×0.5–×1.5 (unrecoverable ×1.5; hard to fix/detect ×1.25; expensive/pausable ×0.75; capped sub-pool ×0.5; stack multiplicatively). Worked examples given (flash-loan reentrancy $75k; fee drift $4k; pool freeze $22.5k).
- **Eligibility gate (strict):** the $500 floor applies ONLY when an external/unprivileged exploit path is demonstrated. NOT eligible: only-privileged-role path (owner/operator/solver/oracle) without showing an unprivileged party can reach the role or induce the privileged party; bugs that would not fire under normal operation. Admin-only bugs are S1 max regardless of damage. Freeze likelihood downgraded one tier (unless a step toward theft). Discretionary bonuses exist for strong write-ups / novel vectors / new evidence in duplicates — recognition, not entitlement.
- **PoC rules:** S4/S3 runnable PoC REQUIRED ("Explanations without code are not accepted"); S2 PoC strongly preferred; S1 description + repro steps sufficient.
- **Duplicates:** first submission gets full payout; duplicates not eligible for automatic reward (discretionary bonus possible for material new evidence). **Previously known:** only a dated internal record predating submission (ticket/triaged finding) counts; raw scanner output / untriaged notes do not. A report never loses value because Relay detected/triaged/fixed after submission.
- **Out of scope:** already-exploited attacks; phishing/social engineering/compromised private key; third-party protocol findings unless root cause is in Relay's code; DoS with no fund loss and no path to fund loss; theoretical issues with no viable PoC against in-scope assets; **Relay Vaults** (RelayPool, RelayBridge, RelayPoolFactory, RelayBridgeFactory, RelayPoolNativeGateway + vaults API + vaults UI).
- **Payout process:** KYC (+ background check) / KYB required, direct payment only to the verified reporter, tax docs (W-8BEN/W-9 or equivalent) requested AFTER reward approval — do not include with the initial report. Rewards paid in cryptocurrency. Relay may suspend/exclude participants at discretion (future participation only).
- **The docs do NOT state:** any in-scope asset/repo/contract list (the framework "applies across Relay's protocol and services" — no addresses, repos, or version pins on the bounty page); any safe-harbor or testing rules; any disclosure timeline / embargo terms; any testnet-vs-mainnet testing guidance; any SLA beyond the ack/review aims; any statement on whether the off-chain oracle service / APIs are in scope as "services" (the Zellic Oracle web assessment suggests the service is a security concern, but the bounty page never names it).

---

## 6. Fresh angle — post-audit delta

- **Oracle (measurable):** audit commit `7dbe806a` (2026-03-11) IS an ancestor of HEAD `55b22de` (2026-08-12). **137 commits after the audit commit, 93 touching `src/`** (repo total 556 commits). Real post-audit churn in the attestor code — but the same recurring attestation patterns Zellic flagged, so variants must be genuinely new.
- **Settlement (NOT measurable via git):** `relay-settlement` has only **8 commits in its entire history, all "chore: publish v0.0.x" squashes (2026-06-26 → 2026-09-11)**. It is a publish mirror, not a development repo. The Zellic audit commit `15ba05ba` (old "decentralized-protocol" repo name) does NOT exist in this repo's history — no ancestry link. Delta must be measured by comparing the audit's scope file list (Nov 2025) against the current tree (Sep 2026): the Relay Chain core (Hub, OracleV2, Executor, PriceOracle, funding pools, deposit addresses, rate limiters, fee calculators) is largely OUTSIDE the audit's scope list and postdates it in substance. Relay Chain was announced alongside the Series B in Jan 2026 (secondary source); the Hub/Oracle/Allocator code is the newest architecture in the repos.
- **Depository ancestry unverified:** the full-history fetch for `relay-depository` did not complete in ~10 minutes and was killed; whether audit commit `aec671d3` is an ancestor of HEAD `458a64c` (2026-08-13, archived repo) is unknown. Fallback: dates only (audit Nov 2025 vs HEAD Aug 2026). The repo is archived and its content is merged into relay-settlement, so this gap is low-impact.
- **Periphery (measurable, freshest):** 383 commits, HEAD 2026-11-09 (4 days before scoping), no dedicated audit of current code. Latest commit itself is a residue-sweep fix (DEC-2400) — active bug-fixing in exactly the funds-movement surface.
- **Unaudited / lightly-audited surfaces (highest value first):** (1) Relay Chain core — Hub, OracleV2, Executor, PriceOracle, funding pools, deposit addresses, rate limiters, fee calculators; (2) current periphery Router 3.2 / Proxy 3.1 (+ NonTstore variant, + Receiver); (3) Gateway depository variant (Circle Gateway integration — not named in any audit scope); (4) newer payload builders (TON, Tron, XRP, Lighter, Gateway, Hedera) vs the 5 builders Zellic listed; (5) oracle-service post-audit churn (137 commits); (6) Solana deposit-address program (newer than the Certora-covered escrow/forwarder).
- **Structural limits on any code-only audit:** the system's security rests heavily on off-chain components (oracle attestors, MPC/chain signatures, Lit/multisig signers, Security Council) whose code is partly absent (RelayAllocatorSpender) or off-chain; privileged-role findings cap at L1/S1 under the bounty terms; every finding needs a demonstrated external path + (for S3/S4) a runnable PoC.

---

## 7. Ranked audit options

**Toolchain:** Foundry `forge` 1.5.1 IS installed at `~/.foundry/bin` (not on default PATH — prepend). Node v24 + Python 3.12 present. **Rust is NOT installed** (no rustc/cargo, no Solana toolchain); no Sui/Move or TON/FunC toolchains. VM ~1.5 shared CPUs — serialize heavy builds/tests. All options: local-only, Foundry/TS PoCs against pinned HEADs; deployed-bytecode verification + exclusion-list dedup (§3–§4) FIRST, before any finding is drafted.

| # | Option | Size | Toolchain | Effort | Why this rank |
|---|---|---|---|---|---|
| 1 | **Relay Chain core** — Hub, OracleV2 (+Multisig, IdempotencyStore), Executor, Allocator, PriceOracle, FundingPool, deposit-address manager, rate limiter, fee calculator | ~4,500–5,000 LOC subset of the 14,645 (re-measure at audit start; named files sum 3,320) | Foundry (present) | 3–5 days | Largest unaudited surface; newest architecture; highest severity ceiling (Hub balances, oracle verification, allocator execution). Hardest to PoC end-to-end (cross-contract + oracle signer). |
| 2 | **Periphery** — Router 3.2 + NonTstore, ApprovalProxy 3.1, Receiver | 2,004 LOC | Foundry (present), tests exist | 2–3 days | Freshest code (HEAD 4 days old), no dedicated audit, self-contained, PoC-friendly. Must dedup Cantina 0203 + issue #2 + map findings to deployed versions (22 chains still on older generation). |
| 3 | **Oracle service** — post-audit delta review of `src/` attestors + verification logic | 18,129 LOC TS; review scoped to the 93 post-audit `src/` commits + attestor modules | Node (present); PoC needs simulated chain data | 3–5 days | Real churn (137 commits) and Zellic itself recommended reassessment. Downgraded: attestation patterns already deeply covered; oracle-role findings face the L1/external-path gate; PoCs are integration-heavy, not unit-style. |
| 4 | **EVM depositories** — RelayDepository + Gateway variant, delta/dedup pass | 743 LOC | Foundry (present) | 1–2 days | Smallest, but most heavily covered (Zellic + Cantina + issue #2). Value only in the Gateway variant (unaudited) and in verifying whether issue #2 claims survive in current code — as exclusion confirmation, not new findings. |
| 5 | **Non-EVM depositories** — Solana (2,094 LOC), Sui (284), TON (1,236) | ~3,600 LOC | **BLOCKED:** Rust/Solana, Move, FunC toolchains all absent | Do not start | Certora covered Solana escrow/forwarder; Zellic covered Sui/TON escrows. Needs toolchain installs + version mapping; lowest expected value per effort. |

**Prerequisites for ANY option (do first):** (a) resolve the §2 address discrepancies (docs vs prod.json) via read-only chain reads; (b) verify deployed bytecode matches pinned source for each target contract; (c) re-check the §3–§4 exclusion list against the exact target files/versions; (d) confirm the audit commit pins above are still HEAD (repos move — periphery HEAD is 4 days old).

---

## DECISION: CAUTION

A code audit is worth doing ONLY narrowly scoped to Option 1 or 2 (Relay Chain core and/or current periphery), with the §7 prerequisites done first. Reasons: submission is free and the payout matrix is generous ($500–$100k), and large surfaces (Hub/OracleV2/Executor/price oracle/funding pools, Router 3.2) have no dedicated audit — but the protocol is mature and multi-audited (Zellic 4 person-weeks, Cantina, Certora), the low-hanging depository/router fruit is already publicly disclosed (issue #2), the bounty terms are strict (external path required, admin-only capped at S1, PoC required for S3/S4, known/duplicate rules), key trust components are off-chain or unpublished (RelayAllocatorSpender source absent), and deployed-bytecode equivalence is unverified. Expect a hard search with a real chance of zero eligible findings; do NOT scope it as a broad "audit Relay" effort.

---

## Evidence locations

- Clones: `~/workspace/relay-audit/repos/{relay-settlement,relay-protocol-oracle,relay-depository,relay-periphery,relay-docs,relay-vaults}/` (settlement/oracle/periphery full history fetched; depository/docs/vaults shallow).
- Audit PDFs: inside the clones (`relay-settlement/docs/audits/`, `relay-depository/audit-reports/`). Extracted texts were in `/tmp/relay-pdf/` (ephemeral — findings captured above).
- Chains API snapshot: `/tmp/relay-chains.json` (ephemeral — addresses captured in §2).
- Bounty page: https://docs.relay.link/security/bounties (re-read 2026-11-13, full text).
- Public issue: https://github.com/relayprotocol/relay-settlement/issues/2 (titles + addresses only; no POC code copied).
