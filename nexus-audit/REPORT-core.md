DECISION: CAUTION — 0 findings survive; nothing filing-ready; the tracker filed 14 more issues in ~6.5 hours, so any future filing needs a fresh re-sweep first.

# Adversarial Code Audit — Biconomy Nexus, Option 2: Core Account + Module Manager (Strict Delta-and-Gap Review)

**Repo:** bcnmy/nexus, pinned HEAD `9007ba1352e606575e32456512e25c41a9bf449c` (2026-08-07, `main`)
**Date:** 2026-11-14 · **Mode:** single pass, local only, read-only repo, no live testing, no submissions
**Pipeline:** Hunter → Skeptic → Referee (fail-closed) + triage_validation 7-Question Gate (no input — see below)
**Source integrity:** HEAD verified matching and tree clean at dispatch, mid-run, and again before concluding.

## Verdict

**0 confirmed findings. 0 filing-ready. 0 Hunter candidates.**

Three domain Hunters produced exactly zero candidates between them — not zero after review, zero at the Hunter stage. Every suspicious pattern chased died by dedup (100 kills against the 176-entry exclusion list) or by verified mechanism (40 merits/disproved leads), and the coordinator independently re-checked the closest calls. The core surface — validation, execution, module install/uninstall, hooks, enable mode, emergency uninstall — held up under this strict delta-and-gap pass, which is the expected outcome for the most heavily-audited files in the repo: five prior audits, 31 open tracker issues, and a second filing burst (14 issues in ~6.5 hours on 2026-11-13 UTC) that claimed the remaining low-hanging mechanisms, including several this audit's Hunters independently re-derived before killing them by dedup.

This is a "no findings" report, not a clean bill of health: single-pass coverage, no executed POCs (none were required — nothing survived), and the residual risks below apply. In particular, the tracker is moving faster than any audit: 14 issues filed between the Option 1 dedup pass and this run, and issues filed after the 2026-11-14 02:48 UTC delta sweep are not covered.

## Phase 0 — pre-audit checklist (SCOPE.md §8)

All five items are now done. Items 1–3 were substantially completed during Option 1 (contrary to the task brief's "never done before" note, which was written from the pre-Option-1 SCOPE.md); this run verified that work, closed its gaps, and made its outputs durable.

| # | Item | Status |
|---|---|---|
| 1 | Enumerate CLOSED GitHub issues | Done (Option 1: 30/30) + delta re-verified 2026-11-14: open count 31 = 17 + 14 new, consistent with zero status changes. LIMIT: closed-list re-enumeration could not be rendered directly (page-1-only list rendering, no API); rests on open-count arithmetic — re-verify via live browser before any filing. |
| 2 | Refresh the exclusion list | Done: 161 → **176 entries**. Added §I: 14 new issues #325–#338 (EX-122–EX-135) + the Option 1 H-B1 disproof (EX-136). Counts table, appendix clusters, and end-line total updated; all 15 new entries verified present. |
| 3 | stx-contracts public? Clone + diff | Done: public, cloned to `repos/stx-contracts` at `develop` HEAD `61001d0f` (2026-09-01). Durable diff written to `STX-DIFF.md` (the Option 1 /tmp diff was lost) + 36 raw diffs in `evidence-stx/`. See Lineage section. |
| 4 | `develop`-branch question | Settled as far as public evidence goes: `bcnmy/nexus` has NO `develop` branch; `bcnmy/stx-contracts` HAS one and it is the default branch (HEAD = `61001d0f`, tag `v2.2.3` identical). The bounty text's "must not be fixed in `develop`" therefore maps to stx `develop` for the deployed lineage. Any factory/registry finding would still be scope-uncertain (registry removed in 1.3.x; `dev` removes registry/factory code) — none was claimed. |
| 5 | Foundry builds `main` HEAD cleanly | Re-verified this run: forge 1.5.1, solc 0.8.27, Prague, smoke tests 2/2 pass in the existing `poc/` harness. See Build verification. |

## All Hunter output

| Domain | Surface | Files / lines | Candidates | Kills |
|---|---|---|---|---|
| A | Validation + execution entry points (`Nexus.sol`, `BaseAccount.sol`) | 2 files, 708 lines | 0 | 40 dedup + 7 self-disproved leads |
| B | Module lifecycle (`ModuleManager.sol`, `RegistryAdapter.sol`) | 2 files, 785 lines | 0 | 42 dedup + 23 verification |
| C | Execution + storage + libs (`ExecutionHelper`, `Storage`, `ExecLib`, `ModeLib`, enumerable libs, parsers, types) | 15 files, 2,165 lines (verified by `wc`) | 0 | 18 dedup + 10 merits |

**Total: 21 files, ~3,658 lines read in full. 140 kills. 0 candidates.**

### Closest calls, and why they died (coordinator-verified)

The Hunters' sharpest leads, each re-checked by the coordinator against the pinned source:

1. **Uninitialized-list bypass of `_checkInitializedValidators` (Hunter A, D2).** The coordinator independently noticed the same shape while reading `Nexus.sol`: if `validators.entries[SENTINEL] == 0`, the loop exits with `next == ZERO_ADDRESS` and the `next == SENTINEL` revert never fires. DISPROVED: `uninstallModule` requires `_isModuleInstalled` → `validators.contains()`, and the pinned SentinelListLib `contains` returns false for unmapped entries — so the guard is reachable only with list membership, which implies an initialized list. Coordinator re-read the pinned `SentinelList.sol` (`init`/`pop`/`contains`) and confirmed.
2. **Emergency-uninstall nonce griefing via failed signatures (Hunter A, D3).** The nonce is marked used before the signature check — but a failed `require` reverts the whole transaction, rolling back the write. Nonces burn only on successful calls, which is #326's distinct, already-known mechanism (EX-123). DISPROVED by EVM revert semantics; coordinator confirmed the code order in `ModuleManager._checkEmergencyUninstallSignature`.
3. **`setRegistry` lacking an inner `withHook` (Hunter B, closest call).** Killed twice: EX-023 root-cause family (Cantina 5.2.5, registry configuration state) plus the threat model — `setRegistry` requires `msg.sender == address(this)`, reachable only via owner-validated `execute()` (which carries `withHook`) or a trusted executor (likewise hooked). Zero incremental privilege per the H-B1 reasoning. NOT_A_BUG.
4. **H-B1 re-test (Hunter A, K10).** All routes to the `initializeAccount` self-call branch re-enumerated (EntryPoint-validated userOp, trusted executor, fallback handler, hook callbacks, 7702 direct tx, composable execution) — every route is owner-key, trusted-executor, or guard-gated. No new principal. The Option 1 disproof stands; recorded as EX-136 so no future pass re-claims it.
5. **`#304` / ComposableExecution constraint bypass (Hunter C).** Verified to live entirely in the third-party `composability` package with no touchpoint in `ExecutionHelper`/`ExecLib`. Out of scope by asset (third-party code), and already known (EX-079).
6. **Inherited Solady `upgradeTo()` bypassing `withHook` (Hunter A, D1).** DISPROVED: Solady v0.1.9 `UUPSUpgradeable` exposes no `upgradeTo`; only `upgradeToAndCall`, which Nexus overrides with `withHook`. Verified in pinned source.
7. **`executeUserOp` `[4:]` slice on short calldata (Hunter A).** Unreachable: reaching `executeUserOp` requires ≥4 bytes of calldata (the selector itself). No panic path.

### Skeptic / Referee / Gate

With zero Hunter candidates, `skeptic.json` and `referee.json` are empty arrays per the skill contracts for empty input, and nothing reached the 7-Question Gate (`gate-7q.json` records that explicitly — the gate was not bypassed, it had no input). The pipeline's adversarial work in this run happened inside the Hunter phase (dedup kills + self-disproved leads with checked counter-evidence) and in the coordinator's independent verification of the closest calls above. No finding was softened, downgraded, or carried forward on a trace.

## Dedup summary

`exclusions/EXCLUSION_LIST.md`: **176 entries** (EX-001–EX-136 + EX-G01–G07 + EX-I01–I33), all re-verified or newly verified this run:

- **68 security findings** across the 5 in-repo audit PDFs + 40 gas/info items = 108 PDF items (Option 1).
- **31 open issues** (17 baseline + 14 delta #325–#338, all bodies read in full); **30 closed issues** enumerated (Option 1).
- **1 published advisory** (GHSA-q47q-h6x2-f5qg, fix verified present at HEAD); no second GHSA found.
- **5 Pashov stx-contracts (Nov 2025) issues** with per-issue applicability checks.
- **1 disproved candidate** (H-B1, EX-136).

**The 14 delta issues (#325–#338)** — six novel mechanisms, all now excluded: EX-122 (#325 bootstrap zero-address validator brick), EX-123 (#326 emergency-uninstall nonce burn/reset), EX-125 (#328 raw 0x32 panics at 4 boundaries), EX-126 (#329 zero-validator init vs uninstall invariant), EX-129 (#332 hook-keyed emergency timelock clock-sharing), EX-130 (#333 assembly parser without bounds checks; gap 2 duplicates #319). The rest duplicate already-excluded families (#330/#331/#334/#335) or are stx-only (#336/#337/#338). Duplicate clusters extended: `_multiTypeInstall` silent skip (4 filings), short-signature revert (4 filings), zero-owner `tryRecover` (4 filings across both lineages), emergency-uninstall mechanisms (4 distinct: stale timelock, oracle confusion, nonce burn, hook-keyed clock).

**Most-collided-with exclusions on this surface:** EX-071/EX-086/EX-127/EX-130 (`_multiTypeInstall`), EX-078/EX-088/EX-128/EX-132 (short-signature revert), EX-073/EX-074 (#310/#312 oracle confusion), EX-075/EX-081 (#309/#300 uninstall-guard loop), EX-072 (#316 default validator), EX-055 (Pashov M-02 guard origin), EX-136 (H-B1).

## Lineage assessment (1.2.1 vs deployed 1.3.3)

From `STX-DIFF.md` (tree-to-tree diff, nexus `main` @ `9007ba1` vs stx `develop` @ `61001d0f`):

- **Team-changed (strong duplicate/fix signal — a finding here is likely already addressed upstream):** T1 ERC-7484 registry removed entirely (all 6 enforcement points + config surface; coordinator spot-verified: 0 registry references in stx `contracts/` vs 7 in nexus); T2 K1 successor EOA-only owner guard; T3 K1 validation dispatch rewritten (MEE modes + cross-account-replay hashing; plain-ECDSA core preserved); T4 ERC-7739 detection internalized; T5 composability base re-sourced to audited `erc8211-contracts`; T6 EIP-712 domain versions bumped (Nexus 1.3.2, bootstrap 1.3.0); T7 `nonce()` view removed.
- **Explicitly NOT team-changed (a finding here would survive to 1.3.3):** `validateUserOp`, enable-mode/emergency-uninstall mechanics, install/uninstall mechanics, execution decoding, PREP, storage layout, the single-use init flag (fixed independently in both repos on 2026-08-07).
- **Per-finding lineage:** N/A — zero findings. Had any survived, this section's lists would have determined its lineage verdict; the mechanism tables in `STX-DIFF.md` + `evidence-stx/` are preserved for any future pass.
- **CAVEAT (coordinator-caught):** the diff worker claimed `cast` selector/hash verification, but `cast` is NOT installed on this VM (exit 127). All assembly/selector-equivalence claims in `STX-DIFF.md` therefore rest on manual review only, not tooling. The structural claims (registry removal, file verdicts, branch facts) were spot-verified by the coordinator; the equivalence claims were not executed. Treat them as manual-review-grade.

## Coverage

- **21/21 Option 2 scope files read in full** (see `artifacts-core/coverage.json`): `Nexus.sol`, `ModuleManager.sol`, `BaseAccount.sol`, `ExecutionHelper.sol`, `Storage.sol` + `IStorage.sol`, `RegistryAdapter.sol`, `ExecLib`, `ModeLib`, `ModuleTypeLib`, `EnumerableMap4337`, `EnumerableSet4337`, `AssociatedArrayLib`, `NonceLib`, `BytesLib`, `BootstrapLib`, `LocalCallDataParserLib`, `Constants`, `DataTypes`, plus `interfaces/` as context.
- Evidence-only reads: `NexusBootstrap.sol`, `K1Validator.sol`, `NexusProxy.sol`, `Initializable.sol`, `ProxyLib.sol`, pinned dependency sources (solady v0.1.9, sentinellist 1.0.1, EntryPoint v0.7, ERC-7739 base).
- Out of scope and not read except as evidence: `contracts/factory/*`, `contracts/modules/*` (except K1Validator as evidence), `contracts/mocks/*`, `test/*`. `LibPREP.sol` internals were relied on from Option 1 Domain A verification rather than re-read (Hunter A caveat).
- Boundary-pair pass: not run as a separate phase — with zero candidates in all three domains there were no cross-domain claims to adjudicate. The coordinator traced the two highest-risk seams during its own full reads of the six core files (enable-mode → install → hook/registry enforcement; `executeUserOp` delegatecall → self-call install) and found nothing beyond already-excluded mechanisms.
- Single pass. Complete-coverage looping was not ordered; this report covers the Option 2 scope only, not the whole repo. Options 3–4 (factories/bootstrap/proxy; K1Validator/7739) remain unaudited as standalone passes.

## Build verification (Phase 0 item 5, re-verified)

The pinned HEAD **compiles cleanly under Foundry** in the existing scratch project at `~/workspace/nexus-audit/poc/` (repo untouched, one absolute read-only remapping): `forge build` (cached, no changes), `forge test` **2/2 pass** (proxy deploy + `initializeAccount` + `isInitialized()`; `signDelegation` cheatcode availability). Toolchain: forge 1.5.1, solc 0.8.27, Prague. No finding POCs were built: with zero surviving findings, none were required. Hunter code traces were never presented as executed repros. (Skill §14 staleness note, repeated from Option 1: the vendored skills state Foundry is not installed; forge 1.5.1 IS installed at `~/.foundry/bin` and was used.)

## Gaps and caveats (state plainly)

1. **1.2.1 vs deployed 1.3.3:** this repo is two minor versions behind the deployed Nexus (v1.3.3 from `bcnmy/stx-contracts`, MEE suite 2.2.3). Whether Biconomy pays for bugs present only in the 1.2.1-lineage `main` is **UNVERIFIED**. No finding in this audit claims deployed impact, and no deployed-bytecode verification was ordered or performed.
2. **#303 (EX-080):** a private security report sent Aug 2, 2026, contents UNKNOWN. It may cover this exact surface. No public dedup can rule out collision with it. Unretireable residual risk.
3. **Private duplicates unsearchable:** as with any bounty program, privately filed duplicates can never be fully excluded.
4. **Tracker velocity:** 14 issues filed in ~6.5 hours on 2026-11-13 (UTC); the delta sweep is a snapshot at 2026-11-14 02:48 UTC. Issues filed after that moment, issue comments, and any post-crawl maintainer triage are NOT covered. **Re-sweep immediately before any filing.** The closed-list/oldest-open re-verification also rests on count arithmetic, not direct re-rendering (see Phase 0 item 1).
5. **STX-DIFF equivalence caveat:** assembly/selector-equivalence claims rest on manual review only (`cast` not installed). Structural claims spot-verified; equivalence claims not executed.
6. **External modules untraced:** session validators, policies, and executor modules live outside this repo. The zero-incremental-privilege bar (H-B1) and the "no limited-scope principal in-repo" threat model could not be traced further. A future audit with the session-module repos could revisit enable-mode/emergency-uninstall oracle-confusion variants — but #310/#312 already claim that root cause, so any revisit must prove a genuinely distinct mechanism.
7. **Sentinellist version correction (Hunter B):** SCOPE.md says sentinellist v1.0.0; the yarn.lock pin and fetched source are **1.0.1** (commit `e722c5c`). Semantics were verified from the pinned 1.0.1 source. SCOPE.md was not edited (scoping artifact, left as-is).
8. **Single pass:** a second pass, a loop order, or a wider scope (Options 3–4 in SCOPE.md) could find what this pass missed. This report describes this run only.

## Deliverables

- `REPORT-core.md` (this file)
- `STX-DIFF.md` + `evidence-stx/` (36 raw diffs) + `repos/stx-clone-log.txt` + `repos/stx-contracts/` (full clone at `develop` HEAD)
- `exclusions/EXCLUSION_LIST.md` (176 entries, §I merged) + `exclusions/NEW-ISSUES-2026-11-14.md` (delta source)
- `artifacts-core/` — `triage.json`, `retrieval-plan.json`, `recon.json`, `hunter-findings-{A,B,C}.json` (all `[]`), `hunter-{A,B,C}-coverage.txt`, `skeptic.json` (`[]`), `referee.json` (`[]`), `validated-findings.json`, `verification-report.json`, `gate-7q.json`, `coverage.json`, `scan-report.json` (all 13 JSON artifacts validated: parse cleanly, required fields present, enums match the skill contracts)
- `poc/` — existing Foundry scratch project, re-verified green (BUILD_LOG.md with POC instructions; no new POCs — none required)
- `findings/` — no subdirectories: zero surviving findings, so no finding write-ups or POCs exist. The disproved-candidate record lives in EX-136 and in Option 1's artifacts.

## Verification status

- Pinned HEAD `9007ba1…` verified matching and tree clean at dispatch, mid-run, and before concluding (0 dirty files).
- All 13 JSON artifacts validated (see Deliverables). All three Hunter coverage files confirm dedup-first reading (SCOPE.md §5, all 161 baseline exclusions, REPORT-delta.md, all 14 delta issues).
- Coordinator parent-verification performed: full reads of all six core files; independent re-checks of the seven closest calls (listed above); SentinelListLib semantics re-read from pinned source; stx registry-removal spot-check by grep; exclusion-merge entry check (EX-122–EX-136 all present); `cast`-absence caveat caught and recorded.
- Nothing was filed; filing needs a separate user order (and there is nothing filing-ready to file).
