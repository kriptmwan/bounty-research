# Nexus (bcnmy/nexus) — Issue-tracker DELTA, 2026-11-14

**Sweep date:** 2026-11-14 (WIB). **Baseline:** `EXCLUSION_LIST.md` built 2026-11-13
(17 open issues #106–#321 + 30 closed issues, highest recorded number **#324**,
filed and closed 2026-11-13). **This file covers the DELTA since that pass only.**
Do NOT edit `EXCLUSION_LIST.md` — the coordinator merges this file.

**Method (read-only):** `browser.search` + `browser.open` on public github.com pages
only. **Zero `api.github.com` calls** (rate-limited/stopped from this VM — no calls,
no retries, no endpoint-switching). No contact with Biconomy, no filing, no login.
The open-issues list page was crawled fresh 2026-11-14 02:48 UTC (09:48 WIB) and
showed **Open (31)**. All 14 new issue bodies below were read in full via
`browser.open`. Issue comments were NOT read. Timestamps marked "Published" are
the per-issue UTC timestamps shown on each issue page; WIB = UTC+7. The list page
dates all 14 as "opened on Nov 13, 2026" (UTC dating); #332–#338 fall on Nov 14
in WIB.

## Counts

| Category | Count |
|---|---|
| New open issues (#325–#338) | **14** (all still Open at crawl time) |
| New closed issues (numbered above #324) | **0 observed** (see Status changes — limits apply) |
| Status changes (open→closed or closed→reopened) after 2026-11-13 | **0 observed** (see Status changes — limits apply) |
| New published security advisories (GHSA) beyond GHSA-q47q-h6x2-f5qg | **0** |
| New audit-report mentions for the nexus repo dated after 2026-11-13 | **0** |

**This is NOT a "nothing new" sweep:** 14 new bounty-style reports were filed
2026-11-13 (UTC) in a second filing burst, mirroring the Nov 11–13 burst noted in
the baseline. Eight of them touch the highest-duplicate-risk surfaces for the
running Option 2 audit (see Flags section). Three are stx-contracts-only reports
filed on the nexus tracker (#336, #337, #338) — recorded here as known tracker
items, but their mechanisms do not exist in the nexus 1.2.1 `main` code.

---

## New issues (#325–#338, all Open)

### #325 — NexusBootstrap.initNexus (generalized flow) lacks the zero-address skip for validator entries, reverting the entire initialization
- **Status:** Open. **Opened:** 2026-11-13T15:23:24Z (22:23 WIB, 2026-11-13). **Closed:** —.
- **Severity:** Not stated in title/body (bug-report template).
- **Root cause:** The `_initNexus` validators loop has no `address(0)` skip, unlike
  the sibling `_initNexusWithDefaultValidatorAndOtherModules` flow and the
  executors/fallbacks/preValidationHooks loops in the same function. A single
  zero-address validator entry calls `IValidator(address(0)).isModuleType()`,
  which returns false, reverting the whole initialization with
  `MismatchModuleTypeId` — and since the flow runs inside the `NexusProxy`
  constructor, the deployment fails and that CREATE2 address becomes unobtainable.
- **Source:** https://github.com/bcnmy/nexus/issues/325
- **Note:** Install/init-adjacent. The delta's `validators[]` param + loop lives in
  the flow that HAS the skip; this report is about the generalized flow that lacks
  it. Flagged below.

### #326 — Emergency hook uninstall: signature nonce burned at initiation makes the 3-day reset path a dead end for the original signature
- **Status:** Open. **Opened:** 2026-11-13T15:24:29Z (22:24 WIB, 2026-11-13). **Closed:** —.
- **Severity:** Not stated in title/body (bug-report template).
- **Root cause:** `_checkEmergencyUninstallSignature` marks the nonce consumed at
  INITIATION time (the first call only starts the 1-day timelock), so after the
  3-day auto-reset the original signature can never complete the removal
  (reverts `InvalidNonce`) and a fresh signature with a new nonce is required.
  Additionally the reset branch is checked BEFORE the uninstall branch, so at
  exactly t+3d the reset wins and resurrects the timelock instead of uninstalling.
- **Source:** https://github.com/bcnmy/nexus/issues/326
- **Note:** **FLAG — emergency uninstall.** Distinct mechanism from #332 (hook-keyed
  clock) and from Pashov L-08 stale timelock (EX-063).

### #327 — Stale/incorrect natspec: nonce layout in validateUserOp and onInstall/onUninstall reference in uninstallModule
- **Status:** Open. **Opened:** 2026-11-13T15:26:13Z (22:26 WIB, 2026-11-13). **Closed:** —.
- **Severity:** Not stated (docs-only).
- **Root cause:** Two natspec statements in `Nexus.sol` contradict the code: the
  `validateUserOp` natspec says the validator address is encoded in the upper 96
  bits of the nonce, while the actual `NonceLib` layout is [3 bytes empty][1 byte
  validation mode][20 bytes validator][8 bytes nonce]; and the `uninstallModule`
  natspec says the underlying functions call `module.onInstall()` when they call
  `IModule.onUninstall`.
- **Source:** https://github.com/bcnmy/nexus/issues/327
- **Note:** Non-security docs item. No code mechanism; record for completeness.

### #328 — Malformed boundary calldata produces raw Solidity panics instead of the documented typed errors across install/execute/init paths
- **Status:** Open. **Opened:** 2026-11-13T15:28:42Z (22:28 WIB, 2026-11-13). **Closed:** —.
- **Severity:** Not stated in title/body (bug-report template).
- **Root cause:** Four unguarded slicing/parsing boundaries panic with 0x32
  (array out-of-bounds) instead of reverting with their documented typed errors:
  `_installFallbackHandler` does `bytes4(params[0:4])` / `bytes1(params[4])` with
  no length check; `ExecLib.decodeSingle` slices `executionCalldata[0:20]` /
  `[20:52]` unguarded; the `initializeAccount` 7702 branch slices `initData[0:65]`
  before `_initializeAccount`'s length check; and `parseEnableModeData` reads
  lengths/offsets with raw `calldataload` and panics when the offset exceeds the input.
- **Source:** https://github.com/bcnmy/nexus/issues/328
- **Note:** **FLAG — touches all four high-risk surfaces:** ModuleManager install
  (`_installFallbackHandler`), execution (`ExecLib.decodeSingle`), Nexus
  validation/init (7702 `initializeAccount` branch), and enable mode
  (`parseEnableModeData`). All paths are EntryPoint/self-gated per the reporter.

### #329 — Account can be initialized with zero validators while the uninstall path enforces 'at least one validator must remain'
- **Status:** Open. **Opened:** 2026-11-13T15:30:09Z (22:30 WIB, 2026-11-13). **Closed:** —.
- **Severity:** Not stated in title/body (bug-report template).
- **Root cause:** The init flows `_initNexus` / `_initNexusScoped`
  (`NexusBootstrap.sol`) accept an empty `validators` array with no post-loop
  assertion, producing an account whose sentinel lists are initialized and whose
  `isInitialized()` returns true yet has no installed validator at all. The
  uninstall path enforces the at-least-one-validator invariant
  (`CanNotRemoveLastValidator` via `_checkInitializedValidators`), so the
  invariant is asymmetric: unreachable by uninstalling, reachable by deploying
  directly into it — in which state enable mode, emergency-uninstall routing,
  and default-validator validation misbehave or the account is inoperable.
- **Source:** https://github.com/bcnmy/nexus/issues/329
- **Note:** **FLAG — init + uninstall invariant.** Adjacent to Pashov M-02
  (EX-055, the fix whose guard this report contrasts) and to Cantina info
  5.5.20 (EX-I20, `initializeAccount` validator check). Distinct claim: the
  empty-array init path itself, not the guard's loop.

### #330 — [Low] Multi-type module install silently drops unknown module type IDs while reporting success
- **Status:** Open. **Opened:** 2026-11-13T15:54:08Z (22:54 WIB, 2026-11-13). **Closed:** —.
- **Severity:** Low (reporter).
- **Root cause:** `ModuleManager._multiTypeInstall`'s if/else-if chain over the
  known module types has no final `else` branch, so an unknown type id is
  silently skipped while the transaction succeeds and emits
  `ModuleInstalled(0, module)` — unlike the single-type `_installModule`, which
  reverts `InvalidModuleTypeId`.
- **Source:** https://github.com/bcnmy/nexus/issues/330
- **Note:** **FLAG — ModuleManager install. DUPLICATE of known root cause:**
  identical to #319 (EX-071) and closed #322 (EX-086). Third/fourth filing of
  the same mechanism; do not file.

### #331 — [Low] isValidSignature reverts on malformed signatures instead of returning 0xffffffff (ERC-1271)
- **Status:** Open. **Opened:** 2026-11-13T15:54:13Z (22:54 WIB, 2026-11-13). **Closed:** —.
- **Severity:** Low (reporter).
- **Root cause:** In `Nexus.isValidSignature`, the validator-prefix parsing
  (`signature[0:20]`) and `_handleValidator()` lookup run OUTSIDE the try/catch
  that only protects the validator call, so 0–19-byte signatures panic on the
  out-of-bounds slice and signatures whose first 20 bytes are not an installed
  validator revert with `ValidatorNotInstalled`, instead of returning `0xffffffff`.
- **Source:** https://github.com/bcnmy/nexus/issues/331
- **Note:** **FLAG — Nexus.sol validation. DUPLICATE of known root cause:**
  same pre-try/catch slicing mechanism as #306 (EX-078) and closed #324
  (EX-088); this filing additionally names the unknown-validator-prefix revert
  variant explicitly. Same mechanism family; do not file either variant.

### #332 — Emergency-uninstall timelock is keyed by hook only — a later request executes on an earlier request's clock
- **Status:** Open. **Opened:** 2026-11-13T19:00:17Z (02:00 WIB, 2026-11-14). **Closed:** —.
- **Severity:** Low (reporter, stated in body).
- **Root cause:** `emergencyUninstallTimelock` is keyed by hook address only — not
  by nonce or `deInitData` — so a later, different emergency-uninstall request
  for the same hook (different nonce, different `deInitData`) executes as soon
  as the FIRST request's 1-day clock expires, compressing the second request's
  own 1-day review window to whatever remains of the first clock. Authorization
  is still enforced per request (a valid signature is required); the defect is
  clock-sharing across distinct requests.
- **Source:** https://github.com/bcnmy/nexus/issues/332
- **Note:** **FLAG — emergency uninstall, HIGHEST duplicate-risk among the delta's
  novel mechanisms.** Reporter explicitly distinguishes it from #326 (nonce burn /
  reset ordering) and Pashov L-08 (EX-063, stale timelock after removal via
  another path); the PoC uses two distinct valid nonces and never exercises the
  #326 mechanism. Treat as a NEW known mechanism on the emergency-uninstall surface.

### #333 — [Low] Multi-type module install silently ignores unknown types and malformed initData
- **Status:** Open. **Opened:** 2026-11-13T19:47:53Z (02:47 WIB, 2026-11-14). **Closed:** —.
- **Severity:** Low (reporter).
- **Root cause:** Two compounding gaps: (1) `LocalCallDataParserLib.parseMultiTypeInitData`
  is hand-rolled assembly documented as equivalent to
  `abi.decode(initData, (uint[], bytes[]))` but performs no bounds or length
  checks — `calldataload` beyond the end of calldata returns zero, so
  truncated/garbage `initData` decodes to empty arrays and the install loop
  never runs; and (2) `_multiTypeInstall` has no final `else revert`, so unknown
  type ids are silently skipped — while `Nexus.installModule` unconditionally
  emits `ModuleInstalled`, so callers and indexers see a successful install that
  installed nothing.
- **Source:** https://github.com/bcnmy/nexus/issues/333
- **Note:** **FLAG — ModuleManager install + parser.** Gap (2) DUPLICATES #319
  (EX-071) / #322 / #330. Gap (1), the parser's missing bounds checks, is the
  reporter's stated NEW contribution (prior CodeHawks submission #193 did not
  cover it) — treat the parser half as a NEW known mechanism. Also present in
  stx-contracts 1.3.3 per the reporter (identical parser + chain).

### #334 — [Low] K1Validator.validateSignatureWithData returns true for malformed signatures when data encodes the zero address
- **Status:** Open. **Opened:** 2026-11-13T19:49:17Z (02:49 WIB, 2026-11-14). **Closed:** —.
- **Severity:** Low (reporter).
- **Root cause:** `K1Validator.validateSignatureWithData` takes the expected owner
  straight from caller-supplied `data` with no zero-address check, and Solady's
  `tryRecoverCalldata` returns `address(0)` on any recovery failure — so when
  `data` encodes `address(0)`, any malformed signature (including an empty one)
  "validates" via `0 == 0`. The Zenith H-1 fix (`getOwner` fallback) covers only
  the `validateUserOp` / `isValidSignature` paths, not this function.
- **Source:** https://github.com/bcnmy/nexus/issues/334
- **Note:** **DUPLICATE of known root cause:** identical to #307 (EX-077) and
  closed #323 (EX-087). Reporter additionally verifies the same defect in the
  1.3.3 lineage (`K1MeeValidator` via `NoMeeFlowLib`/`EcdsaHelperLib`). No
  in-repo caller passes a zero owner today (Low). Validation-adjacent; not one
  of the four flagged Nexus/ModuleManager surfaces, but excluded all the same.

### #335 — [Low] Nexus.isValidSignature reverts instead of returning 0xffffffff for malformed signatures
- **Status:** Open. **Opened:** 2026-11-13T19:51:02Z (02:51 WIB, 2026-11-14). **Closed:** —.
- **Severity:** Low (reporter).
- **Root cause:** `Nexus.isValidSignature` wraps only the validator call in a
  try/catch returning `0xffffffff`; the validator-address extraction
  (`signature[0:20]`) and `_handleValidator` resolution happen BEFORE it, so a
  signature shorter than 20 bytes panics on the slice and a signature whose
  20-byte prefix is not an installed validator reverts `ValidatorNotInstalled`
  instead of returning `0xffffffff`.
- **Source:** https://github.com/bcnmy/nexus/issues/335
- **Note:** **FLAG — Nexus.sol validation. DUPLICATE of known root cause:**
  same mechanism as #306 (EX-078) / #324 (EX-088) / #331. Reporter states it is
  present in both 1.2.1 (`main` @ `9007ba1`) and the deployed 1.3.3 lineage
  (identical code). Do not file either variant.

### #336 — [Medium] Simple-mode ERC-1271 signatures replay across same-owner Nexus accounts
- **Status:** Open. **Opened:** 2026-11-13T21:37:59Z (04:37 WIB, 2026-11-14). **Closed:** —.
- **Severity:** Medium (reporter).
- **Root cause:** In `bcnmy/stx-contracts` (default branch, commit `61001d0`),
  `HashLib.hashTypedDataForAccount()` rebuilds the EIP-712 domain separator from
  the account name only ("Nexus", a constant for every account), ignoring
  `chainId`, `verifyingContract`, and version — and the explicit account binding
  (`keccak256(dataHash, account)`) is applied only to Permit and On-Chain modes,
  not to Simple mode — so a Simple-mode SuperTx signature made for one Nexus
  account validates on any other Nexus account with the same owner. The ERC-4337
  `validateUserOp` path is NOT affected (the userOpHash binds sender + chainId);
  this is ERC-1271-only.
- **Source:** https://github.com/bcnmy/nexus/issues/336
- **Note:** **stx-contracts ONLY** (`K1MeeValidator`, `HashLib`, SuperTx/MEE
  code). No `SuperTx`/`MeeUserOp`/`HashLib` code exists in the nexus 1.2.1 repo,
  so there is no 1.2.1 mechanism to duplicate — but it is a known tracker item
  filed on the nexus repo. Do NOT treat as a Nexus.sol validation finding for
  the Option 2 audit; record for lineage completeness. Reporter notes Pashov
  2025-10-16 [L-03] covered the domain separator only as a cross-chain UX issue.

### #337 — [Medium] tx.origin authorization in NodePaymaster lets a tricked operator sponsor arbitrary attacker userOps
- **Status:** Open. **Opened:** 2026-11-13T21:38:16Z (04:38 WIB, 2026-11-14). **Closed:** —.
- **Severity:** Medium (reporter).
- **Root cause:** In `bcnmy/stx-contracts` (commit `61001d0`),
  `NodePaymaster._validatePaymasterUserOp` accepts all userOps and the only gate
  is `tx.origin == owner() || _workerEOAs[tx.origin]`; a node operator tricked
  into calling a malicious contract from the owner/worker EOA lets the attacker
  bundle arbitrary userOps through `EntryPoint.handleOps`, draining the
  paymaster deposit via sponsored gas plus DAPP-mode refunds to an
  attacker-controlled `refundReceiver` parsed straight from `paymasterAndData`.
- **Source:** https://github.com/bcnmy/nexus/issues/337
- **Note:** **stx-contracts ONLY** (`contracts/node-pm/`). No NodePaymaster code
  exists in the nexus 1.2.1 repo. Known tracker item; no Option 2 duplicate-risk.
  Reporter honestly notes the code documents `tx.origin` use as intentional and
  the Zenith node-pm audit report does not mention `tx.origin`.

### #338 — [Low] validateSignatureWithData accepts address(0) as owner — any garbage signature validates
- **Status:** Open. **Opened:** 2026-11-13T21:38:39Z (04:38 WIB, 2026-11-14). **Closed:** —.
- **Severity:** Low (reporter).
- **Root cause:** In `bcnmy/stx-contracts` (commit `61001d0`),
  `K1MeeValidator.validateSignatureWithData()` only checks `data.length >= 20`,
  then takes the owner from `data[:20]` with no zero-address check; a non-MEE-
  prefixed signature routes to `NoMeeFlowLib` → `EcdsaHelperLib`, where Solady
  `tryRecover` returns `address(0)` for invalid signatures, so `0 == 0` returns
  true for any hash — despite `EcdsaHelperLib`'s own doc warning never to pass
  `address(0)` as `expectedSigner`.
- **Source:** https://github.com/bcnmy/nexus/issues/338
- **Note:** **stx-contracts ONLY** (1.3.3 `K1MeeValidator`). Same root-cause
  family as #307 (EX-077) / #323 / #334, in the other lineage — consistent with
  the baseline §F note that `K1MeeValidator.validateSignatureWithData` still
  takes the owner from caller data with no zero check. Known tracker item.

---

## Flags — highest duplicate-risk for the Option 2 audit

Flagged = root cause touches `Nexus.sol` validation/execution, ModuleManager
install/uninstall/hooks, enable mode, or emergency uninstall. **Hunters must not
claim any of these mechanisms.**

| Issue | Surface | Novel vs baseline? |
|---|---|---|
| #326 | Emergency uninstall (nonce burn + 3-day reset dead end) | **Novel mechanism** |
| #328 | ModuleManager install + execution + Nexus 7702 init + enable-mode parsing (panics) | **Novel mechanism** (four boundaries; enable-mode parser boundary overlaps #333's parser claim) |
| #329 | Bootstrap init + uninstall invariant (zero-validator init) | **Novel mechanism** (contrast to the M-02 guard, not the guard's loop) |
| #330 | ModuleManager install (`_multiTypeInstall` no-else) | Duplicate of #319 / #322 |
| #331 | Nexus.sol validation (`isValidSignature` pre-try/catch) | Duplicate of #306 / #324 (adds unknown-prefix variant) |
| #332 | Emergency uninstall (hook-keyed timelock clock-sharing) | **Novel mechanism** |
| #333 | ModuleManager install + `LocalCallDataParserLib` (no-else + parser bounds) | No-else duplicates #319; **parser bounds half is novel** |
| #335 | Nexus.sol validation (`isValidSignature` pre-try/catch) | Duplicate of #306 / #324 / #331 |
| #325 | Bootstrap install (`_initNexus` zero-address validator) | **Novel mechanism** (install/init-adjacent; sibling of the delta's `validators[]` loop) |

Not flagged (recorded above, still excluded as known tracker items): #327
(docs-only), #334 (K1Validator duplicate of #307), #336/#337/#338 (stx-only).

**Duplicate clusters extended by this delta** (for the coordinator's appendix):
- `_multiTypeInstall` silent skip: EX-071 (#319), EX-086 (#322), #330, #333 (gap 2).
- Short/malformed-signature revert in `isValidSignature`: EX-078 (#306),
  EX-088 (#324), #331, #335.
- Zero-owner + `tryRecover` returns-0 in `validateSignatureWithData`: EX-077
  (#307), EX-087 (#323), #334 (1.2.1), #338 (1.3.3).
- Emergency-uninstall mechanisms now known: Pashov L-08 stale timelock (EX-063),
  oracle confusion (EX-073/#310, EX-074/#312), #326 (nonce burn/reset),
  #332 (hook-keyed clock) — four distinct mechanisms; file none of them.

---

## Status changes after 2026-11-13

**Observed: none.** Evidence and limits, stated honestly:

- The fresh open-issues list crawl (2026-11-14 02:48 UTC) shows **Open (31)**.
  Baseline open count was 17; 17 + 14 new (#325–#338) = 31 exactly, consistent
  with zero closures and zero reopenings among previously recorded issues.
- Page 1 of the open list (25 entries, newest-first) shows all 14 new issues
  plus 11 previously recorded open issues still open: #321, #320, #319, #316,
  #312, #310, #309, #308, #307, #306, #305.
- **Limit:** the `browser.open` text rendering of the issues list exposes only
  page 1 (25 entries) and does not expose the Closed-tab or page-2 links as
  followable outlinks, and this sweep was barred from guessing/modifying URLs
  and from all `api.github.com` calls. The remaining 6 open issues (arithmetically
  #304, #303, #300, #298, #296, #106) and the closed list (baseline: 30) could
  NOT be directly re-rendered in this pass. The zero-status-change conclusion
  therefore rests on the open-count arithmetic above, not on a direct closed-list
  re-enumeration. **The coordinator should re-verify the closed count and the
  6 oldest open issues via a live browser before any filing** — a simultaneous
  close + reopen, or a new issue filed and closed between crawls, would not be
  visible to this method. No such event was observed; none is asserted either way
  beyond the evidence above.

## Security advisories (GHSA)

**No new published advisory found.** `SECURITY.md` at `main` HEAD `9007ba1`,
re-crawled fresh 2026-11-14 02:48 UTC, still lists exactly one published
advisory: **GHSA-q47q-h6x2-f5qg** (stale transient initialization flag, already
recorded as EX-116). Web searches for `GHSA` + `bcnmy`/`nexus` returned only
that advisory (plus unrelated Sonatype/Hazelcast/Cisco "Nexus" results). The
baseline §D discrepancy stands: the advisories tab reportedly shows no published
advisories, and a Nov 4, 2026 third-party write-up also reports the GHSA page
returning 404 — but no SECOND GHSA identifier for this repo surfaced anywhere.

## Audit reports

**No new audit-report mention for the nexus repo dated after 2026-11-13 found.**
Searches returned only the already-recorded reports (CodeHawks-Cyfrin Jul 2024,
Cantina/Spearbit Oct–Nov 2024, Zenith Mar 2025, Pashov Mar 2025, Pashov
`stx-contracts` Nov 2025). Two mentions inside the new issues are NOT new
nexus-repo reports: #337 references a Zenith node-pm audit (stx-contracts
scope, no date given, `tx.origin` not mentioned in it); #336 references Pashov
2025-10-16 [L-03] (domain separator, pre-dates the baseline). The unverified
"reviewed by Pashov in July 2026" claim in `SECURITY.md` remains unverified —
no report for it surfaced in this sweep either.

---

## Sweep limits

1. **No API.** All GitHub API access was stopped/rate-limited; this sweep used
   page reads only. Counts above are page-render counts, not API counts.
2. **Issue comments not read.** A root cause disclosed only in a comment thread
   (e.g. a maintainer triage note closing one of #325–#338 as a duplicate after
   the crawl) would not be captured. Re-check immediately before filing.
3. **Snapshot time.** List crawl 2026-11-14 02:48 UTC (09:48 WIB); issue bodies
   crawled 02:49 UTC. Issues filed after that moment are not covered. The
   tracker filed 14 issues in ~6.5 hours on Nov 13 (UTC) — re-sweep before filing.
4. **PRs not swept.** GitHub issue/PR numbers share one sequence; numbers above
   #338, if any exist by filing time, must be checked to distinguish issues from
   PRs. None above #338 appeared on the open-issues list at crawl time.
5. **Private reports unsearchable.** As in baseline §H: SECURITY.md routes
   Critical/High reports to private email; #303's unknown contents and any other
   private reports cannot be ruled out by any public sweep.

*End of delta. 14 new entries (#325–#338), 0 status changes observed, 0 new
advisories, 0 new audit reports. Awaiting coordinator merge into
EXCLUSION_LIST.md.*
