# Build status

- Foundry installed 2026-11-13 via official foundryup under ~/.foundry (user-authorized).
  - Active toolchain: forge 1.5.1-v1.5.1 (commit b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2, build 2025-12-19, maxperf) — matches repo CI pin (foundry-toolchain v1.5.1).
  - Also installed: 1.9.0 (6056c5845d). Switch with `foundryup --use <version>`.
  - cast 1.5.1, anvil 1.5.1, chisel 1.5.1 alongside forge.
- solc 0.8.35 fetched automatically by forge (svm) per repo foundry.toml (via_ir=true, optimizer_runs=200).
- `forge build --skip test --skip script --root packages/perps --threads 2`: EXIT 0 in 3m48s (2026-11-13 ~13:24 WIB). 237 files compiled. Only output: forge lint notes (unwrapped-modifier-logic) — no errors, no warnings blocking the build.
- Smoke test: `forge test --match-path test/perps/spec/admin/EngineConfiguration.t.sol` (warming the test-compile cache) — see /tmp/plether-smoke.log.
- POC placement: new test files under packages/perps/test/perps/poc/ (untracked additions; in-scope contracts never modified), with copies in ~/workspace/plether-audit/findings/<id>/.
