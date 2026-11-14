# poc-2nd-pass — frozen copies of the executed proofs + fuzz tests

These files are byte-identical snapshots (verified with `diff -r` at report time,
2026-11-14) of the runnable tests in `../harness-2nd-pass/`. The harness copies
are the runnable source of truth; this directory is the frozen deliverable record.

## splits-v2/ (run in `../harness-2nd-pass/splits-v2/`)

| File | What it proves | Result |
|---|---|---|
| `Hunt2Reentrancy.t.sol` | HUNT-2: reentrant PushSplit ETH distribution gains exactly the sequential baseline; overdraft reverts atomically | 2/2 PASS |
| `Hunt3HookToken.t.sol` | HUNT-3: ERC777-style hook-token reentrancy bounded identically; mid-loop reentry reverts atomically | 2/2 PASS |
| `WarehouseInvariant.t.sol` | Warehouse accounting identity, solvency, no phantom balances (invariant 64 runs x 32 depth) | 3/3 PASS |
| `WarehouseReentrancy.t.sol` | H2-15: reentrant batch/single warehouse withdrawals cannot multiply payouts (CEI) | 2/2 PASS |
| `DistributionFuzz.t.sol` | Push/Pull ETH+ERC20 exact allocation math, conservation, over-amount revert, extreme-allocation revert (fuzz 256 runs) | 5/5 PASS |
| `Smoke.t.sol` | Harness smoke: warehouse deploys, split contracts compile | 1/1 PASS |

## modules/ (run in `../harness-2nd-pass/modules/`)

| File | What it proves | Result |
|---|---|---|
| `ModulesInvariant.t.sol` | Asset conservation, zero leftover allowance, outsider never enrolled, shares backed (invariant 64 runs x 32 depth) | 4/4 PASS |
| `ModulesEdge.t.sol` | Enroll/deposit edge cases: ownership rules, undeployed reverts, no-op paths, yield-rate crediting, zero-address ctors | 12/12 PASS |

## Re-run

```bash
export PATH="$HOME/.foundry/bin:$PATH"
cd ~/workspace/splits-audit/harness-2nd-pass/splits-v2 && forge test --fuzz-runs 256
cd ~/workspace/splits-audit/harness-2nd-pass/modules && forge test --fuzz-runs 256
```

Total: 31 tests, 0 failures at report time.
