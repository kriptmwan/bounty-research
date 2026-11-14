# Hunter B — non-qualifying items (FraxlendPair ERC-4626 / admin / pauses)

Hunter B, Fraxlend @ `2bed49d4`, 2026-11-14. Every item below was examined and
fails the bounty bar (theft of funds or permanent freezing on a live deployment
by an unprivileged caller, with a fork PoC). None of these is in
`hunter-findings-B.json`. Line numbers are repo HEAD; all four assigned files
were verified byte-identical to the deployed reference-pair sources
(`0xaB3cb84c310186B2Fa4B4503624A5D90b5DcB22D`, Sourcify exact match).

## NQ-B-1 — setMaxLTV has no bounds (FraxlendPair.sol:353-358)

`setMaxLTV` accepts any `uint256`, including 0 and values above `LTV_PRECISION`
(1e5). `maxLTV == 0` makes `FraxlendPairCore._isSolvent` return `true` for every
borrower (Core:220), so borrows need no collateral and liquidations can never
trigger; `maxLTV > 1e5` permits undercollateralised borrows. Fails the bar: the
setter is timelock-only (`_requireTimelock`, :354) and the live timelock is
`0xB174…`; no unprivileged path to the setter was found, so this is an
admin-key/governance precondition the bounty excludes.

## NQ-B-2 — setOracle has no validation (FraxlendPair.sol:319-331)

`setOracle` accepts a zero/EOA/malicious oracle and any `maxOracleDeviation`
(including 0, which would brick borrows since low/high are rarely exactly
equal, or huge, which disables the deviation gate). A zero oracle makes
`_updateExchangeRate` revert on every borrow/liquidation path. Fails the bar:
timelock-only (:320), same privileged precondition as NQ-B-1; a bad oracle can
also be replaced by the timelock unless the setter was revoked, so it is not
unprivileged permanent bricking.

## NQ-B-3 — setRateContract has no validation (FraxlendPair.sol:379-384)

`setRateContract` accepts address(0) or any contract. A zero rate contract
makes `_calculateInterest` revert, and `_addInterest` is called first by every
state-changing pair function, so the whole pair would brick until the timelock
fixes it. Fails the bar: timelock-only (:380); installing a malicious/broken
rate contract requires the privileged key, and the live rate contract
(`0x987a96c663…`, VariableInterestRateSettable v3.0.0) is benign. No
unprivileged path exists.

## NQ-B-4 — setLiquidationFees has no bounds (FraxlendPair.sol:417-436)

Clean/dirty/protocol liquidation fees accept any `uint256`. A protocol fee
above `LIQ_PRECISION` makes `_feesAmount` exceed the collateral in `liquidate`
and underflow; a huge dirty fee makes partial-liquidation collateral exceed the
borrower's balance and revert — both brick liquidations. Related in mechanism
to EX-008 (Nov 2022: no constructor bound on liquidation fee), but this is the
v3 setter, not the constructor. Fails the bar: timelock-only (:422), privileged
precondition; live fees are 10000/9000/2000.

## NQ-B-5 — Pause revocations freeze whatever state is current (FraxlendPair.sol:587-590, 605-608, 623-626, 644-647; FraxlendPairAccessControl.sol:134-137, 151-154, 168-171, 185-188)

`revokeRepay/Withdraw/Liquidate/InterestAccessControl` set only the revoked
flag; they do not check or set the pause flag. Revoking while paused freezes
that pause permanently — e.g. revoke-while-`isWithdrawPaused` bricks all
lender withdrawals forever, since `pause()`/`unpause()` skip revoked controls
and the individual pause functions revert with `AccessControlRevoked`. Fails
the bar: every revoke is timelock-only, so permanent bricking requires the
governance key to revoke in the paused state; no unprivileged caller can force
the sequence (the circuit breaker can pause but cannot revoke).

## NQ-B-6 — Borrow/deposit "permanent" limits are re-settable by the timelock (FraxlendPairAccessControl.sol:97-101, 116-120; FraxlendPair.sol:547-550, 569-572)

`_revokeBorrowAccessControl` / `_revokeDepositAccessControl` unconditionally
overwrite `borrowLimit`/`depositLimit` and set the revoked flag, with no
already-revoked guard, so the timelock can call `revokeBorrowLimitAccessControl`
/ `revokeDepositLimitAccessControl` repeatedly with new limits after
"revocation". The one-way promise holds for the oracle/LTV/rate/fee setters
(flags checked, no unsetter) and for the pause flags (re-revoke is a no-op),
but not for the two limits. Fails the bar: only the timelock can re-revoke, so
this is a weakened immutability guarantee under the privileged key, not an
unprivileged theft/freezing path.

## NQ-B-7 — unpause() resets borrow/deposit limits to max (FraxlendPair.sol:516-528)

`unpause()` sets both limits to `type(uint256).max` (when not revoked) rather
than restoring previous values, so a pause/unpause cycle silently destroys any
deliberate timelock-set cap (e.g. a 1,000-asset borrow cap becomes unlimited).
Fails the bar: `unpause()` is timelock-or-owner only (:517), the effect is cap
removal (risk increase, still gated by collateral/solvency on borrows), not
theft or freezing of funds.

## NQ-B-8 — withdrawFees: stale totals, no reentrancy guard, pause bypass, round-up, collateral sweep (FraxlendPair.sol:464-481)

`withdrawFees` never calls `_addInterest` (it prices fee shares off stored
totals, missing pending interest/fees), has no `nonReentrant` guard while
calling `_redeem`/`_removeCollateral` (external token transfers), bypasses
`isWithdrawPaused` (calls `_redeem` directly), rounds the asset amount UP
(`toAmount(_shares, true)`, :474 — at most +1 wei vs lenders' round-down
redeems), and sweeps the pair's entire `userCollateralBalance[address(this)]`
to the recipient. Fails the bar: `onlyOwner` (:464), owner is the timelock
`0xB174…` on the reference pair; no unprivileged caller can reach it, no
standing pair-to-attacker allowance exists (the `_approve` at :476 is consumed
in the same call), and the live asset/collateral tokens are plain ERC-20s with
no callbacks.

## NQ-B-9 — setSwapper is owner-only with no validation; approved swappers are fully trusted (FraxlendPair.sol:492-495)

`setSwapper` (owner-only, weaker than the timelock-gated setters, though
owner == timelock on the reference pair) approves any address with no
zero/contract check, and the Core swap paths approve the swapper for the full
swap amount per call (`leveragedPosition`/`repayAssetWithCollateral`), leaving
residual allowance if a swapper pulls less than approved. Fails the bar: a
malicious swapper requires owner approval (privileged), and no profitable
unprivileged drain was found — swap amounts are bounded by the caller's own
borrow/collateral and the post-swap solvency check, so draining the float via
leftover allowance still leaves the attacker's debt and posted collateral
behind. The approve pattern itself lives in FraxlendPairCore (Hunter A scope);
flagged here only as a cross-reference.

## NQ-B-10 — changeFee has no revocation mechanism (FraxlendPair.sol:443-452)

Unlike the four setters, the protocol fee has no revoke flag: the timelock can
always change it. Mitigated by design: the fee is capped at `MAX_PROTOCOL_FEE`
(50%, :446) and `_addInterest()` runs before the change (:449), so accrued
interest uses the old fee. Fails the bar: timelock-only, capped, no
unprivileged reach, no retroactive theft.

## NQ-B-11 — setCircuitBreaker has no validation; breaker pause power is DoS-only (FraxlendPairAccessControl.sol:214-217)

`setCircuitBreaker` (timelock-only) accepts address(0) (disables breaker
pausing) or any address. A compromised breaker key can pause everything via
`pause()`/`pauseBorrow`/etc., but cannot unpause, set parameters, revoke, or
withdraw fees — and any breaker pause is reversible by timelock/owner. The
live breaker `0xfd3065C629ee890Fd74F43b802c2fea4B7279B8c` has proxy-shaped
code (read-only `eth_getCode` check) and no permissionless forwarding was
found in-repo; the deployer's `globalPause` is breaker-only (see Killed
leads). Fails the bar: privileged-key precondition, reversible temporary DoS,
no theft.

## NQ-B-12 — pricePerShare hardcodes 1e18 (FraxlendPair.sol:229-231)

`pricePerShare` returns `toAssetAmount(1e18, …)` regardless of the fToken's
decimals, so it is wrong by 1e12 on the four live 6-decimal pairs and by 1e10
on the 8-decimal fWBTC pair (e.g. `0xeE847a804b67f4887c9E8fe559A2dA4278deFB52`,
fUSDC(sfrxETH)-26). Fails the bar: view-only, moves no funds; the reference
pair has 18 decimals so it is correct where most value sits, and
`convertToAssets`/`convertToShares` use raw units correctly.

## NQ-B-13 — mint/previewMint round the asset amount DOWN (evidence: FraxlendPairCore.sol:590-612; view surface in FraxlendPair.sol:221-227)

`mint`/`previewMint` use `toAmount(_shares, false)`; ERC-4626 expects the
assets-required preview to round up. The minter's advantage is under 1 wei of
asset per call (division truncation), and on the reference pair the share
price is above 1 so `mint(1)` still costs ≥1 wei — no free shares. Fails the
bar: dust-scale, not attacker-profitable theft; the rounding code itself is in
Core/VaultAccount (Hunter A scope).

## NQ-B-14 — maxDeposit/maxMint overstate the executable maximum (FraxlendPair.sol:238-247)

`maxDeposit`/`maxMint` do not cap at the `uint128` `SafeCast` bounds enforced
by `deposit`/`mint`, and ignore the `_receiver` argument (including
address(0), which `deposit` rejects). A quoted maximum above `uint128.max`
would revert on execution. Fails the bar: view-only mismatch at amounts
exceeding any token supply; execution reverts safely, no funds move.

---

## Killed leads (checked, no finding — recorded so they are not re-raised)

- **Permissionless pause via the deployer:** disproved. `FraxlendPair.pause`
  trusts `DEPLOYER_ADDRESS` (`_requireProtocolOrOwner`, AccessControl:76-86),
  but the deployer's only pair-pausing entry, `globalPause`, is
  circuit-breaker-only (`FraxlendPairDeployer.sol:341-343`). The deployer has
  no other pair-admin forwarding. No unprivileged pause path exists.
- **Share-price manipulation via donation or interest preview:** disproved.
  Share math uses accounting totals (`totalAsset`), not token balances, so
  direct asset donations do not move the share price; `deposit`/`mint` accrue
  interest before pricing, matching the preview functions, and same-block
  accrual short-circuits identically in preview and execution. No
  donation/inflation vector was found.
- **Owner == deployer window at construction:** disproved. The deployed OZ
  4.9.0 `Ownable2Step._transferOwnership` transfers immediately (deletes
  pending owner, sets owner), so the AccessControl constructor's
  `_transferOwnership(_comptrollerAddress)` makes the comptroller the owner
  from deployment; there is no pending-acceptance window.
- **Reentrancy into unguarded admin functions via the rate contract:**
  disproved. `_calculateInterest` is `view`, so the external
  `getNewRate` call compiles to `STATICCALL`; a malicious rate contract
  cannot reenter state-changing functions through it. (Rate-contract
  replacement is timelock-only in any case.)
- **Revoked setters still acting / owner re-granting:** disproved for the
  four setters (flags set only to `true`, checked on every setter call, no
  unsetter; setters are timelock-only so the owner cannot re-grant). The
  borrow/deposit limit exception is NQ-B-6.
- **Fee-share draining by non-owners:** disproved. Fee shares are minted to
  the pair itself; redeeming them requires a pair-granted allowance, and the
  pair grants allowances only inside `withdrawFees` (owner-only, consumed in
  the same call).
- **pauseInterest trapping lenders:** disproved. Interest pause freezes
  accrual only; `redeem`/`withdraw`/`repayAsset` do not check the interest
  flag and keep working.
- **Dedup:** no candidate matched EX-001…EX-022. NQ-B-4 is mechanism-adjacent
  to EX-008 (constructor fee bounds) but concerns the v3 setter and is
  admin-gated. The Jan 2023 ToB dedup gap is noted: no finding is claimed on
  pre-v3 code paths, so no dedup-uncertain claim arises from this Hunter.
