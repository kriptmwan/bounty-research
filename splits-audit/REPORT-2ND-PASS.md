# Splits Contracts Monorepo — Second-Pass Audit Report (executed proofs + fuzzing)

**DECISION: BLOCK — zero filing-ready findings. Nothing to submit to security@splits.org.**

Second pass ordered 2026-11-14 ("Cari repo nya bro. Impprove") after pass 1 finished
with 0 findings. This pass adds what pass 1 could not do: a working Foundry toolchain,
executed negative proofs for HUNT-2/HUNT-3, bounded fuzz/invariant testing, a fresh
Hunter → Skeptic → Referee sweep over all 43 `src` files, and identification of the live
Earn vault. Pass 1's report (`REPORT.md`) is untouched; this file stands alongside it.

- Repo: `github.com/0xSplits/splits-contracts-monorepo`, HEAD pin
  `23e9ef64c918205214fc23b2ff89fa590a32efc2` (verified at start and end; tree clean,
  no source mutation, target code never copied or modified).
- Scope: critical/high draining/freezing in DEPLOYED production contracts only;
  findings must be DISTINCT from the 3 prior audits (see Dedup map below).
- No filing, no email, no contact with anyone. All execution is local Foundry; the only
  live queries are read-only `eth_call`/view calls and public verification APIs.

## Result summary

| Area | Outcome |
|---|---|
| HUNT-2 (PushSplit ETH reentrancy) | Kill CONFIRMED by execution — 2/2 PASS |
| HUNT-3 (ERC20/hook-token reentrancy) | Kill CONFIRMED by execution — 2/2 PASS |
| Warehouse invariant fuzz | 3/3 PASS, 64 runs x 32 depth, 2,048 calls each, 0 violations |
| Distribution-math fuzz | 5/5 PASS, 256 runs each, exact allocation + conservation |
| Modules invariant fuzz | 4/4 PASS, 64 runs x 32 depth, 0 violations |
| Modules edge tests | 12/12 PASS |
| Warehouse reentrancy proof (H2-15) | 2/2 PASS — reentrant gain == sequential gain |
| Fresh sweep | 15 candidates (H2-1..H2-15), all Referee NOT_A_BUG |
| Earn vault | IDENTIFIED: Morpho VaultV2, verified source on Blockscout, not a proxy |
| **Filing-ready findings** | **0 (Critical 0, High 0, Medium 0, Low 0)** |

Total executed: 31 Foundry tests, 0 failures.

## 1. Toolchain setup record

Pass 1 could not execute anything (no `node_modules`/`lib`/pnpm on the VM). This pass
built two Foundry harnesses following the proven pattern from
`~/workspace/hackenproof-aa-audit/poc-harness/` (remappings + `allow_paths`, pinned
checkout compiled in place).

- Foundry 1.5.1 at `~/.foundry/bin/` (forge/cast/anvil/chisel; NOT on default PATH —
  prepend it). solc 0.8.23 (from `~/.local/share/svm/`), optimizer 5,000,000 runs,
  EVM Shanghai — matching the packages' `foundry.toml` settings.
- `harness-2nd-pass/splits-v2/`: remappings `splits-v2/` → pinned checkout `src`,
  `@openzeppelin/contracts/` → OZ 4.9.5, `solady/` → solady 0.0.156, `forge-std/` →
  forge-std. Libs cloned via `git clone --depth 1` into `harness-2nd-pass/lib/`:
  openzeppelin-contracts-4 @ tag v4.9.5 (`bd325d56`), solady @ tag v0.0.156 (`b3d4ad97`),
  forge-std @ master `15b2df9` (same commit as the hackenproof harness copy; NOT the
  pnpm-locked `0844d7e` — recorded, acceptable for test-only code). Full target source
  compiles (75 files). Smoke test deploys `SplitsWarehouse` and references all split
  contracts/factories.
- `harness-2nd-pass/modules/`: the `smart-vault-modules` package has NO external deps
  (only local `src/interfaces/*` imports), so its harness needs only the `src/` remapping
  + forge-std. Quirk found: a `src/` remapping collides with a harness-owned `src/`
  directory, so the placeholder lives in `contracts/` instead.
- NOT built: a smart-vaults harness (needs OZ 5.x @`5705e82`, account-abstraction
  v0.7.0, web-authn, FreshCryptoLib). Not needed — no survivor required executing
  vault code, and the modules harness covers the unaudited package with a faithful
  MockVault. See Coverage gaps.
- pnpm/npm install was never attempted (registry fetches truncate at 1 MiB on this VM;
  the harness pattern worked, so no fallback was needed). Nothing was installed
  system-wide; no `pnpm`, no Go toolchain on the VM.

Re-run (serialized; the VM has ~1.5 shared CPUs):

```bash
export PATH="$HOME/.foundry/bin:$PATH"
cd ~/workspace/splits-audit/harness-2nd-pass/splits-v2 && forge test --fuzz-runs 256
cd ~/workspace/splits-audit/harness-2nd-pass/modules && forge test --fuzz-runs 256
```

## 2. Executed negative proofs (Step 2)

### HUNT-2 — PushSplit ETH distribute reentrancy: KILL CONFIRMED

`Hunt2Reentrancy.t.sol`, 2/2 PASS. 100 ETH fund, 50/50 split (EOA + ETH-rejecting
contract), 6.5% incentive, attacker reenters 5x via `receive()`:

- Reentrant attacker gain EXACTLY equals the sequential baseline gain
  (6.499999999999999999 ETH each); Alice's gain identical; rejector warehouse balances
  identical; conservation holds exactly; leftover <= 10 wei. Reentrancy grants zero
  advantage over the permissionless sequential path.
- A reentrant 5-arg distribute of 1000 ETH reverts the ENTIRE tx; all balances unchanged.

### HUNT-3 — ERC20/hook-token variant: KILL CONFIRMED

`Hunt3HookToken.t.sol`, 2/2 PASS, with a custom ERC20 carrying an ERC777-style
post-transfer hook (balances update before the hook fires):

- Hook attacker gain exactly equals sequential gain (6.499999999999999999 ETH);
  conservation holds.
- Mid-loop hook reentry (attacker first recipient, hook depletes funds owed to BOB)
  reverts the whole tx; state unchanged.

No execution result contradicted the pass-1 kills. No 7-Question Gate was needed
because no live candidate emerged from Step 2.

## 3. Fuzzing / invariants (Step 3)

All runs serialized on the VM. Invariant config lives in each harness `foundry.toml`
(forge 1.5.1 has no `--invariant-runs` CLI flag): `runs = 64, depth = 32,
fail_on_revert = true`. Fuzz runs 256 (`--fuzz-runs 256`).

### (a) SplitsWarehouse accounting — 3/3 PASS, 0 violations

`WarehouseInvariant.t.sol`: handler with deposit, batchDeposit, withdrawSingle
(as-owner/as-third-party), withdrawBatch, setConfig, transfer6909, batchTransfer6909,
approveAndTransferFrom (all try/catch with ghost accounting; ERC6909 has no
`totalSupply`, hence ghost supply tracking). Invariants: accounting identity (sum of
actor balances == ghost expected supply per token id), solvency (warehouse token
balance >= expected supply), no phantom balances. Handler asserts leave-1 and exact
incentive payouts inline. 2,048 calls per invariant, 0 escaping reverts.

`WarehouseReentrancy.t.sol` (added for sweep candidate H2-15), 2/2 PASS: reentrant
batch withdrawer gains exactly the sequential gain; reentrant single-withdraw pays
exactly fund-1 with 1 wei left. CEI burn-before-send bounds all payouts.

### (b) smart-vault-modules (unaudited, deepest-review target) — 4/4 + 12/12 PASS

`ModulesInvariant.t.sol` with a faithful `MockVault` (onlyModule `executeFromModule`,
only-self enable/disable, only-owner-or-entrypoint `execute`), a standard mock ERC4626
(1:1 + yield accrual), and a plain mock ERC20. Topology: treasury (owner = test) owns
a sub-account; an outsider vault is not treasury-owned. 4 invariants hold over 64x32:
asset conservation, zero leftover allowance after every deposit, outsider never
enrolled, shares fully backed. Handler asserts exact share minting at the current
exchange rate and enroll success/revert legitimacy on every action.

`ModulesEdge.t.sol`, 12/12 PASS: treasury self-enroll, sub-account enroll, outsider
revert (`NotOwnedByTreasury`), undeployed account/treasury reverts, already-enabled
no-op succeeding even with the enroller disabled, fresh enroll reverting when the
enroller is disabled, deposit reverting when the module is disabled, zero-balance
no-op, full-balance sweep by an arbitrary caller, post-yield crediting at the current
rate (100 + 50 shares for 200 assets after 100% yield), zero-address constructor
reverts.

Observation (not a finding): a deposit whose amount rounds to 0 shares against a
yield-heavy vault mints 0 shares — standard ERC4626 rounding in the vault, not a
module defect. The live vault (Morpho VaultV2, 1e12 virtual shares) further mitigates
this. The invariant asserts exact `convertToShares` instead of strictly-positive
minting.

### (c) Split distribution math — 5/5 PASS, 0 violations

`DistributionFuzz.t.sol`, 256 runs each: Push/ETH, Push/ERC20, Pull/ETH with random
recipient counts (1-5), allocations, incentives (0-6.5%), split funds and warehouse
seeds (0-1000 ether). Every run asserts EXACT per-recipient amounts, EXACT distributor
reward, and conservation (gains + leftover == funded). Plus: 5-arg over-amount reverts
when the excess exceeds rounding dust (see H2-11), and extreme allocations
(`type(uint256).max`) revert fail-closed (see H2-12 / prior audit L-01).

Two test bugs were found and fixed during this pass (both in test code, neither in
target code): `vm.expectRevert()` being consumed by an intervening `NATIVE_TOKEN()`
staticcall in call arguments (hoist the value first), and a batch-payout assertion
that forgot withdrawer == owner receives amount - reward + reward. Both are documented
in test comments.

## 4. Fresh Hunter sweep (Step 4)

All 43 `src` files re-read line by line (splits-v2, smart-vaults, smart-vault-modules).
15 candidates raised; all 15 Referee NOT_A_BUG. Artifacts:
`triage-2nd-pass.json`, `recon-2nd-pass.json`, `hunter-findings-2nd-pass.json`,
`skeptic-2nd-pass.json`, `referee-2nd-pass.json`, `verification-report-2nd-pass.json`,
`scan-report-2nd-pass.json` (pass-1 files untouched).

| ID | Candidate | Verdict | Kill ground |
|---|---|---|---|
| H2-1 | Factory stuck ETH on already-deployed createAccount | NOT_A_BUG | Solady source: value forwarded to instance (LibClone.sol:754-759) |
| H2-2 | Last-signer unbounded maxFeePerGas | NOT_A_BUG | Duplicate of prior audit 3.1.1 (accepted) |
| H2-3 | Extra signatures ignored (length != threshold) | NOT_A_BUG | Duplicate of prior audit 4.2.1 |
| H2-4 | Duplicate signer values defeat m-of-n | NOT_A_BUG | Owner-gated config (HUNT-4 repeat) |
| H2-5 | Module escalation to signer management | NOT_A_BUG | Modules fully trusted (HUNT-5 repeat) |
| H2-6 | Owner bypasses m-of-n via execute | NOT_A_BUG | Documented recovery design (3.2.3) |
| H2-7 | tx.origin pause bypass → incentive | NOT_A_BUG | Documented pattern; capped; needs owner interaction |
| H2-8 | 256th signer unreachable (uint8) | NOT_A_BUG | No funds impact; below scope |
| H2-9 | Uninitialized proxy threshold-0 panic | NOT_A_BUG | Unreachable via factory; fail-closed |
| H2-10 | Nonce burned on failed signature | NOT_A_BUG | Unordered nonces; harmless |
| H2-11 | Sub-dust over-amount succeeds | NOT_A_BUG | Rounding-bounded; cosmetic event; fuzz-proven |
| H2-12 | Extreme allocations overflow revert | NOT_A_BUG | Duplicate of prior audit L-01; fail-closed |
| H2-13 | Enroller trusts owner() claims | NOT_A_BUG | Documented caveat; value-0; no funds at risk |
| H2-14 | WebAuthn no origin/rpIdHash check | NOT_A_BUG | Documented design; challenge-bound |
| H2-15 | Warehouse reentrancy multiplies payouts | NOT_A_BUG | Executed proof: gain == sequential (CEI) |

Kill breakdown: 3 dedup (prior audit), 1 dependency source, 4 documented behavior,
2 execution, 2 owner-gated/trusted, 3 unreachable-or-no-impact. No survivor reached the
7-Question Gate because none passed Skeptic.

### Dedup map (verified from the audit files in `audits/`)

- `splits-v2.md` (Zach Obront, Feb 2023): H-01 warehouse-incentive drain (acknowledged
  exception), H-02 execCalls ownership spoof (fixed by per-iteration check, verified
  in `Wallet.sol`), M-01 too many recipients, M-02 rounding theft, L-01 unbounded
  allocation overflow, L-02 pull-distribution frontrun DoS, L-03 event data, G-01
  balance-of-1 accounting.
- `smartVaults-first.pdf` (Holterhus, Sep 2024): 3.1.1 last-signer trust (incl.
  accepted maxFeePerGas decision), 3.1.2 signature padding, 3.1.3 bytes32(0) merkle
  root, 3.2.1 empty signers, 3.2.2 validateUserOp reverts, 3.2.3 owner recovery,
  3.2.4 WebAuthn deferred return.
- `smartVaults-second.pdf` (MiloTruck, Oct 2025): 4.1.1 msg.value to fallback
  handlers, 4.1.2 ERC1271 name/version length, 4.2.1 signatures.length assumption,
  4.2.2 duplicate signers with invalid signatures.

## 5. Earn vault identification (Step 5, report-only)

The live vault behind `AutoEarnModuleV2.VAULT()` is:

- **Address:** `0xF5730f6F5bcc2a3E98dA199F40b1A8aF1Ac37A43` (confirmed by on-chain
  `VAULT()` call, 2026-11-14)
- **Identity:** **Morpho VaultV2** — Blockscout-verified source, header
  `Copyright (c) 2025 Morpho Association`, GPL-2.0, `pragma solidity 0.8.28`,
  optimizer 100,000 runs, EVM Cancun. Repo lineage: morpho-org/morpho-vaults-v2
  (`VaultV2.sol`). Source IS findable (45,692 bytes on Blockscout).
- **Proxy?** No. Blockscout `proxy_type: None`; EIP-1967 implementation/admin/beacon
  slots all zero; 21,808-byte runtime code (full implementation, not a minimal proxy).
- **Sourcify?** No match (`match: null`) — this is why pass 1 recorded it as
  unverified. Blockscout verification is the findable source.
- **Live state (2026-11-14):** name "Splits Earn USDC", symbol "splitsUSDC", 18
  decimals, asset USDC `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`, totalAssets
  ~662,922 USDC, totalSupply ~659,494e18 shares (~1.0052 USDC/share).
- **Roles/fees:** owner = curator = `0x5d8B947cE5853Bd8e5CacA8a7c39EAcA452b6752`;
  performanceFee 20% (0.2e18 WAD), managementFee 0, performanceFeeRecipient
  `0x020dB5827cdC1b270Ece1F75c07aa6b841Cd2e05`; virtualShares 1e12.
- **Gates:** receive/send assets/shares gates all unset (zero addresses) — deposits
  are permissionless; no gating affects the module's `deposit()` path.
- **ERC4626 check:** pass 1's "standard ERC4626" assumption HOLDS with one documented
  caveat from the VaultV2 source itself: "the vault has a non-conventional behaviour
  on max functions: they always return zero" — this explains the observed
  `maxDeposit() == 0` and does NOT block deposits. The module calls `deposit()`
  directly and is unaffected.

The vault is a third-party boundary OUT of Splits program scope. Its code was NOT
audited as a Splits finding; this section is identification only.

## 6. Coverage gaps (updated)

- smart-vaults package: line-read only, no executed harness (deps not vendored).
  No candidate from that package survived to need execution; the modules harness
  covers the unaudited package with a faithful vault mock. A full vault harness
  (OZ 5.x + account-abstraction + web-authn + FreshCryptoLib clones) remains
  buildable on request.
- No mainnet fork tests; no live probing beyond read-only view calls and public
  verification APIs. No userOp/EntryPoint execution was attempted.
- Earn vault internals (adapters, allocation, Morpho markets) not audited — out of
  scope by design; only identity, proxy status, verification, roles, gates, and
  live state were established.
- Prior-audit dedup rests on the three audit files in the repo (`audits/`); no
  HackerOne/platform disclosed-report search was performed (Splits runs a direct
  email program, security@splits.org, with no public disclosure feed found).

## Deliverables

- This report: `~/workspace/splits-audit/REPORT-2ND-PASS.md`
- Harnesses: `~/workspace/splits-audit/harness-2nd-pass/splits-v2/` and
  `~/workspace/splits-audit/harness-2nd-pass/modules/` (re-runnable; see §1)
- Frozen proof/fuzz copies: `~/workspace/splits-audit/poc-2nd-pass/` (+ README with
  the per-file result table; verified byte-identical to the harness tests)
- Pipeline artifacts: `triage-2nd-pass.json`, `recon-2nd-pass.json`,
  `hunter-findings-2nd-pass.json`, `skeptic-2nd-pass.json`, `referee-2nd-pass.json`,
  `verification-report-2nd-pass.json`, `scan-report-2nd-pass.json`
- Pass-1 `REPORT.md` and pass-1 artifacts untouched.
