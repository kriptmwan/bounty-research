# Nexus (bcnmy/nexus) — Bug Bounty Scoping

DECISION: CAUTION — free program with real rewards and a small codebase, but 5 prior audits, 13 open security issues in the tracker, and a repo lineage behind the deployed contracts mean high duplicate risk; any audit must be dedup-first and target the post-Pashov delta.

Scoping date: 2026-11-13. Read-only; git protocol only, zero GitHub API calls. No testing, no contact with Biconomy, no filing.

## 1. Program facts (re-confirmed from SECURITY.md, 2026-11-13)

- Scope: code in the `main` branch, Solidity smart contracts. A vulnerability must NOT already be addressed/fixed in the `develop` branch.
- Rewards: Critical up to $50,000; High up to $10,000; Medium/Low case by case.
- Reporting: Critical/High by email to security@biconomy.io; other issues via a public GitHub issue. No fee, no platform, no KYC mentioned.
- Testing policy: NO mainnet/public-testnet testing — local forks only; no DoS-level traffic; no public disclosure before a fix.
- Out of scope: known issues in the issue tracker or fixed in `develop`; third-party components (unless directly affecting Nexus contracts); basic economic/governance attacks.
- Published advisory in SECURITY.md: GHSA-q47q-h6x2-f5qg (stale transient initialization flag), fixed at commit `272c408`, deployed as Nexus 1.3.3 / MEE suite 2.2.3, "reviewed by Pashov Audit Group in July 2026". See §6 for two discrepancies in these claims.

## 2. Pins

| Branch / ref | Full SHA | Date | Subject |
|---|---|---|---|
| `main` HEAD | 9007ba1352e606575e32456512e25c41a9bf449c | 2026-08-07 | fix: consume transient init flag on initializeAccount (#302) |
| `dev` HEAD | 5e64c4a5bc60ebbe39a0fe83a3f4812414982875 | 2025-11-01 | chore: bump version |
| `develop` | DOES NOT EXIST | — | No branch named `develop` in the repo (see §5) |
| Merge-base main/dev | 0031b70de12946fff31cf01a3a588b59fb5bd5d9 | 2025-10-31 | chore: use local PREP lib |
| Tags | v0.0.0, v1.0.1, v1.0.2, v1.2.0 | — | No v1.2.1 / v1.3.x tags in this repo |

Clone: full (non-shallow) clone at `~/workspace/nexus-audit/repos/nexus`, tree clean, checked out at `main` HEAD. Commands + SHAs in `repos/clone-log.txt`.

Fix-commit check: `272c408` (cited in SECURITY.md) is NOT resolvable in this repo — unknown revision locally and `git fetch origin 272c408` fails ("couldn't find remote ref"). The fix itself IS verified present at `main` HEAD: `contracts/lib/Initializable.sol` `requireInitializable()` now loads, checks, and clears (`tstore(slot, 0x00)`) the transient slot, landed in PR #302 (commit 9007ba1). The `272c408` hash most likely belongs to the `bcnmy/stx-contracts` lineage; treat the citation as unverified, the fix as verified.

## 3. Code inventory

Toolchain: Foundry, solc 0.8.27, EVM version Prague, optimizer on (777 runs), `via-ir = false`; Hardhat config also present. Dependencies (remappings): OpenZeppelin, account-abstraction v0.7.0 (ERC-4337 EntryPoint v0.7), solady v0.1.9, erc7579, erc7739-validator-base v1.0.0, sentinellist v1.0.0, @biconomy/composability v1.1.0, excessively-safe-call, solarray. Pragmas: 70 files `^0.8.27`, 6 files `^0.8.23`.

| Area | Files | LOC |
|---|---|---|
| `contracts/` implementation (excl. mocks, excl. interfaces) | 28 | 4,822 |
| `contracts/interfaces/` | 21 | 956 |
| `contracts/mocks/` | 27 | 1,419 |
| `contracts/` total | 76 | 7,197 |
| `test/` (Solidity) | — | 13,423 |

Largest implementation files: ModuleManager.sol 732, Nexus.sol 578, EnumerableMap4337.sol 535, NexusBootstrap.sol 447, EnumerableSet4337.sol 371, ExecutionHelper.sol 284, K1Validator.sol 280, AssociatedArrayLib.sol 276.

What the repo is: Nexus, an ERC-7579 modular smart account (ERC-4337 v0.7, ERC-7484 registry, ERC-7739 signature validation, EIP-7702 delegation incl. the PREP "Provably Rootless EIP-7702 Proxy" flow in `LibPREP.sol`, UUPS upgradeable, composable execution via @biconomy/composability). Only ONE module ships in-repo: `K1Validator.sol`. Session keys, policies, and other modules live in other Biconomy repos and are NOT in bounty scope here (scope = this repo's `main`).

Version mapping: `Nexus.sol` EIP-712 domain version is `"1.2.1"` — confirming the 1.2.1 lineage stated in SECURITY.md. CHANGELOG.md is stale (last entry 1.0.0, 2024-10-14). No deployment addresses in the repo (only the canonical EntryPoint v0.7 address in scripts). Deployed addresses live in the docs (see §6): current MEE Suite v2.2.3 runs Nexus Implementation **v1.3.3** (`0x0000B1c01cB3b5770D8806f0D214d50131a08a5B`), built from `bcnmy/stx-contracts`, NOT from this repo. This repo's `main` is therefore behind the deployed code by two minor versions (1.2.1 → 1.3.3).

## 4. Audit history (all reports in `audits/` unless noted)

| Auditor / engagement | Date | Commit(s) / scope | Findings |
|---|---|---|---|
| CodeHawks-Cyfrin competition | Jul 8–15, 2024 | Contest repo `2024-07-biconomy` (no pin in this repo); whole `contracts/` | 14 (4 High / 4 Medium / 6 Low) |
| Cantina/Spearbit ("Spearbit" per README) | Oct 2024 | `773943fb` (2024-10-14, v1.0.0 release), holistic | 27 (0 Critical / 4 High / 12 Medium / 11 Low); 21 fixed, 6 acknowledged |
| Cantina ERC-7739 add-on | Nov 9, 2024 | `fa415c44` + holistic `72499c9d`; PR 212 + PR 215 | 3 (0 / 0 / 1 Medium / 2 Low) |
| Zenith | Mar 2025 | `e9cbc56` (2025-03-03); DIFFERENTIAL review of PR-242 only | 9 (1 High / 3 Medium / 5 Low); H-1 = K1Validator `validateUserOp` bypass, marked Resolved |
| Pashov Audit Group | Mar 21–25, 2025 | Review `6395f8f` (2025-03-21); fixes review `9af2d1d` (2025-03-30); full contract list | 15 (0 High / 2 Medium / 13 Low); M-01 hook bypass via enable mode, M-02 users can delete all validators |
| DeFiSafety (in `audits/assets/`) | — | Process-quality review, NOT a code audit | n/a |
| Pashov, `bcnmy/stx-contracts` | Nov 26–27, 2025 | Review `b3695fcd`; fixes `8dea408c`; Nexus + Composability (1.3.x lineage) | 5 issues (confirmed via pashov/audits mirror; report NOT in this repo) |
| Pashov "July 2026" review | claimed | Cited in SECURITY.md for the 1.3.3 deployed fix | UNVERIFIED — no such report found; see §6 |

Total in-repo audit findings: 68. All five in-repo audit commits are ancestors of `main` HEAD, so every report predates the current HEAD — but the post-audit delta is small (see below).

Post-Pashov delta (fixes commit `9af2d1d`, 2025-03-30 → `main` HEAD): 15 commits touching `contracts/`, 10 files, +187/−108 lines. Only NEW file: `contracts/lib/local/LibPREP.sol` (46 lines, "use local PREP lib", 2025-10-31). Changed: Nexus.sol, ModuleManager.sol, BaseAccount.sol, Initializable.sol (the transient fix), NonceLib.sol, NexusBootstrap.sol, LocalCallDataParserLib.sol, 2 interface files. Notable post-audit features: EIP-7702 relay initialization (`feat: add 7702 relay initialize`, `store init data hash`, Jun 2025), relay re-init fix (Oct 2025), `getDefaultValidator` (Oct 2025). This delta is the freshest unaudited surface in the repo.

## 5. Exclusions groundwork

### 5a. The `develop`-branch exclusion is effectively unverifiable

No branch named `develop` exists. The closest branch, `dev`, is BEHIND `main` (HEAD 2025-11-01) and diverged: 4 dev-only commits vs 2 main-only commits. The dev-only commits REMOVE code (`chore: rm registry, k1 factory, meta factory`, PR #295) rather than fixing bugs; the main-only commits are merge #294 and the transient-flag fix #302. Main-vs-dev diff: 12 Solidity files, +629/−78 lines — largest: NexusBootstrap.sol (+276/−~), K1ValidatorFactory.sol (+135, present in main, removed in dev), BiconomyMetaFactory.sol (+89), BootstrapLib.sol (+56), RegistryAdapter.sol (+53).

Implication: a finding in registry/factory code could plausibly be "already addressed" in Biconomy's working line (dev removes that code entirely). Confirm with Biconomy before filing anything touching RegistryAdapter, BiconomyMetaFactory, or K1ValidatorFactory. Do NOT treat `dev` as `develop` without asking.

### 5b. GitHub issue tracker — 17 open issues, 13 security-relevant (read 2026-11-13)

All of these are KNOWN issues per the bounty rules — do not re-report by root cause. Note the cluster of recent public bounty-style filings (Oct–Nov 2026): other researchers are actively working this repo.

| Issue | Opened | Title (short) |
|---|---|---|
| #321 | 2026-11-11 | [Low] checkERC7739Support has no try/catch — one reverting validator breaks ERC-7739 detection |
| #320 | 2026-11-11 | [Low] BiconomyMetaFactory.deployWithFactory trusts raw returndata |
| #319 | 2026-11-11 | [Low] _multiTypeInstall silently skips unknown module types |
| #316 | 2026-11-06 | [Low–Medium] Default validator unaddressable by its own address (validateUserOp, isValidSignature, enable mode, emergencyUninstallHook) |
| #312 | 2026-11-05 | Session key can remove the account policy hook via emergency uninstall (same root cause as #310) |
| #310 | 2026-11-05 | [Bug Bounty][Medium] Session key escapes scope via enable-mode module install and drains the account |
| #309 | 2026-10-25 | [Medium] _checkInitializedValidators unbounded loop — gas DoS bricks validator uninstall |
| #308 | 2026-10-14 | [Low] initializeAccount ERC-7702 relay signature not chain-bound (raw initDataHash) |
| #307 | 2026-10-05 | K1Validator.validateSignatureWithData returns true for malformed signatures when owner is zero |
| #306 | 2026-09-06 | isValidSignature reverts for empty/short non-detection signatures |
| #304 | 2026-08-17 | Constraint Validation Bypass in Nexus ComposableExecution |
| #303 | 2026-08-14 | Security report sent privately Aug 2 — requesting confirmation of receipt (contents unknown) |
| #300 | 2026-05-12 | Validator uninstallation blocked by a reverting isInitialized() in a remaining validator |

Non-security open issues: #305 (legacy ethers v5 dep), #298/#296 (docs/behavior), #106 (yarn install, 2024). CLOSED issues were NOT enumerated in this scoping pass — a full closed-issue sweep is mandatory dedup before any filing.

### 5c. Published advisories

- SECURITY.md documents GHSA-q47q-h6x2-f5qg (transient init flag). BUT the repo's GitHub advisories tab shows "There aren't any published security advisories" (read 2026-11-13). Discrepancy recorded; the underlying issue is excluded regardless (fix verified in code at HEAD).
- No other GHSA/CVE for this repo found via web search. The advisory surface is effectively one item.

### 5d. Other exclusion sources for the dedup pass

- The 5 in-repo audit PDFs (68 findings) + the Pashov stx-contracts Nov 2025 review (5 issues, 1.3.x lineage — root causes may still apply to 1.2.1 code).
- `bcnmy/stx-contracts` (carries the 1.3.3 lineage): NOT cloned in this scoping pass. If it is public, diffing Nexus.sol/ModuleManager between the two lineages would show which main-branch code the Biconomy team itself already changed — strong duplicate signal. Recommended as a pre-audit step, not done here.
- Rhinestone fork (`rhinestonewtf/rhinestone-nexus`): downstream fork, not an exclusion source, but its divergences sometimes document upstream bugs. Optional.

## 6. Unverified / discrepancies (state plainly)

1. `272c408` (SECURITY.md fix citation) does not resolve in this repo. Fix verified present at HEAD via PR #302; citation treated as stx-contracts lineage.
2. "Reviewed by Pashov Audit Group in July 2026" (SECURITY.md) could not be independently confirmed. The Pashov review of `stx-contracts` that IS publicly documented ran Nov 26–27, 2025 (5 issues). Either a second July 2026 review exists unpublished, or the date is wrong.
3. GHSA-q47q-h6x2-f5qg is claimed in SECURITY.md but no advisory is published on the repo's advisories tab.
4. No `develop` branch exists; the "fixed in develop" exclusion cannot be checked as written (see §5a).
5. Deployed bytecode vs repo code: NOT verified. Deployed Nexus is v1.3.3 from `stx-contracts`; this repo is v1.2.1. Whether Biconomy pays for bugs present only in the 1.2.1-lineage `main` (and fixed/absent in 1.3.3) is unconfirmed — the bounty text says scope is `main`, but payout relevance to deployed code is the key commercial uncertainty.
6. Deployed addresses (from docs.biconomy.io/contracts-and-audits, updated 2026-09-01, NOT chain-verified here): MEE Suite v2.2.3 (current): Nexus Implementation v1.3.3 `0x0000B1c01cB3b5770D8806f0D214d50131a08a5B`, MEE K1 Validator v1.1.0 `0x0000B1C0790E5a28293276C320d2B95D651dBaD6`, Nexus Bootstrap v1.3.0 `0x0000B1c0A80cb7DD166a15e7390b8A4Ced4500C6`, Nexus Account Factory `0x0000b1C08f1418dA76B5E99c1Bf5718486cf8c53`. An rc suite v2.3.0 with v1.3.1/v1.3.2 implementations is also listed.
7. Closed GitHub issues not enumerated; stx-contracts not cloned/diffed; no KYC/payment-method info published for the bounty.

## 7. Ranked audit options

### Option 1 (RECOMMENDED): Post-Pashov delta + EIP-7702/PREP init surface
- Target: the 10 files changed since Pashov fixes commit — Nexus.sol init paths (7702 relay init, init-data-hash store), ModuleManager.sol 7702 branches, LibPREP.sol (new, 46 lines), NonceLib.sol, NexusBootstrap.sol changes, Initializable.sol fix completeness. Focal ~1,100 LOC plus interfaces.
- Why fresh: the ONLY code in the repo no auditor has reviewed — 7702 relay init (Jun–Oct 2025) and the local PREP lib postdate all five audits, and the transient-flag fix (Aug 2026) is itself fresh code touching the same init paths.
- Caveat: #308 already claims the 7702 relay signature is not chain-bound; #303's private Aug 2 report contents are unknown and may cover this surface. Dedup against #303's subject area is impossible — residual duplicate risk.

### Option 2: Core account + module manager full pass
- Target: Nexus.sol (578) + ModuleManager.sol (732) + BaseAccount.sol (130) + ExecutionHelper.sol (284) + Storage.sol (40) + RegistryAdapter.sol (53) + supporting libs. ~2,200 LOC + interfaces.
- Why: the highest-value surface (validation, execution, module install/uninstall, hooks, emergency uninstall, enable mode). Main HEAD has 15 post-Pashov commits here.
- Caveat: HIGHEST duplicate risk — five audits plus tracker issues #310/#312 (enable-mode/session-key escape), #309 (uninstall loop DoS), #319 (install skips), #300 (uninstall blocked), #316 (default validator). Only viable as a strict delta-and-gap review, not a from-scratch audit.

### Option 3: Factories + bootstrap + proxy
- Target: NexusAccountFactory.sol (61), BiconomyMetaFactory.sol (89), K1ValidatorFactory.sol (135), NexusBootstrap.sol (447), BootstrapLib.sol (56), NexusProxy.sol (22), Initializable.sol (39). ~850 LOC.
- Why: small, self-contained, deployment-critical (counterfactual addresses, CREATE2, init-time trust assumptions — the same class as the published GHSA). The transient-flag fix deserves a completeness re-check across ALL init paths (classic + 7702 + relay).
- Caveat: `dev` branch REMOVES the meta factory, K1 factory, and registry support — Biconomy's direction of travel may make findings here "already addressed". #320 already claims the MetaFactory returndata issue. Confirm scope with Biconomy first if this option is chosen.

### Option 4 (gap-check only): K1Validator + ERC-7739 validation surface
- Target: K1Validator.sol (280) + Nexus.sol 7739 paths + RegistryAdapter.sol (53). ~700 LOC.
- Why: small; signature validation is the classic critical-impact surface.
- Caveat: VERY HIGH duplicate risk — #307 (zero-owner malformed sig), #321 (7739 try/catch), #306 (empty/short sig revert), #316 (default validator), plus Zenith H-1 (K1Validator bypass, resolved) and the Cantina 7739 add-on. Recommend only as a checklist gap-review inside Option 1 or 2, not standalone.

## 8. Pre-audit checklist (before any finding work)

1. Enumerate CLOSED GitHub issues (titles + root causes) — mandatory dedup.
2. Read all 5 in-repo audit PDFs' finding lists into an exclusion list (68 findings) + Pashov stx Nov 2025 (5 issues).
3. Check whether `bcnmy/stx-contracts` is public; if so, diff Nexus/ModuleManager/Bootstrap between lineages for team-fixed code.
4. Decide the `develop`-branch question: treat `dev` diff (§5a) as the working proxy, and flag any factory/registry finding as scope-uncertain.
5. Confirm Foundry builds `main` HEAD cleanly (solc 0.8.27, Prague) before writing POCs.
