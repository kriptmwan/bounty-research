# Audit Report — HackenProof "Account Abstraction Bugs" (ERC-4337/7562)

## DECISION: NO FINDINGS — nothing to file

**0 confirmed findings. 0 filed, 0 to file.** Single-pass adversarial audit (Hunter → Skeptic → Referee) of the full in-scope surface at v0.9.0, with executed verification. Two candidates were raised and both adjudicated `NOT_A_BUG` (confirmed code quirks with no attacker-attainable impact). No 24-hour disclosure clock is running, because no vulnerability was discovered.

- Audit date: 2026-11-14 (WIB)
- Auditor: subagent, parent-verified pipeline (parent must still re-verify decisive claims before any future filing)
- Work dir: `~/workspace/hackenproof-aa-audit/`
- Precheck: `PRECHECK.md` (live program page re-read 2026-11-14)

## Verified program facts (live page, 2026-11-14)

- Program: https://hackenproof.com/programs/account-abstraction-bugs (Ethereum Foundation)
- Scope: ONLY `core` and `utils` folders of `eth-infinitism/account-abstraction`, plus protocol definitions. Attacks on any specific bundler, account, or paymaster are OUT.
- Eligible commits (verified byte-for-byte against git tags):
  - v0.9.0 `b36a1ed52ae00da6f8a4c8d50181e2877e4fa410`
  - v0.8.0 `4cbc06072cdc19fd60f285c5997f4f7f57a588de`
  - v0.7.0 `7af70c8993a6f42973f520ae0752386a5032abe7`
  - v0.6.0 `abff2aca61a8f0934e533d0d352978055fddbd96`
- Cost: FREE — no fee, credit, deposit, or purchase wording anywhere on the public program page.
- KYC: payout-only ("asked for extra KYC verification to proceed with payments"). Audit + submission need no KYC.
- Disclosure: report within **24 hours of discovery**, exclusively through hackenproof.com; no public disclosure without consent; first reporter wins.
- Severity (program's own): Critical = EntryPoint bugs causing major financial damage / redeployment; High = on-chain griefing/censorship; Medium = off-chain mempool DoS not solved by ERC-7562; Low = negligible damage/inconvenience.
- Reputation gate: nothing on the public page mentions one — UNVERIFIED (dashboard-gated).
- Caveat: the live submit form sits behind login at dashboard.hackenproof.com and could NOT be opened without creating an account (forbidden by the task order). Re-check the live form on filing day.

## Pins audited

- **Primary, read line-by-line: v0.9.0** (`b36a1ed5`), tree clean at conclusion. All 12 in-scope files, 2,423 lines: `EntryPoint.sol`, `EntryPointSimulations.sol`, `StakeManager.sol`, `NonceManager.sol`, `UserOperationLib.sol`, `Helpers.sol`, `SenderCreator.sol`, `BaseAccount.sol`, `BasePaymaster.sol`, `Eip7702Support.sol`, `Stakeable.sol`, `utils/Exec.sol`.
- v0.6–v0.8 pins: verified to exist with the exact program SHAs, but NOT line-read. No surviving finding required cross-version checking. A bug present only in older pins would not have been caught — stated honestly.

## Dedup list (built before hunting; any match kills the candidate)

Four audit reports, all extracted to `evidence/audits/`:

1. **Cantina v0.9 Security Review** (post-tag commit `1c6b669`): 2 Low — (3.1.1) paymaster `validatePaymasterUserOp` result insufficiently checked (fixed in `8bc437da`); (3.1.2) can't specify `validAfterBlock == 0` — + 1 Informational. No Critical/High/Medium.
2. **SpearBit Mar 2025**: 1 Medium — 5.1.1 BLOBHASH/BLOBBASEFEE mass-invalidation (spec-level, ERC-7562); 15 Low (5.2.1 wrong opIndex in aggregated validation-data check — fixed; 5.2.2 `outOfTimeRange` validAfter edge; 5.2.11 unenforced paymasterVerificationGasLimit maximum; 5.2.15 `initEip7702Sender` gas accounting; rest spec/doc/reputation items); 6 gas, 74 informational. No Critical/High.
3. **2024 incremental audit**: 5 Medium (M-01 paymaster throttling, M-02 unused-gas penalty, M-03 unattributable paymaster fault, M-04/M-05 samples/spec), 8 Low. No Critical/High. All resolved.
4. **2023 incremental audit**: 1 High (H-01 invalid aggregate signature, samples-only, resolved), 12 Low. No Critical.

Net: this codebase has been reviewed by four professional audits plus years of production use with zero surviving Critical/High in the core. Duplicate risk was extreme, as expected.

## Adjudicated candidates (both NOT_A_BUG)

### BUG-1 — AA35 size-check overflow on crafted paymaster returndata (Low, NOT_A_BUG)

- **Code fact (confirmed by execution):** `_callValidatePaymasterUserOp` computes `expectedReturnDataSize = 96 + ((contextLength + 31) / 32) * 32` inside `unchecked`. A paymaster returning hand-crafted returndata with `contextLength = 2**256-1` and length 96 wraps the expected size to 96, so the AA35 check passes. Executed test (`poc-harness/test/H8Overflow.t.sol`): `simulateValidation` reverted with an **empty reason after ~1.06B gas (OOG), not AA35** — proving the check passed and failure occurred later during context encoding.
- **Why not a bug:** the crafted returndata can only come from the paymaster named in the op itself; every bundler simulates via `simulateValidation` (same code path) before building a bundle, and simulation fails identically, so the op is dropped and never reaches `handleOps`. An on-chain attempt would revert atomically (OOG rolls back the deposit decrement). No victim, no fund movement, no cross-party harm.
- **Suggested fix (observation only):** compute the expected size with checked arithmetic, or reject `contextLength` values that cannot fit in the actual returndata before comparing.

### BUG-2 — Hardcoded opIndex 0 in `initEip7702Sender` revert (Low, NOT_A_BUG)

- **Code fact (source literal):** `SenderCreator.initEip7702Sender` reverts `FailedOpWithRevert(0, "AA13 EIP7702 sender init failed", ...)` unconditionally. In a multi-op bundle, an EIP-7702 init failure is attributed to op 0. (Different function from SpearBit 5.2.1's fixed instance — not a duplicate of it.)
- **Why not a bug:** the revert aborts the entire bundle transaction regardless of the index; no wrong op is executed, charged, or censored. The index is a bundler-diagnostic hint only. Impact is log confusion in one narrow case.
- **Suggested fix (observation only):** thread the real `opIndex` through to `SenderCreator`, or return a boolean and let `_createSenderIfNeeded` raise the error.

## Killed leads (hunter-phase, never reached findings)

- **K-1 — Uninitialized `context` bytes for paymaster-less ops (H81).** Feared the `contextOffset`/`_getMemoryBytesFromOffset` pattern with an unassigned `bytes memory context` would read a garbage length from scratch memory (last validationData) and OOG bundles. **Killed by execution:** 4/4 Foundry tests pass with production-matching compiler settings (solc 0.8.28, `via_ir`, optimizer runs 1M) — zero and time-range validationData, single and 2-op bundles, both orderings. Evidence: `poc-harness/test/ContextOffset.t.sol`.
- **K-2 — Paymaster-signature hash collisions.** Two different `paymasterAndData` values can share a `userOpHash` when only the paymaster signature differs. By design and documented: the paymaster signature is explicitly excluded from the hash; the paymaster validates its own signature. Not a defect.
- **K-3 — Unbounded gas in `aggregator.validateSignatures`.** `handleAggregatedOps` calls it with no explicit gas cap; a malicious aggregator could burn bundle gas. No code defect: the trust model is staking + ERC-7562 reputation, and bundlers verify aggregated signatures off-chain. No bundler-behavior evidence gathered; protocol-design territory, fails Q6. Not filed.
- **K-4 — Malformed paymaster data aborts the whole bundle.** `getPaymasterSignatureLength` reverts (`InvalidPaymasterSignatureLength`) from `getUserOpHash` during validation, and EIP-7702 delegate errors revert raw (not `FailedOp`). Both fail identically in simulation, so bundlers drop the op; the High tier requires passing simulation but reverting on-chain. Fail-closed, no finding.
- **K-5 — Prefund-too-low charges the full prefund on an unexecuted op.** Documented mechanics: `preVerificationGas` exists to cover EntryPoint overhead; underestimation is the bundler/user's fault, and the outcome (full prefund kept, op rolled back) is the specified behavior. Audited and accepted.
- **K-6 — `SenderCreator.createSender` doesn't check returndata size.** Any garbage result is caught by the AA13/AA14/AA15 checks in `_createSenderIfNeeded` (nonzero, equals sender, has code). Harmless.
- **K-7 — `simulateHandleOp` callable on-chain without `_compensate`.** `EntryPointSimulations` is documented never to be deployed on-chain (eth_call-only tooling); the canonical EntryPoint lacks it. Calling it on-chain only harms the caller (uncompensated gas, surplus stays locked in EntryPoint). Not a defect in the deployed target.
- **K-8 — Nonce sequence `uint64` wrap / deposit `unchecked` overflow / `_getUnusedGasPenalty` overflow.** All require ~2^64 operations or ~2^256 ETH — physically unreachable. Accepted bounds.
- **K-9 — `nonReentrant` blocks 7702-delegated EOAs from calling `handleOps`.** Intended anti-reentrancy design (bundlers use plain EOAs). Not a defect.
- **K-10 — Block-range flag requires BOTH flags; mixed flags always expire.** Fail-closed documented behavior. Not a defect.

## 7-Question Gate

Not run — no Referee-confirmed finding exists to gate. Both candidates failed at the Referee stage on impact (Q1/Q6), before any report drafting.

## Coverage gaps (honest)

1. **v0.6–v0.8 pins not line-read** (see Pins audited). A version-specific bug in older pins is not excluded.
2. **Protocol-spec review not done.** The program also lists Protocol targets (ERC-4337/7562 definitions); this was a code-only pass. Spec-level issues (like SpearBit 5.1.1) were not hunted.
3. **No fuzzing / invariant testing.** Not ordered, not run. A fuzzing pass over gas accounting and the paymaster returndata parser is the highest-value follow-up if the user orders a second pass.
4. **Interfaces read only as evidence.** The literal scope is `core` + `utils`; interface files were not audited as targets.
5. **Submit-form gates unverified** (login-gated; see precheck caveat).

## Verification evidence

- Harness: `poc-harness/` (Foundry 1.5.1, solc 0.8.28, `via_ir = true`, optimizer runs 1,000,000, EVM Cancun — matching the project's Hardhat settings). Compiles the pinned checkout in place via remapping + `allow_paths`; target code never copied or modified.
- `poc-harness/test/ContextOffset.t.sol`: 4/4 PASS.
- `poc-harness/test/H8Overflow.t.sol`: 1/1 PASS (revert-with-OOG observed, AA35 absent).
- `poc/` is intentionally empty: no finding PoCs exist because there are no findings. The harness tests above are verification evidence, not finding proofs.
- Toolchain note: `cast` IS installed at `~/.foundry/bin/cast` v1.5.1 (the "cast is NOT installed" note in older skill text is stale — PATH-only check). Not needed for this audit.

## Artifacts

`triage.json`, `recon.json`, `hunter-findings.json`, `skeptic.json`, `referee.json`, `verification-report.json`, `coverage.json`, `scan-report.json`, `PRECHECK.md`, `evidence/audits/` (4 audit reports as text). All JSON artifacts validated (parse + bug-ID coverage).

## Recommendation

Close this track unless the user orders a second pass. The highest-value next steps, in order, would be: (1) a fuzzing/invariant pass over gas accounting + paymaster returndata parsing at v0.9.0; (2) a line-read of the v0.6–v0.8 pins for version-specific issues; (3) a protocol-spec review of ERC-7562 rules. None is authorized by the current order.
