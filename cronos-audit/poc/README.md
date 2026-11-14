# PoC — Cronos / VVS kill-proofs

Kill-proof Foundry tests for the Cronos Smart Contracts audit (2026-11-14).
These prove the two closest candidates do NOT yield an in-scope fund loss.
There are no exploit PoCs here because no finding survived.

## Layout

- `src/target/` — byte-identical copies of the audited `vvs-farm` sources
  (`acd79b99d88157b9d520eeac92e8c6424ae9d8de`):
  `Craftsman.sol` (sha256 `e5491e06…`), `Workbench.sol` (`fae39cd4…`),
  `VVSToken.sol` (`1d4882eb…`), `VVSInitMintable.sol` (`f814baf1…`),
  `WCRO.sol` (`97e376a1…`). Verify with `sha256sum` against
  `../repos/vvs-farm/contracts/`. Never edited.
- `lib/oz-contracts/` — vendored copy of OpenZeppelin contracts 3.4.0
  (`fa64a1ced0b70ab89073d5d0b6e01b0778f7e7d6`), copied so solc's sandbox
  allows the imports.
- `test/CronosAudit.t.sol` — 4 tests, Solidity 0.6.12, no forge-std
  (minimal cheatcode interface declared inline).

## Run

```bash
export PATH="$HOME/.foundry/bin:$PATH"   # forge 1.5.1, NOT on default PATH
cd ~/workspace/cronos-audit/poc
forge test
```

Expected (deterministic):

```
[PASS] testBenchRequiredToLeaveStaking() (gas: 182586)
[PASS] testEmergencyWithdrawKeepsBenchButExtractsNothing() (gas: 362163)
[PASS] testHookLpDepositDoublePaysPending() (gas: 683001)
[PASS] testPlainLpDepositPaysExactlyPending() (gas: 327170)
Suite result: ok. 4 passed; 0 failed; 0 skipped
```

Full output: `test-output.txt` (captured 2026-11-14).

## What each test proves

1. `testEmergencyWithdrawKeepsBenchButExtractsNothing` — BUG-1: the
   `emergencyWithdraw(0)` BENCH-retention mechanic is real, but retained
   BENCH extracts 0 VVS and re-staking mints only the new amount.
2. `testBenchRequiredToLeaveStaking` — BUG-9: transferring BENCH away
   blocks `leaveStaking`, and transferring it back restores the exit.
3. `testPlainLpDepositPaysExactlyPending` — BUG-2 control: with a plain
   ERC20 LP token, `deposit` pays exactly the quoted pending amount.
4. `testHookLpDepositDoublePaysPending` — BUG-2: with an ERC777-style
   hook token, `deposit` pays 2x quoted pending — proving the double-pay
   needs the excluded precondition (an owner-added hook-token pool).
