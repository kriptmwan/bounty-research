# Exclusion set — do NOT report as new findings

## Known incidents (bounty-excluded)
- Jul 2023 Vyper compiler bug (reentrancy locks ineffective in 0.2.15/0.3.0/0.3.1), ~$52M. Compiler-level, patched.
- Mar 2026 sDOLA oracle attack: per-market oracle helper manipulation liquidated 27 positions (~822,475 crvUSD). The *class* (oracle-helper manipulation) is the target; the specific incident/root cause is known.
- Oct 2025 CRV-long bad debt: market/utilization issue, not a code finding.
- Resupply Jun 2025 $9.6M donation attack: separate protocol, not Curve.

## ChainSecurity LLV2 remediation (report unpublished; remediation in-repo)
38 finding IDs appear in commit messages: 002, 003, 005, 006, 007, 008, 009, 010, 011, 012, 016, 030, 037, 038, 039, 042, 043, 044, 046, 047, 058, 060, 061, 062, 083, 087, 088, 090, 092, 093, 095, 096, 097, 098, 099, 101, 103, 104, 106, 109.
Commits touching scoped files (verify diffs before claiming anything adjacent):
- 276bfc59 / bd9c0415 / 037b6020 (092): settable default_admin; ControllerView refactor; immutable DEFAULT_ADMIN.
- 8adc7278 (109): users_with_health DynArray capacity.
- 47a0cdb2 (106): do not call MP.rate_write() from LendFactory/Configurator.
- 0f572ffa (104): borrow_more_health_preview for 0 debt.
- 6944be86 (103): add/remove_collateral_health_preview for 0 amount.
- 5e3f7154 (099): remove reentrant decorator from set_custom_admin.
- 9c85885b (101): AMM fee checks moved to AMM.
- 2c59c069 (098): consistent reentrancy policy for AMM setters.
- c0fa8072 (096): NatSpec fixes. be4132fe (095): events moved to Configurator. 0d56df3d (093): indexed controller in events.

## ChainlinkEMA upstream fixes (already applied — do not re-report)
- 391e221d: loads feed decimals at deploy, rejects zero observations/interval, drops dead next-phase fallback.
- a95dcc48: follows a new phase aggregator's decimals instead of reverting (the revert froze liquidations until a DAO oracle swap).
- 3a090a33: reverts if a new phase aggregator changes decimals (superseded by a95dcc48).
- 19a74d87: merge upstream ChainlinkEMA fixes.

## Other fixed-then-landed items in scoped paths (verify, don't re-report)
- 38481eca: fix _get_utilization guards (mpolicies).
- 1b844a57: fix NO_ARGUMENT detection (pool oracles).
- 63564d5a: refactor don't assert negative rate (mpolicies clamp).
- 533438c0: use convertToAssets in syrupUSDC rate calculator.
- 9bb4e5b3: remove ema from HyperbolicDynamicMP.
- eaab7f43: add _max_spent (TransientLeverageZap).
- 8c02477f / wstGBP oracle PR #258 series: NAV-pause caching, Chainlink-EMA-only FX pricing.

## Documented intended behaviors (kill fast if a candidate matches these)
- EMA oracles: asymmetric dampening (upside EMA, downside immediate) is intended.
- SyrupUSDCAdapter using convertToExitAssets instead of convertToAssets is intended.
- OwnerProxy permissionless apply_new_fee / accept_transfer_ownership / deploy_gauge / deploy_plain_pool: long-standing design (commit steps guarded).
- Configurator max_deviation == max_value(uint256) skipping the deviation check: documented escape hatch for broken oracles.
- HyperbolicMP/DynamicMP clamping negative rates to 0 instead of reverting: intended (never brick rate_write).
- DynamicMP treating a failing calculator as 0 -> MIN_TARGET_RATE: intended (never brick rate_write).
- WstETH calculator returning 0 on insufficient history / non-increasing rates: documented.
