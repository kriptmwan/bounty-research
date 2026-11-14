# Nexus (bcnmy/nexus) — Exclusion List (dedup-first)

**Purpose:** the definitive list of known bugs for the Nexus bug-bounty audit, keyed by ROOT CAUSE.
Hunters must not claim anything on this list. If a candidate finding shares a root cause with an
entry here, it is a duplicate — even if the trigger, severity label, or PoC differs.

**Built:** 2026-11-13 (WIB), read-only. Pins: `main` HEAD `9007ba1` (`9007ba1352e606575e32456512e25c41a9bf449c`),
Pashov fixes commit `9af2d1d` (2025-03-30). No GitHub API calls were used (git protocol + page reads only).
No testing, no filing, no contact with Biconomy.

**Delta merged:** 2026-11-14 — §I added (14 new tracker issues #325–#338 + the Option 1 disproved candidate H-B1);
total 176 entries. Delta source file: `NEW-ISSUES-2026-11-14.md` (same directory).

## Counts summary (all verified this pass, not copied from SCOPE.md)

| Source | Verified count |
|---|---|
| Audit findings, security (5 in-repo PDFs) | **68**: CodeHawks 14 (4H/4M/6L) + Cantina main 27 (4H/12M/11L by section) + Cantina ERC-7739 add-on 3 (1M/2L) + Zenith 9 (1H/3M/5L) + Pashov 15 (2M/13L) |
| Audit gas/informational items (same 5 PDFs) | **40**: Cantina main 6 gas + 28 info; 7739 add-on 1 gas + 3 info; Zenith 2 info. Total items across the 5 PDFs: **108** |
| Open GitHub issues read in full | **17 of 17** (13 security-relevant + 4 non-security) |
| Closed GitHub issues enumerated | **30 of 30** (GitHub reports "30 results"; all 30 numbers + titles identified — see §C for the 3 unrendered list entries resolved by direct probes) |
| Pashov `stx-contracts` review, Nov 2025 | **5 of 5** (1H/4L, all Resolved) |
| Published advisory | **1** (GHSA-q47q-h6x2-f5qg; fix verified present at HEAD) |
| `stx-contracts` lineage | **PUBLIC**, HEAD `61001d0` (= `develop` branch tip); 8 matched files diffed against nexus `main` HEAD |
| Tracker delta, 2026-11-14 (issues #325–#338) | **14** (11 nexus-1.2.1 mechanisms + 3 stx-only; §I) |
| Option 1 disproved candidate H-B1 | **1** (NOT_A_BUG, recorded to prevent re-claim; §I) |
| **Total exclusion entries** | **176** (161 + 14 + 1) |

**SCOPE.md verification notes.** Delta claim CONFIRMED: `git diff --stat 9af2d1d..HEAD -- contracts/` =
10 files, +187/−108, 15 commits touching `contracts/`. No `develop` branch in this repo CONFIRMED
(`git branch -a`). `dev`-removes-registry/factory CONFIRMED (§G). GHSA/advisories-tab discrepancy
CONFIRMED (§D). `272c408` CONFIRMED unresolvable in this repo (`fatal: Not a valid object name`).
Counting discrepancies found: (a) Cantina main §5.3.5 carries a "Medium Risk" severity label while
filed under the Low section — the 4H/12M/11L split counts by section; by label it is 4H/13M/10L;
total 27 either way. (b) Cantina info §5.5.11 carries a "Low Risk" label inside the Informational
section. (c) Zenith reports 11 total items (9 security + 2 info); the 7739 add-on 7 total (3 + 1 gas
+ 3 info). The "68" counts security findings only.

## Delta surface and relevance grading

Post-Pashov delta files (verified): `Nexus.sol`, `base/ModuleManager.sol`, `base/BaseAccount.sol`,
`lib/Initializable.sol`, `lib/NonceLib.sol`, `lib/local/LibPREP.sol` (**new**), `lib/local/LocalCallDataParserLib.sol`,
`utils/NexusBootstrap.sol`, `interfaces/INexusEventsAndErrors.sol`, `interfaces/base/IStorage.sol`.
Substantive delta logic: the ERC-7702 relay-init branch in `Nexus.initializeAccount`
(`ECDSA.recover` over raw `keccak256(initData)` + `erc7702InitHashes` replay map); the transient-flag
consume in `Initializable.requireInitializable`; the `validators[]` param + install loop in
`NexusBootstrap.initNexusWithDefaultValidatorAndOtherModules*`; `ModuleManager.getDefaultValidator()`;
`ModuleManager._uninstallPreValidationHook` signature simplification; version bumps. Everything else
in the delta is formatting, comments, pragmas, or code motion.

Relevance grades used below:

- **DIRECT** — the finding's function/logic was substantively changed by the delta, is the new
  `LibPREP.sol`, or sits on the 7702/PREP init surface (`initializeAccount`, `_handlePREP`,
  `_amIERC7702`-gated branches). These are the highest-collision entries.
- **FILE** — the finding is in a delta file, but its function/region was untouched (or only
  cosmetically touched) by the delta. Still excluded; the delta did not re-open it.
- **NO** — the finding is in a file outside the delta (or in a third-party package).

**Cross-cutting rule:** fix status does NOT matter for exclusion. Fixed, acknowledged, and still-open
items are all EXCLUDED — the bounty excludes known issues and anything fixed in the working line.
"Resolved" in an old audit means the *reported instance* was addressed; a Hunter re-claiming the same
root cause at HEAD is still a duplicate unless they prove a genuinely distinct mechanism.

---

## A. Audit findings (in-repo PDFs)

### A1. CodeHawks-Cyfrin competition, Jul 2024 (14) — no fix statuses stated (contest report)

### EX-001 — [CodeHawks H-01] User may lose funds: `msg.value` ignored
- **Source:** CodeHawks-Cyfrin competition report §7.1. **Severity:** High.
- **Root cause:** `BiconomyMetaFactory.deployWithFactory` (`factory.call(factoryData)` without value),
  `Nexus.executeUserOp` (`target.call(data)` without value), `ModuleManager` fallback CALLTYPE_SINGLE
  assembly (`call(gas(), handler, 0, ...)`) — ETH sent with the call is not forwarded and can strand/lose funds.
- **Status:** Not stated in report. **Delta relevance:** FILE — `Nexus.sol`/`ModuleManager.sol` regions untouched by delta; factory is not a delta file.
- **Verdict:** EXCLUDED. Also claimed in: Cantina 5.2.3 (same root cause).

### EX-002 — [CodeHawks H-02] Registry never called when setting up modules via Bootstrap
- **Source:** CodeHawks §7.2. **Severity:** High.
- **Root cause:** `NexusBootstrap.initNexus*` installs modules BEFORE `_configureRegistry()`, so the
  `withRegistry`/`_checkRegistry` check sees `registry == address(0)` and skips attestation for bootstrap-installed modules.
- **Status:** Not stated. **Delta relevance:** FILE — `NexusBootstrap.sol`; delta did not touch registry ordering (fix present at HEAD: registry configured first in the internal init functions).
- **Verdict:** EXCLUDED. Also claimed in: Cantina 5.3.4.

### EX-003 — [CodeHawks H-03] Enable-mode install doesn't check `moduleType`
- **Source:** CodeHawks §7.3. **Severity:** High.
- **Root cause:** `ModuleManager._getEnableModeDataHash(module, initData)` hashes only module + initData, not
  `moduleType`; a bundler can forge the type (e.g. install a multi-type module as executor) without invalidating
  the enable-mode signature.
- **Status:** Not stated. **Delta relevance:** FILE — `ModuleManager.sol`; delta only moved the function and changed `view`→`pure`.
- **Verdict:** EXCLUDED. Also claimed in: Cantina 5.1.3, Cantina 5.3.9.

### EX-004 — [CodeHawks H-04] Missing nonce in `_getEnableModeDataHash` allows signature replay
- **Source:** CodeHawks §7.4. **Severity:** High.
- **Root cause:** `ModuleManager._getEnableModeDataHash` binds no nonce/`userOpHash`, so an enable-mode signature
  can be replayed (e.g. to re-install an uninstalled validator) in a different userOp.
- **Status:** Not stated. **Delta relevance:** FILE — `ModuleManager.sol` (see EX-003).
- **Verdict:** EXCLUDED. Also claimed in: Cantina 5.1.2 (same root cause; fix = bind `userOpHash`).

### EX-005 — [CodeHawks M-01] Factory deployments won't work correctly on ZKsync
- **Source:** CodeHawks §8.1. **Severity:** Medium.
- **Root cause:** Factories use Solady `LibClone.createDeterministicERC1967` (runtime-constructed bytecode via
  `create2`); the ZKsync compiler cannot know the bytecode in advance, so deployments misbehave.
- **Status:** Not stated. **Delta relevance:** NO — factory files.
- **Verdict:** EXCLUDED.

### EX-006 — [CodeHawks M-02] Anyone can call the fallback function (missing authorization control)
- **Source:** CodeHawks §8.2. **Severity:** Medium.
- **Root cause:** `ModuleManager.fallback()` is unrestricted; anyone can invoke an installed fallback handler
  with arbitrary calldata, no EntryPoint/self check, no validator involvement.
- **Status:** Not stated. **Delta relevance:** FILE — `ModuleManager.sol`; `_fallback` untouched by delta.
- **Verdict:** EXCLUDED. Also claimed in: Cantina 5.2.6 (Acknowledged — by design, handler must check appended `msg.sender`).

### EX-007 — [CodeHawks M-03] Protocol not fully compliant with EIP-7579 (no ERC-165)
- **Source:** CodeHawks §8.3. **Severity:** Medium.
- **Root cause:** `Nexus`/`ModuleManager`/`BaseAccount` do not implement ERC-165 `supportsInterface` as EIP-7579 requires.
- **Status:** Not stated. **Delta relevance:** FILE — delta files, no interface change.
- **Verdict:** EXCLUDED. Also claimed in: Cantina 5.3.5.

### EX-008 — [CodeHawks M-04] Typehash for ModuleEnableMode struct is incorrect
- **Source:** CodeHawks §8.4. **Severity:** Medium.
- **Root cause:** `MODULE_ENABLE_MODE_TYPE_HASH` preimage has a space after the comma AND declares `bytes32 initDataHash`
  while `_getEnableModeDataHash` hashes `bytes initData` — EIP-712-incompatible struct hash.
- **Status:** Not stated. **Delta relevance:** FILE — `Constants.sol` + `ModuleManager.sol`.
- **Verdict:** EXCLUDED. Also claimed in: Cantina 5.5.6 (space), Pashov L-13 (bytes/bytes32 mismatch).

### EX-009 — [CodeHawks L-01] RegistryFactory createAccount reverts on unsorted external attesters
- **Source:** CodeHawks §9.1. **Severity:** Low.
- **Root cause:** `RegistryFactory.addAttester`/`removeAttester` (swap-and-pop) do not keep `attesters` sorted/unique;
  ERC-7484 `REGISTRY.check()` reverts on unsorted input, bricking `createAccount`.
- **Status:** Not stated. **Delta relevance:** NO — `RegistryFactory.sol`.
- **Verdict:** EXCLUDED. Also claimed in: Cantina 5.2.12.

### EX-010 — [CodeHawks L-02] `indexed` bytes event parameter causes data loss
- **Source:** CodeHawks §9.2. **Severity:** Low.
- **Root cause:** `INexusAccountFactory.AccountCreated(address indexed account, bytes indexed initData, ...)` —
  indexed dynamic bytes emit only `keccak256`, so listeners cannot recover `initData`.
- **Status:** Not stated. **Delta relevance:** NO — factory interface.
- **Verdict:** EXCLUDED.

### EX-011 — [CodeHawks L-03] `entryPoint()` cannot be overridden (missing `virtual`)
- **Source:** CodeHawks §9.3. **Severity:** Low.
- **Root cause:** `BaseAccount.entryPoint()` lacks `virtual` despite natspec saying it can be overridden.
- **Status:** Not stated. **Delta relevance:** FILE — `BaseAccount.sol`; delta changed only the version string there.
- **Verdict:** EXCLUDED.

### EX-012 — [CodeHawks L-04] `validateUserOp` violates EIP-4337 (returns failure instead of reverting)
- **Source:** CodeHawks §9.4. **Severity:** Low.
- **Root cause:** `Nexus.validateUserOp` returns `VALIDATION_FAILED` when the nonce-specified validator is not
  installed; EIP-4337 requires reverting for non-signature-mismatch errors.
- **Status:** Not stated. **Delta relevance:** FILE — `Nexus.sol`; `validateUserOp` only cosmetically touched by delta.
- **Verdict:** EXCLUDED.

### EX-013 — [CodeHawks L-05] Missing `_isInitialized` check in `K1Validator.transferOwnership`
- **Source:** CodeHawks §9.5. **Severity:** Low.
- **Root cause:** `K1Validator.transferOwnership` sets `smartAccountOwners[msg.sender]` without checking the module
  is initialized for the account; a stale/delayed call can permanently block later `onInstall` (which reverts if already initialized).
- **Status:** Not stated. **Delta relevance:** NO — `K1Validator.sol`.
- **Verdict:** EXCLUDED.

### EX-014 — [CodeHawks L-06] Fallback handlers can be installed with invalid calltype
- **Source:** CodeHawks §9.6. **Severity:** Low.
- **Root cause:** `ModuleManager._installFallbackHandler` does not validate `calltype` is `CALLTYPE_SINGLE`/`CALLTYPE_STATIC`;
  an invalid calltype installs successfully but the fallback silently does nothing when called (ETH can strand).
- **Status:** Not stated. **Delta relevance:** FILE — `ModuleManager.sol`, function untouched by delta.
- **Verdict:** EXCLUDED. Also claimed in: Cantina 5.2.8.

### A2. Cantina/Spearbit, Oct 2024 (27) — 21 Fixed, 6 Acknowledged

### EX-015 — [Cantina 5.1.1] `fallback()` logic prevents hook's `postCheck` from executing
- **Source:** Cantina main report §5.1.1. **Severity:** High.
- **Root cause:** `ModuleManager.fallback()` assembly uses bare `return` on success, exiting the call context before
  the `withHook` modifier's `postCheck` runs — hook post-checks are skipped for all successful fallback-handled calls.
- **Status:** Fixed (PR 183 + addendum commits). **Delta relevance:** FILE — `_fallback` untouched by delta.
- **Verdict:** EXCLUDED.

### EX-016 — [Cantina 5.1.2] Enable Mode signature can be replayed
- **Source:** Cantina §5.1.2. **Severity:** High.
- **Root cause:** `ModuleManager._getEnableModeDataHash` does not bind `userOpHash`; the enable-mode signature lives
  in `userOp.signature` (not covered by `userOpHash`), so a bundler can transplant a previously signed enable-mode
  blob into a different userOp, across chains/accounts.
- **Status:** Fixed (PR 112). **Delta relevance:** FILE — see EX-003.
- **Verdict:** EXCLUDED. Also claimed in: CodeHawks H-04.

### EX-017 — [Cantina 5.1.3] Enable Mode signature ignores module type
- **Source:** Cantina §5.1.3. **Severity:** High.
- **Root cause:** Same mechanism as EX-003: `moduleType` not covered by the enable-mode signature hash.
- **Status:** Fixed (PR 112). **Delta relevance:** FILE — see EX-003.
- **Verdict:** EXCLUDED. Also claimed in: CodeHawks H-03, Cantina 5.3.9.

### EX-018 — [Cantina 5.1.4] ERC-7484 registry checks missing on calls to modules
- **Source:** Cantina §5.1.4. **Severity:** High.
- **Root cause:** `_checkRegistry` runs at install time and for executors, but NOT when validators, hooks, or fallback
  handlers are *used* (`validateUserOp`, `withHook`, `fallback()`); a module de-attested after install keeps working.
- **Status:** Acknowledged; hook + fallback checks added (PR 151), validator check explicitly NOT added.
- **Delta relevance:** FILE — `Nexus.sol`/`ModuleManager.sol`. Note: the 1.3.x lineage and the `dev` branch remove the registry entirely (§F/§G).
- **Verdict:** EXCLUDED. Related: Pashov L-04 (same validator gap).

### EX-019 — [Cantina 5.2.1] Incorrect check in `_enableMode` prevents installing non-validator module types
- **Source:** Cantina §5.2.1. **Severity:** Medium.
- **Root cause:** `ModuleManager._enableMode` reverts unless `moduleType` is VALIDATOR/MULTI, contradicting the
  documented "any module type via enable mode" behavior.
- **Status:** Fixed (PR 177). **Delta relevance:** FILE — `_enableMode` untouched by delta.
- **Verdict:** EXCLUDED.

### EX-020 — [Cantina 5.2.2] Timelock on `emergencyUninstallHook` can be bypassed
- **Source:** Cantina §5.2.2. **Severity:** Medium.
- **Root cause:** `emergencyUninstallHook` does not check the hook is installed before recording
  `emergencyUninstallTimelock[hook]`; an attacker pre-records the timestamp, installs the hook later, and uninstalls immediately.
- **Status:** Fixed (PR 175). **Delta relevance:** FILE — `Nexus.sol`/`ModuleManager.sol`.
- **Verdict:** EXCLUDED.

### EX-021 — [Cantina 5.2.3] Not all calls forward `msg.value`
- **Source:** Cantina §5.2.3. **Severity:** Medium.
- **Root cause:** Same mechanism as EX-001 (`executeUserOp`, fallback handler, `BiconomyMetaFactory.deployWithFactory`,
  factories' `initializeAccount` calls) — value not forwarded, native tokens can strand (unrecoverable in factories).
- **Status:** Fixed (PR 113). **Delta relevance:** FILE — see EX-001.
- **Verdict:** EXCLUDED. Also claimed in: CodeHawks H-01.

### EX-022 — [Cantina 5.2.4] Module can prevent itself from uninstalling
- **Source:** Cantina §5.2.4. **Severity:** Medium.
- **Root cause:** `ModuleManager` uninstall paths propagate a revert from `module.onUninstall()`, so a malicious
  module can block its own removal.
- **Status:** Fixed (PR 117, PR 143 — reverts ignored via `excessivelySafeCall`). **Delta relevance:** FILE.
- **Verdict:** EXCLUDED.

### EX-023 — [Cantina 5.2.5] Setting the ERC-7484 registry may put modules in an insecure state
- **Source:** Cantina §5.2.5. **Severity:** Medium.
- **Root cause:** `RegistryAdapter._configureRegistry` swaps registry/attesters/threshold without re-checking
  installed modules; executors can silently deactivate and validators can stay active while unattested.
- **Status:** Acknowledged. **Delta relevance:** NO — `RegistryAdapter.sol` (removed in 1.3.x/`dev`).
- **Verdict:** EXCLUDED.

### EX-024 — [Cantina 5.2.6] `fallback()` can be used for direct unauthorised calls to fallback handlers
- **Source:** Cantina §5.2.6. **Severity:** Medium.
- **Root cause:** Same mechanism as EX-006.
- **Status:** Acknowledged (by design; handlers must authorize via appended `msg.sender`).
- **Delta relevance:** FILE — see EX-006.
- **Verdict:** EXCLUDED. Also claimed in: CodeHawks M-02.

### EX-025 — [Cantina 5.2.7] Modules other than validators cannot be installed in enable mode
- **Source:** Cantina §5.2.7. **Severity:** Medium.
- **Root cause:** `Nexus.validateUserOp` enable-mode flow always uses the to-be-installed module address (from the
  nonce) as the validating validator, so hooks/executors/fallbacks cannot be enable-mode-installed.
- **Status:** Fixed (PR 112 — three-role split: nonce validator, enableModeValidator, module).
- **Delta relevance:** FILE — `Nexus.sol`/`ModuleManager.sol`.
- **Verdict:** EXCLUDED.

### EX-026 — [Cantina 5.2.8] Missing call type validation in `_installFallbackHandler`
- **Source:** Cantina §5.2.8. **Severity:** Medium.
- **Root cause:** Same mechanism as EX-014, plus `fallback()` silently no-ops (no revert) for an unrecognized calltype.
- **Status:** Fixed. **Delta relevance:** FILE — see EX-014.
- **Verdict:** EXCLUDED. Also claimed in: CodeHawks L-06.

### EX-027 — [Cantina 5.2.9] Cannot install fallback handler for empty calldata
- **Source:** Cantina §5.2.9. **Severity:** Medium.
- **Root cause:** `receive()` (from `Receiver`) intercepts empty-calldata calls, so a fallback handler for `bytes4(0)`
  is never reached, though `_isModuleInstalled` defaults empty selectors to `bytes4(0)`.
- **Status:** Fixed (PR 132 — `bytes(0)` disabled at install). **Delta relevance:** FILE — `ModuleManager.sol`.
- **Verdict:** EXCLUDED.

### EX-028 — [Cantina 5.2.10] Cannot install fallback handler for NFT token callbacks
- **Source:** Cantina §5.2.10. **Severity:** Medium.
- **Root cause:** The `receiverFallback` NFT-callback short-circuit returns before consulting installed fallback
  handlers for `onERC721Received`/`onERC1155Received`/`onERC1155BatchReceived`, so custom handlers for those selectors never run.
- **Status:** Fixed (PR 132). **Delta relevance:** FILE — `ModuleManager.sol` fallback path.
- **Verdict:** EXCLUDED.

### EX-029 — [Cantina 5.2.11] `ModuleTypeLib.bitEncode*` functions error on duplicates
- **Source:** Cantina §5.2.11. **Severity:** Medium.
- **Root cause:** `ModuleTypeLib.bitEncode` uses addition instead of bitwise OR, so encoding the same module type
  twice produces a wrong bitmask (e.g. VALIDATOR twice encodes as EXECUTOR).
- **Status:** Fixed (PR 133). **Delta relevance:** NO — `ModuleTypeLib.sol`.
- **Verdict:** EXCLUDED.

### EX-030 — [Cantina 5.2.12] `RegistryFactory.addAttester` allows duplicates/unsorted attesters
- **Source:** Cantina §5.2.12. **Severity:** Medium.
- **Root cause:** Same mechanism as EX-009: unsorted/duplicate attesters break ERC-7484 `check()` at deployment time.
- **Status:** Fixed (PR 134 — sort on update). **Delta relevance:** NO — `RegistryFactory.sol`.
- **Verdict:** EXCLUDED. Also claimed in: CodeHawks L-01.

### EX-031 — [Cantina 5.3.1] `_checkEnableModeSignature` conditional branches have duplicate bodies
- **Source:** Cantina §5.3.1. **Severity:** Low.
- **Root cause:** `ModuleManager._checkEnableModeSignature` if/else executes identical code on both branches (dead logic, likely a missed case split).
- **Status:** Fixed (PR 177). **Delta relevance:** FILE — `ModuleManager.sol`.
- **Verdict:** EXCLUDED.

### EX-032 — [Cantina 5.3.2] `withHook` on both external and internal `installModule`
- **Source:** Cantina §5.3.2. **Severity:** Low.
- **Root cause:** `withHook` applied to both `Nexus.installModule` (external) and `ModuleManager._installModule`
  (internal) double-invokes the hook; hooks that cannot run twice revert and DoS installation.
- **Status:** Fixed (PR 178). **Delta relevance:** FILE.
- **Verdict:** EXCLUDED.

### EX-033 — [Cantina 5.3.3] Refactor nested EIP-712 code (diverged Solady copy)
- **Source:** Cantina §5.3.3. **Severity:** Low.
- **Root cause:** `Nexus.sol` inlines nested-EIP-712 helpers copied from Solady instead of calling Solady's
  `_erc1271UnwrapSignature`/`_erc1271IsValidSignatureViaNestedEIP712`; the copy has diverged (maintenance/mistake risk).
- **Status:** Acknowledged (Spearbit; Biconomy fixed in PR 158). **Delta relevance:** FILE — `Nexus.sol`.
- **Verdict:** EXCLUDED.

### EX-034 — [Cantina 5.3.4] Bootstrap installs modules before setting registry
- **Source:** Cantina §5.3.4. **Severity:** Low.
- **Root cause:** Same mechanism as EX-002.
- **Status:** Fixed (PR 115). **Delta relevance:** FILE — see EX-002.
- **Verdict:** EXCLUDED. Also claimed in: CodeHawks H-02.

### EX-035 — [Cantina 5.3.5] Missing EIP-165 `supportsInterface`, not EIP-7579 compliant
- **Source:** Cantina §5.3.5. **Severity:** Medium label, filed under Low section (see counting notes).
- **Root cause:** Same mechanism as EX-007.
- **Status:** Acknowledged (planned via fallback handlers). **Delta relevance:** FILE — see EX-007.
- **Verdict:** EXCLUDED. Also claimed in: CodeHawks M-03.

### EX-036 — [Cantina 5.3.6] Fallback handler can call into sensitive functions of the handler itself
- **Source:** Cantina §5.3.6. **Severity:** Low.
- **Root cause:** `ModuleManager._installFallbackHandler` forbids only `onInstall`/`onUninstall` selectors; any other
  sensitive selector (e.g. `transferOwnership`, `isModuleType`) can be routed via the unrestricted fallback, and the
  module cannot tell a fallback-routed call from an account-originated one.
- **Status:** Acknowledged (ERC-7579 PR 590: fallback modules must self-protect). **Delta relevance:** FILE.
- **Verdict:** EXCLUDED.

### EX-037 — [Cantina 5.3.7] Execute functions may incorrectly report success for calls to EOAs
- **Source:** Cantina §5.3.7. **Severity:** Low.
- **Root cause:** `ExecutionHelper._execute`/`_tryExecute` assembly treats a low-level `call` to an address with no
  code as success (unlike Solidity semantics), so `_execute` won't revert and `_tryExecute` skips the failure event.
- **Status:** Acknowledged (document behavior). **Delta relevance:** NO — `ExecutionHelper.sol`.
- **Verdict:** EXCLUDED.

### EX-038 — [Cantina 5.3.8] Events not emitted for failed `tryExecute` attempts
- **Source:** Cantina §5.3.8. **Severity:** Low.
- **Root cause:** `ExecutionHelper` EXECTYPE_TRY + CALLTYPE_SINGLE/DELEGATECALL paths in `execute()` drop the success
  flag and emit no `TryExecuteUnsuccessful`/`TryDelegateCallUnsuccessful`, unlike the batch and `executeFromExecutor` paths.
- **Status:** Fixed (PR 127). **Delta relevance:** NO — `ExecutionHelper.sol`.
- **Verdict:** EXCLUDED.

### EX-039 — [Cantina 5.3.9] Enable Mode can bypass the registry on multi-type validator modules
- **Source:** Cantina §5.3.9. **Severity:** Low.
- **Root cause:** `ModuleManager._enableMode` installs the module under the caller-chosen type (registry-checked for
  THAT type only), then `validateUserOp` uses it as a validator — a module attested as executor but not validator
  passes validation without a validator-type registry check.
- **Status:** Fixed (PR 129, PR 126). **Delta relevance:** FILE — `Nexus.sol`/`ModuleManager.sol`.
- **Verdict:** EXCLUDED. Related: EX-003/EX-017 (module-type confusion in enable mode).

### EX-040 — [Cantina 5.3.10] `withdrawDepositTo` overwrites free memory pointer, OOG on failure
- **Source:** Cantina §5.3.10. **Severity:** Low.
- **Root cause:** `BaseAccount.withdrawDepositTo` assembly writes `amount` at `0x34`, clobbering the top of the
  free-memory-pointer slot at `0x40`; on a failed EntryPoint call the corrupted pointer causes OOG via quadratic
  memory expansion and swallows revert data.
- **Status:** Fixed (PR 125). **Delta relevance:** FILE — `BaseAccount.sol`; delta changed only the version string there.
- **Verdict:** EXCLUDED.

### EX-041 — [Cantina 5.3.11] `createAccount` actual salt not deterministic given parameters
- **Source:** Cantina §5.3.11. **Severity:** Low.
- **Root cause:** Factories hash raw calldata (including ABI offsets) for the CREATE2 salt, so non-default ABI
  encodings of the same `(initData, salt)` produce different addresses; the address cannot be reconstructed from the
  emitted event parameters alone.
- **Status:** Fixed (PR 124). **Delta relevance:** NO — factory files.
- **Verdict:** EXCLUDED.

### A2b. Cantina main — gas optimizations (6) and informational (28), compact entries

Each row is one excluded item. "Root cause" is the mechanism; all verdicts EXCLUDED.

| ID | Title | Severity | Root cause (file:function + mechanism) | Status | Delta |
|---|---|---|---|---|---|
| EX-G01 | [5.4.1] Unused return data for successful calls | Gas | `ExecutionHelper`: `_execute`/`_tryExecute`/batch/delegatecall variants copy return/revert data that is never used | Fixed (PR 197) | NO |
| EX-G02 | [5.4.2] Inefficient signature validation | Gas | `K1Validator.validateUserOp` double-validates (EOA + ERC-1271 paths, `isValidSignatureNow` twice) | Fixed (PR 196/198) | NO |
| EX-G03 | [5.4.3] Flip if/else to save gas | Gas | `Nexus.sol`: `if` on a negated boolean; flipping branches saves a NOT | Fixed (PR 112) | FILE |
| EX-G04 | [5.4.4] `K1Validator.validateUserOp` can be optimized | Gas | `K1Validator`: use `isValidSignatureNowCalldata` instead of memory variant | Fixed (PR 139) | NO |
| EX-G05 | [5.4.5] `_uninstallValidator` can be optimized | Gas | `ModuleManager._uninstallValidator`: pop first, then check list emptiness; also notes a `popAll()` state bug in the sentinel lib (unused here) | Fixed (PR 139) | FILE |
| EX-G06 | [5.4.6] Validation mode extraction | Gas | `NonceLib`: `shr(248, shl(24, nonce))` → `byte(3, nonce)` | Fixed (PR 144) | FILE (pragma/comments only in delta) |
| EX-I01 | [5.5.1] Enforce non-zero owner for K1Validator | Info | `K1Validator.onInstall` doesn't reject `address(0)` owner (unlike `transferOwnership`) | Fixed (PR 199) | NO |
| EX-I02 | [5.5.2] Update Solady ERC-7739 reference copy | Info | Outdated copied Solady ERC-7739 implementation | Fixed (PR 177) | NO |
| EX-I03 | [5.5.3] BaseAccount incorrectly inherits Storage | Info | `BaseAccount` + `ModuleManager` both inherit `Storage` (convoluted; only one needs it) | Fixed (PR 182) | FILE |
| EX-I04 | [5.5.4] Separate event for emergency-uninstall reset | Info | `emergencyUninstallHook` reset branch re-emits the request event instead of a distinct reset event | Fixed (PR 175) | FILE |
| EX-I05 | [5.5.5] Unused modifiers | Info | `ModuleManager.onlyValidatorModule`/`onlyAuthorized` defined, never used | Fixed (PR 176) | FILE |
| EX-I06 | [5.5.6] Space after comma in type hash preimage | Info | `MODULE_ENABLE_MODE_TYPE_HASH` preimage `"ModuleEnableMode(address module, bytes32 initDataHash)"` has a non-canonical space | Fixed (PR 112) | FILE |
| EX-I07 | [5.5.7] Specify what functions should be hookable | Info | Unclear which Nexus functions carry `withHook` | Fixed (all hookable, commit 79376bc4) | FILE |
| EX-I08 | [5.5.8] Unrecoverable accounts (no active validators) | Info | Design tension: no validators ⇒ unrecoverable (init without validators, registry de-attestation, owner key loss) | Acknowledged (partial fix PR 139) | FILE |
| EX-I09 | [5.5.9] `newOwner` may not have a private key | Info | `K1Validator.onInstall` only checks no-code; any no-code address can be set as owner and brick the validator | Acknowledged | NO |
| EX-I10 | [5.5.10] Security model & trust assumptions | Info | Undocumented: account cannot protect against user-installed malicious modules | Acknowledged | NO |
| EX-I11 | [5.5.11] Fallback static-calls not 7579 compliant | Low label, in Info section | EIP-7579 says fallback MUST use `call`; Nexus also allows `staticcall` (CALLTYPE_STATIC) | Acknowledged | FILE |
| EX-I12 | [5.5.12] Missing memory-safe assembly annotation | Info | `ExecLib`/`LocalCallDataParserLib` assembly blocks lack `"memory-safe"` annotation | Fixed (PR 139) | FILE |
| EX-I13 | [5.5.13] No granular ERC-7484 registry control | Info | Registry is all-or-nothing per account; no per-module opt-out | Acknowledged | NO |
| EX-I14 | [5.5.14] `transferOwnership` two-step process | Info | Single-step ownership transfer risks irreversible loss/misdirection | Acknowledged | NO |
| EX-I15 | [5.5.15] Execution index in failure event not useful | Info | `TryExecuteUnsuccessful` emits batch index instead of execution data | Fixed (PR 127) | NO |
| EX-I16 | [5.5.16] `_SELF` variable unused | Info | `Nexus._SELF` set in constructor, never used | Fixed (commit 84c09410) | FILE |
| EX-I17 | [5.5.17] Unnecessary module type check on uninstall | Info | `Nexus.uninstallModule` re-checks module type at uninstall; no protection gained | Fixed (PR 139) | FILE |
| EX-I18 | [5.5.18] Registry threshold unattainable | Info | `RegistryFactory` doesn't check `threshold <= attesters.length` except in constructor | Partially fixed (constructor only); Acknowledged | NO |
| EX-I19 | [5.5.19] Payable vs non-payable functions | Info | Unclear payable markings (`withdrawDepositTo`, `setRegistry`, `executeUserOp`) | Acknowledged (gas-motivated) | FILE |
| EX-I20 | [5.5.20] `initializeAccount` doesn't check a validator was installed | Info | `Nexus.initializeAccount` delegatecalls bootstrap but never verifies a validator ended up installed | Fixed (PR 139) | **DIRECT** — `initializeAccount` is delta/7702 surface (the `_initializeAccount` post-check `isInitialized()` for non-7702 accounts is the fix; note the 7702 path deliberately skips it) |
| EX-I21 | [5.5.21] `executeFromExecutor` callers can't know what succeeded | Info | TRY-mode subcall success not returned (EIP-defined signature); only events | Acknowledged | FILE |
| EX-I22 | [5.5.22] Document custom enable-mode signature encoding | Info | `LocalCallDataParserLib.parseEnableModeData` packed encoding undocumented | Fixed (PR 139 + wiki) | FILE |
| EX-I23 | [5.5.23] Typos & documentation errors | Info | Typos/doc errors in `IStorage`, `K1Validator`, `LocalCallDataParserLib`, `ModuleManager`, `Nexus`, `RegistryAdapter` | Fixed (PR 139) | FILE |
| EX-I24 | [5.5.24] ModuleType range should be restricted | Info | `ModuleType` wraps `uint256` but is a bitmask index valid only in [0,255] | Fixed (PR 139) | NO |
| EX-I25 | [5.5.25] Undocumented CALLTYPE_STATIC | Info | `CALLTYPE_STATIC` (0xFE) is a Nexus extension, undocumented vs EIP-7579 | Acknowledged | NO |
| EX-I26 | [5.5.26] Missing owner validation in K1ValidatorFactory | Info | `K1ValidatorFactory` constructor doesn't check `factoryOwner != address(0)` unlike sibling factories | Fixed (PR 139) | NO |
| EX-I27 | [5.5.27] Missing return params in natspec | Info | `ExecutionHelper` natspec lacks `@return` descriptions | Fixed (PR 139) | NO |
| EX-I28 | [5.5.28] `RegistryFactory.createAccount` assumes `Bootstrap.initNexus` | Info | Factory decodes `initData` as `initNexus`-shaped, but `initializeAccount` is opaque to the bootstrap function | Fixed (PR 139) | NO |

### A3. Cantina ERC-7739 add-on, Nov 2024 (3 security + 1 gas + 3 info) — all Fixed (PR 216 / commit e7308fff)

### EX-042 — [7739-add-on 3.1.1] `checkERC7739Support` only checks the last validator
- **Source:** Cantina ERC-7739 add-on §3.1.1. **Severity:** Medium.
- **Root cause:** `Nexus.checkERC7739Support` while-loop over the sentinel validator list never calls `getNext()`,
  so only one iteration runs — only the last entry is checked for ERC-7739 support.
- **Status:** Fixed (PR 216). **Delta relevance:** FILE — `Nexus.sol`; loop untouched by delta.
- **Verdict:** EXCLUDED.

### EX-043 — [7739-add-on 3.2.1] Wrong docs for `isValidSignatureWithSender` in K1Validator
- **Source:** Add-on §3.2.1. **Severity:** Low.
- **Root cause:** `K1Validator` natspec omits that `isValidSignatureWithSender` can return `0x77390001` for ERC-7739 detection requests.
- **Status:** Fixed (PR 216). **Delta relevance:** NO — `K1Validator.sol`.
- **Verdict:** EXCLUDED.

### EX-044 — [7739-add-on 3.2.2] `isValidSignatureWithSender` checks `s` value on detection calls unnecessarily
- **Source:** Add-on §3.2.2. **Severity:** Low.
- **Root cause:** `K1Validator.isValidSignatureWithSender` applies the signature `s`-value check even for empty-signature
  ERC-7739 detection calls, where the derived `s` is arbitrary.
- **Status:** Fixed (PR 216). **Delta relevance:** NO — `K1Validator.sol`.
- **Verdict:** EXCLUDED.

| ID | Title | Severity | Root cause | Status | Delta |
|---|---|---|---|---|---|
| EX-G07 | [3.3.1] `isValidSignature` gas: skip 7739 check for non-detection calls | Gas | `Nexus.isValidSignature` calls `checkERC7739Support` for every call, including normal validations (`signature.length != 0`) | Fixed (PR 216) | FILE |
| EX-I29 | [3.4.1] Newer Solady ECDSA available | Info | Pinned Solady ECDSA 0.0.246, newer versions exist | Fixed (PR 216) | NO |
| EX-I30 | [3.4.2] ERC-7739 magic number may change | Info | `SUPPORTS_ERC7739 = 0x77390001` hardcoded; future standard versions may break flows | Fixed (PR 216) | NO |
| EX-I31 | [3.4.3] Nexus deviates from ERC-1271 reference (returns instead of reverting) | Info | `K1Validator.isValidSignatureWithSender` returns `0xffffffff` on invalid `s` where the EIP-1271 reference reverts | Fixed (commit e7308fff) | NO |

### A4. Zenith, Mar 2025 (9 security + 2 info) — differential review of PR-242 only

### EX-045 — [Zenith H-1] `K1Validator.validateUserOp` validation can be bypassed
- **Source:** Zenith report §4.1. **Severity:** High.
- **Root cause:** `K1Validator.validateUserOp` → `_validateSignatureForOwner(smartAccountOwners[userOp.sender], ...)`
  uses Solady `tryRecoverCalldata`, which returns `address(0)` on recovery failure; when the default validator was
  never `onInstall`ed for the account, `smartAccountOwners[account] == address(0)`, so ANY malformed signature
  compares `0 == 0` and validates.
- **Status:** Resolved (PR-254; `getOwner()` fallback). **Delta relevance:** NO — `K1Validator.sol`.
- **Verdict:** EXCLUDED. **Adjacent, distinct:** issue #307 (EX-077) claims the SAME zero-owner mechanism in the
  DIFFERENT function `K1Validator.validateSignatureWithData`, which takes the owner from caller-supplied data instead
  of storage — also excluded.

### EX-046 — [Zenith M-1] `emergencyUninstallHook` does not support DEFAULT_VALIDATOR
- **Source:** Zenith §4.2. **Severity:** Medium.
- **Root cause:** `ModuleManager._checkEmergencyUninstallSignature` requires `_isValidatorInstalled(validator)`, but
  the default validator is never in the sentinel list, so emergency uninstall cannot be authorized via the default validator.
- **Status:** Resolved (PR-254). **Delta relevance:** FILE — `ModuleManager.sol`, function untouched by delta.
- **Verdict:** EXCLUDED. Related: #316 (EX-072) claims the same addressability gap across all four entry points.

### EX-047 — [Zenith M-2] NexusProxy might not be able to receive ether
- **Source:** Zenith §4.2. **Severity:** Medium.
- **Root cause:** `NexusProxy` (OZ `Proxy`) has no `receive()`; 2300-gas `transfer` sends can fail because the
  fallback delegatecalls to the implementation.
- **Status:** Resolved (PR-256). **Delta relevance:** NO — `NexusProxy.sol`.
- **Verdict:** EXCLUDED.

### EX-048 — [Zenith M-3] ERC-7739 detection logic excludes DEFAULT_VALIDATOR
- **Source:** Zenith §4.2. **Severity:** Medium.
- **Root cause:** `Nexus.checkERC7739Support` loops only the sentinel list; the default validator (never in the list)
  is never consulted, so default-only accounts report no 7739 support.
- **Status:** Resolved (PR-254). **Delta relevance:** FILE — `Nexus.sol`.
- **Verdict:** EXCLUDED. Related: Pashov L-03 (EX-058, the inverse complaint), #321 (EX-069).

### EX-049 — [Zenith L-1] Default validator initialization not mandated before use for validation
- **Source:** Zenith §4.3. **Severity:** Low.
- **Root cause:** `Nexus`/`ModuleManager` allow the default validator to validate (enable mode, default-validator mode,
  PREP mode, emergency uninstall) without checking `isInitialized()`; several `NexusBootstrap` init methods never call
  `onInstall` for it — an unconfigured validator verifies signatures (the EX-045 scenario family).
- **Status:** Resolved (PR-254; non-7702 check added; 7702 deliberately exempt — K1 falls back to the account itself as signer).
- **Delta relevance:** FILE — `Nexus.sol`/`ModuleManager.sol`/`NexusBootstrap.sol`.
- **Verdict:** EXCLUDED.

### EX-050 — [Zenith L-2] No way to initialize a Nexus account along with other modules
- **Source:** Zenith §4.3. **Severity:** Low.
- **Root cause:** `NexusBootstrap` had no `{DEFAULT_VALIDATOR + other modules}` init path: `initNexus()` reverts in
  `_installValidator` for the default validator, forcing a two-step setup.
- **Status:** Resolved (PR-252 — added `initNexusWithDefaultValidatorAndOtherModules`).
- **Delta relevance:** **DIRECT** — the delta EXTENDS exactly this function family with the new `validators[]` param + install loop.
- **Verdict:** EXCLUDED.

### EX-051 — [Zenith L-3] ERC-7702 check may not work correctly (2-byte comparison)
- **Source:** Zenith §4.3. **Severity:** Low.
- **Root cause:** `ModuleManager._amIERC7702` compares only the first 2 bytes (`0xef01`) instead of the full 3-byte
  `0xef0100` delegation prefix; a future `0xef01XX` meaning could be misdetected (gates UUPS upgrade blocking).
- **Status:** Resolved (PR-257; 3-byte compare). **Delta relevance:** **DIRECT** — `_amIERC7702` is the 7702-detection
  primitive gating the delta's new relay-init branch (function itself unchanged by the delta; verified 3-byte compare at HEAD).
- **Verdict:** EXCLUDED.

### EX-052 — [Zenith L-4] Uninstalling a pre-validation hook calls `onUninstall()` twice
- **Source:** Zenith §4.3. **Severity:** Low.
- **Root cause:** `ModuleManager._uninstallHook` calls `hook.onUninstall` via `excessivelySafeCall`, AND
  `_uninstallPreValidationHook` (old 3-arg form) ALSO called `onUninstall` — double invocation for pre-validation hooks.
- **Status:** Resolved (PR-257 — removed the inner call).
- **Delta relevance:** **DIRECT** — the delta changed `_uninstallPreValidationHook` itself (dropped the unused
  `preValidationHook`/`data` params, leaving the single `_setPreValidationHook(hookType, address(0))` body).
- **Verdict:** EXCLUDED.

### EX-053 — [Zenith L-5] UserOp in Prep Mode cannot use the default validator
- **Source:** Zenith §4.3. **Severity:** Low.
- **Root cause:** `Nexus.validateUserOp` PREP branch initializes the account via `_handlePREP`/`_initializeAccount`,
  then requires `_isValidatorInstalled(validator)` — false for the default validator (never in the list) — so a
  PREP-mode userOp cannot validate via the default validator.
- **Status:** Resolved (PR-254). **Delta relevance:** **DIRECT** — PREP-mode/`_handlePREP` surface (see EX-051 note).
- **Verdict:** EXCLUDED. Related: #316 (EX-072) flags this adjacency itself.

| ID | Title | Severity | Root cause | Status | Delta |
|---|---|---|---|---|---|
| EX-I32 | [Zenith I-1] Incomplete natspec for `_installModule` | Info | `ModuleManager._installModule` natspec omits the two pre-validation hook module types | Resolved (PR-257) | FILE |
| EX-I33 | [Zenith I-2] Missing event in `initNexusWithDefaultValidator` | Info | `NexusBootstrap.initNexusWithDefaultValidator` installs the default validator without emitting `ModuleInstalled` | Acknowledged | FILE |

### A5. Pashov Audit Group, Mar 2025 (15) — review `6395f8f`, fixes `9af2d1d`

### EX-054 — [Pashov M-01] Hook bypass via enable mode in module installation
- **Source:** Pashov report §8.1. **Severity:** Medium.
- **Root cause:** `ModuleManager._installModule` carries `withHook`, but when reached via `validateUserOp` →
  `_enableMode`, the hook's `preCheck`/`postCheck` see `msg.sender == EntryPoint` and `msg.data` with the
  `validateUserOp` selector (not `installModule`), so selector-based hooks cannot recognize the install and their protection is bypassed.
- **Status:** Resolved. **Delta relevance:** FILE — `ModuleManager.sol`; enable-mode path untouched by delta.
- **Verdict:** EXCLUDED.

### EX-055 — [Pashov M-02] Users can delete all validators from Nexus account
- **Source:** Pashov §8.1. **Severity:** Medium.
- **Root cause:** `ModuleManager._uninstallValidator` had no last-validator guard; removing all validators with an
  uninitialized default validator bricks the account (`validateUserOp` can never pass).
- **Status:** Resolved (fix = `_checkInitializedValidators` in `Nexus.uninstallModule`, merged as `9af2d1d`).
- **Delta relevance:** FILE — `Nexus.sol`/`ModuleManager.sol`; `_checkInitializedValidators` only cosmetically touched by delta.
- **Verdict:** EXCLUDED. Related: #300/#309 (EX-081/EX-075) claim DoS flaws IN the M-02 fix's loop itself.

### EX-056 — [Pashov L-01] Storage pattern inconsistency exposes `registry` variable
- **Source:** Pashov §8.2. **Severity:** Low.
- **Root cause:** `RegistryAdapter.registry` sits in slot 0 instead of the ERC-7201 namespaced pattern used elsewhere;
  manipulable via delegatecall/upgrade collisions.
- **Status:** Resolved. **Delta relevance:** NO — `RegistryAdapter.sol` (removed in 1.3.x/`dev`).
- **Verdict:** EXCLUDED.

### EX-057 — [Pashov L-02] `handlePREP()` lacks sufficient length validation
- **Source:** Pashov §8.2. **Severity:** Low.
- **Root cause:** `Nexus._handlePREP` checks only `data.length >= 0x61` (97 bytes), but the packed layout
  (saltAndDelegation + initData ptr + cleanedSignature ptr + lengths + ≥4-byte initData + ≥65-byte signature)
  needs ≥229 bytes; undersized input can be mis-parsed.
- **Status:** FIXED at HEAD (coordinator correction 2026-11-13, verified in source: `Nexus._handlePREP` checks `data.length >= 0xf9` (249 bytes) since commit `4ab44e27` in the Pashov fixes window, meeting the ≥229-byte requirement; the `0x61` constant cited in the Pashov report no longer exists at HEAD). Do NOT re-litigate without a NEW mechanism.
- **Delta relevance:** **DIRECT** — `_handlePREP`/PREP surface; delta left the length check untouched.
- **Verdict:** EXCLUDED.

### EX-058 — [Pashov L-03] `checkERC7739Support()` checks DEFAULT_VALIDATOR even if unused
- **Source:** Pashov §8.2. **Severity:** Low.
- **Root cause:** `Nexus.checkERC7739Support` unconditionally queries `_DEFAULT_VALIDATOR` even when the account was
  initialized via `initNexus` (custom validators only) and the default was never installed.
- **Status:** Acknowledged. **Delta relevance:** FILE — `Nexus.sol`.
- **Verdict:** EXCLUDED. Related: EX-048 (inverse complaint), EX-069.

### EX-059 — [Pashov L-04] `withRegistry` modifier missing for `validateUserOp()` validator
- **Source:** Pashov §8.2. **Severity:** Low.
- **Root cause:** `Nexus.validateUserOp` performs no registry check on the validator (unlike `executeFromExecutor`'s
  `withRegistry`), so a de-attested validator can still validate.
- **Status:** Acknowledged. **Delta relevance:** FILE — `Nexus.sol`.
- **Verdict:** EXCLUDED. Also claimed in: Cantina 5.1.4 (validator part).

### EX-060 — [Pashov L-05] `createAccount()` skips `isModuleAllowed` for prevalidation hooks
- **Source:** Pashov §8.2. **Severity:** Low.
- **Root cause:** `RegistryFactory.createAccount` whitelist-checks validators/executors/hook/fallbacks but not
  MODULE_TYPE_PREVALIDATION_HOOK_ERC1271/ERC4337 modules.
- **Status:** Resolved. **Delta relevance:** NO — `RegistryFactory.sol`.
- **Verdict:** EXCLUDED.

### EX-061 — [Pashov L-06] Cannot opt out of hook in `createAccount()`
- **Source:** Pashov §8.2. **Severity:** Low.
- **Root cause:** `RegistryFactory.createAccount` unconditionally `_isModuleAllowed(hook.module, ...)`; a zero-address
  hook (the bootstrap's opt-out convention) reverts as unwhitelisted.
- **Status:** Resolved. **Delta relevance:** NO — `RegistryFactory.sol`.
- **Verdict:** EXCLUDED.

### EX-062 — [Pashov L-07] `RegistryFactory::removeAttester` can reduce attester count under limit
- **Source:** Pashov §8.2. **Severity:** Low.
- **Root cause:** `removeAttester` enforces no `attesters.length - 1 >= threshold` invariant (unlike the constructor),
  so the set can drop below threshold and break `_checkRegistry`.
- **Status:** Resolved. **Delta relevance:** NO — `RegistryFactory.sol`.
- **Verdict:** EXCLUDED. Related: Cantina 5.5.18 (EX-I18).

### EX-063 — [Pashov L-08] Outdated `emergencyUninstallTimelock` may affect `emergencyUninstallHook`
- **Source:** Pashov §8.2. **Severity:** Low.
- **Root cause:** `emergencyUninstallTimelock[hook]` is not cleared when the hook is removed via `uninstallModule`/
  `executeFromExecutor`, so a stale timestamp shortens (or confuses) a later emergency uninstall for a reinstalled hook.
- **Status:** Acknowledged. **Delta relevance:** FILE — `Nexus.sol`/`ModuleManager.sol`.
- **Verdict:** EXCLUDED. Related: #312 (EX-074) folds the same stale-timelock residue into its suggested fix.

### EX-064 — [Pashov L-09] Validators may fail to be uninstalled (gas grief via `onUninstall`)
- **Source:** Pashov §8.2. **Severity:** Low.
- **Root cause:** `ModuleManager._uninstallValidator` forwards all `gasleft()` to `validator.onUninstall` via
  `excessivelySafeCall`; a malicious validator can burn gas so the `withHook` `postCheck` afterwards runs out of gas.
- **Status:** Acknowledged. **Delta relevance:** FILE — `ModuleManager.sol`.
- **Verdict:** EXCLUDED.

### EX-065 — [Pashov L-10] Hook check may be bypassed (transient flag spans the whole transaction)
- **Source:** Pashov §8.2. **Severity:** Low.
- **Root cause:** `ModuleManager.withHook` uses a transient-storage flag for the whole transaction; if a hooked
  function (e.g. `executeFromExecutor`) is entered twice in one transaction, the second call's data skips pre/post checks.
- **Status:** Resolved. **Delta relevance:** FILE — `ModuleManager.sol`.
- **Verdict:** EXCLUDED.

### EX-066 — [Pashov L-11] Cannot install preValidationHooks in NexusBootstrap
- **Source:** Pashov §8.2. **Severity:** Low.
- **Root cause:** `NexusBootstrap` init functions had no way to install pre-validation hooks at setup, though
  `validateUserOp` consults the ERC-4337 pre-validation hook immediately after the bootstrap delegatecall.
- **Status:** Resolved (preValidationHooks params added to all init functions).
- **Delta relevance:** **DIRECT** — the delta touched these exact functions (added `validators[]` param; added
  `@param preValidationHooks` docs). The install path itself is the resolved L-11 fix.
- **Verdict:** EXCLUDED. Also claimed in: closed issue #262 (EX-090).

### EX-067 — [Pashov L-12] User can bypass the `withHook` modifier via NexusBootstrap
- **Source:** Pashov §8.2. **Severity:** Low.
- **Root cause:** `NexusBootstrap` install functions lack `withHook`, so module installs during initialization skip
  hook pre/post checks (ERC-7579 recommends hookable installs).
- **Status:** Resolved (per report). **Delta relevance:** FILE — `NexusBootstrap.sol`; delta changed init-function
  signatures (validators param) but added no hook checks.
- **Verdict:** EXCLUDED.

### EX-068 — [Pashov L-13] `MODULE_ENABLE_MODE_TYPE_HASH` incompatible with EIP-712
- **Source:** Pashov §8.2. **Severity:** Low.
- **Root cause:** The typehash declares `bytes32 initDataHash` while EIP-712 requires the dynamic type `bytes` for the
  hashed `initData` (declaration/encoding mismatch in `_getEnableModeDataHash`).
- **Status:** Resolved. **Delta relevance:** FILE — `Constants.sol` + `ModuleManager.sol`.
- **Verdict:** EXCLUDED. Also claimed in: CodeHawks M-04 (EX-008).

---

## B. Open GitHub issues (17/17 read in full, 2026-11-13)

All are KNOWN issues per the bounty rules. "Status: Open" for all; none had a maintainer fix visible on the issue page at read time.

### EX-069 — [Issue #321] `checkERC7739Support` has no try/catch (2026-11-11, Low)
- **Source:** GitHub issue #321. **Severity:** Low (reporter).
- **Root cause:** `Nexus._get7739Version` calls `IValidator(validator).isValidSignatureWithSender(...)` UNGUARDED for
  every installed validator + the default; one reverting validator makes `isValidSignature(magicHash, "")` revert
  account-wide. The normal `isValidSignature` path HAS a try/catch — the detection path is inconsistent.
- **Status:** Open. **Delta relevance:** FILE — `Nexus.sol`; detection path untouched by delta. (1.3.x lineage: unchanged — still no try/catch, §F.)
- **Verdict:** EXCLUDED.

### EX-070 — [Issue #320] `BiconomyMetaFactory.deployWithFactory` trusts raw returndata (2026-11-11, Low)
- **Source:** GitHub issue #320. **Severity:** Low.
- **Root cause:** `BiconomyMetaFactory.deployWithFactory` checks only `success`, then `mload`s `createdAccount` from
  returndata with no length/zero-address/code-size validation; a call returning <32 bytes yields a bogus (typically
  zero) "created account" that a caller may fund.
- **Status:** Open. **Delta relevance:** NO — factory file (also removed in 1.3.x/`dev`, §F/§G).
- **Verdict:** EXCLUDED.

### EX-071 — [Issue #319] `_multiTypeInstall` silently skips unknown module types (2026-11-11, Low)
- **Source:** GitHub issue #319. **Severity:** Low.
- **Root cause:** `ModuleManager._multiTypeInstall` if/else-if chain handles types 1,2,3,4,8,9 with NO final
  `else revert`; unknown ids (0, 5–7, 10+, 99) are silently skipped while the transaction succeeds — the caller
  believes a hook/pre-validation hook was installed when it wasn't. Inconsistent with `_installModule`, which reverts
  `InvalidModuleTypeId`. `LocalCallDataParserLib.parseMultiTypeInitData` does no bounds validation either.
- **Status:** Open. **Delta relevance:** FILE — `ModuleManager.sol` + `LocalCallDataParserLib.sol` (pragma-only delta
  touch); `_multiTypeInstall` untouched. (1.3.x: still no final else, §F.)
- **Verdict:** EXCLUDED. Duplicate of this root cause: closed issue #322 (EX-086).

### EX-072 — [Issue #316] Default validator unaddressable by its own address (2026-11-06, Low–Medium)
- **Source:** GitHub issue #316 (Foundry PoC, 15 tests). **Severity:** Low–Medium.
- **Root cause:** `ModuleManager._handleValidator` resolves ONLY `address(0)` to `_DEFAULT_VALIDATOR`; any other
  address must be in the sentinel validators list, which never contains the default validator (bootstrap bypasses the
  list; `_installValidator` reverts for it). Addressing the default validator by its own address reverts
  `ValidatorNotInstalled` in `validateUserOp`, `isValidSignature`, enable mode, and `emergencyUninstallHook`, even
  with a valid owner signature.
- **Status:** Open. **Delta relevance:** FILE — `ModuleManager.sol`/`Nexus.sol`; `_handleValidator` untouched by delta.
  Adjacency warning: the delta ADDED `getDefaultValidator()`, which returns exactly the address that cannot be used for routing.
- **Verdict:** EXCLUDED. Related: Zenith M-1/L-5 (EX-046/EX-053, narrower variants). Reporter verified the same logic in `stx-contracts` @ `61001d0` (confirmed in §F diff: logic-identical).

### EX-073 — [Issue #310] Session key escapes scope via enable-mode module install, drains account (2026-11-05, Medium)
- **Source:** GitHub issue #310 (PoC: `PocB1B10`, 13 tests). **Severity:** Medium.
- **Root cause:** ORACLE CONFUSION: `ModuleManager._checkEnableModeSignature` checks the enable-mode digest via the
  validator's generic ERC-1271 oracle `isValidSignatureWithSender` (plain ECDSA recovery, no policy context), while a
  session validator's call policy lives ONLY in `validateUserOp`. A scoped session key signs an enable-mode digest,
  installs a persistent attacker-owned validator, and drains the account. Nexus accepts ANY installed validator as the
  enable-mode authorizer and the digest binds nothing about the signer's scope.
- **Status:** Open. **Delta relevance:** FILE — `ModuleManager.sol`; enable-mode path untouched by delta. (1.3.x: unchanged, §F.)
- **Verdict:** EXCLUDED. Same root cause, second path: issue #312 (EX-074).

### EX-074 — [Issue #312] Session key removes the policy hook via emergency uninstall (2026-11-05, Medium)
- **Source:** GitHub issue #312 (PoC via gist; self-described as "second privileged path of the same root cause as #310"). **Severity:** Medium.
- **Root cause:** Same oracle confusion as EX-073 on the emergency-uninstall path: `ModuleManager._checkEmergencyUninstallSignature`
  accepts `isValidSignatureWithSender` from ANY installed validator, so a session key alone can remove the account's
  policy hook after the 1-day timelock (no owner cancel path; `_uninstallHook` doesn't clear the timelock either).
- **Status:** Open. **Delta relevance:** FILE — `ModuleManager.sol`/`Nexus.sol`.
- **Verdict:** EXCLUDED. Same root cause as EX-073; do not file either path, or any third path sharing the oracle-confusion mechanism, as novel.

### EX-075 — [Issue #309] `_checkInitializedValidators` unbounded loop — gas DoS bricks validator uninstall (2026-10-25, Medium)
- **Source:** GitHub issue #309 (PoC: 50 dummies → 274,521 gas; ~12,000 validators extrapolate past the 30M block limit). **Severity:** Medium.
- **Root cause:** `Nexus._checkInitializedValidators` (run on every validator `uninstallModule` when not 7702 and the
  default validator is uninitialized) loops the ENTIRE sentinel list with an external `isInitialized()` call + SLOAD per
  iteration, and `_installValidator` caps validator count at nothing — a long enough list makes uninstall permanently revert.
- **Status:** Open. **Delta relevance:** FILE — `Nexus.sol`; function only cosmetically touched by delta (comment/whitespace). (1.3.x: loop unchanged, §F.)
- **Verdict:** EXCLUDED. Sibling claim on the same function: issue #300 (EX-077, reverting-validator variant).

### EX-076 — [Issue #308] 7702 relay signature not chain-bound — raw `initDataHash` (2026-10-14, Low)
- **Source:** GitHub issue #308 (Foundry PoCs `TestInitChainBinding`/`TestInitCrossChain`). **Severity:** Low.
- **Root cause:** `Nexus.initializeAccount` 7702 relay branch validates the owner signature over RAW
  `keccak256(initData)` via `ECDSA.recover` — no EIP-712 domain, no `chainId`, no `verifyingContract` — while
  enable-mode and emergency-uninstall digests use chain-bound `_hashTypedData`. The same signature + initData can
  initialize the account on ANY chain where the owner sets the same 7702 delegation; the `erc7702InitHashes` replay
  map is per-chain storage, so it doesn't stop cross-chain reuse.
- **Status:** Open. **Delta relevance:** **DIRECT** — this IS the delta's flagship new logic (the 7702 relay branch).
  (1.3.x: same raw-hash semantics, only the hashing moved to assembly with fmp restore, §F — NOT fixed in the newer lineage.)
- **Verdict:** EXCLUDED. **This is the single most likely Hunter collision on the delta surface.**

### EX-077 — [Issue #307] `K1Validator.validateSignatureWithData` returns true for malformed sigs when owner is zero (2026-10-05, Low)
- **Source:** GitHub issue #307 (PoC zip, 3/3 pass). **Severity:** Low (reporter; honest impact note).
- **Root cause:** `K1Validator.validateSignatureWithData(hash, sig, data)` takes the owner from caller-supplied `data`
  with no zero check; `_recoverSigner` = Solady `tryRecoverCalldata` returns `address(0)` on malformed signatures, so
  `0 == 0` returns true. The file's own "owner can not be zero" assumption is enforced on ownership paths but not here.
  No in-scope production caller passes a zero owner (footgun for external `ISessionValidator` consumers).
- **Status:** Open. **Delta relevance:** NO — `K1Validator.sol`.
- **Verdict:** EXCLUDED. Distinct from Zenith H-1 (EX-045: different functions, `validateUserOp`/`isValidSignatureWithSender`,
  fixed via `getOwner()`). Duplicate of this root cause: closed issue #323 (EX-087).

### EX-078 — [Issue #306] `isValidSignature` reverts for empty/short non-detection signatures (2026-09-06, unstated/Low)
- **Source:** GitHub issue #306. **Severity:** Not stated (robustness; reporter proposes returning `0xffffffff`).
- **Root cause:** `Nexus.isValidSignature` special-cases empty signatures ONLY for the ERC-7739 detection hash; any
  0–19-byte signature with an ordinary hash falls through to `signature[0:20]`/`signature[20:]` slicing BEFORE the
  try/catch and reverts with an out-of-bounds panic instead of returning `0xffffffff`. Same pre-slice pattern in
  `ModuleManager._checkEmergencyUninstallSignature` (noted as acceptable-to-revert there).
- **Status:** Open. **Delta relevance:** FILE — `Nexus.sol`; slicing code untouched by delta (one whitespace-only line nearby). (1.3.x: unchanged, §F.)
- **Verdict:** EXCLUDED. Duplicate of this root cause: closed issue #324 (EX-088).

### EX-079 — [Issue #304] Constraint validation bypass in Nexus ComposableExecution (2026-08-17, unstated)
- **Source:** GitHub issue #304 (PoC `PoC_ConstraintOOBBypass.t.sol`). **Severity:** Not stated.
- **Root cause:** `ComposableExecutionLib._validateConstraints` (package `@biconomy/composability` v1.1.0, THIRD-PARTY
  dependency) uses the constraint index as a memory-word offset (`mload(add(rawValue, add(0x20, mul(i, 0x20))))`); for
  single-word fetchers (BALANCE, single-word RAW_BYTES), `Constraint[1]+` are checked against unrelated memory words
  instead of the fetched value, so upper-bound constraints can be bypassed.
- **Status:** Open. **Delta relevance:** NO — third-party package code, not in `contracts/`. (Bounty scope excludes
  third-party components unless directly affecting Nexus contracts; in any case the root cause is known/reported.)
- **Verdict:** EXCLUDED.

### EX-080 — [Issue #303] Private security report (contents UNKNOWN) — residual risk placeholder (2026-08-14)
- **Source:** GitHub issue #303. **Severity:** Unknown — reporter says the private report "may fall under the High-risk category".
- **Root cause:** UNKNOWN. The reporter emailed `security@biconomy.io` on 2026-08-02, received no confirmation, and
  deliberately included NO technical details in the public issue (per the no-pre-fix-disclosure policy). The issue is
  only a receipt-confirmation request.
- **Status:** Open; contents unknowable from any public source. **Delta relevance:** UNKNOWN — could overlap any surface, including the delta/7702 surface (the report predates the Aug 2026 transient-flag fix commit; subject area unknowable).
- **Verdict:** EXCLUDED-BY-UNCERTAINTY — see Residual Risks (§H). Any Hunter finding MUST be checked against the
  possibility that it is this report; there is no way to rule that out before filing.

### EX-081 — [Issue #300] Validator uninstall blocked by reverting `isInitialized()` in a remaining validator (2026-05-12, unstated)
- **Source:** GitHub issue #300 (PoC test, passes). **Severity:** Not stated (validator-management DoS).
- **Root cause:** `Nexus.uninstallModule` → `_checkInitializedValidators` makes RAW external `isInitialized()` calls
  with no try/catch; any remaining validator whose `isInitialized()` reverts (or OOGs) aborts the whole uninstall
  transaction (rolling back the removal), so no validator can be removed while the failing one remains installed
  (when the default validator is uninitialized and the account is not 7702).
- **Status:** Open. **Delta relevance:** FILE — `Nexus.sol`; same function as EX-075, cosmetic-only delta touch. (1.3.x: unchanged, §F.)
- **Verdict:** EXCLUDED. Sibling of EX-075 (same function, different trigger: revert vs. gas).

### Non-security open issues (one line each; all NO delta relevance; all EXCLUDED as known tracker items)

| ID | Issue | Notes |
|---|---|---|
| EX-082 | #305 (2026-08-31) Remove/document legacy ethers v5 dependency | `package.json`/`yarn.lock` carry both ethers v6 and v5 trees; dependency hygiene, no contract bug. |
| EX-083 | #298 (2026-03-19) `[DOCS]` | Empty/spam-like docs template ("zyz"), no technical content. |
| EX-084 | #296 (2026-03-19) "Expected vs. Actual Behavior" | Empty/spam-like bug template from the same author as #298/#297, no technical content. (Body contains apparent personal contact details — not reproduced here.) |
| EX-085 | #106 (2024-07-02) `yarn install` throws on pnpm-using dependencies | Yarn Berry toolchain issue with workaround; no contract bug. |

---

## C. Closed GitHub issues (30/30 enumerated)

**Method/honesty note:** the closed-issues list pages render 30 results across 2 pages, but strip most titles.
Page 1 showed 22 numbered entries + 3 entries whose numbers/titles did not render; page 2 showed 5 titled entries.
The 3 unrendered entries were resolved by probing every number in the gap (#169–#179): #177/#178/#179/#176/#175/#173/#170/#169
are pull requests (excluded from the `is:issue` query), leaving exactly #174, #172, #171 as the 3 closed issues.
22 + 3 + 5 = 30. Every closed issue's number + title below was verified by opening its page (except #64, sampled —
see EX-115 note). **Sweep completeness: 30 of 30.** Security-relevant ones were read in full; the rest are
task/docs/feature trackers with no security root cause (one line each).

### Security-relevant closed issues (read in full)

### EX-086 — [Closed #322] Multi-type install silently skips unknown type IDs (filed + closed 2026-11-13, Low)
- **Source:** GitHub issue #322 (closed the same day it was filed — duplicate triage).
- **Root cause:** IDENTICAL to EX-071 (#319): `ModuleManager._multiTypeInstall` has no final `else revert`; unknown
  type ids silently skip. PoC-verified 6/6 (including all-bogus multi-install succeeding as a no-op).
- **Status:** Closed (as duplicate of the #319 root cause; closure reason not visible on the page).
- **Delta relevance:** FILE — see EX-071. **Verdict:** EXCLUDED (duplicate of EX-071).

### EX-087 — [Closed #323] `K1Validator.validateSignatureWithData` accepts any signature for owner `address(0)` (filed + closed 2026-11-13, Low)
- **Source:** GitHub issue #323 (closed the same day it was filed).
- **Root cause:** IDENTICAL to EX-077 (#307): caller-supplied zero owner + `tryRecoverCalldata` returning `address(0)` ⇒ `0 == 0` validates.
- **Status:** Closed (duplicate of #307). **Delta relevance:** NO. **Verdict:** EXCLUDED (duplicate of EX-077).

### EX-088 — [Closed #324] `Nexus.isValidSignature` reverts on short signatures (filed + closed 2026-11-13, Low/Info)
- **Source:** GitHub issue #324 (closed the same day it was filed).
- **Root cause:** IDENTICAL to EX-078 (#306): `signature[0:20]` slicing before the try/catch panics (0x21) on <20-byte
  signatures and empty non-magic-hash signatures.
- **Status:** Closed (duplicate of #306). **Delta relevance:** FILE. **Verdict:** EXCLUDED (duplicate of EX-078).

**Triage signal:** three independent researchers filed #322/#323/#324 on 2026-11-13 and all three were closed the
same day as duplicates of older open issues. Duplicate risk is not theoretical — it is actively being enforced.

### EX-089 — [Closed #299] TCPI Research automated "tool interface" scan — 169 unvalidated pattern hits (2026-04-16, closed 2026-04-17)
- **Source:** GitHub issue #299 (academic automated static analysis across 138 repos; 63 Critical / 61 High / 45 Medium claimed).
- **Root cause:** NO VALIDATED ROOT CAUSE. The 20 shown findings are keyword-pattern matches, overwhelmingly in
  `test/` and `contracts/mocks/` (e.g. `signMessage` in tests flagged as "private key exposure"; `transferOwnership(`
  flagged as "privilege escalation"; `.delegatecall(` in `Nexus.sol:192` flagged as "delegatecall abuse"; a `MNEMONIC`
  string in `scripts/foundry/Base.s.sol`). 104 further critical/high findings are not shown at all.
- **Status:** Closed. **Delta relevance:** NO (no validated contract mechanism; the one `contracts/` pattern shown,
  the `Nexus.sol` delegatecall, is the bootstrap delegatecall — a documented design, not a finding).
- **Verdict:** EXCLUDED as reported-and-closed scanner output. Hunters: a finding that merely matches one of #299's
  PATTERN LABELS is not novel; a real vulnerability must still clear every other entry in this list on its own mechanism.

### EX-090 — [Closed #262] NexusBootstrap does not allow PreValidationHook installation during setup (2026-03-21)
- **Source:** GitHub issue #262 (closed 2026-03-28). **Severity:** Bug report, unstated.
- **Root cause:** IDENTICAL to Pashov L-11 (EX-066): bootstrap init functions could not install pre-validation hooks.
- **Status:** Closed (fixed — params added). **Delta relevance:** **DIRECT** — see EX-066.
- **Verdict:** EXCLUDED (same root cause as EX-066).

### EX-091 — [Closed #260] `ModuleInstalled` is not triggered in NexusBootstrap (2026-03-19)
- **Source:** GitHub issue #260 (closed 2026-03-28).
- **Root cause:** Same event-gap family as Zenith I-2 (EX-I33): validators installed during initialization don't emit
  `ModuleInstalled`, breaking frontend/indexer enumeration.
- **Status:** Closed. **Delta relevance:** FILE — `NexusBootstrap.sol`.
- **Verdict:** EXCLUDED.

### Non-security closed issues (one line each; all EXCLUDED as known/closed tracker items; all NO unless noted)

| ID | Issue | Title / notes |
|---|---|---|
| EX-092 | #297 (2026-03-19) | `[SECURITY PRE-SCREEN]` — empty/spam-like ("Ugh just"), no content; self-closed same day. |
| EX-093 | #255 (2026-03-15) | `K1Validator` should have an `OwnerRegistered`-like event — feature request (enhancement/question). |
| EX-094 | #228 (2024-12-15) | Failing test `test_ExecuteDelegateCallFromExecutor_Success` — test issue, no contract finding. |
| EX-095 | #223 (2024-11-28) | npm install via GitHub URL misses `scripts/` (`HelperConfig`) due to `.npmignore` — packaging issue. |
| EX-096 | #211 (2024-10-28) | Update ERC-7739 Validator Base + use as dep from K1Validator — dependency task. |
| EX-097 | #210 (2024-10-25) | Fix Nexus thumbnail — repo cosmetic. |
| EX-098 | #206 (2024-10-21) | Infra Passkey Server — internal task; closed as "should not be in public repo". |
| EX-099 | #190 (2024-09-30) | Nexus documentation update (wiki, gas benchmarks, security doc) — docs task. |
| EX-100 | #189 (2024-09-30) | Nexus code freeze and deploy on Base — release task. |
| EX-101 | #188 (2024-09-30) | Add PR to ERC-7579 repo — standards task. |
| EX-102 | #187 (2024-09-30) | Write manual on how to build policies/signers — docs task. |
| EX-103 | #186 (2024-09-30) | Plan next developments for the Smart Sessions ecosystem — planning task. |
| EX-104 | #185 (2024-09-30) | Smart Session fixes // Spearbit audit — remediation tracking task (process, not a finding). |
| EX-105 | #180 (2024-09-23) | `[GENERAL] earggfefgeq` — empty test issue, no content. |
| EX-106 | #174 (2024-09-20) | Nexus Audit Remediations — remediation tracking task (no finding content on the page). |
| EX-107 | #172 (2024-09-18) | Publish Spearbit complete audit on repo — process task. |
| EX-108 | #171 (2024-09-18) | Nexus uploading of DeFi Safety Score to repo — process task. |
| EX-109 | #168 (2024-09-18) | Nexus to allow vanilla ERC-1271 flow — feature request (three design options discussed; implemented via validator paths). |
| EX-110 | #64 (2024-05-27) | Gaslite gas optimization audit — gas-only findings (sampled: first ~546 of 1286 lines, all gas nits across BaseAccount/ExecutionHelper/Storage/ModuleManager; full enumeration of gas nits not performed — gas is out of bounty scope for security findings in any case). |
| EX-111 | #49 (2024-05-27) | `[FEATURE] Factory enhancement and staking methods` — feature task (title from list page). |
| EX-112 | #48 (2024-09-19) | `[FEATURE] ADD ERC7484 registry integration` — feature task (title from list page). |
| EX-113 | #45 (2024-06-04) | `[FEATURE] finalise ERC1271 base` — feature task (title from list page). |
| EX-114 | #42 (2024-06-04) | `[GENERAL] Create Biconomy-7579-Modules Repo` — repo task (title from list page). |
| EX-115 | #18 (2024-06-04) | `[GENERAL] Add latest spec link and architecture diagrams in Readme/assets` — docs task (title from list page). |

Note: EX-111–EX-115 titles come from the page-2 list rendering (which preserved titles); their bodies were not
opened (all are 2024 feature/docs tasks, none plausibly security findings). EX-092–EX-110 pages were opened individually.

---

## D. Published advisory

### EX-116 — GHSA-q47q-h6x2-f5qg: Stale transient initialization flag
- **Source:** `SECURITY.md` ("Published Advisories") + fix commit `9007ba1` (PR #302) at `main` HEAD.
- **Severity:** Not stated in SECURITY.md (High-risk class: counterfactual-balance theft pre-deployment).
- **Root cause:** `NexusProxy` set the `Initializable` transient flag in its constructor and `requireInitializable()`
  never cleared it; EIP-1153 transient storage persists for the whole transaction, so the classic (non-7702)
  `initializeAccount` guard still passed on a SECOND call within the deploying transaction. An account holding funds
  at its counterfactual address could be deployed and re-initialized in the same transaction with attacker bootstrap data.
- **Fix (verified present at HEAD):** `contracts/lib/Initializable.sol::requireInitializable()` now `tstore(slot, 0x00)`
  after checking — single-use within the deploying transaction. Verified in the `9af2d1d..HEAD` diff and identical in
  the `stx-contracts` lineage (comment wording only differs).
- **Status:** Fixed at HEAD. **Delta relevance:** **DIRECT** — the fix commit IS the HEAD commit of the delta.
- **Discrepancy (verified 2026-11-13):** SECURITY.md calls this a published advisory, but the repo's GitHub
  advisories tab shows "There aren't any published security advisories". The issue is excluded regardless (fix verified
  in code). SECURITY.md's fix citation `272c408` does NOT resolve in this repo (verified: `fatal: Not a valid object
  name`); the fix here is `9007ba1`. The "reviewed by Pashov in July 2026" claim is unverified (the documented Pashov
  `stx-contracts` review ran Nov 2025 — see §E).
- **Verdict:** EXCLUDED. **Hunter warning:** re-checks of the transient-flag fix's COMPLETENESS across init paths
  (classic + 7702 + relay + PREP) are the audit's stated focus — but any finding that IS this stale-flag mechanism,
  or a trivial restatement of it, is excluded. Only a genuinely distinct bypass mechanism counts as new.

---

## E. Pashov `stx-contracts` review, Nov 26–27, 2025 (5 issues, 1.3.x lineage)

Source: Pashov Audit Group "Biconomy Security Review" (review `b3695fcd`, fixes `8dea408c`, repo
`bcnmy/stx-contracts`), read via the pashov/audits mirror PDF. Scope: Nexus + Composability
(`ComposableExecutionLib`, `ComposableStorage`, `ComposableExecutionModule`, `Nexus`, `BaseAccount`,
`ModuleManager`, `K1MeeValidator`, interfaces). All 5 Resolved. Each entry records whether the root cause
could apply to the 1.2.1-lineage code in THIS repo (checked against `main` HEAD sources, not assumed).

### EX-117 — [Pashov-stx H-01] Incorrect assembly packing in `getNamespace` causes collisions (High, Resolved)
- **Root cause:** `getNamespace(account, caller)` assembly: `mstore(0x00, account)` then `mstore(0x14, _caller)`
  overwrites the last 12 bytes of the account address with padding; `keccak256(0x0c, 0x28)` hashes only the first
  8 bytes of the account + 12 zero bytes + caller — accounts sharing an 8-byte prefix collide, and external systems
  computing `keccak256(abi.encodePacked(account, caller))` hit uninitialized slots (`SlotNotInitialized` on `readStorage`).
- **Applies to 1.2.1 code in this repo?** NO — `getNamespace` does not exist anywhere under this repo's `contracts/`
  (verified by grep). It lives in the Composability/storage layer of the 1.3.x lineage.
- **Delta relevance:** NO. **Verdict:** EXCLUDED (known, other lineage; not present in this repo).

### EX-118 — [Pashov-stx L-01] Assembly errors not declared in the interface (Low, Resolved)
- **Root cause:** In `stx-contracts`, `EnableModeSigError`/`ValidatorNotInstalled` (selectors `0x46fdc333`/`0x6859e01e`)
  and others are reverted-from assembly but were not defined in `IModuleManagerEventsAndErrors`, so the ABI omits them (integration hazard).
- **Applies to 1.2.1 code in this repo?** NO — all four named errors ARE declared in this repo's interfaces
  (`InvalidPREP` in `INexusEventsAndErrors`; `CanNotRemoveLastValidator`, `ValidatorNotInstalled(address)`,
  `EnableModeSigError` in `IModuleManagerEventsAndErrors`), and this repo's `ModuleManager` assembly blocks emit no
  error selectors (only the `_amIERC7702` extcode check and fallback return/revert passthrough). (At `stx-contracts`
  HEAD the declarations were since added — the fix is visible there.)
- **Delta relevance:** NO. **Verdict:** EXCLUDED (known; defect pattern absent in 1.2.1 code).

### EX-119 — [Pashov-stx L-02] `PREPInitialized` event emitted but not declared (Low, Resolved)
- **Root cause:** In `stx-contracts`, `Nexus._handlePREP` emits `PREPInitialized(r)` via assembly `log1` without an
  event declaration, so the ABI omits it and indexers cannot filter for it.
- **Applies to 1.2.1 code in this repo?** NO — here the event IS declared (`INexusEventsAndErrors.sol:27`) and emitted
  with a normal `emit PREPInitialized(r)` (`Nexus.sol:550`). The assembly-emission pattern does not exist in this repo.
  (At `stx-contracts` HEAD the declaration was since added at `INexusEventsAndErrors.sol:59`.)
- **Delta relevance:** **DIRECT** (PREP surface) — but the defect is absent in 1.2.1; do not file it.
- **Verdict:** EXCLUDED (known; not present in this repo).

### EX-120 — [Pashov-stx L-03] Free memory pointer not updated (Low, Resolved)
- **Root cause:** In `stx-contracts`, assembly EIP-712 hash builders in `ModuleManager._getEnableModeDataHash` and
  `Nexus.initializeAccount` borrow `mload(0x40)` without advancing it, leaving dirty bytes and a stale free-memory pointer.
- **Applies to 1.2.1 code in this repo?** NO — here `initializeAccount` computes `initDataHash` with Solidity-level
  `keccak256(initData)` (`Nexus.sol:319`) and `_getEnableModeDataHash` uses `keccak256(abi.encode(...))`; neither
  borrows the free-memory pointer in assembly. (At `stx-contracts` HEAD both functions restore the pointer with
  `mstore(0x40, ...)` — the fix is visible there.)
- **Delta relevance:** **DIRECT** (both named functions are delta/adjacent) — but the defect pattern is absent in 1.2.1; do not file it.
- **Verdict:** EXCLUDED (known; not present in this repo).

### EX-121 — [Pashov-stx L-04] Invalid EIP-712 domain typehash (+ nested-struct hash) (Low, Resolved)
- **Root cause:** In `stx-contracts` MEE code, `_DOMAIN_TYPEHASH` was computed from a malformed type string missing a
  closing parenthesis (`"EIP712Domain(string name"`), and the `SuperTx(MeeUserOp[] ...)` array typehash omitted the
  nested `MeeUserOp` struct definition required by EIP-712.
- **Applies to 1.2.1 code in this repo?** NO — no `SuperTx`/`MeeUserOp` code exists in this repo's `contracts/`; the
  only `_DOMAIN_TYPEHASH` occurrences are in test mocks with a different (well-formed) value.
- **Delta relevance:** NO. **Verdict:** EXCLUDED (known, other lineage; not present in this repo).

---

## F. `stx-contracts` lineage check (1.3.x vs this repo's 1.2.1)

**Public:** YES. `git ls-remote https://github.com/bcnmy/stx-contracts.git HEAD` →
`61001d0f53540c5bdf00bd79ad64995401446b09` (merge PR #25, deploy/v2.2.3; also the tip of its `develop` branch —
note: THIS repo has no `develop` branch, but `stx-contracts` does). Shallow-cloned to `/tmp/stx-contracts`
(NOT into `~/workspace`); diffed 8 matched files against nexus `main` HEAD. Layout differs
(`contracts/nexus/...`, `contracts/lib/nexus/...`, `contracts/interfaces/nexus/...`); module interfaces come
from the `erc7579` package; the validator is `K1MeeValidator` v1.1.0 (not `K1Validator`).

**What the Biconomy team itself changed between lineages** (strong duplicate/fix signal — a finding whose
mechanism was already rewritten here is likely already known/fixed; a finding whose mechanism is UNCHANGED
here is still excluded if it appears in §A–§E, but the lineage diff cannot by itself prove it):

Changed substantively in 1.3.x:
- **Registry fully removed:** `RegistryAdapter` inheritance dropped; all `withRegistry` modifiers removed from
  install functions and `executeFromExecutor`; `setRegistry` deleted; `RegistryConfig` struct deleted;
  `BiconomyMetaFactory`/`K1ValidatorFactory` absent; `IStorage.registry` slot kept only as a layout placeholder
  ("keeping this to avoid collisions b/w versions"). ⇒ Any registry-mechanism finding (EX-002/018/023/034/056/059
  family) is dead in the working line; do not file registry findings.
- **Gas-optimization assembly rewrites (same semantics):** `installModule` event via `log1`; `executeUserOp`,
  `_initializeAccount`, `_handlePREP`, `_checkInitializedValidators`, `_enableMode`, `_handleValidator`, `_fallback`
  reverts via assembly `mstore`+`revert`; `_getEnableModeDataHash` rewritten in assembly WITH fmp restore
  (Pashov-stx L-03 fix); `initializeAccount` initData hash in assembly WITH fmp restore (same fix);
  `supportsModule` via bitmap `((1 << moduleTypeId) & 0x31F) != 0`; `_isPrevalidationHookType` assembly helper.
- **`checkERC7739Support` → internal `_checkERC7739Support`** (no longer public); `accountId()` hardcoded
  `"biconomy.nexus.1.3.3"`; Nexus EIP-712 domain version `"1.3.2"`; Bootstrap domain version `"1.3.0"`.
- **Bootstrap restructured:** main init functions became `public` (internal `_init*` helpers inlined);
  `*NoRegistry` variants became thin backwards-compat wrappers; `RegistryConfig` param dropped everywhere.
  The delta's `validators[]` param + loop in `initNexusWithDefaultValidatorAndOtherModules` is PRESENT in 1.3.x
  with the same doc-only "should not contain the default validator" guard.
- **`BaseAccount`:** `_ACCOUNT_IMPLEMENTATION_ID` constant and `nonce()` EntryPoint passthrough removed.
- **`K1MeeValidator.validateSignatureWithData`:** adds `require(data.length >= 20)` but STILL takes the owner from
  caller-supplied `data[:20]` with no zero-owner check (delegates to `SimpleValidatorLib`/`TxValidatorLib`/
  `PermitValidatorLib`/`NoMeeFlowLib` — zero-owner behavior inside those libs was NOT verified here).
- **`LibPREP`:** logic-identical; only `LibEIP7702.delegation` → `delegationOf` (Solady API rename) + dropped unused import.
- **`Initializable`:** logic-identical (GHSA fix present in both; comment wording only differs).
- **`NonceLib`/`LocalCallDataParserLib`:** comments/formatting only. **`IStorage`:** comment only.

UNCHANGED in substance in 1.3.x (mechanism-for-mechanism identical to 1.2.1 — these known issues are live in
both lineages, and all are already excluded above): the 7702 relay raw-hash signature + `erc7702InitHashes`
(EX-076/#308); `_handleValidator` address(0)-only default resolution (EX-072/#316); enable-mode any-installed-
validator authorization (EX-073/#310) and emergency-uninstall any-installed-validator authorization (EX-074/#312);
`_multiTypeInstall` no-final-else (EX-071/#319); `_checkInitializedValidators` unbounded/revert-sensitive loop
(EX-075/#309, EX-081/#300); `isValidSignature` pre-try/catch slicing (EX-078/#306); `_get7739Version` unguarded
calls (EX-069/#321); `_handlePREP` 0x61 length check (EX-057/Pashov L-02); stale `emergencyUninstallTimelock`
(EX-063/Pashov L-08).

**Diff limits:** shallow clone (`--depth 1`) at HEAD only — no history, no per-commit attribution; comparison is
file-to-file textual diff on 8 matched files + targeted greps (validator, interfaces, factory dir). Behavioral
equivalence of assembly rewrites was judged by reading, not by execution. The `develop` branch of `stx-contracts`
was NOT separately diffed (it equals HEAD per `ls-remote`).

---

## G. `dev`-branch proxy note (the `develop` exclusion, as written, is unverifiable)

- **No `develop` branch exists in `bcnmy/nexus`** (verified: `git branch -a` lists `main`, `dev`, `deploy/*`,
  `release/*`, `fix/*`, `stacked/*` — no `develop`). The bounty text ("must not have already been addressed/fixed
  in the `develop` branch") cannot be checked as written. Note: `bcnmy/stx-contracts` DOES have a `develop`
  branch (= its HEAD, `61001d0`) — whether the bounty text means THAT branch is unconfirmed; treat as an open
  question for Biconomy, not as an assumption.
- **`dev` (HEAD `5e64c4a`, 2025-11-01) is BEHIND `main` and diverged:** 4 dev-only commits vs 2 main-only commits
  (`9007ba1` transient-flag fix + merge #294). The dev-only commits REMOVE code (PR #295: "rm registry, k1 factory,
  meta factory") rather than fixing bugs.
- **Verified:** `contracts/base/RegistryAdapter.sol`, `contracts/factory/BiconomyMetaFactory.sol`, and
  `contracts/factory/K1ValidatorFactory.sol` exist on `main` and are ABSENT on `origin/dev`;
  `NexusBootstrap.sol` is 447 lines on `main` vs 313 on `dev` (registry paths stripped).
- **Implication:** a finding in registry/factory code (RegistryAdapter, BiconomyMetaFactory, K1ValidatorFactory,
  RegistryFactory, registry checks) could plausibly be "already addressed" in Biconomy's working line, since the
  direction of travel — in BOTH `dev` and the 1.3.x lineage — is removal of that code. Do NOT treat `dev` as
  `develop` without asking Biconomy. Flag any factory/registry finding as scope-uncertain. This reinforces the
  exclusion of EX-002/009/018/023/030/034/056/059/060/061/062/070 and the registry-adjacent info items.

---

## H. Residual risks (read before filing anything)

1. **#303 — unknown private report (EX-080).** A possibly-High report emailed 2026-08-02; contents unknowable
   publicly. It may cover the delta surface, the 7702/PREP surface, or anything else. NO dedup pass can rule out
   collision with it. State this risk plainly in any filing decision; it cannot be retired by public research.
2. **Private H1-style / email duplicates are unsearchable.** SECURITY.md routes Critical/High reports to private
   email. Any number of private reports may exist beyond #303. Public-tracker + audit dedup is necessary but not
   sufficient; first-to-file is decided by Biconomy's private inbox, not by this list.
3. **Closed-sweep limits.** The closed sweep is COMPLETE for issues (30/30, §C) — but: (a) issue COMMENTS were
   generally not read (bodies + titles only), so a root cause disclosed only in a comment thread could be missed;
   (b) #64's 1286-line gas audit was sampled, not fully enumerated (gas-only, low risk); (c) EX-111–EX-115 bodies
   were not opened (titles only, all 2024 feature/docs tasks); (d) pull-request discussions were NOT swept —
   audit-fix PRs (#112–#199 etc.) sometimes contain researcher follow-ups; (e) the sweep is a snapshot of
   2026-11-13 — new issues filed after this pass (note the Nov 11–13 filing burst) are not covered. Re-check the
   tracker immediately before filing.
4. **`stx-contracts` diff limits.** Shallow HEAD-only clone; 8 files diffed textually; assembly-rewrite equivalence
   judged by reading. A subtle behavioral divergence in an "unchanged" function, or a fix on a non-HEAD branch
   (e.g. `stx-contracts/develop` — which equals HEAD today — or a deploy branch), could change the picture.
   The `272c408`/`July 2026 Pashov review` SECURITY.md claims remain unverified and could indicate a second,
   unpublished review whose findings are unknown.
5. **Acknowledged ≠ fixed ≠ fileable.** Several excluded items are Acknowledged-but-unfixed at HEAD (e.g. Cantina
   5.1.4 validator part, 5.2.5, 5.2.6; Pashov L-03/L-04/L-08/L-09; #310/#312/#316/#308/#309/#300 open issues).
   "Still present at HEAD" does NOT make them fileable — they are known issues, and the bounty excludes known
   issues. Hunters must find mechanisms NOT on this list.
6. **Third-party code.** `@biconomy/composability` (EX-079), `erc7579`/`solady`/`sentinellist` dependencies, and
   the MEE/SuperTx code in `stx-contracts` are out of bounty scope unless directly affecting Nexus contracts.
   Findings rooted purely in those packages are excluded here AND likely out of scope.
7. **This list keys on root cause as UNDERSTOOD from the sources.** If a Hunter believes their mechanism is
   distinct from a listed entry, the burden is on them to articulate the distinguishing mechanism precisely
   (different function, different precondition, different violated invariant) — "different PoC, same function,
   same check missing" is a duplicate.

---

## I. Tracker delta 2026-11-14 (14 new open issues #325–#338 + disproved candidate H-B1)

Merged 2026-11-14 from `NEW-ISSUES-2026-11-14.md` (sweep 2026-11-14 02:48 UTC; all 14 bodies read in full via
page reads, zero GitHub API calls). All 14 were Open at crawl time. Issue comments were NOT read; re-sweep before
any filing — the tracker filed 14 issues in ~6.5 hours. §B/§C numbering continues here (EX-122–EX-135); EX-136
records the Option 1 disproved candidate so no future pass re-claims it.

### EX-122 — [Issue #325] `_initNexus` lacks zero-address validator skip, bricks CREATE2 address (2026-11-13)
- **Source:** GitHub issue #325. **Severity:** Not stated.
- **Root cause:** The generalized `_initNexus` validators loop has no `address(0)` skip (unlike the sibling
  default-validator flow and the executors/fallbacks/hooks loops in the same function). One zero entry calls
  `IValidator(address(0)).isModuleType()`, returns false, reverts the whole init with `MismatchModuleTypeId`
  inside the `NexusProxy` constructor — that CREATE2 address becomes unobtainable.
- **Status:** Open. **Verdict:** EXCLUDED. Novel mechanism (bootstrap install/init-adjacent).

### EX-123 — [Issue #326] Emergency-uninstall nonce burned at initiation; 3-day reset dead-ends the signature (2026-11-13)
- **Source:** GitHub issue #326. **Severity:** Not stated.
- **Root cause:** `_checkEmergencyUninstallSignature` marks the nonce consumed at INITIATION (the first call only
  starts the 1-day timelock), so after the 3-day auto-reset the original signature can never complete the removal
  (`InvalidNonce`) and a fresh signature + new nonce is required. The reset branch is also checked BEFORE the
  uninstall branch, so at exactly t+3d the reset wins and resurrects the timelock instead of uninstalling.
- **Status:** Open. **Verdict:** EXCLUDED. Novel mechanism; distinct from #332 (EX-129) and Pashov L-08 (EX-063).

### EX-124 — [Issue #327] Stale natspec: nonce layout + onInstall/onUninstall reference (2026-11-13, docs-only)
- **Source:** GitHub issue #327. **Severity:** None (docs).
- **Root cause:** `validateUserOp` natspec says the validator is in the upper 96 nonce bits; the actual `NonceLib`
  layout is [3 bytes empty][1 byte mode][20 bytes validator][8 bytes nonce]. `uninstallModule` natspec says the
  underlying functions call `module.onInstall()`; they call `IModule.onUninstall`. No code mechanism.
- **Status:** Open. **Verdict:** EXCLUDED (docs-only, recorded for completeness).

### EX-125 — [Issue #328] Raw 0x32 panics instead of typed errors at 4 boundaries (2026-11-13)
- **Source:** GitHub issue #328. **Severity:** Not stated.
- **Root cause:** Four unguarded slicing/parsing boundaries panic with 0x32 (array out-of-bounds) instead of their
  documented typed errors: `_installFallbackHandler` (`bytes4(params[0:4])` / `bytes1(params[4])`, no length check);
  `ExecLib.decodeSingle` (`[0:20]` / `[20:52]` unguarded); the `initializeAccount` 7702 branch (`initData[0:65]`
  before `_initializeAccount`'s length check); `parseEnableModeData` (raw `calldataload`, panics when an offset
  exceeds the input). All paths EntryPoint/self-gated per the reporter.
- **Status:** Open. **Verdict:** EXCLUDED. Novel mechanism family (four boundaries; enable-mode parser boundary
  overlaps EX-130's parser claim).

### EX-126 — [Issue #329] Zero-validator init succeeds while uninstall enforces at-least-one-validator (2026-11-13)
- **Source:** GitHub issue #329. **Severity:** Not stated.
- **Root cause:** `_initNexus` / `_initNexusScoped` accept an empty `validators` array with no post-loop assertion,
  producing an account with initialized sentinel lists and `isInitialized() == true` yet no installed validator.
  Uninstall enforces the invariant (`CanNotRemoveLastValidator` via `_checkInitializedValidators`), so the invariant
  is asymmetric: unreachable by uninstalling, reachable by deploying directly into it.
- **Status:** Open. **Verdict:** EXCLUDED. Novel mechanism; contrasts the Pashov M-02 guard (EX-055), not its loop.

### EX-127 — [Issue #330] `_multiTypeInstall` silently drops unknown type IDs (2026-11-13, Low)
- **Source:** GitHub issue #330. **Severity:** Low (reporter).
- **Root cause:** Same as EX-071 (#319): no final `else revert` in the `_multiTypeInstall` chain; unknown type ids
  silently skipped while the transaction succeeds and emits `ModuleInstalled(0, module)`.
- **Status:** Open. **Verdict:** EXCLUDED. Duplicate of EX-071 / EX-086.

### EX-128 — [Issue #331] `isValidSignature` reverts on malformed signatures (2026-11-13, Low)
- **Source:** GitHub issue #331. **Severity:** Low (reporter).
- **Root cause:** Same pre-try/catch mechanism as EX-078 (#306): validator-prefix parsing (`signature[0:20]`) and
  `_handleValidator()` run OUTSIDE the try/catch, so 0–19-byte signatures panic and unknown-validator prefixes
  revert `ValidatorNotInstalled` instead of returning `0xffffffff`. This filing additionally names the
  unknown-prefix variant explicitly.
- **Status:** Open. **Verdict:** EXCLUDED. Duplicate of EX-078 / EX-088 (same mechanism family; do not file either variant).

### EX-129 — [Issue #332] Emergency-uninstall timelock keyed by hook only; later request rides earlier clock (2026-11-13, Low)
- **Source:** GitHub issue #332. **Severity:** Low (reporter).
- **Root cause:** `emergencyUninstallTimelock` is keyed by hook address only — not by nonce or `deInitData` — so a
  later, different request for the same hook (different nonce, different `deInitData`) executes as soon as the FIRST
  request's 1-day clock expires, compressing the second request's own review window. Authorization is still enforced
  per request; the defect is clock-sharing across distinct requests.
- **Status:** Open. **Verdict:** EXCLUDED. Novel mechanism; reporter distinguishes it from EX-123 and EX-063.

### EX-130 — [Issue #333] Multi-type install ignores unknown types + malformed initData; parser has no bounds checks (2026-11-13, Low)
- **Source:** GitHub issue #333. **Severity:** Low (reporter).
- **Root cause:** Two compounding gaps: (1) `LocalCallDataParserLib.parseMultiTypeInitData` is hand-rolled assembly
  documented as `abi.decode(initData, (uint[], bytes[]))` but performs no bounds/length checks — `calldataload`
  beyond calldata returns zero, so truncated/garbage `initData` decodes to empty arrays and the install loop never
  runs; (2) `_multiTypeInstall` has no final `else revert` (EX-071 mechanism), while `installModule`
  unconditionally emits `ModuleInstalled`, so callers/indexers see a successful install that installed nothing.
  Reporter states the parser + chain are identical in stx-contracts 1.3.3.
- **Status:** Open. **Verdict:** EXCLUDED. Gap (2) duplicates EX-071; gap (1), the parser's missing bounds checks,
  is a NEW known mechanism.

### EX-131 — [Issue #334] `K1Validator.validateSignatureWithData` zero-owner `0==0` bypass (2026-11-13, Low)
- **Source:** GitHub issue #334. **Severity:** Low (reporter).
- **Root cause:** Same as EX-077 (#307): expected owner taken straight from caller-supplied `data` with no
  zero-address check; Solady `tryRecoverCalldata` returns `address(0)` on recovery failure, so `data` encoding
  `address(0)` makes any malformed signature (incl. empty) "validate" via `0 == 0`. Reporter verifies the same
  defect in the 1.3.3 lineage (`K1MeeValidator`).
- **Status:** Open. **Verdict:** EXCLUDED. Duplicate of EX-077 / EX-087.

### EX-132 — [Issue #335] `isValidSignature` reverts instead of `0xffffffff` for malformed signatures (2026-11-13, Low)
- **Source:** GitHub issue #335. **Severity:** Low (reporter).
- **Root cause:** Same mechanism as EX-078 / EX-088 / EX-128: only the validator call is inside the try/catch;
  prefix extraction and `_handleValidator` resolution happen before it. Reporter states it is present in both 1.2.1
  (`main` @ `9007ba1`) and the deployed 1.3.3 lineage (identical code).
- **Status:** Open. **Verdict:** EXCLUDED. Duplicate of EX-078 / EX-088 / EX-128.

### EX-133 — [Issue #336] Simple-mode ERC-1271 replay across same-owner accounts — STX-ONLY (2026-11-13, Medium)
- **Source:** GitHub issue #336. **Severity:** Medium (reporter).
- **Root cause:** In `bcnmy/stx-contracts` @ `61001d0`, `HashLib.hashTypedDataForAccount()` rebuilds the EIP-712
  domain from the account name only, ignoring `chainId`/`verifyingContract`/version, and the explicit account
  binding applies only to Permit/On-Chain modes, not Simple mode — so a Simple-mode SuperTx signature validates on
  any same-owner Nexus account. ERC-4337 `validateUserOp` NOT affected.
- **Status:** Open. **Verdict:** EXCLUDED as a known tracker item; NO 1.2.1 mechanism exists (no SuperTx/HashLib in
  this repo). Do not treat as a Nexus.sol finding.

### EX-134 — [Issue #337] NodePaymaster `tx.origin` gate — STX-ONLY (2026-11-13, Medium)
- **Source:** GitHub issue #337. **Severity:** Medium (reporter).
- **Root cause:** In `bcnmy/stx-contracts` @ `61001d0`, `NodePaymaster._validatePaymasterUserOp` gates only on
  `tx.origin == owner() || _workerEOAs[tx.origin]`; a tricked operator calling a malicious contract from the
  owner/worker EOA lets an attacker bundle arbitrary userOps and drain the paymaster deposit. Reporter notes the
  code documents `tx.origin` use as intentional.
- **Status:** Open. **Verdict:** EXCLUDED as a known tracker item; NO NodePaymaster code exists in this repo.

### EX-135 — [Issue #338] `K1MeeValidator.validateSignatureWithData` zero-owner bypass — STX-ONLY (2026-11-13, Low)
- **Source:** GitHub issue #338. **Severity:** Low (reporter).
- **Root cause:** In `bcnmy/stx-contracts` @ `61001d0`, `K1MeeValidator.validateSignatureWithData()` takes the owner
  from `data[:20]` with no zero-address check; invalid signatures recover to `address(0)`, so `0 == 0` returns true
  for any hash. Same root-cause family as EX-077 / EX-087 / EX-131, in the 1.3.3 lineage.
- **Status:** Open. **Verdict:** EXCLUDED as a known tracker item; same family as the 1.2.1 EX-077 mechanism.

### EX-136 — [Option 1 candidate H-B1] `initializeAccount` self-call branch skips init guards — DISPROVED, NOT_A_BUG (2026-11-13)
- **Source:** Option 1 audit, REPORT-delta.md; artifacts `hunter-findings-B.json`, `skeptic.json`, `referee.json`,
  `gate-7q.json`. Claimed High (CWE-862); Referee verdict NOT_A_BUG (conf 20/low, INDEPENDENTLY_VERIFIED).
- **Root cause (claimed):** `Nexus.initializeAccount` (Nexus.sol:306-334) wraps every guard in
  `if (msg.sender != address(this))`; the self-call branch performs no transient-flag, relay-signature, or
  `!isInitialized()` check, and `_initializeAccount` delegatecalls a caller-supplied bootstrap — so an
  already-initialized account can be re-initialized via self-call.
- **Why it is not a bug (checked):** (1) No attacker principal exists in-repo — only K1Validator (owner ECDSA),
  owner-installed trusted executors, and 7702 direct tx (EOA key). (2) Zero incremental privilege: the same
  principals can already run unrestricted `CALLTYPE_DELEGATECALL` via `execute()`/`executeFromExecutor`, install
  arbitrary modules, and `upgradeToAndCall`. (3) The "no hook/registry" sub-claim was overstated — outer `execute()`
  calls carry `withHook`; the stock bootstrap runs `withHook`+`withRegistry` on every install. (4) 7Q Gate fails at
  Q1 (no attacker-use chain) and Q4 (requires owner key / trusted executor). Option 2 Hunter A re-enumerated all
  routes to the self-call branch (K10) and found no new principal. Hardening suggestion recorded in REPORT-delta.md
  (add `!isInitialized()` to the self-call branch) — a suggestion, not a finding.
- **Status:** Disproved. **Verdict:** EXCLUDED — never re-report. A future claim needs a NEW in-repo principal
  reaching the self-call branch without equal-or-greater power; hypothetical external modules do not count.

---

## Appendix: root-cause clusters (same mechanism, multiple sources — file NONE of these)

| Cluster | Entries |
|---|---|
| Enable-mode signature replay (no userOpHash/nonce binding) | EX-004, EX-016 |
| Enable-mode module-type not signed / type confusion | EX-003, EX-017, EX-039 |
| Enable-mode typehash EIP-712 defects | EX-008, EX-I06, EX-068 |
| Registry skipped at bootstrap (install-before-configure) | EX-002, EX-034 |
| Registry checks missing at use-time (validators/hooks/fallbacks) | EX-018, EX-059 |
| Fallback unrestricted / unauthorized direct calls | EX-006, EX-024 |
| Fallback invalid calltype | EX-014, EX-026 |
| ERC-165 / EIP-7579 compliance | EX-007, EX-035 |
| Attester sorting/duplicates | EX-009, EX-030 |
| `msg.value` not forwarded | EX-001, EX-021 |
| Zero-owner + `tryRecover` returns-0 comparison | EX-045 (validateUserOp/1271, fixed), EX-077 + EX-087 (validateSignatureWithData, open), EX-131 (1.2.1 re-file), EX-135 (1.3.3) |
| Default-validator addressability / init gating | EX-046, EX-048, EX-049, EX-053, EX-058, EX-072 |
| `_checkInitializedValidators` loop (gas + revert) | EX-055 (the fix's origin), EX-075, EX-081 |
| `_multiTypeInstall` silent skip | EX-071, EX-086, EX-127, EX-130 (gap 2) |
| Short-signature revert in `isValidSignature` | EX-078, EX-088, EX-128, EX-132 |
| Session-key oracle confusion (enable mode + emergency uninstall) | EX-073, EX-074 |
| Pre-validation hooks in bootstrap | EX-066, EX-090 |
| Missing `ModuleInstalled` event at init | EX-I33, EX-091 |
| Emergency-uninstall timelock/nonce mechanisms | EX-063 (stale timelock), EX-074 (loose end), EX-123 (nonce burn/reset), EX-129 (hook-keyed clock) |
| Raw 0x32 panics at parsing boundaries | EX-125 |
| Assembly parser without bounds checks (`parseMultiTypeInitData`) | EX-130 (gap 1) |
| Zero-validator init vs uninstall invariant | EX-126 |
| Bootstrap zero-address validator entry | EX-122 |
| Self-call re-init (disproved) | EX-136 (H-B1, NOT_A_BUG) |
| Transient init flag (GHSA) | EX-116 |
| 7702 relay raw-hash signature | EX-076 |
| 7739 detection gaps (loop / default / try-catch) | EX-042, EX-048, EX-058, EX-069 |

*End of exclusion list. Total: 176 entries (EX-001–EX-136 security/tracker/advisory + EX-G01–G07 gas + EX-I01–I33 info; §I merged 2026-11-14).*
