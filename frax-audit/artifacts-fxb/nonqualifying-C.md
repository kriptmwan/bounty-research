# Hunter Domain C — Non-Qualifying Observations (factory / deployment + upgrade paths)

- **Hunter:** Domain C. **Target:** Frax FXB / Frax Bonds, Ethereum mainnet (live v1) + HEAD v2 comparison.
- **Result:** `hunter-findings-C.json` is `[]` — zero findings. Every candidate below was killed for a stated reason.
- **Repo pinned:** `~/workspace/frax-audit/repos/frax-bonds` @ `4ef235e68c8277ad3dbc676762fffe663c9896fc`, `git status` clean at time of audit. Live v1 factory file verified byte-identical (modulo 2 provenance header lines) to the Sourcify exact-match tree for `0x7a07D606c87b7251c2953A30Fa445d8c5F856C7A`.
- **FRAX BAR applied to every item:** demonstrated theft-of-funds or permanent-freezing path against a CURRENT LIVE mainnet deployment, with a working mainnet-fork PoC quantifying funds at risk. Anything failing any leg of that gate is recorded here, not reported.
- **No `cast`, no web browsing, no GitHub API calls** were used. Live-state claims are taken from `ONCHAIN-GROUNDWORK-FXB.md`, `fxb-addresses.json`, and `CORRESPONDENCE-FXB.md` (re-checked where relied on); code claims are from direct source reads cited by file:line.

## Verified-good invariants (checked, no defect — recorded so the report is honest about coverage)

- **V1-1 — Immutable FRAX, no setter.** Live `FXBFactory.sol` assigns `FRAX` once in the constructor (line ~60) and exposes no `setToken`, no `token()`, no setter of any kind. Grep of the whole v1-live tree finds no `setToken`, `initialize`, `delegatecall`, or `selfdestruct`. The backing token of live FXBs cannot be changed by any path. (HEAD's `setToken` is v2-only; see NQ-C-15.)
- **V1-2 — Factory not upgradeable.** Direct deployment; EIP-1967 implementation/admin/beacon slots all zero (groundwork §3.1, correspondence §4); no proxy, no upgrade function, no admin role. There is no upgrade authority over the live factory, any live FXB, or any live auction.
- **V1-3 — No initialization surface live.** V1 factory and v1 FXB are constructor-initialized; neither exposes `initialize`. No front-running / re-initialization path exists on any live contract.
- **V1-4 — Timelock2Step deployed == HEAD lib.** Diff of the deployed `Timelock2Step.sol` (Sourcify tree) against the HEAD submodule copy shows exactly one hunk: constructor parameter renamed `_timelockAddress` → `_timelock`. Semantically identical. All timelock reasoning below applies to the live code.
- **V1-5 — Registry live state consistent.** `fxbsLength()==5`, `fxbs(0..4)` distinct with `isFxb==true`, OOB reverts at 5/99, storage array length 5, factory nonce 6 (1 + 5 CREATEs), `pendingTimelockAddress==0`, `timelockAddress` = Safe `0x831822660572bd54ebaa065C2acef662a6277D40` (6 owners, threshold 3), `FRAX==0x853d955aCEf822Db058eb8505911ED77F175b99e` (fxb-addresses.json, groundwork §3.1).

---

## NQ-C-01 — Wednesday invariant not enforced; 4/5 live maturities are not Wednesdays

**Observation.** README.md:6 claims each FXB "always expires on a Wednesday, UTC 00:00". On-chain maturities: 2024-04-01 Monday, 2024-07-01 Monday, 2025-01-01 Wednesday, 2026-01-01 Thursday, 2027-01-01 Friday (recomputed independently from the five timestamps; matches groundwork §4).

**Attribution (determined, not guessed).**
- The factory is responsible for the *absence of enforcement*: neither the v1 nor HEAD `createFxbContract` checks the day of week at all. `getDayOfWeek` exists in `BokkyPooBahsDateTimeLibrary` but is never called by any factory code (repo-wide grep: only the library's own `isWeekDay`/`isWeekEnd` reference it, and nothing calls those either).
- The date library is NOT responsible: it computes the day-before names/symbols correctly — recomputation shows every live name/symbol matches `getYear/getMonth/getDay(coerced − 1 day)` exactly (e.g. maturity 1711929600 → day-before 2024-03-31 → `FXB_20240331` / `FXB_0_MAR312024`).
- The operator is responsible for the actual dates: all five maturities are 00:00 UTC on the 1st of a month (quarter/year boundaries), a deliberate choice inconsistent with any Wednesday rule.

**Kill reason:** no live consequence. Redemption in v1 `FXB.isRedeemable()` is purely `block.timestamp >= MATURITY_TIMESTAMP`; no contract logic anywhere keys on weekday. This is a documentation mismatch with zero fund impact — fails the FRAX bar (no theft/freezing path, no trigger, $0 at risk).

## NQ-C-02 — Maturity coercion rounds DOWN to 00:00 UTC; same-day creation impossible

**Observation.** V1 `FXBFactory.createFxbContract`: `_coercedMaturityTimestamp = (_maturityTimestamp / 1 days) * 1 days`, then reverts if `<= block.timestamp`. A timelock input of e.g. today 15:00 coerces to today 00:00 and reverts; an input of Wednesday 15:00 silently becomes Wednesday 00:00.

**Kill reason:** intended, documented-in-code behavior ("Round the timestamp down to 00:00 UTC"), identical in HEAD, covered by tests (`FXBFactoryTest.test_CreateFxbContract_BondMaturityAlreadyExpired_reverts`). Caller is the trusted Safe only; the coercion can only move maturity *earlier within the same day*, never past another bond's maturity (uniqueness is checked on the coerced value, NQ-C-03). No theft/freezing path; no funds at risk.

## NQ-C-03 — Metadata/name/symbol collision hypothesis — DISPROVED

**Hypothesis checked.** Two distinct maturities mapping to one name/symbol, letting users confuse bonds or letting a second bond shadow the first.

**Why it fails.** (a) The symbol is a pure function of the *coerced* maturity minus one day, and calendar-date decomposition is injective over day-granular timestamps — distinct coerced maturities yield distinct day-before dates, hence distinct `FXB_YYYYMMDD` symbols (year included, so same month/day in different years also differ). (b) Two inputs coercing to the same day are blocked by the `isTimestampFxb` duplicate check, which is keyed on the coerced value. (c) The name additionally embeds `id = fxbsLength()` at creation time, which is unique per creation. All five live (name, symbol) pairs are distinct, as predicted.

**Kill reason:** mechanism absent. No collision input exists.

## NQ-C-04 — Direct deployment bypass: an FXB can exist that the registry doesn't know

**Observation.** The v1 `FXB` constructor is public: anyone can deploy an `FXB` directly with arbitrary name/symbol/maturity/"FRAX" address, bypassing the factory. Such a contract has `isFxb == false` and no registry entry.

**Does anything trust the registry? Yes — exactly one live consumer, and it gates correctly.** `FxbAMO` (live operator `0x452420df…`, Sourcify-verified, out-of-repo) holds the factory as immutable `iFxbFactory` and its timelock-only `createAuctionContract` reverts `NotLegitimateBond()` unless `iFxbFactory.isFxb(_fxb)` (FxbAMO.sol:218-224). All AMO mint/redeem/withdraw paths further require `isFxbApproved`, which is only set via that gated creation. Repo-wide grep confirms no other contract reads `isFxb`/`fxbs`/`isTimestampFxb` (only tests and deploy scripts). The v1 FXB itself never consults the factory.

**Kill reason:** no theft path via the factory. An unregistered FXB is excluded from the only privileged consumer; it is a standalone ERC20 whose mint/burn are self-contained against whatever token address its deployer chose. User confusion with a lookalike token is a phishing/social risk, not a demonstrated on-chain theft path against live deployments, and no factory change could prevent arbitrary ERC20 deployment. Fails the FRAX bar. **Cross-reference:** `SlippageAuctionFactory.createAuctionContract` is permissionless, takes caller-chosen `_timelock/_tokenBuy/_tokenSell`, and does NOT check `isFxb` — whether an auction over a lookalike token is a finding belongs to the auction-factory domain, not Domain C; recorded here as an unresolved cross-reference, not a C finding.

## NQ-C-05 — Registry desync hypothesis (fxbs / isFxb / isTimestampFxb inconsistency) — DISPROVED

**Hypothesis checked.** Array/mapping divergence via reentrancy, partial failure, or a removal path.

**Why it fails.** V1 `createFxbContract` performs deployment then all three updates (`fxbs.push`, `isFxb=true`, `isTimestampFxb=true`) in one transaction with no removal function, no other writer, and no external call between the checks and the updates except the `new FXB` constructor — which makes no external calls (OZ `ERC20`/`ERC20Permit` constructors only write storage), so no reentrant callback into the factory is possible. A `CREATE` failure reverts the whole transaction. `id = fxbsLength()` before the push, so `fxbs[id] == fxb` holds by construction. Live state corroborates: exactly 5 entries, all consistent (V1-5).

**Kill reason:** mechanism absent.

## NQ-C-06 — `transferTimelock` to address(0) or a wrong address does not brick the factory

**Observation.** `Timelock2Step.transferTimelock` (live code, V1-4) accepts any address including `address(0)` with no validation.

**Kill reason:** no bricking and no fund impact. The current timelock retains full power until `acceptTransferTimelock` is called by the *pending* address; a mistaken nomination (including `0x0`, which can never accept) is fully recoverable because the current timelock can call `transferTimelock` again and overwrite `pendingTimelockAddress`. Live `pendingTimelockAddress == 0` (no transfer in flight). No theft/freezing path.

## NQ-C-07 — `renounceTimelock` permanently disables future FXB creation (real mechanism, sub-bar)

**Observation.** `Timelock2Step.renounceTimelock` requires `msg.sender` to be both current and pending timelock (so the Safe must first nominate itself), then sets timelock and pending to `address(0)`. After that, `createFxbContract` (and any further transfer/accept) can never succeed — `msg.sender` can never be `address(0)`. Future bond creation would be permanently disabled.

**Kill reason:** fails the FRAX bar on every leg. (a) Trigger requires the trusted 3-of-6 Safe to deliberately execute a designed 2-step renounce — an intended admin action, cf. EX-F12 (intended admin powers). (b) No existing funds freeze: live FXBs are immutable contracts with no factory dependency (no factory/timelock address in FXB bytecode, no callback); mint/burn continue exactly as before. Only *future creation* is disabled, and $0 of live funds is at risk. This is a governance-footgun observation, not a theft/freezing finding.

## NQ-C-08 — Constructor accepts zero `_timelock` / `_frax` with no validation

**Observation.** V1 factory constructor `Timelock2Step(_timelock)` + `FRAX = _frax` checks neither argument. A mis-deployment with `_timelock == 0` would be permanently unusable; `_frax == 0` would make all children mint against address 0.

**Kill reason:** deployment-time only. The live instance's values are verified correct on-chain (Safe + real FRAX, V1-5), `FRAX` is immutable, and the timelock can only change via the 2-step process (NQ-C-06/07). No live path, no funds at risk.

## NQ-C-09 — Event-shape mismatch: v1 `BondCreated` vs HEAD shape (indexers)

**Observation.** Live event: `BondCreated(address fxb, uint256 id, string symbol, string name, uint256 maturityTimestamp)` — no indexed params, no `token` field. HEAD event indexes `fxb`/`id` and carries `metadata` + `token`. Different signature ⇒ different topic0; an indexer written against the HEAD shape will not match live logs (confirmed as a divergence in correspondence D1).

**Kill reason:** (a) The indexing half is EX-F06 (ChainSecurity CS-FRUP-018, fixed at HEAD by adding indexed params) — re-reporting "events could be indexed" for the pre-fix v1 code is excluded. (b) No on-chain consumer can read events, and a repo-wide grep finds no off-chain consumer of `BondCreated` (only the factory's own emit/declaration). No live consumer was demonstrated to break, and no fund impact was demonstrated. Fails the FRAX bar. **Unresolved:** off-chain consumers outside this repo (frontend/subgraph) could not be checked from available evidence; absence of a demonstrated break is not proof no consumer exists — but an undemonstrated break is not a finding under the bar.

## NQ-C-10 — Timelock-vs-owner confusion between v1 and HEAD

**Observation.** HEAD `FXB.isRedeemable()` grants early burn to `Ownable(factory).owner()`; the live factory has no `owner()` (reverts) and the live FXB has no factory reference at all — its `isRedeemable()` is timestamp-only from every caller including the Safe (groundwork §4, three simulated callers + bytecode evidence).

**Kill reason:** mechanism absent live. The HEAD early-burn branch does not exist in any live contract, and no live code calls `owner()` on the factory. Any finding premised on it would misstate the live system. (The intended-admin-powers aspect is additionally EX-F12.)

## NQ-C-11 — `coerced − 1 days` underflow hypothesis — DISPROVED

**Hypothesis checked.** `_coercedMaturityTimestampDayBefore = _coercedMaturityTimestamp - 1 days` underflowing for tiny maturities.

**Why it fails.** The preceding check requires coerced maturity `> block.timestamp`, and `block.timestamp` on mainnet is ~1.79e9; coerced maturity is therefore always ≫ 1 day. Solidity 0.8 checked arithmetic would revert on underflow regardless.

**Kill reason:** mechanism absent.

## NQ-C-12 — Date-library edge behavior (post-2345, huge timestamps)

**Observation.** `BokkyPooBahsDateTimeLibrary` is tested to 2345-12-31; `_daysToDate` casts day counts to `int256`, so absurd maturities (near 2^255 seconds) revert rather than produce wrong dates.

**Kill reason:** no reachable harm. Creation is timelock-only, all live maturities are 2024–2027, and the failure mode is a revert (no bond created), not a wrong bond. No funds at risk.

## NQ-C-13 — Dead/unreachable code: `InvalidMonthNumber`, 5-digit years

**Observation.** `_monthNames` reverts `InvalidMonthNumber()` for months outside 1–12, but `getMonth` can only return 1–12 by construction, so the revert is unreachable. `_generateSymbol` uses unpadded `year.toString()`, so a year ≥ 10000 would lengthen the symbol.

**Kill reason:** cosmetic/dead code with no behavioral consequence. (Note: HEAD removed `InvalidMonthNumber` entirely per EX-F08 item 2.)

---

## V2-only issues — checked, killed for NO LIVE MAINNET INSTANCE

Phase 0 established, and this hunter re-verified from the cited evidence, that: no mainnet contract runs HEAD v2 code; there are no proxies on mainnet (all EIP-1967 slots zero, two independent passes); the Fraxtal factory is v1.1.0 `Timelock2Step`, not HEAD; Fraxtal FXBs use OZ `TransparentUpgradeableProxy`, not `FraxBeaconProxy`/`FraxUpgradeableProxy`; and Fraxtal is out of scope. Each item below is the strongest form of the issue, killed on that ground (plus any additional reason noted).

## NQ-C-14 — `FraxBeacon.setImplementation`: unchecked, immediate, single-owner implementation swap for ALL beacon proxies (strongest v2-only issue)

**Mechanism.** `FraxBeacon.sol:33-35` — `setImplementation` is `onlyOwner`, with no zero-address check, no code check, and no timelock/delay. The owner can point every `FraxBeaconProxy` at an arbitrary implementation (including an EOA — bricking — or a malicious contract that could drain proxy-held collateral) in a single transaction. `FraxBeacon` ownership transfer is 2-step (`Ownable2Step`), but implementation changes are not.

**Kill reason:** NO LIVE INSTANCE. No beacon proxy exists on mainnet; Fraxtal FXBs point at a shared OZ-proxy implementation, not a `FraxBeacon`. Additionally the beacon owner is a fully trusted admin under the audit trust model (R2 §2.3; EX-F12 intended upgrade powers), and the beacon-change concern itself is the subject of exclusion EX-F09 (ChainSecurity Note §8.1). Fails the FRAX bar: no live instance, no live funds at risk.

## NQ-C-15 — HEAD `FXBFactory.setToken`: unchecked token swap for future bonds, no event

**Mechanism.** `FXBFactory.sol:192` (HEAD) — `onlyOwner`, sets `token` to any address including `0x0`/a malicious token, with no validation and no event. Subsequently created FXBs would mint/burn against the new token while pre-existing bonds keep their old backing (the divergence documented in EX-F09).

**Kill reason:** NO LIVE INSTANCE (live factory has immutable `FRAX` and no `setToken`, V1-1) + EX-F09 exclusion (the `setToken` divergence behavior is a documented ChainSecurity awareness note) + owner-only trusted admin. No live funds at risk.

## NQ-C-16 — HEAD `FXBFactory.initialize`: hardcoded Fraxtal pre-registration + no `_token` validation

**Mechanism.** `initialize` hardcodes 4 Fraxtal FXB addresses into `fxbs[]`/`isFxb`/`isTimestampFxb` without verifying they are beacon proxies or share the factory's beacon/token — so beacon upgrades never affect them and their backing (frxUSD/LFRAX) diverges from `token` (EX-F09). `_token` is stored unchecked (an `_owner` of `0x0` is blocked by OZ `Ownable._transferOwnership`, but `_token == 0` is not; it would only break future creations, fixable via `setToken`).

**Kill reason:** NO LIVE INSTANCE — the Fraxtal factory on-chain is v1.1.0 `Timelock2Step` (no `beacon()`/`token()`/`owner()`), not this HEAD code (correspondence D5); mainnet runs v1. The pre-registration/beacon-divergence behavior is EX-F09-excluded. No live funds at risk.

## NQ-C-17 — HEAD factory `initialize` front-running — CHECKED, no window in the scripted path

**Checked.** HEAD factory's constructor calls `_disableInitializers()`, and `initialize` carries the `initializer` modifier. The deploy scripts (`DeployFXBFactory.s.sol`, both `deployFXBFactory` and `deployFXBFactoryManual`) deploy `FraxUpgradeableProxy` with the `initialize` calldata in the proxy constructor, so initialization executes atomically in the deployment transaction — no front-running window in the scripted path. A hypothetical manual proxy deployment with delayed initialization is not the deployed procedure and no such instance exists.

**Kill reason:** no window in the actual deployment path + NO LIVE INSTANCE anywhere.

## NQ-C-18 — `FraxBeaconProxy.getBeacon()` selector reservation + payable fallback

**Mechanism checked.** `FraxBeaconProxy` adds a public `getBeacon()` view and a payable `fallback()` override on top of OZ `BeaconProxy`. A public proxy-level function reserves its selector: if an implementation defined `getBeacon()` it would be shadowed. The payable fallback lets the proxy receive ETH, which `FXB` has no path to withdraw.

**Kill reason:** NO LIVE INSTANCE. Additionally no clash exists with the actual implementations (`FXB`/`FXB_LFRAX` define no `getBeacon`), and ETH stickiness via the fallback has no demonstrated fund path (no one is directed to send ETH to a bond proxy). No live funds at risk.

## NQ-C-19 — `FraxBeacon` owner renounce freezes the implementation forever

**Mechanism.** `Ownable2Step` inherits OZ `renounceOwnership`: the beacon owner can set owner to `address(0)` in one call, after which `setImplementation` can never be called again and all beacon proxies are frozen on the current implementation.

**Kill reason:** NO LIVE INSTANCE + trusted-owner intended OZ behavior (cf. EX-F12). No live funds at risk.

## NQ-C-20 — `FraxUpgradeableProxy.changeAdmin`: single-step, unchecked admin transfer (zero address bricks upgrades)

**Mechanism.** `FraxUpgradeableProxy.sol:52-55` — the admin can call `changeAdmin` with any address, including `address(0)`, in one step with no 2-step confirmation. Setting admin to `0x0` (or a wrong address) permanently disables `upgradeToAndCall` (proxies keep functioning on the current implementation). The transparent-proxy `_fallback` gating itself (admin-only `changeAdmin`/`upgradeToAndCall`, `ProxyDeniedAdminAccess` otherwise) was checked and behaves as the intended OZ-5.0-equivalent pattern; `implementation()`/`admin()` views collide with no function in the intended implementations.

**Kill reason:** NO LIVE INSTANCE on either chain — Fraxtal uses OZ `TransparentUpgradeableProxy` bytecode (identical 3,959-byte code hash across all Fraxtal proxies, correspondence §2b), mainnet uses no proxies at all. Admin is a trusted ProxyAdmin/Safe in every deployment plan. No live funds at risk.

## NQ-C-21 — `StorageSetterLFRAX` arbitrary-slot-write danger — DISPROVED as exposed + no live proxy

**Hypothesis checked (per brief).** A transient upgrade helper with arbitrary storage writes, callable by anyone while it is a proxy implementation, could corrupt LFRAX proxy storage (balances, allowances, admin slots).

**Why it fails on both legs.**
1. *No arbitrary write is exposed.* `StorageSetterLFRAX.sol` exposes exactly one writer: `setNameAndSymbol()` (public, no access control), which writes two FIXED values to two FIXED slots — slot 3 = `bytes32("Legacy Frax Dollar") | 36` (18 chars × 2, correct short-string encoding) and slot 4 = `bytes32("LFRAX") | 10` (5 chars × 2, correct). It is idempotent: calling it repeatedly, by anyone, writes the intended name/symbol. The dangerous functions (`clearSlotZero`, `clearSlotOZ5Zero`) exist only as commented-out code. All other exposed functions are view getters (`getBytes32/getUint/getAddress/getBool`) over public storage. The stale natspec ("only allows clearing slot 0…") describes the commented-out code, not the live code — a doc mismatch, not a vulnerability.
2. *No live proxy points at it.* On Fraxtal, the LFRAX proxy's implementation slot currently holds `0x17Fd…` (LFRAX v1.3.0), not the StorageSetter `0x63aD…` (correspondence §2b/§4); the StorageSetter step completed and was superseded. On mainnet there is no StorageSetter deployment at all (0B sweep: no code at the address on chain 1; no mainnet proxy exists for it to serve). Even during the transient window when it WAS the LFRAX implementation, leg 1 shows the only writable effect was the intended name/symbol.

**Kill reason:** no arbitrary-write surface + no live proxy + Fraxtal out of scope. No live funds at risk. **Verification note:** the Fraxtal StorageSetter is Sourcify-404; the HEAD-consistency claim rests on the strong behavioral fingerprint in correspondence D6 (all 6 selectors + `version()` `"1.2.1-beta.2"` + embedded strings match HEAD exactly). Source equality is unproven but the conclusion does not depend on it: the *deployed standalone* contract at `0x63aD…` is not any proxy's implementation today.

## NQ-C-22 — `Storage.sol` assembly setters write unmasked values to arbitrary slots

**Observation.** `Storage.sol` provides internal `setAddress/setUint/setBytes32/setBool` doing raw `sstore` to caller-supplied slots, with WARNING natspec on each.

**Kill reason:** unreachable as an arbitrary-write primitive. The functions are `internal` library functions; repo-wide grep shows the ONLY contract importing `Storage` is `StorageSetterLFRAX`, which calls only `setBytes32` with fixed slot/value pairs (NQ-C-21). `setAddress`/`setUint`/`setBool` have zero callers anywhere in the repo. No live instance of any consumer on mainnet. Dead-code surface, no trigger, no funds at risk.

## NQ-C-23 — `EIP712StoragePad` storage-layout preservation for the FXB_LFRAX upgrade

**Checked.** `EIP712StoragePad.sol` declares two private strings (`DEPRECATED___nameFallback`, `DEPRECATED___versionFallback`) and no functions; `FXB_LFRAX` inherits it (5th in its inheritance list) to preserve storage order across the Fraxtal proxy upgrade. Whether the pad's position/size exactly matches the pre-upgrade implementation's layout cannot be verified from available evidence: the pre-upgrade FXB implementation addresses are unrecoverable (pruned state/logs, correspondence §4) and the current implementation is unverified. Behavioral evidence is consistent with a correct layout: all four Fraxtal proxies report correct name/symbol, maturity, `token()`, `frxUSD()`, and `factory()` through the upgraded implementation (correspondence D6).

**Kill reason:** NO LIVE MAINNET INSTANCE — `FXB_LFRAX`/`EIP712StoragePad` are Fraxtal-upgrade-only and out of scope; the generic "upgrade changes the interface" concern is additionally EX-F10. Recorded as an **unresolved cross-reference** for the FXB_LFRAX domain hunter (layout correctness needs the pre-upgrade implementation source, which is unavailable), not as a Domain C finding. No live mainnet funds at risk.

## NQ-C-24 — HEAD factory upgrade storage-layout corruption (generic)

**Checked.** HEAD factory is designed to sit behind `FraxUpgradeableProxy` (deploy scripts + `test_UpgradeFactory_succeeds`, which upgrades to a storage-identical subclass). No specific layout defect was found: factory state (`beacon`, `token`, `fxbs`, mappings) uses ordinary sequential slots, OZ `Ownable2StepUpgradeable` uses namespaced (ERC-7201) storage, and ERC-1967 proxy slots cannot collide with either. A future implementation with reordered storage could corrupt state, but no such implementation exists in the repo and no factory proxy is live.

**Kill reason:** no specific defect + NO LIVE INSTANCE. Generic upgrade risk, not a finding.

## NQ-C-25 — Shared beacon implementation: one upgrade moves ALL beacon-proxy bonds

**Observation.** By beacon design, changing `FraxBeacon.implementation` upgrades every `FraxBeaconProxy` simultaneously — a single faulty/malicious implementation affects all bonds at once, with no per-bond opt-out or staged rollout.

**Kill reason:** intended beacon architecture, documented in the beacon's own natspec and in the audit scope docs; the beacon-change concern is EX-F09; and NO LIVE INSTANCE exists on mainnet. No live funds at risk.

---

## Files scanned / skipped / evidence read

**Assigned files — all read in full, none skipped:**
1. `~/workspace/frax-audit/work/v1-live/src/contracts/FXBFactory.sol` (222 lines, PRIMARY, live) — read in full.
2. `repos/frax-bonds/src/contracts/FXBFactory.sol` (HEAD, 223 lines) — read in full.
3. `repos/frax-bonds/src/contracts/FraxBeacon.sol` — read in full.
4. `repos/frax-bonds/src/contracts/FraxBeaconProxy.sol` — read in full.
5. `repos/frax-bonds/src/contracts/FraxUpgradeableProxy.sol` — read in full.
6. `repos/frax-bonds/src/contracts/utils/StorageSetterLFRAX.sol` — read in full.
7. `repos/frax-bonds/src/contracts/utils/Storage.sol` — read in full.
8. `repos/frax-bonds/src/contracts/utils/EIP712StoragePad.sol` — read in full.

**Evidence read (not report scope):** v1 `FXB.sol` + `BokkyPooBahsDateTimeLibrary.sol` (full); `Timelock2Step.sol` v2 (full, + Sourcify diff vs deployed tree); `FXBFactoryTest.t.sol` (full); `DeployFXBFactory.s.sol` (full); `SlippageAuctionFactory.sol` create function; HEAD `FXB.sol` initialize/`isRedeemable` + `FXB_LFRAX.sol` inheritance/initialize excerpts; `FxbAMO.sol` registry usages (from Sourcify record `1_0x452420df….json`); LFRAX upgrade scripts (grep for factory/beacon/upgrade references — no factory/beacon calls; scripts only upgrade LFRAX + FXB proxies via ProxyAdmin); `FXB_UPGRADE_NOT_V2_WALKTHROUGH.md` + `AUDIT_SCOPE_LFRAX_AND_FXB_UPGRADE.md` (factory/beacon mentions); `EXCLUSION_LIST_FXB.md` (full, 16 items); `ONCHAIN-GROUNDWORK-FXB.md` (full); `CORRESPONDENCE-FXB.md` (full); `fxb-addresses.json` (factory section + counts); `DELTA-2023-2025.md` (grep: no factory/beacon mentions).

**Skipped:** none of the assigned files. Test files other than `FXBFactoryTest.t.sol` were used only via grep (intended-behavior context). `lib/` vendored code was not audited (OZ + frax-std treated as dependencies, except the `Timelock2Step` diff check above).

## Unresolved cross-references

1. **EIP712StoragePad layout (NQ-C-23):** pre-upgrade Fraxtal FXB implementation source unrecoverable from available evidence; layout correctness unverifiable. Fraxtal-only; no mainnet implication.
2. **Off-chain `BondCreated` consumers (NQ-C-09):** no consumer found in-repo; consumers outside the repo (frontend/subgraph/indexer) could not be checked. No demonstrated breakage.
3. **Direct-deployment exclusion residual (NQ-C-04):** factory nonce + registry + storage prove exactly 5 factory-created FXBs; directly-deployed lookalikes cannot be fully excluded without the event-log search owed in groundwork §10 items 3–4 (RPC `eth_getLogs` unavailable). The registry-trust conclusion does not depend on this: any direct deployment has `isFxb == false` by construction and is excluded from FxbAMO.
4. **Auction-factory gating (NQ-C-04):** `SlippageAuctionFactory` does not check `isFxb`; referred to the auction-factory domain.
5. **Fraxtal StorageSetter/FXB_LFRAX source equality:** both Sourcify-404; HEAD-consistency rests on behavioral fingerprints only (correspondence D6). Fraxtal out of scope; does not affect any mainnet conclusion.
