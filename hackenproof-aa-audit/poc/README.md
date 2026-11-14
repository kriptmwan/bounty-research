# PoCs — none

This directory is intentionally empty: the audit found 0 confirmed findings, so no finding PoCs exist.

Verification evidence (harness tests that killed leads / confirmed quirks) lives in
`../poc-harness/test/`:
- `ContextOffset.t.sol` — 4/4 PASS; kills lead K-1 (paymaster-less context path).
- `H8Overflow.t.sol` — 1/1 PASS; confirms the BUG-1 overflow quirk and that
  simulation catches it (OOG, not AA35).

See `../REPORT.md` and `../verification-report.json`.
