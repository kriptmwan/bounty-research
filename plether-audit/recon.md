# Plether Perps — Recon

- **Repo:** `~/workspace/plether-audit/repo/`, pinned commit `a82d4fefb02768e5b3bddcc97dee371eee24fea8` (verified via `git rev-parse HEAD`).
- **Target:** `packages/perps/src` — Solidity, Arbitrum (Arbitrum Sepolia deployments in repo), USD-strength-index perpetuals.
- **Competition ends:** Mon 16 Nov 2026 17:00 WIB. POCs required for all severities.
- **Method (read-only):** `SECURITY.md` read fully (1555 lines); `README.md`, `ACCOUNTING_SPEC.md`, `CANONICAL_ENTRYPOINTS.md`, `ORACLE_SYNCHRONIZATION.md`, `INTERNAL_ARCHITECTURE_MAP.md` read fully; `EMERGENCY_RESPONSE_GUIDE.md` read fully (264 lines, skim brief was exceeded — it is short); contract headers/`@title`/`@notice` + declarations skimmed for all 131 `.sol` files under `src/`. No builds, no installs, no repo modifications.
- **Status of this document:** recon only, per the adversarial pipeline. No findings are stated here. Where a doc states a limitation or accepted risk, it is recorded as a stated property, not a finding.
- **Naming note:** prior audit reports (Oct 2026 and earlier) call the settlement token USDC; the pinned code uses **USDG** (6 decimals; `MockUSDG` on the Sepolia testnet stack). Identifiers in code say `Assets`/`Usdc` in places (e.g. `settleUsdc`, `getSettlementFreeUSDC`) but denote the configured settlement token. Do not treat the USDC/USDG wording difference as a defect.

## 0. The market in one paragraph

One market: leveraged exposure to USD strength, tracked by a Pyth FX basket ("basket mark", 8 decimals). The mark moves inversely to dollar strength: **LONG profits when the basket mark falls** (dollar strengthens), **SHORT profits when it rises**. The mark is capped at immutable `CAP_PRICE` (deployment scripts used `2e8`; the value is a constructor immutable — verify per deployment). Traders post USDG margin in a clearinghouse; LPs supply counterparty capital via Senior/Junior tranche vaults sharing one HousePool. Orders are **delayed**: trader commits a bounded intent, a permissionless keeper later executes it at the first unique Pyth tick strictly after `commitTime` (historical parse), FIFO-ordered. Traders pay **carry** (LP-capital carry, not long/short funding) plus a signed skew charge/rebate (**VPI**, virtual price impact). Each account holds at most **one position at a time**; positions are whole 100-token lots (`SIZE_QUANTUM = 1e20`, sizes 18 decimals). LP shares use 9 decimals (ERC-4626 offset 3 over 6-decimal USDG).

## (a) Architecture summary

### Core contracts

| Contract | Role |
|---|---|
| `MarginClearinghouse` | **Trader USDG custody.** Free settlement, PnL pledge (isolated position margin), liquidation reserve, VPI rebate reserve, committed-order margin, execution/trigger bounty reserves. Owns the reservation ledger and bounty ledger. Broad operator authority: Engine + settlement sidecar only; Router has narrow reservation paths; protection Book has narrow bounty paths. |
| `OrderRouter` (+ `src/router/*` handler bases) | **Order entry + execution orchestration.** Global FIFO, per-account pending orders, commit validation, execution orchestration via delegatecall sidecars, liquidations, mark refresh, atomic LP settlement entry. Does not hold funds; does not price LP shares; cannot call HousePool inflow hooks directly (Router-sourced value credits treasury via clearinghouse accounting). |
| `OrderLifecycleBook` | **Permanent order identity + authenticated outcomes.** Independently predeployed, immutable-bound to the predicted Router + exact Engine/Clearinghouse/HousePool. Owns `(account, clientOrderId)` → intent-hash idempotency forever, pending policy/timing, config-hash digest, compact terminal outcomes + full-receipt hashes. Holds no tokens. Only the bound Router may register/finalize. |
| `PositionProtectionBook` | **TP/SL protection state.** `PendingOpen` / `Armed` / `Triggered` / `Latched` lifecycle, trigger bounty, close-limit ceilings, latest-attempt linkage. Created by and immutable-bound to Router + Engine. Calls narrow Router hooks to create close orders; cannot execute or move pool cash. |
| `PletherOracle` | **Pyth basket oracle.** Validates signed basket data (six-feed basket per DEPLOYMENT.md; feed ids/weights/bases/inversion flags + Pyth endpoint fixed per instance). Maintains the accepted live basket (Router-only updates), historical execution prices (`parsePriceFeedUpdatesUnique` + stored-feed coverage check), frozen replay, side-adverse confidence adjustments, ETH fee/refund accounting (`claimableEth`). |
| `CfdEngine` | **Position ledger + risk + settlement accounting.** Positions, carry indexes, risk admission, trader claims, settlement plans (via planner), degraded mode, protocol treasury lock/scheduling (inherited `CfdTreasury`), recapitalization. Holds no trader/LP funds; acts through Clearinghouse + HousePool. Owns the cached Engine mark. |
| `CfdEnginePlanner` + `CfdEnginePlanLib` | **Deterministic plan→apply economics.** Stateless planner contract wrapping the pure planning library: builds open/close/liquidation plans from canonical snapshots. The Engine applies plans; the evaluator and lenses reuse the same planner. Review rule in SECURITY.md: execution must apply the canonical planner's economics, never recompute a different result. |
| `CfdEngineSettlementSidecar` | **Engine-authorized settlement executor** for open/close/liquidation flows, via Engine host hooks. Mutations accept only the immutable-bound Engine; read-only `buildRawSnapshot` also accepts the Engine's planning reader. |
| `TerminalNavBookV2` | **Aggregate account-capped terminal price curves** for LP NAV. Only the bound Engine may synchronize curves, from canonical Engine/Clearinghouse state. No owner, no repair/migration path. Does not measure available cash. |
| `HousePool` | **LP capital custody + Senior/Junior waterfall.** Recognized pool USDG (`totalAssets() = min(raw, accounted)`), coupon/HWM accounting, LP epoch clock (round-hour), synchronized epoch settlement (reconcile → fund Senior redemptions → Junior redemptions → activate Junior deposits → Senior deposits), senior capacity/reservations, seed lifecycle, excess/unassigned asset handling, entry pause + independent settlement hold. |
| `TrancheVault` (×2: Senior + Junior) | **LP shares + async requests.** ERC-4626/7540-style: `requestDeposit`/`requestRedeem` → epoch settlement → claim via `deposit`/`mint`/`redeem`/`withdraw`. Holds deposit escrow + funded-redemption escrow. Chooses request epochs from the Pool clock; only the Pool activates deposits / funds redemptions. Junior vault carries the optional maintenance-fee (share-dilution) config. |
| `PerpsPublicLens` | Compact read-only product views (trader/LP/protocol). |
| `SettlementMonitorLens` (+ sidecar) | Bounded advisory diagnostics: settlement route selection (`CachedMark` vs `AtomicOracleRefresh`), oracle/queue/custody health, fault masks. Fail-soft; cannot authorize settlement or pause anything. |
| `EmergencyPauseCoordinator` | Three fixed guardian containment actions (see §b). No unpause surface. |
| `CfdEngineAdmin` / `OrderRouterAdmin` | Timelocked (72h) owner-controlled config admins (see §b). Each deployed admin applies finalized values onto its host; each has `activeConfigVersion` starting at 1. |
| `CfdOrderPolicyEvaluator` (+ `CfdOrderPolicyEvaluatorBase`) | Stateless, permissionless evaluation of current Engine state against a caller's pinned financial bounds. Not a custody authority; the Router sidecar pins its address, validates return shape, and compares assessed fields against live pre/post state. |
| `CfdClosePreview` / `CfdEngineLens` / `CfdEngineAccountLens` / `CfdEngineProtocolLens` / `CfdEngineOpenQuoter` / `CfdEnginePlanningReader` | Read-only planning/preview/diagnostic surfaces. `CfdClosePreview` projects a prospective zero-bounty close including commitment carry. `CfdEnginePlanningReader` is created by the Engine constructor, immutable-bound to it, and builds read-only planner requests. `CfdEngineOpenQuoter` is a stateless interval search for max valid open, deployed by the Lens for EIP-170 size reasons. |
| Sidecars: `OrderRouterExecutionSidecar`, `OrderRecoverySidecar`, `OrderRouterLiquidationBatchSidecar`, `HousePoolRedemptionMathSidecar`, `SettlementMonitorLensSidecar` | Fixed delegate/stateless implementation modules (see "Delegatecall boundaries" below). Not public entrypoints. |

### How they interact (custody vs authority)

USDG custody lives in exactly two places: `MarginClearinghouse` (trader balances) and `HousePool` + `TrancheVault` escrows (LP capital). The Engine and Router **authorize transitions but hold no balances**. Protocol fees and keeper rewards are credited as clearinghouse accounts first, then withdrawn through the ordinary withdrawal path. A trader claim is a recorded liability, not segregated cash.

```
Trader wallet --deposit--> MarginClearinghouse --losses/carry--> HousePool
MarginClearinghouse <--payouts-- HousePool (via Engine/settlement sidecar payOut)
LP wallet --requestDeposit--> TrancheVault escrow --activate--> HousePool
HousePool --fund redemption--> TrancheVault escrow --claim--> LP wallet
```

Order flow: Trader `commitOrder` → Router validates + reserves (Clearinghouse) + registers intent (LifecycleBook) + FIFO append → Keeper `executeOrder`/`executeOrderBatch` with Pyth payload → Oracle resolves historical/frozen price → Evaluator assesses pinned policy via Planner → Engine applies plan → Clearinghouse/Pool settle → Router settles bounty → LifecycleBook finalizes authenticated receipt (last; failure rolls back the item).

LP flow: LP requests via vault (epoch target from 5-minute cutoff rule) → permissionless epoch settlement via `HousePool.settleLpEpoch` (cached-mark route, no positions or frozen) or `OrderRouter.settleLpEpoch` (atomic oracle refresh, live positions) → Pool reconciles once, funds redemptions Senior-first, activates deposits Junior-first → LP claims shares/assets from vault escrow.

Protection flow: Owner arms TP/SL in `PositionProtectionBook` (trigger bounty reserved) → permissionless `triggerPositionProtection` with oracle data pays trigger reward once and queues a full-close attempt (zero bounty) → attempt failure with exact same position relatches (`Latched`) for permissionless `retryPositionProtectionClose`; position change fails the protection.

### Key mechanisms (one line each)

- **Delayed execution:** fills use the first unique Pyth tick in `(commitTime, min(commitTime + orderSettlementWindow, block.timestamp)]`; the Engine never rewinds a newer cached mark for an older fill.
- **Bounded liability:** price PnL bounded by size, exact entry cost, and `[0, CAP_PRICE]`; `longMaxProfit` = Σ LONG entry costs; `shortMaxProfit` = Σ (lots×CAP − entry cost).
- **Settlement buffer:** opens require post-op `E ≥ L + B`, `B = ceil(L × settlementBufferBps / 10_000)` (default 25 bps); closes/liquidations may consume `B`; raw insolvency (`E < L`) latches `degradedMode`.
- **Carry:** LP-capital carry on `max(positionMaxProfit − activePositionMargin, 0)`, utilization vs `economicDepth = max(P − C, 0)`; accrues by wall clock, never pauses when stale/frozen; collected margin-first then free settlement; unpaid carry blocks withdrawal / makes account liquidatable; claims cannot fund carry.
- **VPI:** signed skew charge/rebate, separate from price PnL; negative lifetime VPI backed by a dedicated reserve `max(−vpiAccrued, 0)`; lifetime rebate clamp zeroes rebate-only round trips; partial-close VPI release is a bounded linear approximation.
- **Symmetric exact NAV:** `signedTerminalEquity = physicalAssets − traderClaims + terminalLpPriceDelta` (account-capped at `pnlPledge + same-account claim`); same view prices entry and exit; receivables never fund redemptions before collection; terminal deficit blocks deposit activation.
- **Waterfall:** Senior gets junior-funded coupon (capped by available junior principal) + HWM protection; Junior absorbs losses first, gets residual; Senior exposure `E = max(projected principal, HWM)`, counted admission exposure `C = E + R` (R = pending Senior reservations).
- **Epochs:** round-hour epochs; both tranches/directions share the 5-minute cutoff (`e+1` before `b−300`, `e+2` at/after); maturity (`currentEpoch ≥ requestId`) does not guarantee funding/activation.
- **Frozen/FAD:** FAD = scheduled close-only window, elevated margins, still live oracle. `oracleFrozen` = feeds genuinely offline: closes use stored Engine mark + fixed LP-owned frozen spread (default 50 bps) instead of adverse-confidence shift; LP redemption funding stays live with tranche surcharges (default 25 bps Senior / 75 bps Junior); deposit activation deferred; new protection triggers unavailable.
- **Failure classification:** only exact-shape typed policy failures are terminal; unknown/panic/OOG/empty/malformed failures leave the order pending (retryable). Terminal receipt finalization is last and fail-closed.

## (b) Trust boundaries

### Actors

| Actor | Powers / entry surface | Trust note (per docs) |
|---|---|---|
| **Trader (account owner)** | Deposit/withdraw margin; `addMargin`; `commitOrder`; `settleTraderClaim`; create/replace/cancel protection; claim LP requests as controller/operator. Cannot cancel a committed order. | Self-custody of intent: every fresh request pins client id, target, `submitBy`, execution window, mode mask, config hash, financial bounds. |
| **Keeper (permissionless)** | `executeOrder`, `executeOrderBatch`, `expireOrder`, `clearInvalidOrders`, `updateMarkPrice`, `triggerPositionProtection`, `retryPositionProtectionClose`, `executeLiquidation`, `executeLiquidationBatch`, `clearRiskOffOrder`, LP epoch settlement (both routes). | Untrusted executor. Paid reserved bounties (opens/trigger/liquidation); closes pay **zero** execution bounty — keeper funds gas + oracle fees. Cannot change intent, price selection beyond supplying Pyth payloads within oracle policy, or bypass FIFO (except oracle-free cleanup of expired/config-invalid orders, including non-head). |
| **Owner / governance (per-contract `Ownable2Step` owners)** | See privileged powers below. Owners differ per contract (Engine, EngineAdmin, RouterAdmin, HousePool, Clearinghouse, Coordinator); deployment presumably aligns them — verify bindings, do not assume one owner. | Trusted to configure within timelocks and to release containment; cannot change logic, `CAP_PRICE`, rewrite history, seize arbitrary funds, or bypass solvency/withdrawal accounting (stated). |
| **Guardian (via `EmergencyPauseCoordinator`)** | Exactly 3 fixed actions: `triggerEmergencyPause` (Router risk-off + LP-entry pause), `triggerLpEpochSettlementHold`, `triggerFullContainment` (all three). No mask, no unpause, no config, no funds, no arbitrary calls. | Guardian is set/rotated/disabled by coordinator owner (governance). Restrictions have no expiry; governance releases each component directly. |
| **Pauser (per-component)** | HousePool `pauser` and RouterAdmin `pauser` may `pause()` / `pauseLpEpochSettlement()`; only owner unpauses. Deployment installs the coordinator as both pausers. | Coordinator constructor checks nonzero distinct code-bearing targets, not stack membership — verify wiring. |
| **Pyth Network / Hermes payload suppliers** | Signed price data; keeper/anyone supplies payloads. Oracle validates signatures via Pyth, freshness, divergence, confidence. | Trusted for timely/correct FX data (stated assumption). Known limitations: caller may pick an older valid signed component within the window (live basket selection); sequencer/Pyth clock alignment (see EXCLUSION_LIST.md). |
| **USDG token** | Standard ERC-20 + practical dollar parity assumed. Blacklist/upgrade/centralization risks explicitly unmitigated in core design. | Settlement token is immutable per Engine/Clearinghouse; miswiring is a deployment concern (one-time setters). |
| **OpenZeppelin / deps** | ERC-20/4626/7540, Ownable2Step, Pausable, ReentrancyGuardTransient, Pyth SDK, ArbSys (execution block number). | Pinned versions; integration safety not established by library audits. |
| **Across / bridge handler** | `depositFor` destination-call integration (external handler + SpokePool, shared handler, permissionless callback). | External trust dependencies; verify runtime hashes + EIP-1967 slot. Out of the core perps target except `depositFor` itself. |

### Privileged powers

**Timelocked (72h propose/finalize, owner-only; successful finalization bumps `activeConfigVersion` and changes the execution config hash):**

| Parameter family | Admin → host |
|---|---|
| `EngineRiskConfig` (risk params, execution fee bps, frozen-close spread bps, settlement buffer bps) | `CfdEngineAdmin` → `CfdEngine` |
| `EngineCalendarConfig` (FAD day overrides, FAD runway) | `CfdEngineAdmin` → `CfdEngine` |
| `EngineFreshnessConfig` (`fadMaxStaleness`, engine mark staleness limit) | `CfdEngineAdmin` → `CfdEngine` |
| `RouterConfig` (execution window, staleness limits, confidence policy, settlement window, skew, opening minimum, bounty rates/limits, pending-order cap, min execution gas, cleanup cap) | `OrderRouterAdmin` → `OrderRouter` |
| `OracleConfig` (rotate `PletherOracle` address; new oracle instance required for feed/weight/Pyth changes) | `OrderRouterAdmin` → `OrderRouter` |
| `seniorRateBps`, `markStalenessLimit`, frozen LP fee bps (≤1000), `maxSeniorExposureAssets` / `maxSeniorShareBps` (finite / <100%) | `HousePool` owner, 72h |
| Junior `maintenanceFeeAprBps` (≤10,000 bps), `maintenanceFeeRecipient` | `TrancheVault`, HousePool-owner-only, 72h; finalization checkpoints elapsed fees to old recipient first |

**Instant owner controls:** pause/unpause Router opens+protection (RouterAdmin), pause/unpause HousePool entry, pause/unpause LP settlement independently, install/replace coordinator pauser, rotate/disable guardian, set protocol treasury (when unlocked; optionally starting a lock), propose/replace/cancel treasury successor during a lock, initialize tranche seeds, activate trading (after lifecycle/capacity gates), admit/sweep excess / assign unassigned assets (guarded bootstrap; cannot withdraw claimant backing), `recapitalizePool` (owner-funded, Engine pulls owner's USDG into Pool, no shares minted, degraded mode not auto-cleared), `clearDegradedMode` (once raw `E ≥ L`), rescue non-settlement tokens from Clearinghouse (`rescueToken`; USDG always excluded), initiate 2-step ownership transfer.

**One-time wiring (owner-only, irreversible; several setters do NOT validate reciprocal bindings — deployment must verify):** `CfdEngine.setDependencies` (planner, settlement sidecar, admin; validates sidecar/admin binding, not planner impl), `setTerminalNavBook` (empty book bound to Engine, matching CAP + quantum), `setPool`, `setOrderRouter` (no binding proof), `MarginClearinghouse.setEngine` (no binding proof), `HousePool.setSeniorVault/setJuniorVault` (no binding proof). Router constructor fixes Engine, Engine lens, HousePool, keeper sidecar, evaluator, execution sidecar, lifecycle Book. Lifecycle Book + liquidation-batch sidecar + Router deploy as one consecutive 3-`CREATE` nonce sequence with predicted Router address; a nonce failure leaves unusable immutable-bound deployments.

**Protocol treasury lock:** `setProtocolTreasury(treasury, duration 1s–90d)` activates immediately + locks; both setters revert while locked (even same address); during lock, owner may propose/replace/cancel a successor (activation at original expiry, automatic, no event at expiry); proposal duration (0–90d) sets successor's lock from activation; no emergency override; affects future fee routing only.

**Delegatecall boundaries (security-critical, per SECURITY.md):** `OrderRouterExecutionSidecar` (V3 execution, delegate-only, creates + binds `OrderRecoverySidecar`), `OrderRouterLiquidationBatchSidecar` (commits, mark refresh/trigger, liquidations, atomic LP settlement, oracle-config forwarding; reads Router via external getters, never assumed storage layout; changes Router state only via authorized self/item calls), `CfdEngineSettlementSidecar` (explicit Engine authorization, not Router delegate context), `HousePoolRedemptionMathSidecar` (pure, no storage/custody), `SettlementMonitorLensSidecar` (facade-only). Direct calls to sidecars revert (or, for the execution sidecar, cannot impersonate the Router because downstream caller checks authenticate the actual Router address). Any new external function on Router/Books/sidecars must be reviewed as a core custody change.

**Caller matrix (condensed from SECURITY.md):** LifecycleBook register/finalize = immutable Router only. `CfdEngine.processOrderTyped` = configured Router only. Clearinghouse broad ops = Engine + settlement sidecar; reservation paths = Router/protection Book by kind. `HousePool.payOut`/`recordClaimantInflow` = Engine/settlement sidecar (recap inflow Engine-only). Senior reserve/release hooks = configured Senior vault only. `HousePool.reconcile` = either configured vault. `HousePool.settleLpEpoch` = configured Router when positions exist outside frozen mode, else permissionless. `TerminalNavBookV2` mutations = bound Engine only. `PletherOracle` accepted-basket updates = configured Router only.

## (c) Canonical entry points

### Orders (trader → keeper)

| Action | Entrypoint | Notes |
|---|---|---|
| Fund | `MarginClearinghouse.depositMargin(uint256)` / `deposit` (owner; checkpoints carry); `depositFor(address,uint256)` (permissionless credit-only, no carry checkpoint, no Engine call) | Approve Clearinghouse first. Neither auto-allocates position margin. |
| Add margin | `CfdEngine.addMargin(account, amount)` | Owner-only, open position required, sufficient free settlement after carry. |
| Commit order | `OrderRouter.commitOrder(OrderRequest)` | Fresh V3: nonzero client id + target, explicit bounds, `submitBy`, `executionWindowSeconds` (≤ `maxExecutionWindowSeconds`, default 60s, gov max 1h), nonzero `expectedConfigHash` = current `OrderLifecycleBook.currentExecutionConfigHash()`, nonzero `maxPostLeverageBps` even for full closes. Close: zero `marginDelta`, zero bounty. Exact replay returns original id (idempotent, even after expiry); changed request under same client id reverts. Expiry strictly after `commitTimestamp + executionWindowSeconds`; equality still eligible. |
| Execute | `OrderRouter.executeOrder(orderId, pythUpdateData)` (payable, ETH fee); `executeOrderBatch(maxOrderId, data)` (inclusive id bound, not count) | Global FIFO head only. Returns `ExecutionResult`/`BatchResult`; tx success ≠ executed — verify lifecycle outcome. Historical fee = 2× Pyth fee (parse + update); cache reuse = 0. |
| Expire / cleanup | `OrderRouter.expireOrder(id)`; `OrderRouter.clearInvalidOrders(uint64[])` (≤ min(64, `maxPruneOrdersPerCall)`); `clearRiskOffOrder(id)` | Oracle-free, permissionless, unpaid. Expiry does not auto-release reservations. |
| Close / reduce | Same `commitOrder` with current side, lot-aligned size, zero marginDelta, explicit limits; preview via `CfdClosePreview.previewClose` | Commitment collects carry + records zero-bounty record. Partial close: healthy residual + size minimum + funded charges. Full close: terminal waiver rules. |
| Settle claim | `CfdEngine.settleTraderClaim(account)` | Owner-only, all-or-nothing; requires Pool cash covering **all** outstanding claims. Open position → PnL pledge; flat → free settlement. |
| Withdraw | `MarginClearinghouse.withdrawMargin(uint256)` | Carry + safety checks + reserve locks apply. |

### Position protection

| Action | Entrypoint |
|---|---|
| Open with protection | `PositionProtectionBook.commitOpenOrderWithProtection(request, params)` |
| Protect existing position | `PositionProtectionBook.createPositionProtection(params)` (available in degraded mode; Router pause + frozen restrictions still apply; exact-price safety gate via planner) |
| Replace / cancel (PendingOpen/Armed) | `replacePositionProtection(id, params)` / `cancelPositionProtection(id)` |
| Atomic owner exit | `cancelPositionProtectionAndCommitClose(id, request)` — Armed only, empty queue, exact side/size; failure rolls back cancellation; success permanently cancels protection |
| Amend latched limits | `amendLatchedPositionProtectionCloseLimits(id, limits)` — no pending Router order |
| Trigger (permissionless) | `PositionProtectionBook.triggerPositionProtection(id, pythUpdateData)` — pays trigger bounty once, queues one full close; requires later signed tick + later block than arming; unavailable while frozen |
| Retry latched (permissionless) | `PositionProtectionBook.retryPositionProtectionClose(id)` — nonpayable, fresh FIFO-tail attempt, no trigger re-evaluation, no new bounty |

Protection params must explicitly supply 4 close ceilings (`maxExecutionNotionalAssets`, `maxGrossAccountDebitAssets`, `maxActionChargeAssets`, `maxExplicitFeesAssets`); zero = zero allowance, `type(uint256).max` = explicit unlimited. Only Router-authenticated TP/SL attempts use `expectedConfigHash == 0` (internal unpinned marker).

### Liquidations (keeper, permissionless)

`OrderRouter.executeLiquidation(account, pythUpdateData)`; `executeLiquidationBatch(address[], data)` (one shared Pyth snapshot, per-account rollback frames). Full liquidation only. Uses current account-adverse price; capped charge from dedicated liquidation reserve, split keeper/treasury/LP-remainder (floor-rounded shares, `keeperShareBps + protocolShareBps ≤ 10_000`); bounded account-local cleanup of pending orders (risk-off refunds first, then `AccountLiquidated` receipts; opening bounties may be forfeited to treasury).

### LP flows

| Action | Entrypoint |
|---|---|
| Request deposit | `TrancheVault.requestDeposit(assets, controller, owner)` |
| Claim activated deposit | ERC-4626 `deposit`/`mint` (only claims activated requests; `receiver == controller`) |
| Request redemption | `TrancheVault.requestRedeem(shares, controller, owner)` |
| Claim funded redemption | ERC-4626 `redeem`/`withdraw` (`pendingRedeemRequest` / `claimableRedeemRequest`) |
| Route activated deposit → redemption | `requestRedeemFromClaimableDeposit(depositRequestId, shares, controller)` (after lot cooldown; same controller; no token transfer; escrow reclassification) |
| Request timing | `TrancheVault.getRequestEpochWindow()` → `(nextRequestEpoch, nextRequestCutoffTime)`; 5-min cutoff rule; Senior refunds only on epoch rejection / projected wipe / Senior impairment / settlement hold |
| Epoch settlement | `SettlementMonitorLens.getSettlementStatus(observedEpoch).requiredExecutionPath` → `CachedMark`: `HousePool.settleLpEpoch(uint256,uint256)` (0 ETH); `AtomicOracleRefresh`: `OrderRouter.settleLpEpoch(bytes[])` (exact Pyth fee). No-progress pass reverts (rolls back Pyth + Engine updates on atomic route). Settlement hold blocks both routes. |

### Oracle updates

| Action | Entrypoint |
|---|---|
| Live mark refresh | `OrderRouter.updateMarkPrice(pythUpdateData)` — complete signed current basket or valid replay of accepted basket; fee via `getUpdateFee` |
| Order execution price | Via Router execution entrypoints (historical parse; fee via `PletherOracle.getOrderExecutionFee`) |
| Liquidation / trigger / LP reconcile price | Via respective Router/Book entrypoints (current-basket policy; `PoolReconcile` requires earliest component publish ≥ current round-hour boundary when positions are live) |
| Frozen replay | Stored Engine mark under `fadMaxStaleness`; zero Pyth fee; cannot be repaired from Pyth storage or new payload during freeze |
| ETH refunds | Failed refunds accumulate: `PletherOracle.claimableEth` / `claimEthRefundTo`; RouterAdmin claim ledger / `claimBalanceTo`. Consumers must expose both. Direct Oracle callers: send exact quote (success does not refund overpayment). |

### Admin / emergency

Guardian: `EmergencyPauseCoordinator.triggerEmergencyPause / triggerLpEpochSettlementHold / triggerFullContainment(reasonHash, evidenceHash)`. Governance release: `OrderRouterAdmin.unpause()`, `HousePool.unpause()`, `HousePool.unpauseLpEpochSettlement()` (owner-only, separate). Timelocked config: propose/finalize/cancel on `CfdEngineAdmin`, `OrderRouterAdmin`, `HousePool`, `TrancheVault` (maintenance fee). Degraded-mode clear: `CfdEngine.clearDegradedMode()` (owner, requires raw `E ≥ L`).

### Reads / previews

`PerpsPublicLens` (product views), `OrderLifecycleBook` (identity/outcomes/receipt verification), `CfdEngineLens.previewOpen/quoteMaxOpen` (excludes Router admission/bounty/oracle checks), `CfdClosePreview.previewClose` (pre-commit close projection incl. commitment carry), `SettlementMonitorLens` (settlement preflight/health — advisory, simulate exact calldata before broadcast).

## (d) Stated protocol invariants

Sources: `SECURITY.md` §Critical Protocol Invariants + `ACCOUNTING_SPEC.md` §Required Global Invariants (15) + §Reading the accounting model. Condensed without changing meaning; symbols: `P = HousePool.totalAssets() = min(raw, accounted)`, `C = totalTraderClaimBalance`, `E = max(P−C, 0)`, `L = max(longMaxProfit, shortMaxProfit)`, `B = ceil(L × settlementBufferBps / 10_000)`.

**Solvency / containment**

1. Buffered entry: every risk-increasing open/increase requires post-op `E ≥ L + B` (equality passes).
2. Degraded containment: if a close/liquidation leaves raw post-op `E < L`, `degradedMode` latches (blocks risk expansion; protective transitions still permitted); `B` excluded from the latch test; clearing requires `E ≥ L` only.
3. Bounded price liability: price PnL bounded by size, exact entry cost, `[0, CAP_PRICE]`; collateral return and action settlement accounted independently.
4. Withdrawal firewall: LP redemption funding limited to conservative free cash after base reserve `C + L + B` + pool-level reservations (+ pending claimant + unassigned assets).
5. Matured Senior priority: no Junior redemption funding while eligible matured Senior demand remains unaccounted for.
6. Funded-claim backing: every claimable LP asset held 1:1 in vault escrow, unusable by HousePool, claimable at most once.
7. Trader claims are senior: claim balances stay senior on pool liquidity until serviced; keeper bounties are not pool liabilities.
8. Explicit terminal deficit: signed terminal liabilities above physical assets + collectible receivables persist on fresh reconcile and block LP entry.

**Position / engine**

9. Single direction per account (≤1 live directional position).
10. Margin sufficiency via explicit initial/maintenance/FAD policy surfaces; post-open equity must be strictly greater than initial margin (equality rejected).
11. Side symmetry + total margin conservation: `sides[LONG].totalMargin + sides[SHORT].totalMargin == Σ pos.margin`.
12. Preview/live parity for close and liquidation math.
13. Frozen-spread conservation: assessed spread = LP-paid spread + terminally waived spread; none to treasury.
14. Exact-lot basis: whole 100-token lots; exact entry cost conserved across increases/partial closes (`closedEntryCost = floor(old × closedLots / oldLots)`, remainder keeps dust); rounded average entry price is never a settlement basis.
15. Terminal-book parity: each account curve matches live side, lots, exact entry cost, and `pnlPledge + same-account claim` cap after every successful mutation; any path changing lots/entry cost/side/pledge/claim must atomically sync the curve.

**Router / reservations**

16. Global FIFO for price-dependent execution; oracle-free invalid-order cleanup may remove specific (incl. non-head) orders without executing later valid ones.
17. Binding intents: users cannot cancel queued orders; permanent `(account, clientOrderId)` → full intent hash idempotency; exact replay returns original id; conflicting reuse reverts.
18. Bounded authority: fresh orders pin nonzero target, deadline, mode mask, config hash, inclusive financial limits; zero maxima are real zero allowances.
19. Configuration authority: Book digest binds identities + finalized Engine/Router config versions; execution against a different digest fails terminally (`ConfigMismatch`). Digest excludes dynamic values (price, depth, skew, FAD/frozen, pause states, cutoff) and the redemption-math sidecar.
20. Retryable uncertainty: unknown selector, panic, OOG, empty/malformed revert, malformed success, mark-ordering failures never become terminal policy failures.
21. Terminal evidence: every terminal transition finalizes one authenticated Book receipt after economic settlement; receipt failure rolls back the item; Router records deleted terminally, Book retains permanent identity/outcome/receipt hash.
22. Bounty conservation: reserved opening + protection-trigger bounty conserved until distributed/absorbed, excluded from close-loss reachability while reserved; ordinary/protection close records are zero-amount Active records; nonzero close-bounty config/commitment rejected.
23. VPI reserve conservation: every live negative lifetime-VPI balance has equal dedicated action-reserve backing; only exact clawback / equivalent withholding / lower surviving target may consume/release it. Generic action collection must not cross the floor of protected bounties + `max(−vpiAccrued, 0)`.
24. Reservation source of truth: Clearinghouse records own committed margin, active FIFO, bounty classifications, account bounty totals; Router/protection views compose them; reservations resolved exactly once; no-carry release methods change buckets only.
25. Protection post-lock safety: exact entry basis; price equity = PnL pledge + same-account claim only; uncovered carry / underfunded negative-VPI reserve fail closed; equity must strictly exceed `max(initMargin, active maintenance/FAD margin)`.
26. Earliest-lot gate + granularity: non-100-multiple opens/closes rejected before reserving value or assigning id; partial closes must meet the engine notional floor; only full residual closes may be smaller. Bounded cleanup (account-local; `maxPendingOrders` default 5, gov max 32).
27. Credit-only funding: exact token receipt increases beneficiary settlement only; no Engine hook, carry checkpoint, reserve allocation, or payer authority.
28. Carry-safe reservation resolution: opening-bounty release does not checkpoint carry; ordinary close commitment still collects carry with zero bounty; retryable rollback restores order + zero record.

**HousePool / LP**

29. Canonical asset boundary: depth from `min(raw, accounted)`; excess excluded until governed; shortfalls reduce backing immediately.
30. Economic depth: carry/skew/VPI use `max(P − C, 0)`; physical custody/solvency inputs stay gross.
31. Symmetric terminal NAV: entry and exit pricing use the same signed exact terminal delta + waterfall snapshot; receivables capped per account, never fund redemptions pre-collection; nonzero terminal deficit blocks activation.
32. High-water-mark protection: Senior impairment restored before Junior extracts surplus; Senior withdrawals reduce HWM by the same economic fraction as principal (actual net funded).
33. Bounded new Senior exposure: counted admission exposure `E + R` cannot exceed the smaller absolute/share headroom; Junior covenant retains enough Junior capital to back `E + R` under the share limit.
34. Shared cutoff routing: same 5-minute cutoff for both tranches/directions; equality rolls forward; locked-epoch additions rule (no request at/after `b−300` may increase locked epoch `e+1`, incl. after maturity; cancellations may shrink it).
35. Shared accounting inputs: reconcile, redemption funding, deposit finalization, LP views consume the same canonical Engine snapshot.
36. Activation-aged cooldown: cooldown starts only on successful activation; later wallet claim preserves timestamp (`max(receiver, activation)`); direct deposit→redeem routing preserves controller, consumes one entitlement exactly once, reclassifies escrow shares equally (`depositClaimEscrowShares` ↓, `pendingRedeemEscrowShares` ↑, no token transfer); vault share custody equals the sum of both escrow counters after terminal cleanup.
37. Per-controller floor rounding against immutable epoch totals: splitting requests cannot increase aggregate entitlement; terminal dust rules fixed (deposit-share dust burned, funded-asset dust to Pool as excess, refundable-share dust to seed account).

**Accounting-model rules (ACCOUNTING_SPEC.md)**

38. Physical USDG ≠ mathematical claims; marked equity counts only collectible losses; redemption funding stricter than solvency; buffer is headroom, not liability/NAV/yield/custody.
39. Price loss beyond collectible cap = diagnostic write-off (not asset/debt); unpaid price profit = trader claim; unfunded rebates / uncollectible terminal charges may be waived; terminal deficit separate.
40. Valid risk-reducing transitions must not revert merely to preserve pre-close solvency or buffer headroom; containment via `degradedMode`.
41. Frozen-close spread + frozen LP exit fees stay with LPs, never treasury margin.
42. Same-account claim netting: claim nets once against that account's exact price loss; cannot pay carry/VPI/fees/spread/liquidation charges/order margin; claim paid into an open position becomes PnL pledge (never free settlement).
43. Collected carry is pool revenue once; uncollected carry is not an LP receivable. Claim/bounty credits collect available margin + free settlement toward carry first, retain unpaid carry in `unsettledCarryAssets`, then apply the full credit (credit may fund arrears at a later checkpoint, incl. same timestamp).
44. LP request ids use the shared cutoff; maturity does not fix a price; a settlement pass advancing no queue item reverts.

## (e) Per-file risk map

Rubric (per task): **CRITICAL** = money movement, auth, oracle, settlement accounting. **HIGH** = state transitions, external calls, math. **MEDIUM** = views/lenses (read-only). One line per file. 34 top-level + 28 libraries + 14 router = 76 files; `src/interfaces/` (55 files, declarations/types only) is summarized at the end, not rated per file.

### `src/*.sol` (34)

| File | Risk | One line |
|---|---|---|
| `CfdEngine.sol` (1484 lines) | CRITICAL | Position ledger, risk admission, degraded mode, mark cache, treasury lock, recap; authorizes all settlement via Clearinghouse/Pool. |
| `CfdEngineAdmin.sol` | CRITICAL | 72h-timelocked owner admin for Engine risk/calendar/freshness; finalized values change the execution config hash. |
| `CfdEngineLens.sol` | MEDIUM | Permissionless open/close/liquidation planning diagnostics; reads cached state + planner, no mutation/oracle ingestion. |
| `CfdEngineAccountLens.sol` | MEDIUM | Rich per-account diagnostic reads; wider than product surface; no settlement authority. |
| `CfdEngineProtocolLens.sol` | MEDIUM | Protocol-accounting reads feeding HousePool snapshots; no mutation, but snapshot correctness gates LP accounting. |
| `CfdEngineOpenQuoter.sol` | MEDIUM | Stateless interval search for max planner-valid open; read-only, deployed by Lens for size. |
| `CfdEnginePlanner.sol` | CRITICAL | Stateless wrapper exposing `CfdEnginePlanLib`; every execution/close/liquidation plan flows through it. |
| `CfdEnginePlanningReader.sol` | HIGH | Engine-constructor-created read-only snapshot→planner bridge; no settlement authority, but feeds planner inputs. |
| `CfdEnginePlanTypes.sol` | HIGH | Snapshot/delta structs + failure-lifecycle classification for plan→apply; encoding errors propagate to all plans. |
| `CfdEngineSettlementSidecar.sol` | CRITICAL | Engine-only settlement executor for open/close/liquidation; reaches Engine host hooks + custody contracts. |
| `CfdClosePreview.sol` | MEDIUM | Read-only prospective-close preview incl. commitment carry; shares evaluator base, commits/executes nothing. |
| `CfdMath.sol` | CRITICAL | Pure capped-PnL, solvency-envelope, VPI arithmetic used by all settlement paths. |
| `CfdOrderPolicyEvaluator.sol` | CRITICAL | Stateless pinned-policy assessment the Router sidecar trusts (with shape/field checks) before settlement. |
| `CfdOrderPolicyEvaluatorBase.sol` | HIGH | Shared plan-derivation/evaluation coordinator for evaluator + close preview; assessment correctness gates execution. |
| `CfdTreasury.sol` | CRITICAL | Owner-only treasury lock/proposal/cancel logic inherited by Engine; misbehavior misroutes all future protocol fees. |
| `CfdTypes.sol` | HIGH | Canonical position/order/direction/risk types + `SIZE_QUANTUM`; shared type errors affect every consumer. |
| `EmergencyPauseCoordinator.sol` | CRITICAL | Guardian-only fixed containment actions across RouterAdmin + HousePool; no unpause; wiring/auth is the whole surface. |
| `HousePool.sol` (1886 lines) | CRITICAL | LP custody, waterfall/coupon/HWM, epoch settlement, senior capacity, seeds, excess/unassigned assets, pauses/hold. |
| `HousePoolRedemptionMathSidecar.sol` | HIGH | Stateless pure redemption-budget/pricing helpers; no custody, but settlement funding math depends on it. |
| `MarginClearinghouse.sol` (1833 lines) | CRITICAL | Trader USDG custody + all margin/reserve/bounty buckets; broad ops restricted to Engine/settlement sidecar. |
| `OrderLifecycleBook.sol` | CRITICAL | Permanent intent idempotency, config digest, authenticated terminal receipts; Router-only mutations; no funds. |
| `OrderRecoverySidecar.sol` | CRITICAL | Delegate-only expiry/invalid-cleanup/mismatch-recovery + non-Engine receipts via execution sidecar; per-item rollback. |
| `OrderRouter.sol` | CRITICAL | External execution boundary: commits, FIFO, liquidations, mark refresh, atomic LP settlement; delegatecall orchestration. |
| `OrderRouterAdmin.sol` | CRITICAL | 72h-timelocked Router/oracle config admin + risk-off pause/cutoff + ETH refund claim ledger; pause powers are instant. |
| `OrderRouterExecutionSidecar.sol` (1351 lines) | CRITICAL | Stateless delegate module: oracle orchestration, bounded execution, receipts, gas tails, refund policy. |
| `OrderRouterLiquidationBatchSidecar.sol` | CRITICAL | Router-bound delegate module: commits, trigger/mark-refresh, liquidations, atomic LP settlement, oracle-config forwarding. |
| `OrderV3Types.sol` | HIGH | V3 request/policy/assessment/receipt types + hash domains (V3 requests, V5 receipts/config); encoding is consensus-critical. |
| `PerpsPublicLens.sol` | MEDIUM | Compact product read facade (trader/LP/protocol views); no mutation. |
| `PletherOracle.sol` (1070 lines) | CRITICAL | Pyth basket validation, accepted live basket, historical execution prices, frozen policy, confidence shifts, ETH refunds. |
| `PositionProtectionBook.sol` (1116 lines) | CRITICAL | TP/SL lifecycle + trigger bounty + close ceilings; narrow Router/Clearinghouse hooks; trigger is irreversible. |
| `SettlementMonitorLens.sol` (1533 lines) | MEDIUM | Advisory settlement-route/health diagnostics; fail-soft; cannot authorize settlement or pause. |
| `SettlementMonitorLensSidecar.sol` | MEDIUM | Facade-bound read implementation for the monitor; no setter/delegatecall; advisory only. |
| `TerminalNavBookV2.sol` | CRITICAL | Aggregate account-capped terminal curves for NAV; Engine-only sync; no repair path; stale/wrong curves misprice all LP flows. |
| `TrancheVault.sol` (1875 lines) | CRITICAL | ERC-4626/7540 tranche shares, deposit/redemption escrows, epoch queues, cooldowns, Junior fee dilution; Pool-only activation/funding. |

### `src/libraries/` (28)

| File | Risk | One line |
|---|---|---|
| `CfdEnginePlanLib.sol` (1678 lines) | CRITICAL | Pure open/close/liquidation planning + validation; the canonical economics every executor must apply. |
| `OpenAccountingLib.sol` | CRITICAL | Entry price, VPI, fees, max-profit, margin requirements for opens/increases. |
| `CloseAccountingLib.sol` | CRITICAL | Proportional close state + signed economic settlement for closes. |
| `LiquidationAccountingLib.sol` | CRITICAL | Maintenance requirement, liquidation-charge allocation, residual settlement. |
| `SolvencyAccountingLib.sol` | CRITICAL | Side-liability envelope, effective assets, degraded-mode previews (`E`/`L`/`B`). |
| `PositionRiskAccountingLib.sol` | CRITICAL | Borrow/utilization, carry indexes, equity, liquidation thresholds; carry rounding lives here. |
| `MarginClearinghouseAccountingLib.sol` | CRITICAL | Pure plans for bucket classification, open costs, loss consumption, liquidation settlement. |
| `HousePoolAccountingLib.sol` | CRITICAL | Withdrawal/reconcile/mark-freshness views from Engine snapshots. |
| `HousePoolWaterfallAccountingLib.sol` | CRITICAL | Senior/Junior principal, coupon, revenue, loss, senior-withdrawal accounting. |
| `HousePoolReconcilePlanLib.sol` | CRITICAL | Coupon checkpointing + mark-dependent reconciliation of claimant principal. |
| `HousePoolRedemptionMathLib.sol` | CRITICAL | Exact ERC-4626 redemption pricing + budget-capped share funding. |
| `HousePoolPendingPreviewLib.sol` | HIGH | Applies pending recap/revenue buckets to in-memory waterfall previews. |
| `HousePoolSeniorCapacityLib.sol` | HIGH | Protected Senior exposure, admission capacity, tranche-ratio helpers (`E + R`). |
| `HousePoolFreshnessLib.sol` | HIGH | Engine mark-freshness policy for reconcile/withdrawal gates. |
| `HousePoolTrancheGateLib.sol` | HIGH | Common lifecycle/freshness/impairment gates for tranche deposits. |
| `HousePoolSeedLifecycleLib.sol` | HIGH | Pure predicates for tranche seeding + trading activation gates. |
| `HousePoolWithdrawalPreviewLib.sol` | HIGH | Reservation application + Senior withdrawal-cap helpers. |
| `JuniorMaintenanceFeeMathLib.sol` | HIGH | Fixed-hour Junior dilution math; completed-hour rounding behavior. |
| `CashPriorityLib.sol` | HIGH | Cash reserved for existing trader claims before fresh payouts. |
| `CfdEngineCollateralSnapshotLib.sol` | HIGH | Expands one Clearinghouse observation into planner collateral fields. |
| `CloseCommitmentLib.sol` | HIGH | Canonical close-admission economics shared by commitment + assessment. |
| `MarketCalendarLib.sol` | HIGH | Recurring weekend + governance FAD windows (incl. compiled post-2007 US DST rule). |
| `OracleFreshnessPolicyLib.sol` | HIGH | Close-only + mark-age rules per action/calendar regime. |
| `OracleConfidencePolicyLib.sol` | HIGH | Shared confidence bounds for Router proposals + oracle config application. |
| `OrderFailurePolicyLib.sol` | HIGH | Classifies planner failures rejectable deterministically at commit time. |
| `OrderValidationLib.sol` | HIGH | Pure delayed-order validation helpers (incl. slippage checks). |
| `OrderSettlementFloorLib.sol` | HIGH | Funded floor read for pending flat opens; no separate floor ledger. |
| `ExecutionBlockNumberLib.sol` | HIGH | Execution-chain block number (ArbSys on Arbitrum); same-block guards depend on it. |

### `src/router/` (14, all `abstract contract` bases inherited by `OrderRouter`, except `OrderLiquidationBatchLogic` which backs the delegate sidecar)

| File | Risk | One line |
|---|---|---|
| `OrderHandler.sol` | HIGH | Composes commit/execution/liquidation handlers; applies admin-finalized config. |
| `OrderRouterBase.sol` | HIGH | Shared Router config, deploys admin, Engine/admin integration hooks. |
| `OrderCommitHandler.sol` | CRITICAL | Creates delayed orders, reserves Clearinghouse balances, exposes order-record views. |
| `OrderValidation.sol` | HIGH | Owns commit cursor; dispatches risk-off settlement + terminal receipts to V3 execution. |
| `OrderBountyAccounting.sol` | CRITICAL | Queued-bounty reservation transfers during liquidation. |
| `OrderReservationAccounting.sol` | HIGH | Router-side pending records + per-account queue links shared by commit/execution/liquidation. |
| `OrderQueueBook.sol` | HIGH | Global FIFO list + pending-order accessors. |
| `OrderExecutionHandler.sol` | CRITICAL | Risk-off cleanup + ETH refund policy for V3 execution. |
| `OrderExecutionSettlement.sol` | HIGH | Retained execution events + hooks for canonical Router terminal settlement. |
| `OrderExecutionOrchestrator.sol` | HIGH | Execution config surface read by the V3 sidecar through Router getters. |
| `OrderOracleExecution.sol` | HIGH | Owns/validates Router oracle, Engine lens, HousePool bindings. |
| `OrderLiquidationHandler.sol` | CRITICAL | Priced liquidations, bounty forfeiture, live-order clearing. |
| `OrderLiquidationBatchLogic.sol` (860 lines) | CRITICAL | Router getters + isolated item entrypoints for delegated keeper/liquidation logic (delegatecall context). |
| `PositionProtectionHandler.sol` | CRITICAL | Router-side lifecycle hooks for the external protection Book (commit/trigger/retry paths). |

### `src/interfaces/` (55 files — declarations/types only, no logic)

Interface + view-type files (`ICfdEngine*`, `IHousePool`, `IMarginClearinghouse`, `IOrderLifecycleBook`, `IOrderRouter*`, `IPletherOracle`, `IPositionProtection*`, `IPerps*`, `ITerminalNavBookV2`, `IAsyncTrancheVault*`, `IERC7540/7575`, `*ViewTypes`, `*Types`). Not individually rated: they carry no implementation, but several carry security-relevant surface definitions (error/event ABI, `IOrderRouterErrors`, receipt/config hash domains, `IWithdrawGuard`). Treat interface/implementation drift as a review check, not a standalone risk class. Note `OrderRouter` exposes keeper/trader surfaces via `IPerpsKeeper`/`IPerpsTraderActions`; the canonical integration interfaces are listed in `CANONICAL_ENTRYPOINTS.md`.

## Scope notes / ambiguities (for the coordinator)

1. **Stated target is `packages/perps/src` only.** Sibling packages exist and were not reconned: `packages/spot`, `packages/options`, `packages/shared`, `packages/perps-aa` (AA paymaster: `PletherVerifyingPaymaster.sol`), `packages/perps-aa-client`, plus root `script/` deployment/keeper scripts and `integration/`. If the Immunefi scope includes any of these, this recon does not cover them.
2. **Deployed vs pinned code:** `deployments/` contains Arbitrum Sepolia releases (latest `2026-10-28-perps-arbitrum-sepolia-v2.0.0`, USDG testnet). The pinned commit (`a82d4fef`, "fix(ci)… #135") postdates the v2.0.0 release commit. Verify whether the competition scope is the pinned commit, a deployed stack, or both — SECURITY.md stresses non-upgradeable stacks must be reviewed as one internally compatible unit with matching ABIs.
3. **Docs describe one fresh-stack deployment model.** No migration path exists for legacy Router/Book/protection state; old deployments need archived ABIs. Findings must be grounded in the pinned commit's code, not in deployment manifests.
4. **No scope/asset list was in the task beyond the package path.** No Immunefi scope page was available to this subagent; the exclusion list was built from the task's known-issues text + the three named reports + SECURITY.md sections (see `exclusions/EXCLUSION_LIST.md`).
