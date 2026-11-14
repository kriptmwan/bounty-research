# stx-contracts lineage diff: Nexus 1.2.1 (bcnmy/nexus) → Nexus 1.3.3 (bcnmy/stx-contracts)

**Purpose.** For the Nexus bug-bounty audit (scope = `bcnmy/nexus` `main`): identify
which 1.2.1 mechanisms the Biconomy team itself changed in the deployed 1.3.3
lineage. A finding in team-changed code is a strong duplicate / already-fixed
signal and must be weighed before filing. Conversely, mechanisms verified
unchanged in 1.3.3 are still live in deployed code.

**Method.** Tree-to-tree `git diff --no-index` between the two pinned checkouts
(see pins table). No GitHub API calls, no build/test, no contact with Biconomy.
Assembly reverts/emits introduced by the 1.3.x size-reduction wave were verified
selector-by-selector with `cast keccak` / `cast sig` (foundry binary, hash
computation only — no compilation). `validateUserOp` bodies were compared
whitespace-insensitively. The `bcnmy/nexus` checkout was never modified
(verified clean afterwards).

**Status note.** A prior pass diffed stx-contracts from `/tmp`; that diff was
lost. This file + `evidence-stx/` + `repos/stx-clone-log.txt` are the durable
recreation (2026-11-14).

## Pins

| Repo | Ref | SHA | Date | Identity |
|---|---|---|---|---|
| `bcnmy/nexus` (scope) | `main` HEAD | `9007ba1352e606575e32456512e25c41a9bf449c` | 2026-08-07 | Nexus v1.2.1 lineage; `accountId()` = `biconomy.nexus.1.2.1`; EIP-712 domain `1.2.1` |
| `bcnmy/stx-contracts` (deployed) | `develop` HEAD = tag `v2.2.3` | `61001d0f53540c5bdf00bd79ad64995401446b09` | 2026-09-01 | Nexus 1.3.3, MEE suite 2.2.3; `accountId()` = `biconomy.nexus.1.3.3`; EIP-712 domain `1.3.2` |

Checkouts: `repos/nexus` (clean, untouched) and `repos/stx-contracts` (clean,
checked out at `develop` HEAD). Full clone log:
`repos/stx-clone-log.txt`.

**Lineage caveat.** The two histories diverged before 2026-08-07: nexus `main`
HEAD `9007ba13` is not an object in the stx clone and not an ancestor of stx
`develop`. Diffs below are tree-to-tree, not ancestry diffs. Notably, the
single-use-initialization fix landed independently in both repos on the same
day (nexus PR #302; stx PR #24) — see §9, it is *not* a 1.2.1→1.3.3 delta.

**Version-string discrepancy (recorded, not judged).** In the 1.3.3 tree three
different versions coexist: `accountId()` = `1.3.3`, Nexus EIP-712 domain =
`1.3.2` (comment says v2.2.2 bumped both to 1.3.2; only `accountId()` was later
bumped to 1.3.3), NexusBootstrap EIP-712 domain = `1.3.0`. Cross-version
signature-domain reasoning must use the per-contract value, not `accountId()`.

## Branch / tag findings (stx-contracts)

- **`develop` EXISTS and is the default branch** (`origin/HEAD ->
  origin/develop`; HEAD = `61001d0f`, 2026-09-01, merge of PR #25
  `deploy/v2.2.3`). This is the branch the bounty text's "must not be fixed in
  `develop`" warning maps to for the deployed lineage. Contrast: `bcnmy/nexus`
  has **no** `develop` branch at all (only `dev`, HEAD `5e64c4a5`,
  2025-11-01).
- `main` (`7bfb18f1`, 2026-07-16) is stale; merge-base with `develop` is the
  v2.2.1 commit `6c28f0b0` (2025-12-15). All 1.3.x work is on `develop` /
  `deploy/v2.2.x`.
- Tags: `v2.2.1` (lightweight), `v2.2.2` (annotated), `v2.2.3` (lightweight,
  **identical to `develop` HEAD** — empty diff).
- Deploy branches: `deploy/v2.2.3` HEAD `887924af` (2026-07-27, salt
  re-mining); `deploy/v2.2.2` HEAD `5eae7824` (2026-08-07, single-use-init
  PR #24); `deploy/v2.2.2-inlined-fallback`, `feat/safe-sa-mode-poc`,
  `feat/stx-validator` (side branches, not diffed).
- **No `SECURITY.md`** in stx-contracts at HEAD. The bounty program text lives
  only in `bcnmy/nexus` `SECURITY.md`; payout for 1.2.1-only bugs remains
  unverified (see `SCOPE.md`).

## Path map (1.2.1 → 1.3.3)

The stx tree reorganized paths; all counterparts below were located by filename
+ content search, not assumed:

| File | 1.2.1 path (`contracts/…`) | 1.3.3 path (`contracts/…`) |
|---|---|---|
| Nexus.sol | `Nexus.sol` | `nexus/Nexus.sol` |
| ModuleManager.sol | `base/ModuleManager.sol` | `nexus/base/ModuleManager.sol` |
| NexusBootstrap.sol | `utils/NexusBootstrap.sol` | `nexus/utils/NexusBootstrap.sol` |
| BaseAccount.sol | `base/BaseAccount.sol` | `nexus/base/BaseAccount.sol` |
| ExecutionHelper.sol | `base/ExecutionHelper.sol` | `nexus/base/ExecutionHelper.sol` |
| Storage.sol / IStorage.sol | `base/Storage.sol`, `interfaces/base/IStorage.sol` | `nexus/base/Storage.sol`, `interfaces/nexus/base/IStorage.sol` |
| RegistryAdapter.sol | `base/RegistryAdapter.sol` | **NO COUNTERPART** (§7) |
| K1Validator.sol | `modules/validators/K1Validator.sol` | **No direct counterpart**; successor is `validators/stx-validator/K1MeeValidator.sol` (§8) |
| Initializable.sol | `lib/Initializable.sol` | `lib/nexus/Initializable.sol` |
| LibPREP.sol | `lib/local/LibPREP.sol` | `lib/nexus/local/LibPREP.sol` |

Dependency re-sourcing affecting several files: module interfaces
(`IValidator`, `IExecutor`, `IHook`, `IFallback`, `IModule`,
`IPreValidationHook*`) moved from local `interfaces/modules/` to the
`@erc7579/implementation` package (`erc7579/interfaces/IERC7579Module.sol`);
`Execution` struct moved from local `DataTypes.sol` to
`erc7579/interfaces/IERC7579Account.sol`; `ExecLib`/`ModeLib` moved to
`lib/erc-7579/` (same Rhinestone code, formatting only — see appendix).
Solady bumped **v0.1.9 → v0.1.26** (explains the `LibEIP7702.delegation` →
`delegationOf` rename in §10). ERC-7739 validator base unchanged at v1.0.0 in
both trees.

## Per-file verdicts

Summary (one line each; detail in §§1–10):

1. **Nexus.sol — SUBSTANCE-CHANGED** (registry gone; 7739-detection
   internalized; version bumps; rest is verified-equivalent assembly).
2. **ModuleManager.sol — SUBSTANCE-CHANGED** (registry gone from all installs;
   install/validation logic otherwise identical).
3. **NexusBootstrap.sol — SUBSTANCE-CHANGED** (registry config removed from
   all init flows; compat shims kept; install loops identical).
4. **BaseAccount.sol — SUBSTANCE-CHANGED, small** (`nonce()` view removed;
   implementation-ID constant removed).
5. **ExecutionHelper.sol — COSMETIC** (formatting/braces/imports; assembly
   bodies identical).
6. **Storage.sol + IStorage.sol — COSMETIC** (comments/imports; slot constant
   and struct layout identical; registry field kept as reserved slot).
7. **RegistryAdapter.sol — NO COUNTERPART** (mechanism removed entirely; never
   present in stx history).
8. **K1Validator.sol → K1MeeValidator.sol — SUBSTANCE-CHANGED** (successor
   contract: MEE validation dispatch + EOA-only owner guard; plain-ECDSA core
   preserved via libraries).
9. **Initializable.sol — COSMETIC** (comment reword only; consume-flag logic
   identical — parallel fix, not a delta).
10. **LibPREP.sol — COSMETIC** (Solady API rename + dead import dropped; PREP
    math identical).

Diff stats (`git diff --no-index --stat`, 1.2.1 → 1.3.3): Nexus.sol +181/−77
(578→682 lines); ModuleManager.sol +196/−112 (732→816); NexusBootstrap.sol
+88/−226 (447→309); BaseAccount.sol +1/−12 (130→119); ExecutionHelper.sol
+80/−22 (284→342); Storage.sol +8/−4; IStorage.sol +12/−8; Initializable.sol
+6/−6; LibPREP.sol +6/−11; K1Validator→K1MeeValidator +230/−111 (280→399).
Full diffs: `evidence-stx/`.

---

### 1. Nexus.sol — SUBSTANCE-CHANGED

**Removed — ERC-7484 registry (the headline change).** The `withRegistry`
modifier is dropped from `executeFromExecutor`; `setRegistry()` is deleted;
the `IERC7484` import is gone. Executor calls no longer consult any registry
in 1.3.3. (Install-side registry checks are covered in §2; the adapter itself
in §7.)

**Visibility change — ERC-7739 detection.** Public `checkERC7739Support()`
becomes internal `_checkERC7739Support()`, reachable only via the
`isValidSignature` empty-signature probe path. Detection logic itself
(iterate validators, `_get7739Version`, max-version-wins) is unchanged. Any
1.2.1 finding that relies on *external* calls to `checkERC7739Support` (e.g.
gas-griefing the validator iteration from outside) has no 1.3.3 surface; the
probe path through `isValidSignature` is unchanged.

**Equivalent rewrites (verified, not assumed).**

- `supportsModule()` if-chain → bitmap `((1 << moduleTypeId) & 0x31F) != 0`.
  Bits 0,1,2,3,4,8,9 = MULTI, VALIDATOR, EXECUTOR, FALLBACK, HOOK,
  PREVALIDATION_1271/4337 — exactly the old set (ids confirmed in
  `Constants.sol`, identical in both trees). Shifts ≥256 yield 0, so unknown
  ids still return false. Note the new `MODULE_TYPE_STATELESS_VALIDATOR = 7`
  constant is *not* in the bitmap: `supportsModule(7)` is false.
- `initializeAccount` init-data hash: `keccak256(initData)` → assembly
  `calldatacopy` + `keccak256` over the same bytes. Same hash.
- Reverts/emits converted to assembly with **verified-identical**
  selectors/topics (`cast sig`/`cast keccak`): `ExecutionFailed()`
  `0xacfdb444` in `executeUserOp` (inner returndata was already discarded in
  1.2.1); `NexusInitializationFailed()` `0x315927c5`;
  `ModuleInstalled(uint256,address)` topic `0xd21d0b28…` (non-indexed, same
  64-byte data layout); `InvalidPREP()` `0xe483bbcb` +
  `PREPInitialized(bytes32)` topic `0x4f058962…`; `CanNotRemoveLastValidator()`
  `0xcc319d84`. Observable revert data / logs are unchanged.
- Pre-validation-hook type checks replaced by `_isPrevalidationHookType()`
  (`(type − 8) < 2`, wrapping arithmetic) — provably equivalent to
  `type == 8 || type == 9`, including for `type < 8` (wraps to huge, fails)
  and `type == 7` (stateless validator is *not* treated as a pre-validation
  hook).
- `_authorizeUpgrade` param unnamed; `_handlePREP` otherwise identical;
  `_domainNameAndVersion` name still `"Nexus"`, version `1.2.1` → `1.3.2`.

**Unchanged (strong).** `validateUserOp` is **byte-identical modulo
whitespace** (64 lines both sides, `diff -w` empty) — validation modes,
nonce handling, PREP/enable-mode dispatch, missing-funds logic all survive.
`isValidSignature` body unchanged apart from the renamed internal call.
Emergency-uninstall flow, `isInitialized`, `getImplementation`, upgrade guard
(7702 rejection + `onlyEntryPointOrSelf`) unchanged.

**Documented, NOT fixed.** `executeComposable` gains a long NatSpec caveat
only (commit `4ec8940e`, "docs: document withHook visibility caveat"): the
hook's `preCheck` sees the raw composable spec, not the resolved
per-sub-call payload for `STATIC_CALL`/`BALANCE` fetchers. No code change.
A finding on hook visibility over resolved sub-calls is therefore
team-acknowledged behavior in 1.3.3, not a silent fix — frame accordingly.
Separately, the `ComposableExecutionBase` import was re-sourced to the
audited `erc8211-contracts` submodule "which carries the L-01..L-07 fixes +
follow-ups" (per the `_domainNameAndVersion` comment; commit `803ce027`).
That submodule is outside the diffed files: if the audit touches
`executeComposable` internals, the submodule delta needs its own check.

Illustrative hunk (registry removal, `executeFromExecutor`):

```diff
         onlyExecutorModule
         withHook
-        withRegistry(msg.sender, MODULE_TYPE_EXECUTOR)
         returns (bytes[] memory returnData)
```

### 2. ModuleManager.sol — SUBSTANCE-CHANGED

**Removed — registry from every install path.** Inheritance drops
`RegistryAdapter` (`abstract contract ModuleManager is Storage, EIP712,
IModuleManager`). `withRegistry` is removed from all five install functions:
`_installValidator`, `_installExecutor`, `_installHook`,
`_installFallbackHandler`, `_installPreValidationHook`. Install logic in each
is otherwise untouched: `isModuleType` checks, `DefaultValidatorAlreadyInstalled`
guard, SentinelList push/pop, `onInstall`/`onUninstall` calls, single-hook
guard, fallback forbidden-selector set (`onInstall`/`onUninstall`/zero),
`FallbackAlreadyInstalledForSelector` guard, multi-type dispatch. Uninstall
paths unchanged (they never had registry checks).

**Equivalent rewrites (verified).**

- `_enableMode`: named-arg signature check → positional + assembly revert
  `EnableModeSigError()` `0x46fdc333` (verified). Same struct hash, same
  validator resolution, same `this.installModule` call.
- `_checkEmergencyUninstallSignature`: `_getEmergencyUninstallDataHash`
  helper inlined at its single call site (identical `abi.encode` +
  `_hashTypedData` expression) and the helper deleted. Nonce check-then-mark,
  validator signature check unchanged. Constant rename
  `ERC1271_MAGICVALUE` → `ERC1271_SUCCESS`, same value `0x1626ba7e`
  (likewise `_checkEnableModeSignature`, same try/catch shape).
- `_handleValidator`: assembly revert `ValidatorNotInstalled(address)`
  `0x6859e01e` with correct 4+32-byte ABI encoding (verified). Same
  zero-address → default-validator fallback, same installed-check.
- `_getEnableModeDataHash`: assembly reimplementation of
  `keccak256(abi.encode(TYPEHASH, module, moduleType, userOpHash,
  keccak256(initData)))` — five words, same layout, same hash. Type hashes
  confirmed identical in `Constants.sol` (`MODULE_ENABLE_MODE_TYPE_HASH`,
  `EMERGENCY_UNINSTALL_TYPE_HASH`).
- `_fallback` missing-handler revert moved into assembly:
  `MissingFallbackHandler(bytes4)` `0x08c63e27`, arg left-aligned via
  `shl(224, s)` where `s = shr(224, calldataload(0))` — correct `bytes4` ABI
  encoding, same revert data. ERC-721/1155 receiver selector handling
  unchanged.
- `_isPrevalidationHookType()` helper (see §1) replaces the four repeated
  `type == 8 || type == 9` checks (install dispatch, uninstall, multi-type
  install, `_isModuleInstalled`).
- Dead code removed: `ECDSA` import + `using ECDSA for bytes32` (never used
  in 1.2.1 `ModuleManager` — no `recover` call sites). Constructor change is
  braces-only.

**Unchanged.** Pre-validation-hook call wiring (4337 + 1271), `_paginate`,
sentinel-list init checks, `_multiTypeInstall` loop structure, hook
pre/post-check wiring in `_fallback`.

**Interface-declaration drift (observation, 1.3.3 only).** In stx's
`IModuleManagerEventsAndErrors`, `ValidatorNotInstalled` is re-declared
*without* its address argument (`error ValidatorNotInstalled();`), while the
runtime assembly revert still emits the 1.2.1 with-argument form. The
declaration is stale; runtime behavior is unchanged. `NoValidatorInstalled`
and `FallbackHandlerUninstallFailed` declarations were dropped — both were
declaration-only in 1.2.1 (never reverted). `CanNotRemoveLastValidator`
moved to `INexusEventsAndErrors`. No behavioral consequence; do not file
the declaration drift as a 1.2.1 finding.

### 3. NexusBootstrap.sol — SUBSTANCE-CHANGED

**Removed — registry configuration from all init flows.** `RegistryConfig`
struct deleted; the `registryConfig` parameter removed from all four primary
init functions (`initNexusWithDefaultValidatorAndOtherModules`,
`initNexusWithSingleValidator`, `initNexus`, `initNexusScoped`); all four
`_configureRegistry(...)` calls removed. The internal `_initNexus*` helpers
were inlined into the primaries, which changed `external` → `public` so the
compat shims can call them.

**Backwards-compat shims kept.** All four `*NoRegistry` entry points survive
with unchanged signatures, now as thin forwarders explicitly marked "expose
this function for backwards compatibility". Behavior is equivalent to 1.2.1:
the old shims passed a zero-registry config, and `_configureRegistry(0, …)`
only stored address(0) and skipped `trustAttesters` — i.e. a no-op. The only
lost capability is configuring a *non-zero* registry at init time (and there
is no longer any `setRegistry` to do it later — §1).

**Unchanged.** All install loops (validators, executors, hook, fallbacks,
pre-validation hooks), zero-address skips, `ModuleInstalled` emits,
`_withInitSentinelLists` placement, `initNexusWithDefaultValidator`
(`onInstall` only, no sentinel init — same in both), constructor, and the
do-nothing `installModule` / `uninstallModule` / `isModuleInstalled → false`
stubs. `BootstrapConfig` / `BootstrapPreValidationHookConfig` structs: same
fields/order (de-indented only). EIP-712 domain version `1.2.1` → `1.3.0`.

### 4. BaseAccount.sol — SUBSTANCE-CHANGED (small: API removal)

Two deletions, both deliberate size reductions (removal commit `ce1669a3`,
"chore: reduce size: rm nonce() method"):

- `nonce(uint192)` external view (EntryPoint `getNonce` proxy) **removed**
  from both implementation and `IBaseAccount` interface. No replacement in
  `Nexus.sol` or elsewhere in the account: callers must query the EntryPoint
  directly. No validation/execution logic depended on it internally.
- `_ACCOUNT_IMPLEMENTATION_ID` constant (`"biconomy.nexus.1.2.1"`) removed;
  `Nexus.accountId()` now returns the `"biconomy.nexus.1.3.3"` literal
  directly. The `IEntryPoint` import goes away with `nonce()`.

Everything else — `_ENTRYPOINT` immutable, `onlyEntryPoint` /
`onlyEntryPointOrSelf` modifiers, `getDeposit`, `addDepositFor`, `withdrawDepositTo`,
`_requireFromEntryPointOrSelf` — identical.

### 5. ExecutionHelper.sol — COSMETIC

All ten helpers (`_execute`, `_executeMemory`, `_tryExecute`, `_executeBatch`,
`_tryExecuteBatch`, `_executeDelegatecall`, `_tryExecuteDelegatecall`,
`_executeNoReturndata`/`_executeDelegatecallNoReturndata`, and the six
`_handle*Execution*` dispatchers) keep identical assembly bodies and
identical dispatch semantics. The diff is: signature reformatting, braces
around single-statement `if/else` in three dispatchers, NatSpec rewraps, and
import re-sourcing (`Execution` from the erc7579 package, `ExecLib`/`ModeLib`
from `lib/erc-7579/`). The `Execution` struct fields (`target`, `value`,
`callData`) are the same. `ExecLib`/`ModeLib` themselves are formatting-only
deltas (appendix) — decode/encode behavior unchanged. **Execution semantics
are fully preserved; findings here survive to 1.3.3.**

### 6. Storage.sol + IStorage.sol — COSMETIC

`Storage.sol`: comment rewraps + import path only. The ERC-7201 slot constant
`0x0bb70095…b82f00` (`biconomy.storage.Nexus`) is identical, and the
`_getAccountStorage()` accessor is unchanged.

`IStorage.sol`: comment rewraps + import re-sourcing (module interfaces from
the erc7579 package). The `AccountStorage` struct field list and order are
identical — including the `registry` address field, now annotated:

```solidity
address registry; // keeping this to avoid collisions b/w versions
```

The slot is deliberately retained (dead in 1.3.3: nothing reads or writes
it) to preserve storage layout across upgrades from 1.2.1 accounts that may
have a registry configured. **Storage layout is unchanged; no new collision
surface.**

### 7. RegistryAdapter.sol — NO COUNTERPART (mechanism removed)

There is no `RegistryAdapter.sol` in stx-contracts, no `withRegistry`,
`_configureRegistry`, `_checkRegistry`, `getRegistry`, `setRegistry`, or
`IERC7484` reference anywhere under `contracts/` (verified by grep), and no
commit in stx history (all refs) ever contained `RegistryAdapter.sol` or the
`withRegistry` string (verified via `git log --diff-filter=D` and pickaxe
`-S` search — both empty; the registry predates the fork point / was never
ported).

What 1.2.1 had (53 lines): opt-in ERC-7484 attestation. `setRegistry`
(account-only) stored a registry + called `trustAttesters(threshold,
attesters)`; `_checkRegistry` called `registry.check(module, moduleType)`
whenever a registry was configured, enforced via `withRegistry` on
`executeFromExecutor` and all five install functions; `getRegistry` exposed
the configured registry; `ERC7484RegistryConfigured` event on configure.

**Audit implication (strongest in this file).** The entire attestation
mechanism is absent from deployed code. Any 1.2.1 finding predicated on
registry behavior — attestation bypass, `trustAttesters` misuse, registry
confusion, `setRegistry` access control, `check()` revert handling — is
**moot against 1.3.3** and carries a high duplicate/already-addressed risk
under the bounty rule (fixed/removed in `develop`). Conversely, the removal
itself means 1.3.3 accounts have *no* module-attestation gate; that is the
team's deliberate product decision (the bootstrap had already grown
`NoRegistry` variants in 1.2.1), not a 1.2.1 vulnerability to report.

### 8. K1Validator.sol → K1MeeValidator.sol — SUBSTANCE-CHANGED

There is no file named `K1Validator.sol` in stx-contracts. The successor is
`K1MeeValidator` — same skeleton (same storage layout start:
`smartAccountOwners` mapping + `_safeSenders` set; same
`onInstall`/`onUninstall`/safe-sender/ERC-7739 structure, same
`ERC7739Validator` v1.0.0 base), but validation is substantially rewritten
for the MEE stack. Treat K1 findings as **successor-changed**: the contract
that would be deployed for new MEE accounts is this one, not `K1Validator`.

**New guard — EOA-only owners (fix-signal).** `onInstall` and
`transferOwnership` now revert `NewOwnerIsNotEoa()` when the new owner has
code, *except* `extcodesize == 23` (the EIP-7702 delegation designator
`0xef0100` + 20-byte address), so 7702-delegated EOAs remain valid owners
(version NatSpec confirms: "supports erc7702-delegated EOAs as owners"):

```solidity
function _isNotEoa(address account) private view returns (bool) {
    uint256 size;
    assembly { size := extcodesize(account) }
    // has code and is not delegated via eip-7702
    return (size > 0) && (size != 23);
}
```

A 1.2.1 finding about contract owners (e.g. a malicious contract owner, or
owner-slot confusion with code-bearing addresses) is addressed upstream in
the successor. Known limitation class of this guard shape (not a new
finding): `extcodesize` is 0 during a contract's construction, so the check
is bypassable by installing from a constructor — record the mechanism, do
not over-claim it as airtight.

**Validation rewritten — MEE dispatch.** `validateUserOp` (now *non-`view`*,
returning `vd`) dispatches on a 4-byte signature prefix to four libraries:
`SimpleValidatorLib` (`0x177eee00`, super-tx hash signed),
`TxValidatorLib` (`0x177eee01`, on-chain tx), `PermitValidatorLib`
(`0x177eee02`, ERC-2612 permit deadline smuggling), else
`NoMeeFlowLib` (plain ECDSA fallback, including short signatures). The
plain-ECDSA core is **preserved**: `NoMeeFlowLib` and the 7739 path both
delegate to `EcdsaHelperLib.isValidSignature`, which keeps the exact 1.2.1
dual-recover semantics (raw hash, then `toEthSignedMessageHash`). The team
documents a prefix-collision caveat in NatSpec: a plain signature whose
first 4 bytes happen to match a MEE prefix misroutes and fails validation —
"very unlikely", fixable by altering the userOp. That is acknowledged
behavior, not a silent fix.

**1271 MEE branch — cross-account replay hardening.** `isValidSignatureWithSender`
bypasses ERC-7739 for MEE-flow signatures (prefix `0x177eee`) and, for
permit/on-chain modes, hashes the calling account into the digest
(`keccak256(dataHash ‖ msg.sender)`, 52 bytes, assembly) "to protect against
two SAs with same owner vector". The non-MEE branch is the unchanged 7739
path. `_erc1271IsValidSignatureNowCalldata` now calls `EcdsaHelperLib`
directly instead of the (now dispatching) `_validateSignatureForOwner`, so
the 7739 path stays plain-ECDSA. `_erc1271CallerIsSafe` unchanged (same
MulticallerWithSigner hardcode + safe senders).

**Other deltas.** `validateSignatureWithData`: `data.length == 20` → `>= 20`
(owner = first 20 bytes, trailing bytes ignored); repurposed from
"ISessionValidator" to `IStatelessValidator` (ERC-7780, module type 7);
`isModuleType` now also true for type 7. `OwnerSet` event **removed**
(all three emits + declaration) — owner changes emit nothing in the
successor. `smartAccountOwners` `internal` → `public` (auto-getter added;
`getOwner()` retained). Safe-sender error renamed
`InvalidSafeSendersLength` → `SafeSendersLengthInvalid` (same `% 20` check).
`name()` → `"K1MeeValidator"`, `version()` → `"1.1.0"` (separate MEE
versioning line; the CHANGELOG lists MEE K1 Validator 1.1.0 — not comparable
to Nexus versions). `_recoverSigner` deleted (recovery moved into libs).

### 9. Initializable.sol — COSMETIC (parallel fix, not a delta)

Comment reword only; `requireInitializable()` logic is identical in both
trees (load transient `INIT_SLOT`, revert `NotInitializable` if unset, clear
it — single-use per transaction). **Both pins already contain the fix.**
Nexus HEAD `9007ba13` *is* the fix commit ("fix: consume transient init flag
on initializeAccount (#302)"); stx applied the same change as PR #24 /
commit `2ac6cc8e` ("feat(nexus): make initialization single-use per
transaction; Nexus 1.3.3", touching `Initializable.sol` + accountId bump +
a new `TestNexusFactory_SingleInitialization` test). Do **not** report the
transient-flag consumption as a 1.2.1→1.3.3 team change, and do not file a
double-init finding against 1.2.1 `main` HEAD — it is fixed at the scope pin
itself.

### 10. LibPREP.sol — COSMETIC

`rPREP` hash construction, `isValid`, and `isPREP` logic are identical. The
diff is: import formatting, dropped unused `LibBytes` import, and the Solady
API rename `LibEIP7702.delegation(target)` → `delegationOf(target)` (Solady
v0.1.9 → v0.1.26). PREP verification semantics are unchanged; findings in
PREP math survive to 1.3.3.

---

## Team-changed mechanisms (duplicate / fix-signal list)

Ordered by audit significance. "Signal" = likelihood a 1.2.1 finding in this
mechanism is already addressed upstream and would be treated as duplicate /
fixed-in-`develop`.

| # | Mechanism | 1.3.3 change | Signal |
|---|---|---|---|
| T1 | ERC-7484 registry attestation (all of §7 + §§1–3 registry hunks) | **Removed entirely** — adapter, modifier, `setRegistry`/`getRegistry`, bootstrap config, all six enforcement points | **Very high** — moot in deployed code |
| T2 | K1 owner gating (§8) | **New guard**: contract owners rejected (`NewOwnerIsNotEoa`), 7702 designators exempted | **High** for contract-owner findings (in successor contract) |
| T3 | K1 validation dispatch (§8) | **Rewritten**: MEE sig-type dispatch; 1271 MEE branch hashes account into digest (cross-account replay); plain path preserved via libs | **High** for dispatch/prefix findings; low for plain-ECDSA-core findings (preserved) |
| T4 | ERC-7739 detection surface (§1) | `checkERC7739Support` public → internal | **Medium-high** for external-probing findings; nil for probe-path logic (unchanged) |
| T5 | Composability base (§1, adjacent) | Re-sourced to audited `erc8211-contracts` submodule carrying "L-01..L-07 fixes + follow-ups" | **High** for `executeComposable` internals — needs its own submodule check; out of diffed files |
| T6 | EIP-712 domain versions (§§1, 3) | Nexus `1.2.1`→`1.3.2`, bootstrap `1.2.1`→`1.3.0`, `accountId`→`1.3.3` | **Medium** — cross-version domain/replay reasoning changed; same-version logic unchanged |
| T7 | `nonce()` view (§4) | Removed (size reduction) | **Low** (API surface only; no internal use) |
| T8 | Error/event declaration layout (§§1–2) | Several errors moved to assembly reverts; declarations shuffled/dropped; one stale no-arg `ValidatorNotInstalled()` declaration | **Nil** — runtime revert data verified identical |
| T9 | Assembly-ization wave (§§1–2) | Reverts, emits, hashes, type checks → assembly | **Nil** — all verified behavior-preserving; findings in these paths survive |
| — | Single-use init flag (§9) | **NOT a delta** — fixed in both pins independently | N/A — do not cite as team change |
| — | `executeComposable` hook visibility (§1) | **Documented, not fixed** (NatSpec caveat only) | N/A — acknowledged behavior, not a fix |

## Mechanisms verified UNCHANGED (findings here are still live in 1.3.3)

- `validateUserOp` (byte-identical modulo whitespace) and the full 4337
  validation-mode / nonce / PREP / enable-mode dispatch.
- Module enable-mode signature verification (struct hash, validator check,
  `installModule` via `this`).
- Emergency uninstall (typed-data hash, one-time nonce, validator signature,
  timelock flow in `Nexus.sol`).
- Install/uninstall mechanics (minus registry): type checks, sentinel lists,
  hook singleton, fallback forbidden selectors, multi-type install,
  pre-validation-hook wiring.
- Execution dispatch + helpers + `ExecLib`/`ModeLib`/`NonceLib` decoding.
- Fallback routing incl. ERC-721/1155 receiver selectors and hook
  pre/post-checks.
- PREP verification math (`LibPREP`) and `_handlePREP` flow.
- ERC-7739 version-detection logic (visibility changed, logic not).
- Storage layout (ERC-7201 slot + struct order, registry slot reserved).
- K1 plain-ECDSA dual-recover semantics (via `EcdsaHelperLib`) and safe-sender
  / caller-safe logic.
- EOA-owner exemption for 7702 designators is new (§8) — but note the
  *absence* of any other owner-model change: single-owner mapping,
  `transferOwnership` (msg.sender-keyed), `isInitialized` semantics survive.

## Appendix: supporting files (spot-diffed, outside the 10-file scope)

- `ExecLib.sol`, `ModeLib.sol`, `NonceLib.sol`,
  `LocalCallDataParserLib.sol`, `ProxyLib.sol` — **COSMETIC** (formatting,
  comment rewraps, import re-sourcing; decode/encode/parse logic identical).
  Diffs: `evidence-stx/support-*.diff`.
- `Constants.sol` — values preserved (`ERC1271_SUCCESS = 0x1626ba7e` =
  old `ERC1271_MAGICVALUE`; `ERC1271_FAILED = 0xffffffff` = old
  `ERC1271_INVALID`; type hashes, module ids 0/1/2/3/4/8/9, validation modes
  identical). Additive: `MODULE_TYPE_STATELESS_VALIDATOR = 7`, MEE
  `SIG_TYPE_*` + Node Paymaster constants. No Nexus-core constant changed
  value.
- `DataTypes.sol` — `Execution` struct removed locally (sourced from erc7579
  package, same fields); `EmergencyUninstall` struct identical.
- `INexus.sol` — parent interfaces re-sourced
  (`IERC4337Account`/`IERC7579Account` → `IAccountConfig`/`IExecutionHelper`/
  `IERC1271`/`IAccount`); `initializeAccount` unchanged.
- `NexusAccountFactory.sol` — `INexusFactory` dropped, its errors/event
  inlined; `createAccount`/`computeAccountAddress` logic identical.
  `NexusProxy.sol` (2-line) and `Stakeable.sol` (3-line) diffs are cosmetic.
- `K1MeeValidator` support libraries (`Simple`/`Tx`/`Permit`/
  `NoMeeFlowLib`, `EcdsaHelperLib`, `HashLib`, `MEEUserOpHashLib`) are **new
  code with no 1.2.1 counterpart** — not diffed beyond the `NoMeeFlow` /
  `EcdsaHelper` reads needed for §8. They are new attack surface in the
  deployed lineage, not 1.2.1-scope code.
- Not diffed: `NodePaymaster` suite, `EtherForwarder`, deploy scripts,
  tests, `composability` submodule content (see T5).

## Evidence index

- Raw diffs: `evidence-stx/*.diff` (+ `*.stat` for the 10 primary pairs).
  Primary: `Nexus.sol`, `ModuleManager.sol`, `NexusBootstrap.sol`,
  `BaseAccount.sol`, `ExecutionHelper.sol`, `Storage.sol`, `IStorage.sol`,
  `Initializable.sol`, `LibPREP.sol`,
  `K1Validator-vs-K1MeeValidator.sol`. Supporting: `support-*.diff`.
- Clone log: `repos/stx-clone-log.txt` (HEAD/branch/tag pins, git-protocol
  only, zero GitHub API calls).
- Selector/topic verifications (`cast sig` / `cast keccak`, all matched):
  `ExecutionFailed()` `0xacfdb444`, `NexusInitializationFailed()`
  `0x315927c5`, `InvalidPREP()` `0xe483bbcb`,
  `CanNotRemoveLastValidator()` `0xcc319d84`, `EnableModeSigError()`
  `0x46fdc333`, `ValidatorNotInstalled(address)` `0x6859e01e`,
  `MissingFallbackHandler(bytes4)` `0x08c63e27`,
  `ModuleInstalled(uint256,address)` topic `0xd21d0b28…ef123`,
  `PREPInitialized(bytes32)` topic `0x4f058962…af38d`.
- Negative searches (all empty, as reported): `RegistryAdapter` /
  `withRegistry` / `IERC7484` / `setRegistry` in stx `contracts/`; `*RegistryAdapter*`
  path in stx history (all refs); `withRegistry` pickaxe in stx history;
  `SECURITY.md` in stx tree.

## Limits

- Tree-to-tree comparison only; no compilation, tests, or deployment
  verification (toolchain owned by another worker). Assembly-equivalence
  claims rest on manual review + selector/hash verification, not execution.
- Interface re-sourcing (erc7579 package) was compared at the Nexus-tree
  level; the *vendored package contents* in `node_modules` were not present
  in either checkout and were not diffed. If the audit depends on exact
  `IValidator`/`IExecutor`/etc. signatures, pin the package versions
  (`@erc7579/implementation#v0.0.2` in stx) separately.
- The `erc8211-contracts` composability submodule (T5) and the MEE validator
  libraries are new/adjacent code; their internals were not audited here.
