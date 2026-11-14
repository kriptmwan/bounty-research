# Adversarial Code Audit — Biconomy Nexus, Option 1: Post-Pashov Delta + EIP-7702/PREP Init Surface

**Repo:** bcnmy/nexus, pinned HEAD `9007ba1352e606575e32456512e25c41a9bf449c` (2026-08-07, `main`)
**Date:** 2026-11-13 · **Mode:** single pass, local only, read-only repo, no live testing, no submissions
**Pipeline:** Hunter → Skeptic → Referee (fail-closed) + triage_validation 7-Question Gate
**Source integrity:** HEAD verified matching and tree clean at dispatch and again before concluding.

## Verdict

**0 confirmed findings. 0 filing-ready. 1 Hunter candidate, disproved.**

Three domain Hunters produced exactly one candidate (H-B1, claimed High). The Skeptic disproved it with checked counter-evidence; the Referee independently traced the full chain and adjudicated **NOT_A_BUG**. The 7-Question Gate independently kills it at Q1 (and Q4). The delta surface — the only code in the repo no auditor had reviewed — held up under this pass: the 7702 relay-init logic, the PREP validation library, and the transient-flag fix are all sound as far as this single pass could determine, and every suspicious pattern the Hunters chased resolved to correct code, by-design behavior, or an already-known issue.

This is a "no findings" report, not a clean bill of health: single-pass coverage, no executed POCs (none were required — nothing survived), and the residual risks below apply.

## The one candidate, and why it died

| ID | Claimed | Verdict | One line |
|---|---|---|---|
| H-B1 | High (CWE-862) | **NOT_A_BUG** (Referee, conf 20/low, INDEPENDENTLY_VERIFIED) | `initializeAccount`'s `msg.sender == address(this)` branch skips all init guards — real as a code fact, but zero incremental privilege: every principal that can reach it already has equal-or-greater power. |

**Mechanism (verified real):** `Nexus.initializeAccount` (Nexus.sol:306-334) wraps every guard in `if (msg.sender != address(this))`; the self-call branch performs no transient-flag check, no relay signature check, and no `!isInitialized()` check, and `_initializeAccount` (336-356) delegatecalls a caller-supplied bootstrap. An already-initialized account can therefore be re-initialized via a self-call.

**Why it is not a bug (checked counter-evidence, Skeptic + Referee both traced independently):**

1. **No attacker principal exists in-repo.** The only validator shipping in this repo is K1Validator: owner-ECDSA-key only, no calldata/policy inspection. Executors are owner-installed and fully trusted. A 7702 direct self-transaction requires the EOA key itself. Session/limited-scope modules live in other repos — untraced, and not assumed.
2. **Zero incremental privilege.** The same principal, through the same outer validation and the same `withHook` check, can already run unrestricted `CALLTYPE_DELEGATECALL` via `execute()`/`executeFromExecutor()` (arbitrary code in account storage context, no target restriction), install arbitrary modules, and (for proxy accounts) `upgradeToAndCall` via self-call. Re-init grants nothing new.
3. **The "no hook/registry checks" sub-claim was overstated.** Outer `execute()` calls carry `withHook`; the stock NexusBootstrap path runs `withHook`+`withRegistry` on every `_install*`. Only a custom bootstrap skips them — exactly as delegatecall-mode `execute()` does.
4. **Gate:** Q1 fails (no attacker-use chain right now; the attacker walks away with nothing), Q4 fails (requires the owner key / trusted executor). Q5 checked: no root-cause duplicate among EX-116, EX-049, EX-I20, EX-067, EX-073/EX-074 (effect-overlap only with the last three).

**Hardening suggestion (recorded, not a finding):** add a `!isInitialized()` check to the self-call branch of `initializeAccount`. Per both the Skeptic and the Referee, this would not break the intended 7702 first-init flow (first userOp self-call on an uninitialized account) and would close the re-init path as defense in depth. If Biconomy is ever contacted about anything else, this is a one-line suggestion, not a bounty report.

Full traces: `artifacts/hunter-findings-B.json`, `artifacts/skeptic.json`, `artifacts/referee.json`, `artifacts/gate-7q.json`.

## All Hunter output

| Domain | Surface | Candidates | Survived |
|---|---|---|---|
| A | LibPREP + PREP init (`LibPREP.sol`, `_handlePREP`, PREP branch, `NonceLib`) | 0 | 0 |
| B | 7702 relay-init + transient flag (`initializeAccount`, `Initializable`, `IStorage`, `NexusProxy`) | 1 (H-B1, High) | 0 — disproved |
| C | Bootstrap + ModuleManager/BaseAccount delta (`NexusBootstrap`, `ModuleManager`/`BaseAccount` hunks) | 0 | 0 |

**Domain A verification highlights:** upstream `lib-prep` source (yarn-lock pin `7334641`) is byte-identical to the local `LibPREP.sol` copy (diff exit 0) — zero drift. The RLP designation hash is byte-exact vs EIP-7702. Solady v0.1.9 `tryRecover`/`EfficientHashLib`/`LibEIP7702` semantics verified from pinned source. `_amIERC7702` (extcodesize 23 + 3-byte `0xef0100`) is precise with no reachable false positive/negative. `_handlePREP`'s non-comparison of proof delegation vs live delegation is safe because the mining structure enforces consistency (a second solution for the same target with a different delegation is a 2^160 search).

**Domain C verification highlights:** default-validator-in-`validators[]` is enforced by revert (`DefaultValidatorAlreadyInstalled`), not doc-only; the loop calls the same guarded `_installValidator`; `getDefaultValidator()` has zero call sites; the `_uninstallPreValidationHook` re-sign is behavior-neutral with exactly one `onUninstall`; `_getEnableModeDataHash` view→pure is byte-identical; the BaseAccount delta is a version string only; `NonceLib`/`LocalCallDataParserLib` deltas are pragma/comment-only (zero executable lines changed).

## Dedup summary

`exclusions/EXCLUSION_LIST.md`: **161 entries**, keyed by root cause, all re-verified this pass (not copied from SCOPE.md):

- **68 security findings** across the 5 in-repo audit PDFs (CodeHawks 14, Cantina main 27, Cantina 7739 add-on 3, Zenith 9, Pashov 15) + 40 gas/info items = 108 PDF items.
- **17/17 open issues read in full** (13 security-relevant); **30/30 closed issues enumerated** (6 security-relevant read in full).
- **1 published advisory** (GHSA-q47q-h6x2-f5qg, fix verified present at HEAD).
- **5 Pashov stx-contracts (Nov 2025) issues** with per-issue applicability checks (3 don't apply to 1.2.1 at all, 2 are other-lineage-only).
- **stx-contracts confirmed PUBLIC** (HEAD `61001d0`, diffed from /tmp): registry fully removed in 1.3.x; most delta-surface mechanisms unchanged in substance. The `develop`-branch exclusion remains unverifiable as written in this repo (no `develop` branch; `dev` removes registry/factory code; stx-contracts DOES have a `develop` branch — ambiguity to confirm with Biconomy before filing anything factory/registry-adjacent).
- **Triage is actively closing duplicates:** issues #322/#323/#324 were filed and closed the same day (2026-11-13) as duplicates of #319/#307/#306. Duplicate risk is enforced, not theoretical.

**Most-collided-with exclusions on this surface:** EX-076 (#308, raw-hash relay signature — the delta's flagship logic, already claimed), EX-116 (GHSA transient flag), EX-057 (Pashov L-02 — **status corrected during this audit:** the `_handlePREP` length check is `0xf9` (249) at HEAD since commit `4ab44e27`, meeting the ≥229 requirement; fixed, not merely accepted), EX-052 (Zenith L-4, `_uninstallPreValidationHook`), EX-075/EX-081 (#309/#300, `_checkInitializedValidators` loop).

Hunters recorded 15+ additional dedup kills in their coverage files; every hinted check that died by dedup is named with its exclusion ID there.

## Coverage

- **10/10 delta files covered** (see `artifacts/coverage.json`): `LibPREP.sol`, `Initializable.sol`, `Nexus.sol` (full read; findings scope = init/PREP paths), `NexusBootstrap.sol` (full read), `IStorage.sol`, `ModuleManager.sol` (delta regions + install/uninstall paths), `BaseAccount.sol`, `NonceLib.sol`, `LocalCallDataParserLib.sol`, `INexusEventsAndErrors.sol`.
- Evidence-only partial reads: `ExecutionHelper`, `K1Validator`, `NexusProxy`, `ProxyLib`, `DataTypes`, `Constants`, solady v0.1.9 pinned source, upstream lib-prep, PREP unit test (context).
- Out of scope and not read except as evidence: remaining `contracts/modules/*`, `contracts/factory/*`, non-delta libs, tests/mocks.
- Single pass. Complete-coverage looping was not ordered; this report covers the delta surface only, not the whole repo.

## Build verification (pre-audit checklist item 5: done)

The pinned HEAD **compiles cleanly under Foundry** in a scratch project at `~/workspace/nexus-audit/poc/` (repo untouched, referenced via one absolute read-only remapping): `forge build`, 102 files, solc 0.8.27, Prague, 0 errors, 6 warnings (all pre-existing in repo code). Dependencies fetched via npm matching the repo's yarn.lock commits exactly (composability, account-abstraction v0.7.0, erc7579, erc7739-validator-base, solady v0.1.9, sentinellist, etc.; OpenZeppelin pinned 5.1.0). Smoke test **2/2 pass**, including an end-to-end proxy deploy + `initializeAccount` + `isInitialized()` assertion, and Prague transient storage (`tstore`/`tload`-and-clear, the GHSA fix) verified working under forge 1.5.1. Full log + POC-writing instructions: `poc/BUILD_LOG.md`. Exact POC command: `cd ~/workspace/nexus-audit/poc && export PATH="$HOME/.foundry/bin:$PATH" && forge test`.

No finding POCs were built: with zero surviving findings, none were required. Hunter code traces were never presented as executed repros.

## Gaps and caveats (state plainly)

1. **1.2.1 vs deployed 1.3.3:** this repo is two minor versions behind the deployed Nexus (v1.3.3 from `bcnmy/stx-contracts`, MEE suite 2.2.3). Whether Biconomy pays for bugs present only in the 1.2.1-lineage `main` is **UNVERIFIED** — the bounty text says scope is `main`, but payout relevance to deployed code is the key commercial uncertainty. No finding in this audit claims deployed impact, and no deployed-bytecode verification was ordered or performed.
2. **#303 (EX-080):** a private security report sent Aug 2, 2026, contents UNKNOWN. It may cover this exact surface. No public dedup can rule out collision with it. Unretireable residual risk.
3. **Private duplicates unsearchable:** as with any bounty program, privately filed duplicates can never be fully excluded.
4. **7702 end-to-end execution unproven:** forge-std declares `signDelegation`/`attachDelegation` and `signDelegation` executes, but no test in this audit executed through a delegated EOA. The first future 7702/PREP POC must verify that path itself. (No finding depended on it.)
5. **Dependency-source gaps:** `SentinelListLib.alreadyInitialized()` source could not be fetched (one Hunter); SentinelList uniqueness is natspec-asserted. No finding depends on either gap.
6. **External modules untraced:** session validators, policies, and executor modules live outside this repo. H-B1's limited-principal precondition could not be traced further than "no such principal exists in-repo." A future audit with the session-module repos could revisit the self-call re-init question — but the zero-incremental-privilege argument (delegatecall-mode `execute()` is strictly more powerful) would still need to be overcome.
7. **Single pass:** a second pass, a loop order, or a wider scope (Options 2–4 in SCOPE.md) could find what this pass missed. This report describes this run only.
8. **Skill §14 staleness note:** the vendored skills state Foundry is not installed; that is outdated — forge 1.5.1 is installed at `~/.foundry/bin` and was used for the build/scaffold work. Two Hunters repeated the stale "no toolchain" note in their coverage files; it affected nothing (no finding required execution).

## Deliverables

- `REPORT-delta.md` (this file)
- `exclusions/EXCLUSION_LIST.md` (161 entries)
- `artifacts/` — `triage.json`, `retrieval-plan.json`, `recon.json`, `hunter-findings-{A,B,C}.json`, `hunter-{A,B,C}-coverage.txt`, `skeptic.json`, `referee.json`, `validated-findings.json`, `verification-report.json`, `gate-7q.json`, `coverage.json`, `scan-report.json`
- `poc/` — Foundry scratch project (compiles pinned HEAD; 2/2 smoke tests; `BUILD_LOG.md` with POC instructions)
- `findings/` — no subdirectories: zero surviving findings, so no finding write-ups or POCs exist. The single disproved candidate is fully documented in the artifacts above.

## Verification status

- Pinned HEAD `9007ba1…` verified matching and tree clean at dispatch and again before concluding (0 dirty files).
- All 13 JSON artifacts validated: parse cleanly, required fields present, enums match the skill contracts, H-B1 appears exactly once in Skeptic and Referee outputs, the DISPROVE carries file:line counter-evidence.
- Parent must re-verify decisive claims (re-read file:line, re-check dedup) before any report to the user, per the adversarial_code_audit skill. Nothing was filed; filing needs a separate user order (and there is nothing filing-ready to file).
