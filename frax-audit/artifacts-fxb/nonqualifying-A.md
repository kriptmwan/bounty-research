# Non-Qualifying Observations — Hunter, Domain A (FXB mint/redeem + maturity accounting)

- **Hunter:** Domain A. **Date:** 2026-11-14. **Mode:** read-only, no repo patches, no web browsing, zero GitHub API calls, no `cast` (not installed; no cast-based verification is claimed).
- **Assigned files (report scope):** `work/v1-live/src/contracts/FXB.sol` (157 lines incl. 2 provenance header lines; Sourcify exact_match content sha256 prefix `f4366c0a`, identical across all 5 live FXBs — re-verified this run against all 5 Sourcify records) and `work/v1-live/src/contracts/utils/BokkyPooBahsDateTimeLibrary.sol` (360 lines; sha256 prefix `7fa3833b`, identical across all 5 records). Line numbers below refer to these work files including the provenance header.
- **Comparison baseline:** repo HEAD `4ef235e68c8277ad3dbc676762fffe663c9896fc` (verified clean, `git status` empty at end of run).
- **Result:** **0 qualifying findings.** `hunter-findings-A.json` is `[]`. Every candidate below failed the FRAX BAR (demonstrated theft-of-funds or permanent-freezing path against a current live deployment, with a working mainnet-fork PoC) or is excluded. Nothing here is inflated into a finding.
- **Live state relied on (verified in `ONCHAIN-GROUNDWORK-FXB.md` + `fxb-addresses.json`):** 5 FXBs, 4 matured, only `0x76237BCfDbe8e06FB774663add96216961df4ff3` (FXB_20261231, matures 2027-01-01) unmatured with totalSupply 6,046,780.873165932571809639 FRAX-backed exactly 1:1; total outstanding 6,082,680.004302 backed 1:1; minted − redeemed == totalSupply exactly on every used FXB. Live FXBs are immutable, no owner, no proxy, timestamp-only `isRedeemable()`.

## Kill reasons used

- **EXCLUDED (EX-Fxx):** matches a Phase 0A exclusion.
- **NO-LIVE-TRIGGER:** the code shape exists but no reachable runtime trigger against a live mainnet instance (wrong token, uncalled code, hypothetical deployment).
- **SUB-BAR:** real observation, but impact is below the FRAX BAR (no theft/freeze, fail-closed, self-harm only, informational).
- **KILLED-BY-EVIDENCE:** the hypothesized mechanism is affirmatively disproved by code read.
- **HEAD-ONLY / NO-LIVE-INSTANCE:** defect (if any) exists only in v2 code with no Ethereum mainnet instance; Fraxtal out of scope.

---

## NQ-A-01 — Unchecked `FRAX.transferFrom` / `FRAX.transfer` return values in `mint` / `burn`

- **Location:** `FXB.sol:124` (`mint`), `FXB.sol:145` (`burn`). `IERC20` returns `bool`; neither call checks it.
- **Hypothesis considered:** a `false`-returning or fee-taking underlying would let `mint` create unbacked FXB (theft of the 6.05M FRAX backing FXB_20261231) or let `burn` destroy FXB without paying FRAX (holder fund loss).
- **Kill reason: KILLED-BY-EVIDENCE / NO-LIVE-TRIGGER.** The live underlying is immutable legacy FRAX `0x853d955aCEf822Db058eb8505911ED77F175b99e` (same address embedded in all 5 FXBs; `FRAX` is `immutable`, set once in the constructor, and the factory passes its own immutable `FRAX`). FRAX's verified source (`ERC20Custom.sol`, Sourcify partial `match`, solc 0.6.11): `transfer`/`transferFrom` call `_transfer`, which `require`s non-zero sender/recipient and uses `SafeMath.sub(amount, "ERC20: transfer amount exceeds balance")` — i.e. they **return `true` or revert**; there is no `false`-return path, no fee, no partial-amount path, and the exact `amount` is credited. A failed FRAX leg therefore reverts the whole FXB transaction atomically (the `_mint`/`_burn` and counter updates roll back). Corroborated on-chain: ~8.92M FXB minted and ~8.89M redeemed historically across FXBs #1/#2 with minted − redeemed == supply exactly and FRAX balances exactly 1:1 — no silent-failure drift exists.
- **Caveats recorded honestly:** (a) FRAX's Sourcify record is a partial `match`, not `exact_match` (runtime code matches; metadata differs) — see Unresolved cross-references. (b) A *fresh* deployment of this FXB code pointed at a `false`-returning token would mint unbacked tokens; that deployment would be a new, unregistered token harming nobody and is not a live instance. As defense-in-depth the unchecked calls are sub-bar style; they are not a live theft path.

## NQ-A-02 — No reentrancy guard; external calls to FRAX in `mint` / `burn`

- **Location:** `FXB.sol:111-125`, `131-146`.
- **Hypothesis considered:** reentrancy via FRAX callbacks draining backing or double-minting.
- **Kill reason: KILLED-BY-EVIDENCE.** (1) Both functions follow checks-effects-interactions: counters and `_mint`/`_burn` complete before the FRAX call. (2) The only external calls go to the immutable FRAX contract. FRAX `_transfer` makes **no external calls**; `_beforeTokenTransfer` is an empty hook in `ERC20Custom.sol` and is **not overridden** in `Frax.sol` (grep-verified). (3) OpenZeppelin 5.0.0 `ERC20._mint`/`_burn`/`_update` make no calls to the recipient — no ERC-721-style receiver hook exists. There is no callback surface through which any caller, including a malicious `account`/`to` contract, can reenter. A malicious-token reentrancy variant requires a non-FRAX deployment (see NQ-A-01 caveat) and has no live instance.

## NQ-A-03 — FRAX sent directly to an FXB cannot be recovered (no rescue function)

- **Kill reason: EXCLUDED — EX-F01** (TOB-FBSRO-1, unresolved, verified still present at HEAD). Direct FRAX donations only *increase* backing; they cannot be extracted by anyone, including via the mint/burn round-trip (see NQ-A-04). Not re-reported.

## NQ-A-04 — Minting allowed after maturity; post-maturity mint→burn round-trip

- **Location:** `FXB.sol:111-112` ("NOTE: Allow minting after expiry", no maturity check in `mint`).
- **Kill reason: EXCLUDED — EX-F13** (documented intended behavior). Additionally killed on the merits: the round-trip is exactly 1:1 (deposit X FRAX → X FXB → burn → X FRAX, minus gas), so it cannot extract the stuck/donated excess (if balance B > supply S, minting X and burning X leaves B−S unchanged; each burn pays only the amount burned and each mint requires a matching deposit). No profit, no dilution, no theft path.

## NQ-A-05 — `burn` has no pre-check that the contract holds enough FRAX

- **Location:** `FXB.sol:131-146`.
- **Kill reason: EXCLUDED — EX-F08 item 4** ("will not fix"; verified still as described). The FRAX `transfer` reverts on insufficient balance (NQ-A-01), so the burn reverts atomically; the only consequence is wasted gas on a failing call. The HEAD `FXB_LFRAX` `InsufficientCollateral()` check is a HEAD-only delta, not a live defect. Not re-reported.

## NQ-A-06 — `totalFxbMinted` / `totalFxbRedeemed` are set-only, never read on-chain

- **Location:** `FXB.sol:38-41`, `:118`, `:139`.
- **Kill reason: EXCLUDED — EX-F08 item 3** (kept "for extra information"). The counters are consistent: both increment under Solidity 0.8 checked arithmetic before the corresponding `_mint`/`_burn`, and any revert rolls the whole transaction back, so minted − redeemed == `totalSupply()` holds exactly (verified on-chain for all 5 FXBs). No accounting defect.

## NQ-A-07 — Early redemption / factory-owner burn bypass

- **Hypothesis considered:** HEAD `FXB.sol` `isRedeemable()` returns true for `Ownable(factory).owner()` before maturity — an early-burn privilege over the 6.05M FRAX in FXB_20261231.
- **Kill reason: HEAD-ONLY / KILLED-BY-EVIDENCE.** Live v1 `isRedeemable()` (`FXB.sol:91-93`) is purely `block.timestamp >= MATURITY_TIMESTAMP`; the FXB bytecode embeds no factory/timelock address and exposes no `factory()`/`owner()`/`timelockAddress()` selectors. Phase 0B behaviorally confirmed `isRedeemable()` returns `false` for the Safe, the factory, and the zero address on unmatured FXB #4. No caller can redeem early on mainnet. Distinguished from EX-F12 (which documents the HEAD intended admin power — that power does not exist in the live code).

## NQ-A-08 — EIP-712 domain name is the token *symbol*, not the token *name*

- **Location:** `FXB.sol:71`, `ERC20Permit(symbol_)` (OZ 5.0.0 `ERC20Permit` constructor passes its argument as the EIP-712 `name`, version `"1"`).
- **Observation:** the EIP-712 domain is `(name = symbol e.g. "FXB_20261231", version = "1", chainId = 1, verifyingContract = self)` while `ERC20.name()` is e.g. `"FXB_4_DEC312026"`. An integrator that builds the permit domain from `name()` will sign the wrong domain and `permit()` will revert.
- **Kill reason: SUB-BAR (fail-closed).** The mismatch causes permit *rejection*, never wrongful approval: the domain actually used is self-consistent and exposed via `eip712Domain()`/`DOMAIN_SEPARATOR()`, so correct signers (reading the domain from the contract, as EIP-2612 clients should) work fine; `approve()`/`transferFrom()` are unaffected; mint/burn do not use permits; no funds can be stolen or frozen by this. Distinguished from §2 CS-FRUP-007 (a proxy/implementation name mismatch in sfrxUSD): there is no proxy here, the domain name is immutable, and `eip712Domain()` output matches the separator used. No live funds at risk.

## NQ-A-09 — Permit replay, signature malleability, nonce handling, deadline, chain-fork replay

- **Location:** inherited OZ 5.0.0 `ERC20Permit` / `EIP712` / `ECDSA` / `Nonces` (exact_match tree bundled with the live factory record).
- **Kill reason: KILLED-BY-EVIDENCE.** `permit()` checks `block.timestamp > deadline` first; binds `owner, spender, value, _useNonce(owner), deadline` in the struct hash; `ECDSA.recover` reverts on malleable `s` (`ECDSAInvalidSignatureS`) and invalid signatures; `_useNonce` increments the owner's nonce (a failed permit reverts the whole tx, so no nonce-burning griefing); the domain separator binds name + version + chainId + verifying contract, is cached with `_cachedChainId`/`_cachedThis`, and is rebuilt if the chain ID changes (fork replay blocked). Distinct symbols *and* distinct contract addresses across the 5 FXBs block cross-bond replay. No defect found in the inherited permit path as instantiated by v1 FXB.

## NQ-A-10 — Constructor validates neither `_frax` nor `_maturityTimestamp`

- **Location:** `FXB.sol:66-77` (no zero-address check, no future-maturity check).
- **Kill reason: NO-LIVE-TRIGGER / SUB-BAR.** All 5 live FXBs were created by the v1 factory, which passes its immutable FRAX address and a validated future day-floored maturity (factory reverts on expired/duplicate maturities). The immutables cannot change after deployment. A direct deployment with `_frax = address(0)` or a past maturity creates a new, unregistered token: with a zero-address underlying, high-level calls to an EOA succeed silently and `mint` would mint unbacked tokens — but those tokens are the deployer's own worthless deployment, hold no live backing, and are not in the factory registry (`isFxb` false). No live funds are reachable through this path.

## NQ-A-11 — "Always expires on a Wednesday" is false: 4 of 5 live maturities are NOT Wednesdays

- **Finding of this hunt (benign):** README states each maturity "always expires on a Wednesday, UTC 00:00". On-chain maturities are 2024-04-01 (Mon), 2024-07-01 (Mon), 2025-01-01 (Wed), 2026-01-01 (Thu), 2027-01-01 (Fri) — all 00:00 UTC on the 1st of a month, only one a Wednesday.
- **Kill reason: KILLED-BY-EVIDENCE — not a library or factory defect; SUB-BAR docs mismatch.** (1) The date library is correct: I re-implemented `_daysToDate`, `_daysFromDate`, and `getDayOfWeek` in Python with Solidity truncation semantics and compared against `datetime` for **every day from 1970-01-01 through 2345-12-31 (137,331 days): zero mismatches**, including leap years and all 5 live maturities/day-before dates. `getDayOfWeek` returns 4 (Thursday) for 1970-01-01 as specified. (2) **No contract code enforces Wednesday**: `getDayOfWeek` is never called by any repo contract (grep-verified across `src/`); the v1 factory's `createFxbContract` accepts any future day-floored timestamp with no weekday check. (3) The maturities are quarter/year-end dates chosen by the timelock at creation, not computed by the library. (4) Redemption gating uses the raw `MATURITY_TIMESTAMP` only (`FXB.sol:92`); the weekday has no on-chain consequence whatsoever. The README sentence is simply wrong/stale. No funds at risk, no freezing path, no fixable code defect in the assigned files.

## NQ-A-12 — Date-library functions beyond `getYear`/`getMonth`/`getDay`, and their edge-case quirks

- **Location:** `BokkyPooBahsDateTimeLibrary.sol` — `timestampFromDate` (`:113`, no month/day validation: out-of-range inputs roll over arithmetically per the Julian-day formula), `_getDaysInMonth` (`:196`, returns 30 for invalid months such as 0 or 13), `subMonths`/`subYears` (underflow reverts under 0.8 checked arithmetic), `addYears`/`addMonths` (clamp day to month length, monotonicity `require`), `diff*` (ordering `require`s).
- **Kill reason: NO-LIVE-TRIGGER (unreachable dead code).** The only library functions reachable from any live contract are `getYear`/`getMonth`/`getDay` via `_daysToDate`, called by the v1 factory's `_generateSymbol`/`_generateName` for metadata strings only. `FXB.sol` does not use the library at all. Internal library functions that are never called are not inlined into deployed bytecode. The quirks above are therefore unexercisable against any live instance; the reachable `_daysToDate` path was verified exhaustively (NQ-A-11). None of these is a live defect. (The reachable path's `int256` casts revert only for timestamps beyond ~292 billion years — unreachable.)

## NQ-A-13 — Name/symbol use the day *before* maturity

- **Observation:** the factory names bonds from `maturity − 1 day` (e.g. `FXB_20261231` matures 2027-01-01). A holder reading only the symbol might expect redemption a day early.
- **Kill reason: SUB-BAR (deliberate convention, factory domain).** The convention is explicit in factory code ("Use the day before for the name/symbol"), `MATURITY_TIMESTAMP` is the public authoritative value, and redemption still pays 1:1 at the stated timestamp. No theft, no permanent freeze (at most a 1-day expectation gap, fully visible on-chain). Factory metadata generation is outside Domain A's assigned files in any case.

## NQ-A-14 — `mint`/`burn` accept arbitrary `account`/`to` addresses

- **Location:** `FXB.sol:111` (`mint` to any `account`, FRAX taken from `msg.sender`), `FXB.sol:131` (`burn` pays FRAX to any `to`, FXB burned from `msg.sender`).
- **Kill reason: SUB-BAR / KILLED-BY-EVIDENCE (self-harm only or reverting).** Minting to `address(0)` reverts (OZ `_mint`); burning to `address(0)` reverts (FRAX `_transfer` zero-address require), both atomically. Minting FXB to the FXB contract itself, or burning with `to` = the FXB contract, only strands the *caller's own* funds (the contract can never move its own FXB balance or spend the returned FRAX except via others' burns, which benefits remaining holders). No path lets a caller mint from or burn another account's balance: `_burn` debits `msg.sender` only, and `transferFrom` requires allowance. The arbitrary-recipient design is the intended AMO/auction flow (cf. repo tests minting to third parties).

## NQ-A-15 — `block.timestamp` manipulation near the maturity boundary

- **Kill reason: SUB-BAR.** A block proposer can shift `block.timestamp` by seconds. Redeeming seconds before the 00:00 UTC maturity changes nothing economically: the rate is fixed 1:1 with no yield accrual, no price curve, and no time-weighted quantity in the contract. No measurable funds at risk.

## NQ-A-16 — Donation / share-inflation ("first depositor") attack

- **Kill reason: KILLED-BY-EVIDENCE.** FXB is not a vault: there is no share price, no `totalAssets/totalSupply` ratio, and minting is fixed 1:1 regardless of the contract's FRAX balance. A donation increases backing per outstanding FXB but cannot be extracted (NQ-A-04) and cannot dilute or inflate anyone. The classic ERC-4626 inflation attack has no analogue here.

## NQ-A-17 — Rounding, precision, decimals, overflow

- **Kill reason: KILLED-BY-EVIDENCE.** No division, multiplication, or price math exists in `mint`/`burn` — pure 1:1 unit transfer. FXB `decimals()` = 18 (OZ default) and FRAX `decimals` = 18 (constant), confirmed on-chain. All arithmetic is Solidity 0.8.23 checked (counter increments revert on overflow; OZ `_update` checks `totalSupply` overflow on mint). Overflow is unreachable in practice (FRAX total supply ~219M vs uint256 max). No rounding defect is possible in this code shape.

## NQ-A-18 — `transfer`/`transferFrom` return-value handling and allowance semantics

- **Kill reason: KILLED-BY-EVIDENCE.** FXB does not override `transfer`, `transferFrom`, `approve`, or allowance logic; it inherits OZ 5.0.0 `ERC20`, which reverts on insufficient balance (`ERC20InsufficientBalance`) and insufficient allowance (`ERC20InsufficientAllowance`), rejects zero-address receivers/spenders, and treats `type(uint256).max` allowance as infinite (standard, intended). No defect in the assigned files.

## NQ-A-19 — No custom `Mint`/`Burn` events

- **Kill reason: SUB-BAR (informational).** `_mint`/`_burn` emit standard ERC-20 `Transfer` events and the FRAX legs emit `Transfer` events, so mint/burn activity is fully observable off-chain. Missing dedicated events affect only indexer convenience. No funds impact.

## NQ-A-20 — Unused `FXBFactory` import in `FXB.sol`

- **Location:** `FXB.sol:21` (`import { FXBFactory } from "./FXBFactory.sol";` — never referenced; the import is circular since the factory imports FXB).
- **Kill reason: SUB-BAR / out of scope (§4: unused code).** An unused import has no runtime effect and embeds no factory code in FXB bytecode. Not a finding.

## NQ-A-21 — HEAD-only / v2-only observations (no live mainnet instance)

- **Kill reason: HEAD-ONLY / NO-LIVE-INSTANCE.** The following were checked against HEAD for delta understanding only and are **not** reported as findings, per the scope-deciding facts (HEAD v2.0.0 runs nowhere on Ethereum mainnet; Fraxtal is out of scope):
  - `FXB_LFRAX` hand-rolled EIP-712 domain logic — also **EXCLUDED, EX-F07** (acknowledged by design); no concrete separator/replay bug was found in the comparison read, and the code has no verified mainnet instance.
  - Missing `_disableInitializers` in the old implementation constructor — **EXCLUDED, EX-F04** (verified fixed at HEAD).
  - Beacon-proxy / `Ownable2Step` factory / `FXBFactory.initialize` Fraxtal registry / `setToken` behaviors — **EXCLUDED in part, EX-F09**; no mainnet deployment exists to attack.
  - EIP-712 version bump to `1.2.0` invalidating pending permits — **EXCLUDED, EX-F16** (intended upgrade effect, Fraxtal only).
  - `FXB_LFRAX.initialize` frxUSD burn + trusted LFRAX refill solvency assumption — **EXCLUDED, EX-F14**.
  - `FXB_LFRAX.burn` `InsufficientCollateral()` check present at HEAD but absent in v1 — a HEAD-only hardening delta; v1 behavior is EX-F08 item 4 (NQ-A-05).

## NQ-A-22 — Direct deployment / name-symbol spoofing of a live FXB

- **Hypothesis considered:** anyone can deploy `FXB` directly with the same name/symbol/maturity as a live bond and confuse users/integrators.
- **Kill reason: SUB-BAR / NO-LIVE-TRIGGER.** Contract identity on-chain is the address plus factory-registry membership (`isFxb`), not the metadata strings; a spoof deployment holds no backing and cannot touch live FXB balances or FRAX. No code-level theft/freeze path exists in the assigned files. (Phishing via lookalike deployments is a UX/ecosystem concern, not a demonstrated on-chain exploit against a live deployment.)

## NQ-A-23 — FRAX-side admin seizure, pause, or blacklist freezing FXB backing

- **Kill reason: KILLED-BY-EVIDENCE, with a stated residual caveat.** FRAX `ERC20Custom._transfer` has no pause, blacklist, fee, or admin-seizure branch; `collateral_ratio_paused` gates only collateral-ratio refreshes, not transfers; FRAX exposes no function that moves another account's balance without allowance (pools can only mint; `burnFrom` requires allowance, which FXB never grants); FRAX is a non-proxy immutable 0.6.11 deployment. The FXB contracts' FRAX balances can therefore only decrease through `burn` transfers. **Residual caveat:** this rests on FRAX's partial-match Sourcify source (see Unresolved cross-references); it is corroborated by 2+ years of exact 1:1 on-chain accounting but was not re-verified by a bytecode rebuild (no solc/forge on this VM).

---

## Files scanned / skipped

**Scanned in full (assigned files):**

| File | Lines | Coverage |
|---|---|---|
| `work/v1-live/src/contracts/FXB.sol` | 157 (incl. 2 provenance lines) | 100% — constructor, `bondInfo`, `isRedeemable`, `version`, `mint`, `burn`, errors; all 6 hunt angles in the brief traced. |
| `work/v1-live/src/contracts/utils/BokkyPooBahsDateTimeLibrary.sol` | 360 | 100% — every function read; reachable path (`_daysToDate` via `getYear`/`getMonth`/`getDay`) verified numerically over 137,331 days; unreachable functions assessed for reachability. |

**Read as evidence (not report scope):**

| File | Extent |
|---|---|
| `work/v1-live/src/contracts/FXBFactory.sol` | Full read (maturity coercion, naming, registry, factory→FXB wiring; Domain B's file — no findings reported in it). |
| HEAD `repos/frax-bonds/src/contracts/FXB.sol` | Full read (delta vs v1). |
| HEAD `repos/frax-bonds/src/contracts/FXB_LFRAX.sol` | `isRedeemable`/`mint`/`burn`/errors only (delta understanding). |
| OZ 5.0.0 `ERC20.sol`, `ERC20Permit.sol`, `EIP712.sol`, `ECDSA.sol`, `Nonces.sol` from the exact_match Sourcify tree (`sourcify-fxb/1_0x7a07….json`) | Permit/EIP-712/`_mint`/`_burn`/`_update`/allowance paths read. |
| FRAX `Frax.sol` + `ERC20Custom.sol` from the partial-match Sourcify record (`sourcify-fxb/1_0x853d….json`) | `transfer`/`transferFrom`/`_transfer`/hook-override/fee/seizure behavior read; grep-verified no `_beforeTokenTransfer` override, no external calls in `_transfer`. |
| `repos/frax-bonds/src/test/FXBTest.t.sol` | Grep-level (intended mint/burn/redeemability behavior incl. HEAD-only owner early-burn tests — confirms the HEAD/v1 semantic split). |
| `exclusions/EXCLUSION_LIST_FXB.md`, `CORRESPONDENCE-FXB.md`, `ONCHAIN-GROUNDWORK-FXB.md`, `fxb-addresses.json` | Read in full / queried (scope, exclusions, live state). |

**Skipped:** none of the assigned files were skipped. `Timelock2Step.sol` was not read beyond the correspondence/groundwork summaries — it is not imported by v1 `FXB.sol` and has no bearing on mint/redeem/maturity accounting in the assigned files (factory access control is Domain B's scope). No other files were in scope for Domain A.

## Unresolved cross-references / could not determine

1. **FRAX source is a partial Sourcify `match`, not `exact_match`.** The revert-or-`true`, no-fee, no-hook conclusions in NQ-A-01/02/23 rest on the verified FRAX source tree plus 2+ years of exact on-chain 1:1 accounting. A bytecode-rebuild equality check (solc 0.6.11) was not possible — no `solc`/`forge`/`cast` on this VM — so a theoretical divergence between verified source and deployed FRAX bytecode cannot be excluded from this desk alone. No observed behavior contradicts the source.
2. **No mainnet-fork PoC was executed** (no Foundry toolchain; per the brief, `cast` is not installed). No PoC was needed: no qualifying finding was produced, so nothing required fork execution. Any future finding in this domain would still need a working fork PoC before filing, per the FRAX BAR.
3. **Direct-deployment exclusion gap (inherited from Phase 0B):** factory registries + nonce + storage checks prove exactly 5 factory-created FXBs, but `eth_getLogs` was unavailable to RPC probes, so directly-deployed v1 FXBs bypassing the factory cannot be fully excluded from RPC evidence alone. If one existed, it would run the same audited code with the same conclusions and hold no identified live funds; no such deployment was found in the 171-address sweep.
4. **FxbAMO operator contract** (`0x452420df…`, holds 1,999,230 FXB_20261231) was not traced: its mint/burn/auction flows through FXB are another domain's scope. Nothing in the assigned FXB code gives the operator (or any caller) a privileged mint/burn path — `mint`/`burn` are permissionless 1:1 for every caller equally.
5. **Source-integrity recheck:** sha256 of both assigned files was re-verified unchanged at conclusion (`FXB.sol` `00aa5098…`, date library `41887791…`, both including provenance headers); repo HEAD still `4ef235e…`, working tree clean. No source mutation occurred during the hunt.
