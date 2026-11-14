# Non-Qualifying Observations — Domain B (SlippageAuction mechanics)

**Hunter:** Domain B · **Date:** 2026-11-14 · **Verdict:** 0 qualifying findings (`hunter-findings-B.json` = `[]`).
Every observation below was investigated and KILLED against the FRAX BAR: Frax reviews only
demonstrated theft-of-funds or permanent-freezing paths against current live deployments, each with
a working mainnet-fork PoC quantifying funds at risk. Nothing below meets that bar. Nothing below
is inflated; each entry states its kill reason plainly.

## Scope-deciding facts applied (not relitigated)

- **HEAD == live for this domain, verified by diff in this pass:** the v1-live
  `SlippageAuction.sol` differs from repo HEAD only by 2 provenance comment lines; the v1-live
  `SlippageAuctionFactory.sol` differs from HEAD only by those 2 comment lines plus the absent
  `version()` function. Line numbers below are v1-live lines (HEAD lines = v1-live − 2).
  SHA-256 at time of hunt: SlippageAuction `90093f7e…96bf`, Factory `2240ead4…7578`.
- **Live state (per ONCHAIN-GROUNDWORK-FXB.md):** 5 auctions, ALL stopped + expired, ZERO token
  balances, 33 historical runs, 7,025,001.50 FXB sold historically. Auctions are restartable by the
  FxbAMO operator (`0x452420df4AC1e3db5429b5FD629f3047482C543C`, timelock of all 5, holds
  ~1,999,230 FXB_20261231). Any mechanics defect would therefore have FUTURE-auction exposure only;
  **current funds at risk in every auction = 0.** No entry below claims current locked funds.
- **Exclusions honored:** EXCLUSION_LIST_FXB.md read in full. EX-F02 (TOB-3 array OOB) and EX-F03
  (TOB-4 swapped swap args) re-verified fixed at the hunted source (see NQ-B-25) and not re-reported.
- **FxbAMO used as evidence only** (out-of-scope repo). No finding is reported in FxbAMO itself.

## NQ-B-1 — swapExactTokensForTokens: rounding-dust spurious revert (strongest sub-bar observation)

**Mechanism.** `getAmountOut` (SlippageAuction.sol:150) floors `_slippagePerTokenSell`
(`(priceSlippage * amountIn) / PRECISION`), which slightly *inflates* the quoted `amountOut`;
`swap()` then recomputes the minimum via `_getAmountIn` (:225), whose own floor on
`(amountOut * priceSlippage) / PRECISION` shrinks the denominator and slightly *inflates*
`_minAmountIn`. The two formulas are exact inverses over the reals but not under dual flooring, so
`_minAmountIn` can exceed the `amountIn` the wrapper just transferred, and `swap()` reverts with
`InsufficientInputAmount` (SlippageAuction.sol:515) even though the quote came from the contract
itself. Verified by pure-math fuzz (Python, exact integer arithmetic replicating both formulas):
with historical parameter ranges (pre-slippage price 0.87–1.00e18, slippage ∈ {0, 6.2e8…3.75e10},
amountIn 1 wei–3M FRAX), 94,531/200,000 random cases (47.3%) had `_minAmountIn > amountIn`, but the
gap is dust: mean ~539k wei (~5.4e-13 FRAX), max ~3.2M wei (~3.2e-12 FRAX). The reverse wrapper
`swapTokensForExactTokens` is unaffected (same `_getAmountIn` formula both times → exact equality).
**Kill reason (FRAX bar):** revert-only, zero funds at risk, trivially workaroundable (retry with a
larger `amountIn` buffer, or call `swap()` directly paying `_minAmountIn`). No theft, no freeze
(stop/swap paths unaffected). A mainnet-fork PoC would demonstrate only a reverted call.

## NQ-B-2 — `_getAmountIn` denominator zero / underflow at extreme slippage

**Mechanism.** `amountIn = (amountOut * _preSlippagePrice) / (PRECISION - (amountOut *
priceSlippage) / PRECISION)` (:244–246). The denominator hits ≤ 0 (division-by-zero panic or
checked-arithmetic underflow revert) when `amountOut ≥ 1e36 / priceSlippage`: at the historical max
slippage 3.75e10 that needs 26.7M tokens (above every historical listing, max 3M); at slippage =
1e18 it needs just 1 token; at `type(uint64).max` it needs 0.054 tokens. Slippage is set solely by
the timelock in `startAuction`; no bound exists in the auction.
**Kill reason:** requires the trusted timelock/operator to choose pathological parameters; effect is
swap-revert only; `stopAuction` (no denominator math) always recovers listed funds, so no permanent
freeze. No unprivileged trigger exists.

## NQ-B-3 — The 50% slippage cap present in v1.0.0 is absent in live v1.0.1 (regression datum)

**Mechanism.** Per CORRESPONDENCE-FXB.md §6, the FxbAMO-bundled v1.0.0 `SlippageAuction.sol` had a
`PriceSlippageTooHigh` 50%-cap check in `startAuction`; the live/HEAD v1.0.1 has no slippage bound
(`startAuction` checks only expiry, `amountListed ≥ 1e8`, `priceStart ≥ priceMin`, and the
priceMin/slippage both-zero case, :368–380), and FxbAMO's `startAuction` (evidence-only) caps only
`priceMin` (time-weighted floor), expiry, and amount — not slippage or decay.
**Kill reason:** slippage only ever *raises* `amountIn` (smaller denominator) and *raises* the next
`priceLast` (2× slippage term); there is no underpricing direction. Worst case is buyer overcharge
or NQ-B-2 brickage, both operator-chosen and stop-recoverable. No attacker-controlled theft path.

## NQ-B-4 — Zero / near-zero decayed price (priceMin = 0 + decay)

**Mechanism.** `startAuction` permits `priceMin == 0` with nonzero slippage. `getPreSlippagePrice`
(:124) then decays to 0, at which point `getAmountOut` divides by zero for small `amountIn`
(denominator `0 + floor(slippage*amountIn/PRECISION)` = 0 when `slippage*amountIn < PRECISION`),
and `_getAmountIn` returns `amountIn = 0`, which `swap()` rejects via `InputAmountZero` (:516).
Near-zero (but nonzero) decayed prices would let buyers acquire FXB for dust.
**Kill reason:** requires the trusted operator to start an auction with `priceMin = 0` (a Dutch
auction decaying to zero is the parameterized behavior, not a bypass); the zero case is explicitly
defended by the `InputAmountZero` revert; FxbAMO additionally enforces a `priceMin` floor (live
floor value unresolved — see Unresolved Cross-References). No unprivileged trigger.

## NQ-B-5 — Direct FRAX donations subsidize the next buyer and are absorbed into `tokenBuyReceived`

**Mechanism.** `swap()` computes `_tokenBuyIn = balance − detail.tokenBuyReceived` (:491–492) and
then sets `tokenBuyReceived =` full balance (:520). FRAX sent directly to the contract (not via a
swap) therefore counts toward the next buyer's payment, and is relabeled from "excess" to "received"
instead of being counted in `amountExcessBuy` at `stopAuction` (whose skim, :439, then finds zero
excess). The donation still ends with the timelock at `stopAuction`; only the buyer/seller split of
who paid for the FXB changes.
**Kill reason:** no live donations exist (all `amountExcessBuy`/`amountExcessSell` are 0 across all
33 historical runs) and no protocol flow creates donations; exploiting it requires a victim who
gifts FRAX to the contract address. Gift-redirection dependent on a donor's error is not a
demonstrated theft path against the live deployment. (The symmetric case — donated FXB — is swept to
the timelock at stop/start and cannot be bought without payment, since `amountLeft` never includes
it.)

## NQ-B-6 — `startAuction` sweep books prior leftovers as excess on the NEW auction

**Mechanism.** `startAuction` pushes the new `Detail` first (:392), then
`_withdrawAnyAvailableTokens({_excess: true})` (:420) sweeps ALL balances (prior balance 0) to
`msg.sender` (the timelock) and books them into the new detail's `amountExcessBuy/Sell`
(:627–645, always indexing `details[details.length − 1]`).
**Kill reason:** intended behavior, asserted by `test_StartAuction_WithdrawAnyAvailableTokens_succeeds`
(StartAuctionTest.t.sol:133). The recipient is the timelock — the correct party (the previous
auction's `stopAuction` is required first, and it drains to the same timelock, so only
between-stop-and-start donations can be present). No misdirection; only cross-auction labeling of
excess counters, with no fund-flow consequence.

## NQ-B-7 — `stopAuction` overwrites `tokenBuyReceived`/`amountLeft` with raw balances; raw `uint128()` casts

**Mechanism.** `stopAuction` (:430) skims excess over the bookkept priors, then sets
`detail.tokenBuyReceived = uint128(tokenBuyReceived)` and `detail.amountLeft =
uint128(tokenSellRemaining)` from post-skim raw balances (:449–450), using truncating casts rather
than `safeUint128` as `swap()` does. If a balance somehow fell below its prior (deflationary token),
the overwrite silently lowers the bookkept figure; if a balance exceeded `uint128.max`, it would
truncate.
**Kill reason:** with standard tokens the post-skim balances equal the priors exactly (skim removes
precisely `balance − prior`), so the overwrite is the identity and FxbAMO's derived `fxbSold =
listed − unsold` stays consistent. The truncation magnitude (3.4e38) is unreachable (total FRAX
supply 2.19e26; historical balances ≤ 3M). No fund diversion in any reachable state.

## NQ-B-8 — Factory `getAuction` off-by-one: `>` instead of `>=`

**Mechanism.** SlippageAuctionFactory.sol:75: `if (_index > auctions.length) revert
AuctionDoesNotExist();` — `_index == auctions.length` passes the check and then reverts with a
panic (array out-of-bounds) on `auctions[_index]` instead of the custom error.
**Kill reason:** view-only function; both paths revert, so no caller can obtain a wrong address or
move funds. Wrong-error-selector cosmetic defect only.

## NQ-B-9 — Permissionless factory creation: registry pollution / impersonation, no duplicate check

**Mechanism.** `createAuctionContract` (Factory:38) is permissionless (natspec: "Permission-less
factory"), takes any caller-chosen `_timelock` and any 18-decimal tokens, registers the result in
`auctions[]`/`isAuction` and emits `AuctionCreated`. The declared `AuctionAlreadyExists` error
(:94) is never used — unlimited duplicates are allowed.
**Kill reason:** no on-chain consumer relies on the registry as a trust anchor. Grep over
`src/**/*.sol` finds `isAuction`/`getAuctions` used only in tests; FxbAMO (evidence-only) keeps its
own `auctionDetails` mapping, only operates auctions it created, and gates on `isFxbApproved` +
`BondNotApproved`. A fake auction can only sell tokens its own timelock funds, and `TOKEN_SELL` is
publicly readable. No demonstrated on-chain victim; UI-spoofing concern only, and permissionless
creation is the documented design.

## NQ-B-10 — Factory validates only `decimals() == 18`: zero timelock, buy == sell, exotic tokens

**Mechanism.** `createAuctionContract` does not reject `_timelock == address(0)` (auction can never
be started/stopped; directly-sent tokens would be stuck), `_tokenBuy == _tokenSell`, or
fee-on-transfer / rebasing / ERC-777 tokens, whose behavior breaks the auction's balance-delta
accounting (rebasing-down buy token → `_tokenBuyBalance − tokenBuyReceived` underflow panic in
`swap()`; fee-on-transfer sell token → `amountLeft` overstates deliverable balance, bricking the
tail of the auction).
**Kill reason:** all parameters are the creator's own choice (self-inflicted for factory users); the
LIVE auctions use FRAX/FXB, whose standard behavior is evidenced by exact-to-the-wei accounting
across all 33 historical runs (operator-counter cross-check in ONCHAIN-GROUNDWORK-FXB.md §5.1).
No live exotic-token auction exists or can be created through FxbAMO (fixed FRAX/FXB pair).

## NQ-B-11 — `skim`/`sync` are silent no-ops while sibling UniV2 stubs revert

**Mechanism.** `skim(address)` (:274) and `sync()` (:279) are `pure` no-ops that return success
without moving funds or updating state, while `getReserves`, `factory`, `initialize`, etc. revert
`NotImplemented()`. An integrator calling `skim()` expecting excess-token recovery would silently
get nothing.
**Kill reason:** no contract in scope calls `skim`/`sync` (grep: no callers in `src/` outside the
definitions); UniV2 routers do not call them during swaps. Integrator-confusion only, no
demonstrated on-chain harm or fund flow.

## NQ-B-12 — `getAmountOut` clamp mode misreports `_postPriceSlippage`

**Mechanism.** With `_revertOnOverAmountLeft == false`, `getAmountOut` clamps `amountOut` to
`amountLeft` (:176–179) but returns `_postPriceSlippage` computed from the full unclamped `amountIn`
slippage term. The router-compat overload `getAmountOut(amountIn, tokenIn)` (:268) always uses
clamp mode.
**Kill reason:** view-only misinformation; execution (`swap()` via `_getAmountIn`) reverts rather
than clamps when `amountOut > amountLeft`, so no swap can execute at the misreported price.

## NQ-B-13 — Empty-`details` panic (`details.length − 1` underflow) on never-started auctions

**Mechanism.** `swap`, `getAmountOut`, `getAmountIn`, `getAmountInMax`, `stopAuction`, and the
no-arg `getPreSlippagePrice()` all index `details[details.length − 1]` without an emptiness check,
panicking on auctions 0 and 3 (never started). Observed on-chain: `getAmountOut()` on auction #0
reverts with an overflow panic (ONCHAIN-GROUNDWORK-FXB.md §5). Only `getLatestAuction()` handles
the empty case.
**Kill reason:** revert-only on fundless, never-started contracts; a panic reverts the whole call
exactly as a custom error would. No funds, no state corruption.

## NQ-B-14 — `startAuction` allows `expiry == block.timestamp` (instantly expired auction)

**Mechanism.** The check is `if (_params.expiry < block.timestamp) revert Expired()` (:368), so an
expiry equal to the current timestamp passes; the auction is immediately unswappable
(`block.timestamp >= expiry` reverts in `_getAmountIn`/:231) while `amountListed` has already been
pulled in.
**Kill reason:** operator parameter error only; `stopAuction` has no expiry check and recovers the
listed tokens immediately. No freeze.

## NQ-B-15 — Inherited timelock renounce could strand an active auction's funds (unreachable live)

**Mechanism.** `Timelock2Step.renounceTimelock` (dependency, 2-step via self-transfer) sets the
timelock to `address(0)`. If executed mid-auction, nobody could ever `stopAuction`; swaps would run
until expiry and then received FRAX + unsold FXB would be permanently stuck (no rescue function).
**Kill reason:** unreachable for live auctions — FxbAMO (the sole timelock of all 5) contains no
call to `renounceTimelock`/`transferTimelock`/`acceptTransferTimelock` on auctions (grep of the
evidence-only source), and the Safe cannot call the auctions directly. Requires trusted-timelock
self-harm. Generic inherited-admin-footgun, not an attacker path.

## NQ-B-16 — `priceLast` 2×-slippage update and `lastBuyTime` reset across buys

**Mechanism.** Each `swap()` sets `priceLast = _preSlippagePrice + 2 * _slippagePerTokenSell` and
`lastBuyTime = now` (:521–522). A large buy pumps the next price up; frequent small buys keep
resetting the decay clock near the decayed price.
**Kill reason:** intended mechanism (code comment: "Price impact is twice the slippage"; covered by
`PostSlippagePriceTest`). `priceLast` can only rise on a buy and only fall via time decay floored at
`priceMin`; every buy pays at least the current decayed minimum. No sequence of buys manufactures a
below-floor price. MEV/sandwiching around decay is inherent to a Dutch auction, not a defect.

## NQ-B-17 — Wrapper `path` parameter ignored; raw `swap()` has no deadline or slippage cap

**Mechanism.** Both wrappers take `path` and discard it (`path; // compile warnings`, :553/:590)
without validating endpoints; raw `swap()` (documented low-level: "should be called from a contract
which performs important safety checks") enforces only the auction's own minimum via balance delta,
with no caller-side `amountOutMin`/deadline. Wrappers do check `block.timestamp > deadline`
(allowing equality, matching UniV2 convention).
**Kill reason:** documented caller-responsibility design; wrapper return values (`amountIn`,
`amountOut`) are accurate for the single-hop auction trade actually executed. No contract-level
fund diversion.

## NQ-B-18 — `uint32` time truncation and caller-supplied-`Detail` decay underflow

**Mechanism.** `lastBuyTime`/`expiry` are `uint32` (truncation at year 2106); the public
`getPreSlippagePrice(Detail)` (:124) computes `block.timestamp − _detail.lastBuyTime` on
caller-supplied input, underflowing (panic) if `lastBuyTime` is in the future; the no-arg overload
uses stored state where `lastBuyTime ≤ block.timestamp` always (timestamps are non-decreasing and
`lastBuyTime` is set to `now` at start/buy).
**Kill reason:** year-2106 truncation is out of any live horizon (last FXB matures 2027-01-01);
the public-view underflow needs adversarial input to a view function and harms only the caller.

## NQ-B-19 — Decay natspec says "per day", code uses per second

**Mechanism.** The `AuctionStarted` event comment says "Price decay, per day" while
`getPreSlippagePrice` multiplies `priceDecay` by elapsed seconds (:126); the `Detail` natspec
correctly says "wei per second".
**Kill reason:** documentation inconsistency only; code behavior matches tests and the 33
historical runs. No runtime effect.

## NQ-B-20 — `safeUint128` overflow reverts on extreme `priceLast`/amounts

**Mechanism.** `swap()` routes `amountLeft` decrements, `tokenBuyReceived`, `priceLast`, and `Buy`
event fields through `safeUint128` (:519–535), reverting with `Overflow()` if any exceeds
`uint128.max` (reachable only with extreme operator-set `priceStart`/`priceSlippage`).
**Kill reason:** revert-only, fail-closed direction (prevents silent truncation); requires trusted
operator parameters; historical values are ~1e18, nowhere near 3.4e38.

## NQ-B-21 — `swap()` transfers tokens and runs the flash callback BEFORE active/expiry/amountLeft checks

**Mechanism.** `swap()` (:473) transfers `amount1Out` to `to` and invokes `uniswapV2Call` before
`_getAmountIn` checks active/expiry/`amountLeft` and the input-minimum invariant (:508–516).
**Kill reason:** any check failure reverts the entire transaction, rolling back the transfer and
all callback effects atomically (verified reasoning: no state change survives a revert, including
in callee contracts). Reentrancy during the callback is blocked by `nonReentrant` on
`swap`/`startAuction`/`stopAuction`, and the callback cannot change stored auction state (no other
state-changing path is reachable by a non-timelock caller). Ordering costs gas on revert, not funds.
Checked explicitly: callback-time calls to the wrappers reenter guarded `swap()` and revert;
`stopAuction`/`startAuction` additionally require the timelock; `skim`/`sync` move nothing.

## NQ-B-22 — `Swap`/`Buy` events report donation-inflated `amountIn`

**Mechanism.** The `Swap` event's `amount0In` and the `Buy` event's `amountIn` use `_tokenBuyIn`
(balance delta), which includes any pre-existing donated FRAX (see NQ-B-5).
**Kill reason:** off-chain reporting only; no on-chain consumer reads these events. No fund effect.

## NQ-B-23 — No upper bounds on `priceStart` / `priceDecay`

**Mechanism.** `startAuction` bounds `priceStart` only from below (`≥ priceMin`); an astronomic
`priceStart` prices out all buyers and a huge `priceDecay` pins the price at `priceMin`
immediately.
**Kill reason:** operator parameter choice; the auction remains stoppable and funds recoverable.
No attacker trigger.

## NQ-B-24 — `getAuctions()` returns an unbounded array; permissionless creation grows it

**Mechanism.** `getAuctions()` (Factory:65) returns the full `auctions` array; anyone can append by
paying deployment gas.
**Kill reason:** view-only enumeration; no on-chain caller exists (FxbAMO uses its own array).
Off-chain pagination inconvenience at most.

## NQ-B-25 — Prior-audit fixed forms re-verified (EX-F02, EX-F03) — not findings

- **EX-F02 (TOB-3, array OOB):** VERIFIED FIXED — both wrappers execute
  `_amounts = new uint256[](2);` before index assignment (SlippageAuction.sol:571–573 and 607–609
  in v1-live numbering).
- **EX-F03 (TOB-4, swapped swap args):** VERIFIED FIXED — both wrappers call
  `swap({ amount0Out: 0, amount1Out: amountOut, ... })` with named arguments, consistent with
  `swap()` requiring `amount0Out == 0` and `amount1Out != 0` (:474–475).
- Also confirmed no re-report of EX-F01 (FXB rescue — different contract, out of this domain).

## Hunt-focus items checked with no observation (negative results)

- **Flash-swap callback ordering:** transfer-out → callback → balance-delta check is sound; payment
  is enforced by the post-callback balance check + atomic revert, not by the callback itself
  (calling `uniswapV2Call` on an EOA `to` with nonempty `data` succeeds silently but cannot bypass
  the balance check). Callback reentrancy into all state-changing auction functions is blocked
  (guard + timelock). Callback-time donation of FXB back to the contract only increases the
  timelock's stop-time excess; self-harm, not theft.
- **`amountListed` 1e8 rounding:** dust-amount buys that would price to zero `amountIn` are
  rejected by `InputAmountZero`; no free-buy path.
- **Restart state carryover:** new `Detail` zeroes excess counters, `tokenBuyReceived`, and resets
  `priceLast`/`lastBuyTime`; old details are immutable history; only the latest detail is ever
  read. No carryover except the intended NQ-B-6 excess labeling.
- **Expiry boundary:** `>=` consistently enforced in views and `swap()`; `stopAuction`
  deliberately has no expiry check (recovery always available).
- **`uint128`/`uint64` packing:** `amountOut * price` products are bounded below 2^256 by the
  `uint128`/`uint64` field widths given `_getAmountIn`'s `amountOut ≤ amountLeft` check;
  `amountIn * PRECISION` overflow in `getAmountOut` needs a caller-supplied view input > ~1e59
  and reverts harmlessly.
- **Reentrancy coverage of wrappers:** wrappers lack their own guard but their only state-changing
  call is guarded `swap()`; the pre-swap `transferFrom` cannot reenter usefully (FRAX/FXB are plain
  ERC20s with no transfer hooks; generic-token hook reentry would still have to pass the guard or
  the timelock check).
- **Donation / excess / FoT / rebasing under live tokens:** live buy/sell tokens are FRAX and FXB;
  33 historical runs reconcile exactly to the wei against independent operator counters, evidencing
  standard-token behavior. Exotic-token breakage is NQ-B-10 only.

## Coverage

**Files scanned (assigned, report scope):**

| File | Lines | Status |
|---|---|---|
| `work/v1-live/auction-tree/src/contracts/SlippageAuction.sol` | 778 (incl. 2 provenance lines) | Fully read, all functions traced |
| `work/v1-live/auction-factory-tree/src/contracts/SlippageAuctionFactory.sol` | 104 (incl. 2 provenance lines) | Fully read |

**Files read as evidence only (no findings reported in them):**

- `work/v1-live/auction-tree/src/contracts/interfaces/IUniswapV2Callee.sol` (callback interface)
- `work/v1-live/amo-evidence-only/src/contracts/FxbAMO.sol` (operator capabilities: `startAuction`/
  `stopAuction` gating, `priceMin` floor, allowance/mint flow; grep-confirmed no auction
  renounce/transfer calls, no slippage/decay caps)
- `repos/frax-bonds/lib/frax-standard-solidity/src/access-control/v2/Timelock2Step.sol`
  (timelock/renounce semantics)
- Repo tests (intended behavior only): `src/test/SlippageAuction/*.t.sol` (Swap, StartAuction,
  StopAuction, SwapExactTokensForTokens, SwapTokensForExactTokens, GetAmountIn/Out/Max,
  GetPreSlippagePrice, PostSlippagePrice, InsufficientInputAmount),
  `src/test/SlippageAuctionFactoryTest.t.sol`, `src/test/fuzz/SlippageAuction/*.t.sol`,
  `src/test/e2e/E2ESlippageAuction.t.sol` (listed, key assertions sampled; fuzz bounds noted)
- `exclusions/EXCLUSION_LIST_FXB.md` (full), `CORRESPONDENCE-FXB.md` (full),
  `ONCHAIN-GROUNDWORK-FXB.md` (full)

**Files skipped:** none within the assigned scope. The HEAD duplicates at
`repos/frax-bonds/src/contracts/SlippageAuction.sol` and `SlippageAuctionFactory.sol` were not
separately hunted after the diff proved equivalence (see Scope-deciding facts); `specification/`
mirror files were not read (non-authoritative copies, out of assigned paths).

## Unresolved cross-references (named, not assumed)

1. **Live `globalMinPriceMin` and per-`TimeToMaturity` `minPriceMin` values on FxbAMO** are not in
   the groundwork evidence. FxbAMO's constructor leaves `globalMinPriceMin` at 0 (timelock-settable
   via `setGlobalMinPriceMin`); if all floor values were 0 on-chain, a `priceMin = 0` auction would
   be startable *by the trusted operator*. This does not change any verdict (operator-trusted
   parameters either way; NQ-B-4), but a fork PoC for any price-floor claim would need these values.
2. **FRAX/FXB token implementations** were not source-verified in this domain (out of scope);
   standard-ERC20 behavior is inferred from exact historical accounting reconciliation, not from
   token source. Any FoT/rebasing claim would need token-source verification.
3. **No EVM execution was performed:** `cast`/`forge`/`anvil`/`solc` are not installed (verified
   per skill §14) and no fork PoC was run. NQ-B-1's quantification rests on exact-integer Python
   replication of the two pricing formulas (200k samples × 2 ranges), not on-chain execution. All
   other entries rest on code traces. No claim above is presented as an executed reproduction.
4. **No web browsing and zero GitHub API calls** were made, per task constraints. The v1.0.0
   slippage-cap datum (NQ-B-3) is taken from CORRESPONDENCE-FXB.md §6, not independently re-verified
   against the FxbAMO-bundled tree in this pass.
