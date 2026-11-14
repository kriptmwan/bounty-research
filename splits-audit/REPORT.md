# Splits Contracts Monorepo — Bug Bounty Audit Report

**DECISION: BLOCK — zero filing-ready findings. Nothing to submit to security@splits.org.**

Single-pass adversarial audit (Hunter → Skeptic → Referee) of all 43 `src` Solidity files. 7 candidates were raised and all 7 were killed with checked counter-evidence: 1 is a duplicate of an audit-covered, acknowledged issue; 2 are accounting-bounded reentrancy leads that self-revert; 4 are documented/owner-gated/trusted-model behaviors. No critical or high severity bug causing draining or freezing of user funds was found in deployed production contracts. This is a negative result, stated plainly — not a claim that the code is bug-free.

- **Run date:** 2026-11-14 (WIB). Audit + proofs only; nothing was filed, submitted, or emailed.
- **Repo:** `github.com/0xSplits/splits-contracts-monorepo`, cloned fresh under `~/workspace/splits-audit/repos/`.
- **HEAD pin:** `23e9ef64c918205214fc23b2ff89fa590a32efc2` (2026-11-12, "PE-9598: Pin GitHub Actions to commit SHAs (#91)"). Tree verified clean at dispatch and before concluding; no source mutation.
- **Method:** `adversarial_code_audit` pipeline + `triage_validation` 7-Question Gate + `web3_audit` bug classes. Artifacts: `triage.json`, `retrieval-plan.json`, `recon.json`, `hunter-findings.json`, `skeptic.json`, `referee.json`, `verification-report.json`, `scan-report.json` (all in `~/workspace/splits-audit/`).

## Scope and deployed production contracts

Program scope (SECURITY.md, re-read at HEAD): critical/high bugs causing **draining** of user funds (eligibility also covers loss **or freeze**) in deployed production contracts of the monorepo `src`. Out: test/script dirs, testnets, third-party contracts, previously reported issues, and anything contingent on frontend bugs, DDoS, phishing, key leaks, or third-party compromise. Findings must be **distinct from issues covered in previous audits**.

Mainnet (chain 1) deployments from `packages/*/deployments/1.json`, all verified on Sourcify v2 on 2026-11-14:

| Contract | Address | Sourcify |
|---|---|---|
| SplitsWarehouse | `0x8fb66F38cF86A3d5e8768f8F1754A24A6c661Fb8` | exact_match |
| PullSplitFactoryV2.2 | `0x6B9118074aB15142d7524E8c4ea8f62A3Bdb98f1` | exact_match |
| PushSplitFactoryV2.2 | `0x8E8eB0cC6AE34A38B67D5Cf91ACa38f60bc3Ecf4` | match |
| SmartVaultFactory | `0x8E6Af8Ed94E87B4402D0272C5D6b0D47F0483e7C` | exact_match |
| AutoEarnModuleV2 (AutoEarnModule code) | `0x2E59620f3521E52aC6CBa4EFd556e6C750b35C9a` | match |
| AutoEarnEnrollerModule | `0xB574ECA4Bb912B5d71E6B1f90950225908E27201` | match |

Live parameter check (read-only `eth_call`, 2026-11-14): AutoEarnModuleV2 `ASSET()` = USDC `0xA0b86991…`, `VAULT()` = `0xF5730f6f…` (`name()` = "Splits Earn USDC"); enroller `AUTO_EARN_MODULE()` points at AutoEarnModuleV2. The Earn vault is **not** in this monorepo and is Sourcify-unverified — treated as a third-party boundary (see Coverage gaps).

Code-movement check: `git diff` of splits-v2 `src` from V2.2 (#65) to HEAD is **formatting-only** (forge fmt #76), and smart-vaults `src` from the second-audit commit (`dbc09cd`) to HEAD is **formatting-only**. Deployed logic == audited logic for those two packages. `smart-vault-modules` is entirely new (Mar–Sep 2026) and unaudited — it was prioritized first.

## Prior-audit dedup list (exclusion list — any overlap kills the candidate)

1. **splits-v2.md — Zach Obront, Feb 2023** (audit commit `9dde20f`, fixes reviewed to `740abb4`): H-01 warehouse-incentive drain via redeposit loop (fixed by push/pull split; **pull-split exception acknowledged**); H-02 ownership spoof via `execCalls()` (fixed, per-iteration check); M-01 too many recipients → locked funds (acknowledged); M-02 rounding lets majority shareholders steal (acknowledged); L-01 allocation overflow in `getDistributions()` (acknowledged); L-02 precise pull distribution front-run DoS (fixed/acknowledged); L-03 `OwnershipTransferred` wrong data via `execCalls()` (fixed); G-01 leave-1 accounting (fixed).
2. **smartVaults-first.pdf — Riley Holterhus, Sep 2024** (commit `1db8acb`): Low 3.1.1 last-signer gas trust assumptions (addressed, PR 43, except maxFeePerGas by agreement); Low 3.1.2 signature padding (partially mitigated, PR 43); Low 3.1.3 `bytes32(0)` light merkle root (addressed, PR 47); Info 3.2.1 empty signers (fixed, PR 45); Info 3.2.2 `validateUserOp` revert-vs-fail (addressed, PR 46); Info 3.2.3 owner recovery invariants (informational, design blessed); Info 3.2.4 WebAuthn deferred return (addressed, PR 50).
3. **smartVaults-second.pdf — MiloTruck, Oct 2025** (commit `dbc09cd`): Low 4.1.1 `msg.value` not forwarded to fallback managers (acknowledged); Low 4.1.2 ERC1271 name/version > 32 bytes (acknowledged); Info 4.2.1 implicit `signatures.length == threshold` assumption (acknowledged); Info 4.2.2 duplicate signers with invalid signatures (acknowledged, gas-estimation rationale).

## Findings: none survive

| ID | Title | Hunter severity | Referee verdict | Disposition |
|---|---|---|---|---|
| HUNT-1 | PullSplit warehouse-incentive drain loop | High | NOT_A_BUG (conf 92) | **Duplicate of audit H-01 acknowledged exception.** Mechanism is real in current code, but the program requires distinctness from audit-covered issues. Fails 7Q Q5. |
| HUNT-2 | PushSplit ETH distribute reentrancy via distributor reward | Medium | NOT_A_BUG (conf 88) | Accounting-bounded: fresh balance snapshots per call + full-amount payout mean any reentrant overdraft reverts the whole tx. Gain bounded by dust + 1-wei leftovers. Team documents the unwind behavior. |
| HUNT-3 | PushSplit ERC20 distribute reentrancy via hook tokens | Medium | NOT_A_BUG (conf 86) | Same bound as HUNT-2; hook/fee-on-transfer tokens are outside the documented supported set. |
| HUNT-4 | Duplicate signer values defeat m-of-n threshold | Medium | NOT_A_BUG (conf 90) | Requires owner/self authorization to configure; owner is root by documented design. Fails 7Q Q4. Hardening suggestion only. |
| HUNT-5 | Ownerless vault: module self-call upgrade | Low | NOT_A_BUG (conf 88) | Modules are fully trusted and can already drain all funds directly; deployed modules cannot construct an upgrade call. No new impact. |
| HUNT-6 | `batchDeposit` mint-before-pull insolvency (FoT) | Low | NOT_A_BUG (conf 94) | Explicitly documented unsupported behavior with the exact consequence described. Fails 7Q Q5. |
| HUNT-7 | AutoEarnModule permissionless full-balance sweep | Low | NOT_A_BUG (conf 92) | The module's stated purpose; owner-enabled; shares stay with the account and are owner-redeemable. No theft, no freeze. |

### HUNT-1 detail (the only High-severity mechanism found — killed on dedup, not on mechanics)

`SplitsWarehouse.withdraw(owner, tokens, amounts, withdrawer)` (batch, `SplitsWarehouse.sol:226-250`) pays `config.incentive` to a caller-chosen withdrawer and reverts only when paused; `PullSplit.depositToWarehouse` (`PullSplit.sol:105-107`) is public/permissionless. If a PullSplit owner sets a withdrawal incentive and leaves withdrawals unpaused, anyone can cycle withdraw → redeposit, skimming the incentive each round until the split is drained. This is **exactly** the exception documented in the H-01 review paragraph of `audits/splits-v2.md` ("This situation is Acknowledged by the Splits team. They will add warnings to the docs and UI"). Per SECURITY.md eligibility ("distinct from the issues covered in the previous audits"), it is not fileable. No new causal element beyond H-01 was found. 7Q gate: Q1 pass (mechanism real), Q5 **fail** (audit-covered) → killed.

### Checked and cleared without Hunter findings

- **H-02 fix holds:** `Wallet.execCalls` re-checks `caller != owner` on every iteration; single-call spoof chains fail because callbacks cannot pass `onlyOwner`/`execCalls` guards as a non-owner.
- **ERC6909X permits:** EIP-712 domain binds chain + contract; nonces burn only on success (revert rolls back); temporary grants restore prior allowance/operator state after the callback; operator grants require id/amount zero.
- **SmartVault validation:** light-hash gas bounds enforced when >1 signature; merkle paths verified for both trees when threshold > 1; empty signers revert (`InvalidSigner`); duplicate indices revert; `threshold - 1` loop cannot underflow on initialized vaults (threshold ≥ 1 enforced).
- **Factories/clones:** CREATE2 salts commit to params + owner (+ salt/nonce); `initialize` is factory-only and unreachable twice; implementation contracts stay uninitialized and inert (owner 0, no modules/handlers, no reachable self-call).
- **Enroller:** calls fixed calldata to fixed targets; arbitrary `account_`/`treasury_` inputs cannot make the treasury do anything beyond one `enableModule` call on the named account; no enroller state, so reentrancy through `owner()`/`isModuleEnabled()` is harmless.
- **No `delegatecall` to user input, no `selfdestruct`** in any `src` file; `tx.origin` appears only in the two analyzed pause-bypass checks, neither of which can redirect funds (single-token withdraw always pays the owner; batch withdraw has no bypass).
- **WebAuthn:** standard Coinbase/Daimo fork with malleability guard, type/challenge/UP-flag checks, RIP-7212 precompile with FCL fallback; missing rpIdHash/origin checks are documented authenticator-trust assumptions. The `0x100` precompile-trust concern was considered and dropped: no evidence of a hostile contract at `0x100` on any deployment chain, and the fallback path is sound.

## Coverage notes and gaps (honest limits)

- **Coverage:** all 43 `src/*.sol` files across the 3 packages read in full, in risk order; all 3 prior audit reports read in full; post-audit diffs reviewed; 6 mainnet deployments verified on Sourcify; live module parameters read on-chain. `test/` and `script/` excluded per program scope (read only as context where needed).
- **No Foundry execution:** the repo has no `node_modules/` or `lib/` on this VM and no pnpm; dependencies were unavailable offline, so no `forge build` and no PoC runs were attempted. Zero findings survived, so no PoC was required by the task; all kills rest on checked file:line counter-evidence plus audit/doc citations. If the parent wants an executed negative proof for HUNT-2 (reentrancy bound), it needs a toolchain setup first.
- **Earn vault boundary:** the live `VAULT()` (`0xF5730f6f…`, "Splits Earn USDC") is outside this monorepo and unverified; its code was not audited. Module analysis assumes standard ERC4626 behavior. A vault-side bug would be a different target, not a monorepo finding.
- **Single-pass:** this was one pass, not a loop. Fuzzing/invariant testing and a second pass were not run. The codebase is small (~4,300 src lines), heavily audited, and post-audit movement is formatting-only except for the new modules package, which received the deepest review.
- **Toolchain note:** `cast` 1.5.1 **is** installed and working on this VM (`~/.foundry/bin/cast`), contrary to the stale brief note; it was used for read-only calls only. `forge` 1.5.1 present but not run (see above).

## Observations (non-findings, no action needed)

1. **Owner supremacy (SmartVault):** the vault `owner` can `execute`/`executeBatch` and upgrade without threshold signatures. Documented recovery design (first audit 3.2.3); users who assume m-of-n always gates execution would be surprised, but this is intended.
2. **Duplicate-signer hardening:** `initializeSigners`/`addSigner` could reject duplicate signer values; currently only duplicate indices are rejected. Owner-gated, so not a vulnerability.
3. **`PushSplit.withdrawFromWarehouse` is not `pausable`** while `PullSplit.depositToWarehouse` is. Harmless (funds move between the split's own accounts), but asymmetric.
4. **Module trust:** any enabled module can self-call `enableModule`/`disableModule`/signer management via `executeFromModule`. Consistent with the documented "careful when adding a module" model; the deployed modules are minimal and fixed.

## PoCs

None. Zero surviving findings → zero PoC dirs (task requires runnable PoCs only for survivors). `~/workspace/splits-audit/poc/` is intentionally empty.
