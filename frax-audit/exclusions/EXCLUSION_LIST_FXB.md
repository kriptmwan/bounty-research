# Exclusion List — FXB / Frax Bonds (Phase 0A)

**Purpose:** every prior-audit finding covering FXB / Frax Bonds, so Hunters never re-report them.
Any Hunter candidate matching an item below (same contract, same mechanism) is EXCLUDED, whether
the report says fixed, acknowledged, or unresolved. A *distinct* mechanism in the same contract is
not excluded — cite the EX-F ID you distinguished it from in the finding draft.

**Target repo:** `~/workspace/frax-audit/repos/frax-bonds` @ `4ef235e68c8277ad3dbc676762fffe663c9896fc`
(read-only; left clean). All "HEAD verification" below is a source read at that commit only.
`cast` is not installed; no on-chain verification was performed. No web browsing, no GitHub API.

## Sources read in full

| # | Report | Coverage relevant here |
|---|--------|------------------------|
| R1 | Trail of Bits, *Frax Bonds, Savings Frax, Frax Ether Redemption Queue, Frax Oracles*, Oct 27 2023 (fix review Oct 18 2023). frax-bonds @ `9c4be49`. 5 findings. | FXB (`FXB.sol`), SlippageAuction. **FXBFactory and SlippageAuctionFactory were explicitly OUT of scope for ToB** — no ToB exclusion exists for either factory. |
| R2 | ChainSecurity, *Code Assessment of the Frax Upgrade Smart Contracts*, Jul 17 2025. Frax Bonds V1 @ `fe4caf0` (Jun 23 2025), V2 fixes @ `4ef235e` (Jul 14 2025) — **V2 is exactly the current HEAD**, so "Code Corrected" dispositions were assessed at this HEAD. 23 numbered findings (CS-FRUP-001…023, all accounted for below) + 5 unnumbered Notes. | FXB_LFRAX, FraxBeacon, FraxBeaconProxy, FraxUpgradeableProxy, FXB, FXBFactory + 3 `LFRAX_FXB_Upgrade` scripts. **SlippageAuction, SlippageAuctionFactory, OwnedV2, and ERC20PermitPermissionedOptiMintable were NOT in ChainSecurity scope** — no ChainSecurity exclusion exists for them. |
| R3 | `AUDIT_SCOPE_LFRAX_AND_FXB_UPGRADE.md` and `FXB_UPGRADE_NOT_V2_WALKTHROUGH.md` in the target repo (skimmed for known-issue / accepted-risk / scope statements). | Scope + trust-model statements recorded as EX-F11…EX-F14. |

**Completeness check.** R1: 5 findings = 3 in scope (EX-F01…F03) + 2 out of scope (§2). R2: 23 numbered
findings = 5 in scope (EX-F04…F08, two of them partial — see notes) + 18 out of scope (§2); 5 Notes =
2 in scope (EX-F09, EX-F10) + 3 out of scope (§2). No finding in either report touches OwnedV2,
FraxBeaconProxy, FraxUpgradeableProxy, ERC20PermitPermissionedOptiMintable, SlippageAuctionFactory,
or the `LFRAX_FXB_Upgrade` scripts directly.

**HEAD-verification rule used:** code at HEAD was checked only where a report gave a file:line or a
precise description. Otherwise the status is recorded as **unverified** — never guessed.

---

## §1. Exclusions (in-scope findings and accepted risks) — 16 items

### EX-F01 — R1 / TOB-FBSRO-1: "FRAX tokens mistakenly sent to FXB cannot be retrieved"
- **Severity:** Informational (Difficulty: Medium; Type: Configuration)
- **Affected:** `FXB.sol` — `mint()` (FXB contract as a whole: no token-recovery function). Cited at `FXB.sol#L101-L109` (2023 code).
- **Mechanism (one line):** FRAX sent directly to the FXB contract (e.g. `transfer` instead of `approve`) mints no FXB and cannot be recovered — there is no rescue function, so the tokens are effectively burned.
- **Fix status as stated in report:** **Unresolved** (fix review: Frax added no retrieval mechanism and indicated no plans to warn users in documentation).
- **HEAD verification: VERIFIED STILL PRESENT.** No rescue/recover/sweep/skim function exists in `src/contracts/FXB.sol` or `src/contracts/FXB_LFRAX.sol` at HEAD (only `ECDSA.recover` references). The one-shot frxUSD burn inside `FXB_LFRAX.initialize()` is an upgrade step, not a general recovery mechanism. Hunters must not re-report "stuck tokens, no rescue function" for FXB/FXB_LFRAX.

### EX-F02 — R1 / TOB-FBSRO-3: "Array assignment to index out of bounds breaks swap functions"
- **Severity:** High (Difficulty: Low; Type: Configuration)
- **Affected:** `SlippageAuction.sol` — `swapTokensForExactTokens()` and `swapExactTokensForTokens()`. Cited at `contracts/SlippageAuction.sol#408-425`.
- **Mechanism (one line):** Both functions wrote `_amounts[0]` / `_amounts[1]` on the named return variable, which defaults to a zero-length array, so every call reverted out-of-bounds.
- **Fix status as stated in report:** **Resolved** in commit `42120ad` (functions reassign `_amounts` with `new` + static array; tests added). Note: the fix-review text names only `swapExactTokensForTokens`, but the finding covered both functions.
- **HEAD verification: VERIFIED FIXED.** `SlippageAuction.sol:569-571` and `:605-607`: both functions execute `_amounts = new uint256[](2);` before the index assignments.

### EX-F03 — R1 / TOB-FBSRO-4: "Incorrect order of arguments passed to swap function triggers revert"
- **Severity:** High (Difficulty: Low; Type: Data Validation)
- **Affected:** `SlippageAuction.sol` — `swapExactTokensForTokens()` calling `swap()` (signature at `L343` in 2023 code; body cited at `L434-L446`).
- **Mechanism (one line):** `swapExactTokensForTokens` passed `(amountOut, 0, …)` to `swap(_buyTokenOut, _sellTokenOut, …)`, reversing the arguments, so `swap` always reverted on its `_sellTokenOut != 0` check.
- **Fix status as stated in report:** **Resolved** in commit `42120ad` (named arguments; correct argument order).
- **HEAD verification: VERIFIED FIXED.** Both router-style functions call `swap({ amount0Out: 0, amount1Out: amountOut, to: to, data: new bytes(0) })` with named arguments (`SlippageAuction.sol`, in `swapExactTokensForTokens` and `swapTokensForExactTokens`), and `swap()` (line 471) requires `amount0Out == 0` and `amount1Out != 0`, consistent with that order.

### EX-F04 — R2 / CS-FRUP-014: "Initializer Not Disabled"
- **Severity:** Informational
- **Affected:** `FXB` — constructor (missing `_disableInitializers()`).
- **Mechanism (one line):** The FXB implementation contract's constructor did not disable initializers, leaving the implementation itself initializable.
- **Fix status as stated in report:** **Code Corrected** — "The constructor was updated to include the call to `_disableInitializers()`."
- **HEAD verification: VERIFIED FIXED.** `src/contracts/FXB.sol:62-63`: `constructor() { _disableInitializers(); }`.

### EX-F05 — R2 / CS-FRUP-015: "Misleading Natspec" (FXB part only)
- **Severity:** Informational
- **Affected:** `FXB_LFRAX` — natspec comment citing EIP-721 where EIP-712 was meant. (Item 2 of this finding, about `SfrxUsd2OracleImplementation`'s "Events" category name, is sfrxUSD-only and is listed in §2.)
- **Mechanism (one line):** A natspec comment in FXB_LFRAX referenced the wrong EIP number (721 vs 712), misleading readers about the signature domain logic.
- **Fix status as stated in report:** **Code Corrected** — "Natspec comments were updated."
- **HEAD verification: VERIFIED FIXED (FXB part).** The string `EIP721` occurs nowhere under `src/contracts/` at HEAD; `FXB_LFRAX.sol` natspec/code consistently references EIP-712 (e.g. lines 70-73, 177).

### EX-F06 — R2 / CS-FRUP-018: "Some Events Could Be Indexed"
- **Severity:** Informational
- **Affected:** `FraxBeacon.FraxBeaconImplementationUpdated`, `FXBFactory.BondCreated`.
- **Mechanism (one line):** The two events had no indexed parameters, making them inefficient to search/filter off-chain.
- **Fix status as stated in report:** **Code Corrected** — "The events listed are now indexed."
- **HEAD verification: VERIFIED FIXED.** `FraxBeacon.sol:59`: both parameters indexed (`address indexed oldImplementation, address indexed newImplementation`). `FXBFactory.sol:206-212`: `BondCreated` indexes `fxb` and `id` (`string metadata`, `token`, `maturityTimestamp` remain unindexed — that residual is part of the accepted fix as reported, not a new finding).

### EX-F07 — R2 / CS-FRUP-010: "Code Simplification by Inheritance"
- **Severity:** Informational (§7 Informational, Acknowledged)
- **Affected:** `FXB_LFRAX` — locally re-implemented EIP-712 domain-separator logic/helpers instead of inheriting OpenZeppelin `EIP712Upgradeable`.
- **Mechanism (one line):** FXB_LFRAX hand-rolls domain-separator logic (cached separator, hashed name/version, short-string fallbacks) instead of reusing the audited OZ implementation, adding maintenance/audit surface.
- **Fix status as stated in report:** **Acknowledged** — "Frax said that this is due to legacy reasons and that they will not address it."
- **HEAD verification: VERIFIED STILL AS DESCRIBED.** `FXB_LFRAX.sol:34` inherits `Initializable, ERC20, IERC20Permit, IERC5267, EIP712StoragePad, Nonces` — no `EIP712Upgradeable`; local EIP-712 state/helpers remain (lines ~70-75, ~150-158, ~177+). Do not re-report the *choice* of local EIP-712 logic; a concrete bug *in* that logic (wrong separator, replay, malleability) with a proof would be a distinct finding — cite this ID when distinguishing.

### EX-F08 — R2 / CS-FRUP-013: "Gas Optimizations" (FXB-side items 1–5 only)
- **Severity:** Informational (§7 Informational, Code Partially Corrected)
- **Affected:** `FXB_LFRAX.initialize`, `FXBFactory`, `FXB` (see sub-items). Items 6–14 concern StakedFrxUSD2 / LinearRewardsQuasiErc4626 / FraxtalERC4626MintRedeemer and are listed in §2.
- **Mechanism (one line each) / fix status as stated / HEAD verification:**
  1. `FXB_LFRAX.initialize` takes a factory-address parameter although docs say it is always `msg.sender`. Status: **kept** — "Needed for the upgrade." HEAD: **verified still present** (`FXB_LFRAX.sol:116-122`, `_factory` parameter).
  2. `FXBFactory.InvalidMonthNumber` error unused. Status: **removed**. HEAD: **verified removed** (no occurrence under `src/contracts/`).
  3. `FXB.totalFxbMinted` / `FXB.totalFxbRedeemed` only set, never read (total supply available via `totalSupply()`). Status: **kept** — "Left for extra information." HEAD: **verified still present** (`FXB.sol:39,42` declarations; `:130`, `:151` increments; public getters only).
  4. `FXB.burn` doesn't fail early when there isn't enough underlying (relies on the token transfer reverting). Status: **will not fix**. HEAD: **verified still as described** — `FXB.burn` (`FXB.sol:143-158`) has no balance check before `_burn`/`token.transfer`. (Contrast: `FXB_LFRAX.burn` DOES check `InsufficientCollateral()` — do not confuse the two.)
  5. `FXB_LFRAX.FXB_LFRAX` "not used, only set". Status: **will not fix**. HEAD: **UNVERIFIED** — no state variable or member named `FXB_LFRAX` exists in `FXB_LFRAX.sol` at HEAD (state vars are `totalFxbMinted`, `totalFxbRedeemed`, `factory`, `token`, `frxUSD`, `MATURITY_TIMESTAMP`, plus EIP-712 storage); the V1 commit is not present in local history, so the V1 identifier this referred to could not be resolved. Do not re-report item 5 as worded; if a dead-set-only variable is found at HEAD, treat it as a new candidate and cite this sub-item.

### EX-F09 — R2 / Note §8.1: "Changing Beacon Implementation"
- **Severity:** Note (awareness, no severity; no fix expected)
- **Affected:** `FXBFactory` / `FraxBeacon` / beacon-proxy FXBs.
- **Mechanism (one line):** (1) Beacon-implementation changes do not affect the pre-existing FXBs registered at factory initialization; (2) `setToken` can change the token used for subsequently created FXBs, so FXBs sharing one beacon implementation can diverge in backing token.
- **Fix status as stated in report:** n/a — documented admin-awareness note.
- **HEAD verification: VERIFIED CONSISTENT.** `FXBFactory.initialize` (lines 61-86) hardcodes the 4 pre-existing FXB addresses into `isFxb`/`fxbs` while creating a fresh `FraxBeacon`; `setToken` exists (`FXBFactory.sol:192`, `onlyOwner`). Re-reporting either behavior as a "finding" is excluded; a concrete exploit arising from a *specific* token/beacon combination would need its own proof and must cite this ID.

### EX-F10 — R2 / Note §8.3: "Function Names After Upgrade"
- **Severity:** Note (awareness, no severity; no fix expected)
- **Affected:** Upgraded contracts generally (including the FXB upgrade).
- **Mechanism (one line):** Upgraded contracts do not always keep the same interface — renamed functions and `DEPRECATED`-prefixed public state variables change the externally visible view-function interface, breaking integrators that rely on the old names.
- **Fix status as stated in report:** n/a — documented awareness note.
- **HEAD verification: UNVERIFIED** — the note cites no file:line and makes a general claim. (Consistent observation only: `DEPRECATED___nameFallback` / `DEPRECATED___versionFallback` private vars exist in `src/contracts/utils/EIP712StoragePad.sol:24-25`.) Do not re-report generic "upgrade changes the interface" for the FXB upgrade; a *specific* broken integration (named caller + named renamed entrypoint + demonstrated breakage) would be distinct — cite this ID.

### EX-F11 — R3 scope statement: OptimismMintable token/factory code out of audit scope
- **Severity:** n/a (scope exclusion)
- **Source:** `AUDIT_SCOPE_LFRAX_AND_FXB_UPGRADE.md`, "LFRAX Audit Scope": "The underlying OptimismMintablePermitERC20 and OptimismMintableERC20Factory code is well-established and does not need to be audited. I would just check that the proxy is set up properly."
- **Affected:** OptimismMintablePermitERC20 / OptimismMintableERC20Factory (LFRAX on Fraxtal, proxy `0xff00…01Fd`); `ERC20PermitPermissionedOptiMintable` interaction surface inherits this boundary for the *underlying Optimism code itself*.
- **Mechanism (one line):** Findings *inside* the OptimismMintable implementation/factory code are out of scope by the project team's own audit scoping; only the proxy setup is in scope.
- **Fix status:** n/a. **HEAD verification:** n/a (scope statement, not code). Boundary: a bug in how FXB_LFRAX *calls* the token (e.g. its `burn()` call in `initialize`) is still in scope; a bug inside the Optimism token implementation is not.

### EX-F12 — R3 trust model: admin upgrade power + factory-owner early burn are intended
- **Severity:** n/a (intended admin powers)
- **Source:** `FXB_UPGRADE_NOT_V2_WALKTHROUGH.md`, "Actors and trust model": "The ProxyAdmin can upgrade the contract, and the FXBFactory.timelockAddress() can burn bonds early. Other than that, there are no higher level permissions beyond that for ERC20s." Corroborated by `FXB.isRedeemable()` natspec ("Frax team msig has rights to burn FXB before maturity") and R2 §2.3 (Frax Admin fully trusted, can upgrade implementations at will).
- **Affected:** ProxyAdmin / `FXBFactory` owner-timelock; `FXB.isRedeemable()` / `burn()`.
- **Mechanism (one line):** The admin's ability to upgrade FXB implementations and to burn FXB before maturity is documented, intended functionality — not a centralization "finding."
- **Fix status:** n/a. **HEAD verification:** corroborated — `FXB.sol` `isRedeemable()` returns true when `msg.sender == Ownable(factory).owner()` regardless of maturity. Do not file "admin can upgrade / burn early" as a finding; a *missing* access check letting a non-admin do so would be distinct.

### EX-F13 — R3 documented behavior: minting allowed before AND after maturity; redemption only at/after maturity
- **Severity:** n/a (intended behavior)
- **Source:** `FXB_UPGRADE_NOT_V2_WALKTHROUGH.md`: "users can still mint bonds 1:1 with underlying before (or after) maturity, but they cannot redeem it until after maturity."
- **Affected:** `FXB.mint()` / `FXB_LFRAX.mint()` vs `burn()`.
- **Mechanism (one line):** Post-maturity minting at 1:1 is explicitly intended (also used by the Slippage Auction when preparing a tranche); only redemption is maturity-gated.
- **Fix status:** n/a. **HEAD verification:** corroborated — `FXB.mint()` carries the comment `NOTE: Allow minting after expiry` and has no maturity check, while `burn()` requires `isRedeemable()`. "Mint after maturity" alone is excluded; early *redemption* (burn before maturity by a non-owner) is NOT excluded — R3 lists "Make sure people cannot redeem early" as an open audit concern.

### EX-F14 — R3 + R2 trust model: FXB solvency depends on the team pre-funding LFRAX 1:1 before maturity
- **Severity:** n/a (accepted operational risk)
- **Source:** `AUDIT_SCOPE_LFRAX_AND_FXB_UPGRADE.md` ("Before maturity, our team will directly transfer LFRAX to the FXB contract matching its' totalSupply 1:1, enabling full redemption") and `FXB_UPGRADE_NOT_V2_WALKTHROUGH.md` (same); R2 §2.3 ("They are trusted to deposit the required balance of LFRAX to the FXB_LFRAX for users to redeem their FXBs"; "The system is assumed to be solvent when it's supposed to be").
- **Affected:** `FXB_LFRAX` post-upgrade (frxUSD drained + burned in `initialize`; LFRAX refill is an off-chain team action).
- **Mechanism (one line):** Between upgrade and the team's LFRAX refill, an FXB_LFRAX contract is undercollateralized by design; redemption solvency is a trusted-team operational assumption, not an on-chain invariant.
- **Fix status:** n/a. **HEAD verification:** corroborated — `FXB_LFRAX.initialize()` burns the contract's entire frxUSD balance with a comment noting collateral must be filled 1:1 "eventually". The bare observation "contract may lack collateral until funded" is excluded; a mechanism that *prevents* funding, *diverts* the refill, or lets someone redeem more than funded would be distinct — cite this ID.

### EX-F15 — R2 trust model / scope: Fraxtal sequencer fully trusted; EVM-equivalence assumed; financial modeling out of scope
- **Severity:** n/a (scope + trust assumptions)
- **Source:** R2 §2.1.1 ("The Fraxtal L2 … is assumed to implement similar semantics to EVM and its sequencer is fully trusted. The financial modeling of the system is beyond the scope") and §2.3 (rollup admins "have full control over the sequencing, safety, and security of the system" via hard forks).
- **Affected:** All Fraxtal-deployed FXB contracts.
- **Mechanism (one line):** Sequencer/rollup-admin misbehavior, L2-vs-L1 semantic divergence, and bond-pricing/financial-model critiques are outside the audit's scope and trust assumptions.
- **Fix status:** n/a. **HEAD verification:** n/a (assumption statement). Note the repo docs record that production FXBs were converted from immutable contracts to proxies *by hardfork overwrite* — that history is context, not a finding.

### EX-F16 — R2 documented effect: EIP-712 version bump to 1.2.0 invalidates pending permits
- **Severity:** n/a (intended upgrade effect)
- **Source:** R2 §2.2.2: "During the upgrade, the version field of the FXB for EIP712 will change to 1.2.0 invalidating pending permits."
- **Affected:** `FXB_LFRAX` EIP-712 domain (`initialize`).
- **Mechanism (one line):** The upgrade deliberately changes the EIP-712 `version` to `1.2.0`, so permits signed against the old domain no longer verify.
- **Fix status:** n/a (intended). **HEAD verification:** corroborated — `FXB_LFRAX.initialize()` sets `_thisVersion = "1.2.0"` and rebuilds the cached domain separator. "Upgrade invalidates outstanding permits" is excluded; a flaw in the *new* domain construction (wrong name/chainId/verifyingContract, replay across versions) would be distinct — cite this ID and EX-F07.

---

## §2. Out-of-scope findings in the same reports (NOT exclusions — do not confuse)

These findings are in R1/R2 but touch only sFRAX / sfrxUSD, the frxETH redemption queue, or oracles.
They do NOT exclude anything in FXB scope. They are listed so nobody mistakes them for FXB exclusions
— and so a Hunter does not "exclude" a genuinely new FXB bug by mis-citing one of them. Fix statuses
are as stated in the reports; no HEAD verification was attempted (contracts outside the target repo).

### R1 (Trail of Bits) — out of FXB scope
| ID | Title | Severity | Affected | Fix status in report |
|----|-------|----------|----------|----------------------|
| TOB-FBSRO-2 | Oracle deployed with misconfigured base token | Low | `SfrxEthEthDualOracle` (deployed with frxETH address as base token instead of sfrxETH) | Resolved (redeployed, commit `42120ad`) |
| TOB-FBSRO-5 | `collectRedemptionFees` can be called before `feeRecipient` has been set | Medium | `FraxEtherRedemptionQueue.collectRedemptionFees` (fees to `address(0)`) | Unresolved (team chose not to address) |

### R2 (ChainSecurity) — out of FXB scope (all sfrxUSD / oracle / MintRedeemer contracts)
| ID | Title | Severity | Affected | Fix status in report |
|----|-------|----------|----------|----------------------|
| CS-FRUP-001 | An Outdated Price Is Used in Computations | Low | `FraxtalERC4626MintRedeemer` (`_convertToShares`/`_convertToAssets` mixing fresh + stored oracle prices) | Code Corrected |
| CS-FRUP-002 | Breaking ERC-4626 | Low | `LinearRewardsQuasiErc4626` (all 4 `preview<X>` return 0) | Risk Accepted |
| CS-FRUP-003 | Missing Check for `lastSync` | Low | `SfrxUsd2OracleImplementation.setAllPricingParams` (no future-`lastSync` check) | Code Corrected |
| CS-FRUP-004 | Oracle Time Tolerance Is Not Respected | Low | `FraxtalERC4626MintRedeemer` (stale cached price accepted via `oracleTimeTolerance` double-use) | Specification Changed |
| CS-FRUP-005 | Rounding Errors Break Some ERC-4626 Calculations | Low | `FraxtalERC4626MintRedeemer` (`previewRedeem`/`previewDeposit` vs `max*` rounding) | Risk Accepted |
| CS-FRUP-006 | The Initial Price Is Not Defined Correctly | Low | `SfrxUsd2OracleImplementation` init (price 0, backrunnable `latestRoundData`) | Code Corrected |
| CS-FRUP-007 | Token Name on the Proxy Can Mismatch the Name on the Implementation Contract | Low | `StakedFrxUSD2.initialize` vs immutable `INITIAL_DOMAIN_SEPARATOR` | Risk Accepted |
| CS-FRUP-008 | Underlying Price Model Ambiguity | Low | `FraxtalERC4626MintRedeemer` (relative-price vs dual-oracle models mixed) | Code Corrected |
| CS-FRUP-009 | Unverified Assumptions Can Break the Code | Low | `LinearRewardsQuasiErc4626`, `SfrxUsd2OracleImplementation`, `FraxtalERC4626MintRedeemer` (assumed 18 decimals, unenforced) | Code Corrected |
| CS-FRUP-011 | Far in the Future, Times Result in Computation Errors | Informational | `LinearRewardsQuasiErc4626` / `SfrxUsd2OracleImplementation._previewPricePerShare` precision loss | Acknowledged (no explicit fix line in report body) |
| CS-FRUP-012 | Fee Can Be Set to Wrong Value | Informational | `FraxtalERC4626MintRedeemer` (`initialize` missing fee `< 1e18` check present in setter) | Code Corrected |
| CS-FRUP-016 | Missing Events | Informational | `StakedFrxUSD2.initialize`, `FraxtalERC4626MintRedeemer` (fee/oracle/owner events) | Code Corrected (note: still no events emitted in `initialize` functions) |
| CS-FRUP-017 | Reentrancy Guard Implementation | Informational | `FraxtalERC4626MintRedeemer` (non-upgradeable `ReentrancyGuard` in a proxied contract) | Acknowledged (storage-layout impact) |
| CS-FRUP-019 | Unnecessary Setters in the Constructor | Informational | `SfrxUsd2OracleImplementation` constructor (`_setAllowed`, owner left on implementation) | Acknowledged |
| CS-FRUP-020 | Users Can Lose Funds on Rounding | Informational | `FraxtalERC4626MintRedeemer` (`withdraw`/`deposit`/`mint`/`redeem` rounding to zero) | Risk Accepted |
| CS-FRUP-021 | `_previewPricePerShare` Should Be Internal | Informational | `LinearRewardsQuasiErc4626`, `SfrxUsd2OracleImplementation` (public helper, naming convention) | Code Corrected |
| CS-FRUP-022 | `calcPPSIPSForGivenAPY` Missing Input Validation | Informational | `LinearRewardsQuasiErc4626` (assumes `_apyE18 >= 1e18`, else `ln()` revert) | Code Corrected |
| CS-FRUP-023 | Price Initialization Mismatch | Low | `FraxtalERC4626MintRedeemer.initialize` (manually set price vs oracle price, backrunnable) | Code Corrected |
| Note §8.2 | Cross-chain Oracle Desynchronization Enables Arbitrage Opportunities | Note | sfrxUSD price feeds (Ethereum vs Fraxtal) | n/a (awareness) |
| Note §8.4 | Future Price and Rounding Errors | Note | `LinearRewardsQuasiErc4626` / `SfrxUsd2OracleImplementation` (`sync` rounding-down accumulation) | n/a (awareness) |
| Note §8.5 | Price Can Be Stale | Note | `FraxtalERC4626MintRedeemer` view functions use stored prices | n/a (awareness) |

**Partial-component remainders (for completeness):** CS-FRUP-015 item 2 (`SfrxUsd2OracleImplementation`
"Events" category name) and CS-FRUP-013 items 6–14 (StakedFrxUSD2 / LinearRewards / MintRedeemer gas
items) are likewise out of FXB scope; their FXB counterparts are EX-F05 and EX-F08 respectively.

**Cross-reference caution:** CS-FRUP-007 (proxy/implementation name vs domain-separator mismatch) and
CS-FRUP-009 (unenforced 18-decimal assumption) describe mechanisms that *could* have analogues in
FXB code. The reported instances are sfrxUSD-only and do not exclude a *proven, distinct* FXB instance —
but any such Hunter candidate must demonstrate the FXB-specific mechanism and cite the corresponding
§2 row to show it is not a re-report.

---

## §3. HEAD-verification summary

| EX-F ID | HEAD status |
|---------|-------------|
| EX-F01 | Verified still present (no rescue function) — excluded as known/unresolved |
| EX-F02 | Verified fixed |
| EX-F03 | Verified fixed |
| EX-F04 | Verified fixed |
| EX-F05 | Verified fixed (FXB part) |
| EX-F06 | Verified fixed (indexed params added; see residual note) |
| EX-F07 | Verified still as described (acknowledged, by design) |
| EX-F08 | Items 1–4 verified; **item 5 unverified** (identifier absent at HEAD, V1 history unavailable locally) |
| EX-F09 | Verified consistent with code |
| EX-F10 | **Unverified** (general statement, no file:line cited) |
| EX-F11 | n/a (scope statement) |
| EX-F12 | Corroborated at HEAD (`isRedeemable` owner branch) |
| EX-F13 | Corroborated at HEAD (mint comment + no maturity check; burn gated) |
| EX-F14 | Corroborated at HEAD (frxUSD burn in `initialize`) |
| EX-F15 | n/a (assumption statement) |
| EX-F16 | Corroborated at HEAD (version `"1.2.0"`) |

**Items whose fix status could NOT be verified at HEAD:** EX-F08 item 5 only, and EX-F10 (general
note). All other code-checkable exclusions were verified by direct source reads at HEAD. No
verification used `cast` (not installed) or any network call.
