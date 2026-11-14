# Hunter A — Non-qualifying items (FraxlendPairCore / VaultAccount)

Impact gate: ONLY demonstrated theft-of-funds or permanent-freezing on a CURRENT LIVE
deployment with a fork PoC counts. Each item below was traced and fails that bar.
Line numbers are repo HEAD (`2bed49d4`) unless noted; the deployed reference pair
(`0xaB3cb84c310186B2Fa4B4503624A5D90b5DcB22D`, v3.1.0) differs in exactly the 3
documented ways (verified by diff — no other divergence spotted).

## NQ-A-1. VaultAccount.toAmount roundUp division-by-zero in the amount==0 / shares>0 state

`libraries/VaultAccount.sol:29-38`: `toAmount` takes the `total.shares != 0` branch when
`total.amount == 0`, computes `amount = 0`, then the roundUp check divides by
`total.amount` (line 34) and panics. Callers with `roundUp=true` are `_isSolvent`
(`FraxlendPairCore.sol:219`, via `totalBorrow.toAmount(..., true)`), `repayAsset`
(:940), and `liquidate`'s `_amountLiquidatorToRepay` (:983ff) — so in that state,
borrowing, collateral removal, repayment and liquidation all revert, and a borrower
holding dust shares cannot repay or retrieve collateral. Fails the bar: reaching
`totalBorrow=(0, shares>0)` requires share price below 1, which requires a bad-debt
writeoff larger than all accrued interest (repay roundUp grinding from the live
price of ~1.1 cannot get there; the reference pair would need >~310k frxUSD of
writeoffs first), and any new permissionless borrow heals the state because
`_borrowAsset` restores `totalBorrow.amount > 0` before the post-body solvency check.
For `totalAsset`, amount can never reach 0 on the reference pair because writeoffs
are bounded by `totalBorrow` (3.42M) while 1.17M of unborrowed float remains. The
same root state also makes `toShares` return 1:1 deposits (`VaultAccount.sol:16-18`)
that old shareholders can dilute — but that needs a victim depositing into a
visibly dead pair after the attacker destroyed their own funds to create it.
DEDUP-UNCERTAIN: VaultAccount math is unchanged since the pre-v3 baseline, and the
Jan 2023 ToB report is unretrieved.

## NQ-A-2. mint() rounds the required amount DOWN (ERC-4626 deviation, <1 wei)

`FraxlendPairCore.sol:595-612`: `mint` computes `_amount = _totalAsset.toAmount(_shares,
false)` — round DOWN, where ERC-4626 expects round UP for mint. A minter underpays by
strictly less than 1 wei per call, and `redeem` rounds the payout down symmetrically,
so there is no mint/redeem arbitrage and no extractable value. Fails the bar:
sub-wei, non-compounding. (Other rounding directions are correct: `deposit` rounds
shares down, `withdraw` rounds shares up, `borrowAsset` rounds borrow shares up,
`repayAsset` rounds the repay amount up.)

## NQ-A-3. _calculateInterest silently skips accrual on uint128 overflow — but advances time

`FraxlendPairCore.sol:353-407`: if `interestEarned + totalBorrow.amount` or
`interestEarned + totalAsset.amount` exceeds `type(uint128).max`, accrual is skipped,
yet `_addInterest` (:416ff) still advances `lastTimestamp`, updates the rate, and
emits `AddInterest` carrying the un-accrued `interestEarned` — interest for the period
is forgiven and the event misreports. Fails the bar: the guard needs totals near
2^128 (~3.4e20 tokens at 18 decimals) versus 4.59M live; unreachable on any live pair.

## NQ-A-4. feesShare uint128 truncation in extreme post-writeoff states

`FraxlendPairCore.sol:390-405`: `_results.feesShare = feesAmount * totalAsset.shares /
(totalAsset.amount - feesAmount)` is added to `totalAsset.shares` via a truncating
`uint128(...)` cast while `_mint(address(this), _feesShare)` mints the full uint256,
so if `feesShare > 2^128` the ERC20 supply and `totalAsset.shares` diverge (and the
comment's claim `feesShare < feesAmount` is false whenever share price < 1, i.e.
after a large writeoff). Fails the bar: `feesShare` is bounded by
`deltaTime * rate * totalAsset.shares / 1e18` with the rate clamped by the calculator
(`VariableInterestRate.sol` clamps to `[MIN,MAX]_FULL_UTIL_RATE`, live ~7.9e9) and
borrows bounded by `totalAsset.amount`; reaching 2^128 needs an extreme dust-amount /
huge-shares state of the NQ-A-1 kind plus an enormous elapsed time. The fee-denominator
underflow variant is independently killed: `changeFee` caps `feeToProtocolRate` at
`MAX_PROTOCOL_FEE = 5e4` (50%, `FraxlendPair.sol` + `FraxlendPairConstants.sol`),
so `feesAmount < totalAsset.amount` always. The same extreme-state precondition gates
the truncating `uint128(_sharesAdded)` cast in `_borrowAsset` (:757ff).

## NQ-A-5. Interest-rate gaming via utilization manipulation is intended rate dynamics

`FraxlendPairCore.sol:353-407`: `_calculateInterest` applies the NEW rate (from
`rateContract.getNewRate` at current utilization) to the whole elapsed `deltaTime`,
so a borrower who deposits enough to depress utilization before an accrual gets a
lower rate applied retroactively. Fails the bar as theft: this is the designed
utilization response (every accrual uses current utilization, and `_addInterest` runs
before each function's effects, so same-tx manipulation cannot affect that tx's
accrual); movement is damped by the calculator's half-life drift and clamped to
`[MIN,MAX]_FULL_UTIL_RATE`; exploiting it needs large locked capital plus a large
pre-existing borrow, and the "saving" is bounded ordinary rate movement, not an
extraction of others' funds. Deployed rate-contract parameters are Hunter C's
surface (live contract is `VariableInterestRateSettable` v3.0.0, not in the repo).

## NQ-A-6. Bad-oracle data is stored (warn-don't-revert); liquidate ignores the deviation gate

`FraxlendPairCore.sol:494-538`: `_updateExchangeRate` stores whatever
`IDualOracle.getPrices()` returns even when `_oneOracleBad` is true, emitting only
`WarnOracleData`; borrows are gated by the deviation check, but `liquidate` (:983ff)
discards `_isBorrowAllowed` and liquidates at the stored low rate regardless. A
manipulated or stale low rate could therefore wrongfully liquidate borrowers. Fails
the bar standalone: there is no pair-core trigger — stored rates can only change via
the admin-set oracle, so exploitability depends entirely on manipulating the live
`SfrxEthUsdTripleOracle` (Hunter C surface: Chainlink/Redstone/Curve EMA/UniV3 TWAP
legs). The deviation computation itself fails closed for borrows (division by zero
on `high == 0`, underflow revert on `low > high`). Related but distinct from EX-010 /
EX-011 (v1 single-feed Chainlink validation / outage monitoring — superseded by the
v3 dual-oracle model); not a dedup match.

## NQ-A-7. Unbounded privileged risk-parameter setters can brick or drain — privileged only

`FraxlendPairCore.sol:219` (`_isSolvent` returns true when `maxLTV == 0`, which also
blocks all liquidations), :983ff (`liquidate` underflows if `protocolLiquidationFee >
LIQ_PRECISION`, reverts if a huge dirty fee pushes collateral above the borrower's
balance), and :494ff (deviation gate passes always if `maxOracleDeviation` is set
above 1e5). All three parameters are set only via timelock-gated setters in
`FraxlendPair.sol` (`setMaxLTV`, `setLiquidationFees`, `setOracle` — no upper-bound
checks; Hunter B's file). Fails the bar: every trigger requires timelock compromise /
governance action, which the bounty explicitly excludes; live values are sane
(maxLTV 75,000; clean/dirty/protocol 10,000/9,000/2,000; deviation 5,000). Related
to EX-008 (missing constructor bounds, Nov 2022) — the constructor likewise has no
liquidation-fee bound, but pair creation is deployer-whitelist-gated.

## NQ-A-8. Pause interplay gaps are by design or risk-reducing; no bypass extracts funds

There are no `isBorrowPaused` / `isDepositPaused` flags anywhere in the repo: borrow
and deposit "pauses" are limit-0 via `pauseBorrow` / `pauseDeposit`
(`FraxlendPair.sol`), and every borrow/deposit path checks its limit
(`borrowAsset` :792ff, `leveragedPosition` :1121ff, `deposit` :571ff, `mint`
:595ff) — no missing-check bug. `repayAssetWithCollateral` (:1217ff) does not check
`isRepayPaused` (only `repayAsset` does), and `addCollateral` / `removeCollateral`
have no pause checks at all; but repaying debt and adding collateral only reduce
risk, and removing collateral is the borrower's own funds behind a post-body
solvency check — no path extracts lenders' funds. At most an incident-response
weakening if repay were paused over a compromised swapper, which needs the
admin-trusted swapper to be malicious first. Fails the bar.

## NQ-A-9. previewAddInterest returns a stale timestamp in the preview struct

`FraxlendPairCore.sol:307-348`: when interest is updated, the returned
`_newCurrentRateInfo` carries the new rate fields but the OLD `lastTimestamp` /
`lastBlock` (never set to the current block). Only the totals are consumed by the
`FraxlendPair.sol` views, so there is no behavioral consequence beyond a misleading
view return. Fails the bar: view-only inconsistency, no funds impact.

## Killed leads (no bug; recorded so they are not re-raised)

- **HEAD `_isSolvent` truncation**: the HEAD formula truncates
  `(_borrowerAmount * _exchangeRate) / EXCHANGE_PRECISION` before applying LTV
  precision, understating LTV. INVALID per deployed-source primacy — the deployed
  v3.1.0 formula multiplies by `LTV_PRECISION` first (diff-verified, line 226).
- **EX-005 (stale rate in leverage paths)**: fixed in v3 — both `leveragedPosition`
  (:1121ff) and `repayAssetWithCollateral` (:1217ff) call `_updateExchangeRate`
  before acting. Dedup-kill, cite EX-005.
- **EX-009 (penalty-rate misapplication)**: maturity/penalty logic removed entirely
  in v3 (0 mentions at HEAD). Dedup-kill, cite EX-009.
- **First-deposit inflation / donation attacks**: neutralized — `VaultAccount` math
  uses accounting totals, never token balances, so direct asset/collateral donations
  never enter `totalAsset.amount` or any share price; new pairs are seeded by the
  deployer (2025 `amountToSeed`); the 1:1 branch only applies at exactly (0,0) with
  fair pricing. The only residual is the dead-pair state in NQ-A-1.
- **Reentrancy / CEI violations**: all state-changing externals in Core are
  `nonReentrant`; the two self-noted CEI violations (`leveragedPosition` :1176,
  `repayAssetWithCollateral` :1261) are guarded, the fToken is plain OZ ERC20 with
  no callbacks, transfers use OZ `SafeERC20`, and swappers are admin-whitelisted.
  (`withdrawFees` in `FraxlendPair.sol` lacks `nonReentrant` — Hunter B's file;
  flagged to parent as a cross-reference, not claimed here.)
- **Exchange-rate direction**: solvency uses the HIGH rate (conservative for
  borrowers) and liquidation the LOW rate (conservative against wrongful
  liquidation) — correct directions for a collateral-per-asset quote.
- **Liquidate writeoff math**: full-liquidation amount removal equals the borrower's
  exact debt (`ceil + floor` identity); partial writeoffs shift remaining borrowers'
  share price by dust only; protocol-fee collateral bookkeeping nets correctly
  across the three `_removeCollateral` / `_addCollateral` calls.
