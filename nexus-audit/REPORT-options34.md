DECISION: CAUTION — 0 findings survive across Options 3+4; nothing filing-ready; all four SCOPE.md audit options are now complete with 0 findings total.

# Adversarial Code Audit — Biconomy Nexus, Options 3+4: Factories + Bootstrap + Proxy, and K1Validator / ERC-7739 Gap-Check

**Repo:** bcnmy/nexus, pinned HEAD `9007ba1352e606575e32456512e25c41a9bf449c` (2026-08-07, `main`)
**Date:** 2026-11-14 · **Mode:** single pass, local only, read-only repo, no live testing, no submissions
**Pipeline:** Hunter → Skeptic → Referee (fail-closed) + triage_validation 7-Question Gate (no input — see below)
**Source integrity:** HEAD verified matching and tree clean at dispatch, at each Hunter's conclusion, and again before concluding.

## Verdict

**0 confirmed findings. 0 filing-ready. 0 Hunter candidates in either option.**

Two Hunters produced exactly zero candidates between them — not zero after review, zero at the Hunter stage. Every suspicious pattern chased died by dedup (45 kills against the 176-entry exclusion list) or by verified mechanism (46 merits/disproved leads), and the coordinator independently re-checked the closest calls and the highest-value completeness claim (the transient-flag re-check). The factory/bootstrap/proxy surface and the K1Validator/7739 gap surface held up under this pass, which is the expected outcome for heavily-audited, heavily-filed code: five prior audits, 31 open tracker issues, and a second filing burst (14 issues in ~6.5 hours on 2026-11-13 UTC) that claimed the remaining low-hanging mechanisms on these exact surfaces, including the bootstrap zero-address brick (#325) and the MetaFactory returndata claim (#320).

This is a "no findings" report, not a clean bill of health: single-pass coverage, no executed POCs (none were required — nothing survived), and the residual risks below apply. With this run, **all four SCOPE.md audit options are complete**: Option 1 (post-Pashov delta + 7702/PREP), Option 2 (core account + module manager), Option 3 (factories + bootstrap + proxy), Option 4 (K1Validator + 7739 gap-check) — **0 findings across all four**.

## Step 0 — fresh tracker re-sweep (mandatory, done first)

**Verdict: COMPLETE (new-issue enumeration). Zero new issues.** No issues numbered above #338 were filed in the window 02:48 → 03:19 UTC (09:48 → 10:19 WIB); the #325–#338 set from the Option 2 delta sweep was confirmed complete and contiguous with matching titles; no status changes observed.

Evidence: fresh issues-list render at 03:19 UTC showing Open (31), unchanged, highest issue #338, page 1 identical (25 entries, #338 down to #305); an independent fresh probe of issue #339 returned HTTP 404, ruling out anything above #339 and any file-and-close event in the window (sequential numbering; closed/filed items still render). Four web searches surfaced nothing above #338 (search indexes days stale — corroboration only). Zero `api.github.com` calls. One methodology note from the sweep worker: the first fetch returned the prior sweep's cached copy — the fresh crawl was forced with `max_age_minutes=30` after the cache aged; re-sweeps must check the "Page crawled" header.

Honest gap: page 2 (6 oldest open issues) and the Closed tab still don't render as followable links — a same-issue close+reopen on page 2 with no net count change would be invisible. This does not affect the new-issue conclusion (new filings must top page 1 and consume a new number). Re-verify closed count + oldest 6 via live browser before any filing.

**EXCLUSION_LIST.md was NOT extended** (zero new issues, per instructions). Total remains **176 entries**; the next new security entry would be EX-137. Delta file: `exclusions/NEW-ISSUES-2026-11-14-PM.md`.

## Option 3 — Factories + Bootstrap + Proxy (full read, ~849 LOC)

**Scope:** `NexusAccountFactory.sol` (61), `BiconomyMetaFactory.sol` (89), `K1ValidatorFactory.sol` (135), `NexusBootstrap.sol` (447), `BootstrapLib.sol` (56), `NexusProxy.sol` (22), `Initializable.sol` (39). All 7 read in full; zero skipped; `ProxyLib.sol` read as evidence. **0 candidates. 56 kills: 28 dedup + 28 disproved-on-merits.**

### Transient-flag completeness re-check (the highest-value shape): no bypass found

All 4 paths to `_initializeAccount` are gated. Coordinator independently re-verified the gating code, the single flag-set site, the absence of any other transient-storage use repo-wide, and the selector/slot derivation by read-only computation (see Parent verification).

| # | Path | Gate | Verdict |
|---|---|---|---|
| 1 | Classic proxy: `NexusProxy` ctor → `initializeAccount`, `msg.sender != self`, not 7702 | `requireInitializable()` consumes the flag (`Initializable.sol:27-38`); a 2nd call in the same tx reverts `NotInitializable` | GATED. Fix verified present; selector `0xaed59595` + `INIT_SLOT` derivation verified byte-exact via read-only ethers keccak computation. |
| 2 | EIP-7702 relay: `initializeAccount`, `msg.sender != self`, `_amIERC7702()` | Owner ECDSA sig over `keccak256(initData)` + `!isInitialized()` + `erc7702InitHashes` replay map (`Nexus.sol:310-329`). No transient flag by design (no proxy ctor sets one for EOAs). | GATED by equivalent guards. Residual raw-hash/chain-binding weakness is EX-076 (#308), already claimed. No new bypass. |
| 3 | Self-call: `initializeAccount`, `msg.sender == address(this)` | No guards (EX-136 / H-B1) | DISPROVED as a bug in Option 1: zero incremental privilege; not re-reported. |
| 4 | PREP: `validateUserOp` PREP branch → `_initializeAccount` directly | `onlyEntryPoint` + `require(!isInitialized())` (`Nexus.sol:129`) + `_handlePREP` proof: length ≥ `0xf9` + `LibPREP.rPREP != 0` binding target address + `keccak256(initData)` + delegation. Proxy accounts are initialized at construction, so the branch is unreachable for proxies; mining a proof for an arbitrary target is a 2^160 search per Option 1 Domain A verification (relied on, not re-proved). | GATED by equivalent guards. No bypass found. |

Supporting facts (all coordinator-verified): single deployment site (`ProxyLib:27`); single flag-set site (`NexusProxy:13` — the only `setInitializable` call site repo-wide); no other `tstore`/`tload` use repo-wide outside `Initializable.sol`. Factory front-running/squatting is harmless (counterfactual address binds the full initData); the K1 salt is injective; K1 zero-owner fails closed via K1's own check.

### Closest calls, all killed

1. **D4 — single-validator zero check (EX-122 family, scalar variant).** Killed on root-cause identity with #325 (init revert). If a gate ever judged sibling-function instances distinct, this is the one to revisit; impact is identical to #325.
2. **D17 — bootstrap `preValidationHooks` arbitrary hookType silently no-op** (`_setPreValidationHook` no-else + `_getPreValidationHook` ternary). Killed on EX-071 mechanism family + deployer-only input. No attacker principal exists in-repo; revisitable only as Low if the gate judged the function distinct from `_multiTypeInstall` AND deployer-footgun reports in scope.
3. **M17 — empty-data `NexusProxy` permanently uninitialized.** Killed: no attacker principal + factories prevent it. Deployer footgun only.

### Dedup highlights (Option 3)

EX-070 (#320 MetaFactory returndata), EX-122 (#325 zero-validator brick, including the `_initNexusScoped` loop and single-validator scalar variants), EX-126 (#329 empty-validator init), EX-116 (GHSA flag itself), EX-136 (H-B1 self-call re-init), EX-076 (#308 relay raw hash), EX-002/EX-034 (registry ordering — fixed at HEAD), EX-047 (proxy receive — fixed). Full 56-kill ledger with exclusion IDs / counter-evidence file:line: `artifacts-o34/hunter-O3-coverage.txt`.

### Option 3 lineage tags (from STX-DIFF.md)

- `NexusBootstrap.sol`: SUBSTANCE-CHANGED in 1.3.3 (registry config removed from all init flows; install loops identical). A bootstrap install-loop finding would survive to 1.3.3; a registry-ordering finding would not.
- `Initializable.sol`: COSMETIC (comment reword; consume-flag logic identical, parallel fix). Flag mechanisms are live in both lineages.
- `NexusAccountFactory.sol`: logic identical in 1.3.3 (interface inlined only). `NexusProxy.sol`: cosmetic diff only. `ProxyLib.sol`: cosmetic.
- `BiconomyMetaFactory.sol` / `K1ValidatorFactory.sol`: NO COUNTERPART in stx-contracts 1.3.3 (absent); also REMOVED on nexus `dev` (PR #295). Any finding here would be scope-uncertain (see caveat below).

### Scope-uncertainty caveat (Option 3)

All factory/registry-adjacent kills are SCOPE-UNCERTAIN: the `dev` branch removes the meta factory, K1 factory, and registry support, and stx-contracts 1.3.3 removed the registry entirely. Any future finding in this surface must be tagged "possibly already addressed in Biconomy's working line" for the Referee/gate. No candidate was reported, so no finding carries this caveat into review. The bounty text's "must not be fixed in `develop`" maps to stx-contracts `develop` (which exists; nexus has no `develop` branch) per REPORT-core.md Phase 0 item 4.

## Option 4 — K1Validator + ERC-7739 gap-check ONLY (not a from-scratch audit)

**Scope:** `K1Validator.sol` (280 lines) read in full as a reporting target for the first time; `Nexus.sol` 7739 gap regions only (`isValidSignature` L374–390, `checkERC7739Support` L486–499, `_get7739Version` L500–506, `setRegistry` L363–366, `_domainNameAndVersion` L573–576); `RegistryAdapter.sol` (53 lines) gap re-check. The remaining 533 lines of `Nexus.sol` and `ModuleManager.sol` were relied on from Option 2's full reads, re-read only as K1/7739 consumers, not re-adjudicated. **0 candidates. 35 kills: 17 dedup + 18 self-disproved.** No verdict depended on execution (no NEEDS-POC items).

Note: no `isValidSignatureWithData` exists anywhere in `contracts/` — Nexus dispatch is `isValidSignature` only; K1 has `validateSignatureWithData`. The brief's naming was corrected against the code.

### Sharpest self-disproved leads (checked file:line counter-evidence)

1. **64-byte EIP-2098 `yParity=1` reverting on the 1271 path.** The trace is real, but the root is third-party base code, the failure is fail-closed (revert, not false acceptance), no 64-byte promise is documented, and the 65-byte form works. Killed on scope/impact, not execution.
2. **Empty-inner-sig + magic hash returning `0x77390001` via the normal path.** Distinct from the success magic; no consumer confusion established.
3. **`sender == msg.sender` safe-caller deviation.** Digests are already account-bound; no new principal.
4. **Safe-sender set soundness.** `_contains`/`_removeAll` verified correct.
5. **EIP-712 domain consistency** between Nexus, Solady, and the 7739 base. Verified, no mismatch.
6. **Dual-recovery and high-s malleability.** By design / no attacker gain (Solady `tryRecover` enforces low-s).
7. **Detection-loop DoS.** Owner-controlled validator list; no attacker principal.

### Dedup highlights (Option 4)

K1 `validateSignatureWithData` zero-owner 0==0 (EX-077/087/131/135 — the `#307` cluster; coordinator re-verified: `getOwner`'s zero-fallback protects the `validateUserOp`/`_erc1271IsValidSignatureNowCalldata` paths, leaving only the caller-supplied-owner `validateSignatureWithData` shape, which is exactly the claimed cluster); `validateUserOp` zero-owner bypass (EX-045, Zenith H-1 — fix verified present via the `getOwner` fallback); short-signature revert cluster (EX-078/088/128/132); detection no-try/catch (EX-069 / #321); default-validator unaddressable (EX-072 / #316); detection loop/default fixes verified present (EX-042/048); `transferOwnership` missing init check (EX-013); contract-owner brick (EX-I09 + lineage T2); registry use-time gap including all 7739 paths (EX-018/059 — O4 grep-verified no registry check exists on any validation/7739 path); `setRegistry` (EX-023 + Option 2 closest call); oracle confusion via the 1271 oracle (EX-073/074); H-B1 (EX-136, never re-reported). Full 35-kill ledger: `artifacts-o34/hunter-O4-coverage.txt`.

### Option 4 lineage tags (from STX-DIFF.md)

- `K1Validator.sol` → `K1MeeValidator.sol`: SUBSTANCE-CHANGED (EOA-only owner guard as a fix-signal; validation dispatch rewritten for MEE modes; plain-ECDSA core preserved via `EcdsaHelperLib` with the exact 1.2.1 dual-recover semantics; `validateSignatureWithData` length check `== 20` → `>= 20`). A finding in the preserved ECDSA core would survive to 1.3.3; a contract-owner finding would not (EOA-only guard upstream).
- `RegistryAdapter.sol`: NO COUNTERPART in 1.3.3 — the entire attestation mechanism is absent from deployed code. Any 1.2.1 registry finding is moot against 1.3.3.
- ERC-7739 detection internalized in the successor (T4). Detection-mechanism findings carry team-changed risk.

## Skeptic / Referee / Gate

With zero Hunter candidates in both domains, `skeptic.json` and `referee.json` are empty arrays per the skill contracts for empty input, and nothing reached the 7-Question Gate (`gate-7q.json` records that explicitly — the gate was not bypassed, it had no input). The pipeline's adversarial work in this run happened inside the Hunter phase (dedup kills + self-disproved leads with checked counter-evidence) and in the coordinator's independent verification of the closest calls and the transient-flag completeness table. No finding was softened, downgraded, or carried forward on a trace.

## Dedup summary

`exclusions/EXCLUSION_LIST.md`: **176 entries** (EX-001–EX-136 + EX-G01–G07 + EX-I01–I33), unchanged by this run (Step 0 found zero new issues):

- **68 security findings** across the 5 in-repo audit PDFs + 40 gas/info items = 108 PDF items (Option 1).
- **31 open issues** (17 baseline + 14 delta #325–#338, all bodies read in full); **30 closed issues** enumerated (Option 1); re-sweep 2026-11-14 03:19 UTC found zero new filings and zero status changes.
- **1 published advisory** (GHSA-q47q-h6x2-f5qg, fix verified present at HEAD); no second GHSA found.
- **5 Pashov stx-contracts (Nov 2025) issues** with per-issue applicability checks.
- **1 disproved candidate** (H-B1, EX-136).

**Most-collided-with exclusions on this run's surfaces:** EX-122/EX-126 (#325/#329 bootstrap init), EX-070 (#320 MetaFactory), EX-116 (GHSA), EX-136 (H-B1), EX-076 (#308 relay hash), EX-077/087/131/135 (#307 zero-owner cluster), EX-078/088/128/132 (short-signature revert cluster), EX-069 (#321 detection try/catch), EX-072 (#316 default validator), EX-045 (Zenith H-1), EX-018/059 (registry use-time gap).

## Lineage assessment (1.2.1 vs deployed 1.3.3)

From `STX-DIFF.md` (tree-to-tree diff, nexus `main` @ `9007ba1` vs stx `develop` @ `61001d0f`), for this run's files:

- **Team-changed (strong duplicate/fix signal):** registry removed entirely (all enforcement points + config surface; no `RegistryAdapter` counterpart); K1 successor EOA-only owner guard; K1 validation dispatch rewritten (MEE modes + cross-account-replay hashing; plain-ECDSA core preserved); ERC-7739 detection internalized; bootstrap registry config removed from all init flows; `BiconomyMetaFactory` / `K1ValidatorFactory` absent from 1.3.3.
- **Explicitly NOT team-changed (a finding here would survive to 1.3.3):** bootstrap install loops, zero-address skips, `ModuleInstalled` emits, `_withInitSentinelLists` placement; the single-use init flag (fixed independently in both repos on 2026-08-07); `NexusAccountFactory` logic; `NexusProxy` (cosmetic only); the plain-ECDSA dual-recover core.
- **Per-finding lineage:** N/A — zero findings. Had any survived, the lists above would have determined its lineage verdict.
- **CAVEAT (carried from Option 2):** the diff worker claimed `cast` selector/hash verification, but `cast` is NOT installed on this VM. All assembly/selector-equivalence claims in `STX-DIFF.md` therefore rest on manual review only, not tooling. No kill in this run depends on an equivalence claim. The coordinator's own selector/slot verification in this run used read-only ethers keccak computation, not `cast`.

## Coverage

- **Option 3: 7/7 files read in full** (849 lines). Evidence-only reads: `ProxyLib.sol`, `Nexus.sol` init paths, `LibPREP.sol` binding structure, `K1Validator.sol` (zero-owner check), sentinellist pinned source, `StaleInitFlagPoC` test (context).
- **Option 4: `K1Validator.sol` read in full** (280 lines, first time as a reporting target); `Nexus.sol` 7739 gap regions + `RegistryAdapter.sol` gap re-check as listed above; remainder of `Nexus.sol`/`ModuleManager.sol` relied on from Option 2. Evidence-only reads: pinned ERC-7739 base + upstream sample comparison, Solady ECDSA/EIP712, `EnumerableSet4337`, tests as context only.
- Out of scope and not read except as evidence: `contracts/modules/*` (except K1Validator), `contracts/mocks/*`, `test/*`, remaining libs. `LibPREP.sol` mining-argument soundness relied on from Option 1 Domain A verification rather than re-proved.
- Boundary-pair pass: not run as a separate phase — with zero candidates in both domains there were no cross-domain claims to adjudicate. The coordinator traced the init seam end-to-end during its own verification (factory → proxy ctor → flag → `initializeAccount` → bootstrap delegatecall) and found nothing beyond already-excluded mechanisms.
- Single pass. Complete-coverage looping was not ordered. **All four SCOPE.md options are now covered** (Options 1–4, 0 findings each); no SCOPE.md audit option remains unaudited as a standalone pass.

## Build verification

Not re-run this pass: no POCs were required with zero survivors, and the harness at `~/workspace/nexus-audit/poc/` was last re-verified green in the Option 2 run (2026-11-14 10:00 WIB): forge 1.5.1, solc 0.8.27, Prague, `forge test` 2/2 pass. It was deliberately not re-run here to avoid straining the shared VM while a concurrent audit runs. No finding POCs were built: with zero surviving findings, none were required. Hunter code traces were never presented as executed repros. (Skill §14 staleness note, repeated from Options 1–2: the vendored skills state Foundry is not installed; forge 1.5.1 IS installed at `~/.foundry/bin`.)

## Gaps and caveats (state plainly)

1. **1.2.1 vs deployed 1.3.3:** this repo is two minor versions behind the deployed Nexus (v1.3.3 from `bcnmy/stx-contracts`, MEE suite 2.2.3). Whether Biconomy pays for bugs present only in the 1.2.1-lineage `main` is **UNVERIFIED**. No finding in this audit claims deployed impact, and no deployed-bytecode verification was ordered or performed.
2. **#303 (EX-080):** a private security report sent Aug 2, 2026, contents UNKNOWN. It may cover this exact surface. No public dedup can rule out collision with it. Unretireable residual risk.
3. **Private duplicates unsearchable:** as with any bounty program, privately filed duplicates can never be fully excluded.
4. **Tracker velocity:** 14 issues filed in ~6.5 hours on 2026-11-13 (UTC); the Step 0 re-sweep is a snapshot at 2026-11-14 03:19 UTC. Issues filed after that moment, issue comments, and any post-crawl maintainer triage are NOT covered. **Re-sweep immediately before any filing.** Page-2/Closed-tab rendering limits (see Step 0) also stand.
5. **STX-DIFF equivalence caveat:** assembly/selector-equivalence claims rest on manual review only (`cast` not installed). Structural claims spot-verified; equivalence claims not executed. No kill in this run depends on one.
6. **External modules untraced:** session validators, policies, and executor modules live outside this repo. The "no limited-scope principal in-repo" threat model could not be traced further. A future audit with the session-module repos could revisit init/validation variants — but the claimed root causes (#310/#312, #307, #325) would still need genuinely distinct mechanisms to overcome dedup.
7. **LibPREP mining argument relied on, not re-proved:** the 2^160 search argument for PREP proof/target binding comes from Option 1 Domain A verification; O3 re-read the binding structure but did not independently re-prove the mining soundness. No candidate depends on it beyond the PREP-path completeness statement.
8. **OZ semantics cited, not re-read:** OZ ERC1967Utils `upgradeToAndCall` code-check and OZ ECDSA low-s enforcement were cited from OZ 5.x documented semantics; pinned OZ source was not re-read in this pass. Both kills stand on independent in-repo evidence.
9. **Single pass:** a second pass, a loop order, or a wider scope could find what this pass missed. This report describes this run only.

## Deliverables

- `REPORT-options34.md` (this file)
- `exclusions/EXCLUSION_LIST.md` (176 entries, unchanged) + `exclusions/NEW-ISSUES-2026-11-14-PM.md` (Step 0 re-sweep source)
- `artifacts-o34/` — `triage.json`, `retrieval-plan.json`, `recon.json`, `hunter-findings-O3.json` (`[]`), `hunter-findings-O4.json` (`[]`), `hunter-O3-coverage.txt`, `hunter-O4-coverage.txt`, `skeptic.json` (`[]`), `referee.json` (`[]`), `validated-findings.json`, `verification-report.json`, `gate-7q.json`, `coverage.json`, `scan-report.json` (all JSON artifacts validated: parse cleanly, required fields present, enums match the skill contracts)
- `poc/` — existing Foundry scratch project (BUILD_LOG.md with POC instructions; no new POCs — none required; build not re-run this pass, see Build verification)
- `findings/` — no subdirectories: zero surviving findings, so no finding write-ups or POCs exist. The disproved-candidate record lives in EX-136 and in Option 1's artifacts.

## Verification status

- Pinned HEAD `9007ba1…` verified matching and tree clean at dispatch, at each Hunter's conclusion, and before concluding (0 dirty files).
- All JSON artifacts validated (see Deliverables). Both Hunter coverage files confirm dedup-first reading (SCOPE.md §5, all 176 exclusions, REPORT-delta.md, REPORT-core.md, both delta files, STX-DIFF.md).
- Coordinator parent-verification performed: independent read-only ethers recomputation of the `NotInitializable()` selector (`0xaed59595`, MATCH) and the `INIT_SLOT` derivation (`0x90b772c2…829300`, MATCH); full re-reads of `Initializable.sol`, `NexusProxy.sol`, `Nexus.sol` init regions (PREP branch L110–135, `initializeAccount` L300–360); repo-wide grep confirming the single `setInitializable` call site and no other transient-storage use; re-reads of the K1Validator owner-fallback and dual-recovery code (`validateUserOp`, `getOwner`, `_validateSignatureForOwner`, `_erc1271IsValidSignatureNowCalldata`); STX-DIFF §§3/7/8/9 re-read for the lineage tags above.
- Nothing was filed; filing needs a separate user order (and there is nothing filing-ready to file).
