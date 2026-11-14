# Ticko Bug Bounty — Testnet Black-Box Test Plan

**Date:** 2026-11-13 (WIB)
**Status:** PLAN ONLY. Phase 0 (docs recon) complete. **Zero live testing has been performed.** No requests have been sent to testnet.ticko.xyz, app.ticko.xyz, ticko.xyz, or any Ticko API/service. Every later phase needs its own explicit user authorization before it starts.
**Source audit verdict (see [SCOPE.md](sandbox://workspace/ticko-audit/SCOPE.md)):** BLOCK — Ticko is closed source. The FAQ states the contracts are undergoing an audit and source code + API docs will be published once complete. This plan covers black-box testing of the testnet deployment only.
**Docs baseline:** all 22 pages in the docs index (`https://docs.ticko.xyz/llms.txt`) were read on 2026-11-13 via their `.md` versions. Section 2 cites the page each expected behavior comes from.

---

## 1. Scope boundaries (quoted from the governing docs)

### 1.1 The governing rule — testnet only

From the bug bounty page (`resources/ticko-bug-bounty.md`):

> "Do **not** test on Ticko Mainnet or any production system. Use Ticko Testnet or another non-production environment. Reports based on testing in production are disqualified."

From the FAQ (`resources/ticko-bug-bounty/ticko-bug-bounty-faq.md`):

> "Can I test on Mainnet? No. All testing must take place on Ticko testnet or another non-production environment."

**Consequence for this plan:** every test action targets `testnet.ticko.xyz` only. `app.ticko.xyz` (Mainnet Beta, real funds) is never touched — not even to "look". If a testnet action ever appears to reach a production system, STOP immediately (see §3.0 stop conditions).

### 1.2 What is in scope

From the bounty page — **Ticko Mainnet (Beta)** vulnerabilities that could cause:

- Loss or freezing of user funds
- Unauthorized state changes, withdrawals, or transfers
- Incorrect order matching
- Incorrect margin, liquidation, funding rate, or settlement calculations
- Oracle or mark prices that can be manipulated or misused because of a flaw in Ticko's logic (excluding price moves driven solely by extreme market conditions or large amounts of capital)
- Misuse of trading session keys or signatures, such as placing orders or withdrawing beyond the granted permissions, or replaying signatures
- Node or API outages
- State divergence (nodes disagreeing on state)
- Logic errors in Ticko Core (the Ticko VM and the onchain order book)

**Ticko Testnet:**

> "Testnet-only features and their interaction with Ticko Core, nodes, and APIs. Rewards for a testnet-only issue may be lower than for a Mainnet issue of the same severity. Other experimental testnet features are not in scope unless Ticko announces otherwise, but reports are still welcome."

Interpretation for this plan: a bug demonstrated on testnet is reportable; its reward tier depends on whether the same flaw affects Mainnet. Every finding must state clearly whether it was demonstrated on testnet only, and whether the same code path plausibly serves Mainnet (unknown — closed source — so say so, do not assume).

### 1.3 What is explicitly NOT a vulnerability

1. **Public account state by design** (FAQ):
   > "Is unauthenticated access to another account's balances, positions, and trading history a vulnerability? No. Ticko's onchain account state and trading records are public by design. Permissionless, read-only access by wallet address is intended behavior."
   Do not report read-only visibility of another wallet's balances/positions/history. (Writing to, or acting as, another account is a different matter — see §3.3a.)
2. **Published Beta limits** (bounty page):
   > "Beta limits published before a report is submitted, such as the deposit cap, are not vulnerabilities in themselves, but a way to bypass them is."
3. **Non-security bugs** do not qualify for Critical/High/Medium tiers; they may be considered under the Others tier (see §1.5).
4. **Issues depending on extreme or unrealistic market conditions** are not eligible.
5. **Issues requiring highly unusual or unreasonable user behavior** are not eligible.
6. **Scanner output, or reports the submitter has not personally verified**, are not eligible.

### 1.4 Prohibited activity (bounty page, verbatim list)

- Testing on Mainnet or any production system.
- Phishing or other social engineering.
- Extended or large-scale DDoS. (A short traffic-spike demonstration only to the extent necessary and without causing material disruption is the only carve-out — this plan does not include any traffic-spike test; do not add one without a separate explicit order.)
- Testing third-party systems, apps, wallets, browser extensions, or websites, unless the issue leads directly to an in-scope Ticko vulnerability.
- Extortion or threats.
- Disclosing a vulnerability publicly before a fix ships and Ticko authorizes disclosure.
- Publishing, or threatening to publish, personal or other sensitive information without consent.
- Exploiting a vulnerability for financial gain beyond the rewards in this program, including any trading or liquidation advantage.
- Using another person's credentials, private keys, or trading session keys encountered during testing.
- Bypassing the program's reporting process or acting outside the stated scope.

**Additional boundary from the Terms of Use** (`resources/terms-of-use.md`, §§3.7, 6.2 — read 2026-11-13): do not bypass or circumvent geofencing, sanctions screening, wallet screening, access controls, rate limits, or eligibility controls; do not scrape, overload, or reverse-engineer the Interface; do not exploit bugs/design errors/oracle behavior/liquidation or fee mechanisms; do not wash-trade, spoof, layer, or otherwise undermine market integrity. The bounty program's safe harbour (below) covers good-faith research **that complies with the program**; it does not license conduct the Terms prohibit. Practical consequences baked into this plan:

- No VPN/proxy/location concealment. Testing runs from the user's own session/device.
- No automated scraping or high-rate requests. Manual, low-rate, human-paced actions only.
- No decompiling or binary reverse engineering. Observation is limited to what the testnet app shows in normal browser use.
- Self-trade-prevention tests (Phase 3b) use the smallest possible sizes and orders are cancelled promptly — the test verifies STP behavior, it does not create misleading volume.
- Invite-code/faucet tests (Phase 3d) are bounded: no sock-puppet Discord accounts, no automated claiming, no stockpiling codes, no faucet draining. One controlled re-claim attempt at most to test cooldown enforcement; stop at the first sign of a bypass and report.

**Safe harbour** (bounty page):

> "Ticko will not take legal action against good-faith security research that complies with this program."

### 1.5 Eligibility conditions (all must hold)

From the bounty page:

1. **First report** — only the first valid report of an issue is reward-eligible.
2. **Not already known** — the issue must not have been recorded internally by Ticko, disclosed in any published audit report, under investigation/remediation, or covered by an earlier valid report. Ticko determines whether an issue is already known. (No audit report is published yet — see SCOPE.md §3 — so no exclusion list exists today; re-check before filing.)
3. **Reproducible** — Ticko must be able to reproduce the issue.
4. **Direct submission** — email to `security@ticko.market`, not via a third-party platform, unless Ticko announces otherwise.
5. **Confidentiality** — keep the vulnerability and all related communications confidential until Ticko authorizes disclosure.
6. **Payout verification** — complete applicable KYC/KYB checks, sanctions screening, and payout procedures; be able to receive USDT through a method and network Ticko designates.
7. **Conflict of interest** — contributors to the affected code are not eligible for a reward for that code.

**Reward tiers** (bounty page; maximums, sole discretion, USDT):

| Severity | Maximum | Illustrative examples from the page |
|---|---|---|
| Critical | 200,000 USDT | Significant loss of user funds; unauthorized withdrawal/transfer; violation of Mainnet execution invariants (total assets changing with no valid cause); incorrect matching/margin/liquidation/funding/settlement producing an incorrect final state or loss of funds; permanent freezing of funds; bypassing session-key permissions to place orders or withdraw as another user; permanent or repeatable Mainnet state corruption |
| High | 25,000 USDT | Mainnet outage; severe unavailability of Ticko Core, nodes, or APIs; state divergence or processing failure without incorrect final state or direct loss; temporary freezing of funds |
| Medium | 3,000 USDT | API authentication or authorization issues; material data integrity issues; service degradation with meaningful security impact |
| Others | 50 USDT | Reproducible general bugs, deposit/withdrawal issues with no security impact, product suggestions. Ongoing tier; amount depends on report quality; each issue rewarded once, earliest valid submission. |

Notes from the FAQ: every submission gets an acknowledgment email within one business day; **only fund-security reports receive further email follow-up**; an acknowledgment does not confirm validity or reward eligibility. Approved rewards are distributed in weekly batches after review. Public acknowledgment (opt-in, name/handle + optional link) is available for valid reports that do not earn a reward, published only after the fix and authorized disclosure.

---

## 2. Documented-behavior baseline

Every test in Phase 3 is checked against the expectations below. Each expectation cites its docs page. Values the docs do **not** state are flagged as gaps (§6) — tests must record observed values, never assume them.

### 2.1 Matching (`trading-on-ticko/matching-rules.md`)

- Orders are matched **on-chain** using **price-time priority**.
- Price: buy orders at higher prices match first; sell orders at lower prices match first.
- Time: orders at the same price match in the sequence received (**FIFO**).
- Execution is **sequential within a block**: each order is fully processed before the next order in the block is evaluated.
- **Order modification:** modifying an order's **price** loses queue position (treated as cancel and re-place). **Reducing quantity only** preserves queue position. (Increasing quantity is not addressed — gap, §6.)

### 2.2 Order types (`trading-on-ticko/order-types.md`)

- **Market order:** executes immediately at the best available price; subject to slippage protection — rejected if execution price exceeds the user-defined slippage tolerance or the system limit.
- **Limit order:** executes at the specified price or better. Time-in-force: **GTC** (rests until filled/cancelled), **IOC** (fills as much as possible immediately, unfilled portion cancelled), **FOK** (must fill entirely in one match or the whole order is rejected).
- **Post-only** limit orders are rejected if they would trade immediately (guarantees maker execution).
- **Price match:** order price derived from the book at a specified level — queue side (bid1, bid5) or counter-party side (ask1, ask5) for buys, vice versa for sells.
- **Conditional order:** dormant; activates when the **mark price or last traded price** crosses a specified trigger price; then submits a market or limit order. (Which of the two prices triggers, and who chooses, is not stated — gap, §6.)
- **TP/SL:** attached to an existing position; triggers at a specified price to close all or part of the position. A **new full-position TP/SL replaces any existing one**.
- **Order with attached TP/SL:** attached TP/SL orders remain dormant and activate **only after the parent order is fully filled**. Partial fills of the parent do **not** activate the attached TP/SL.
- **Reduce-only:** can only reduce an existing position, never increase or open one; quantity is **capped to current position size**. In one-way mode the trader marks the order reduce-only; in hedge mode, reduce-only is determined by order direction (open orders increase, close orders reduce by construction).

### 2.3 Self-trade prevention (`trading-on-ticko/self-trade-prevention.md`)

- STP prevents an account's orders from matching against each other. Each order can specify an STP mode:
  - **Cancel maker** (default): resting order cancelled; incoming order continues matching.
  - **Cancel taker**: incoming order cancelled; resting order remains.
  - **Cancel both**: both cancelled.

### 2.4 Margin, leverage, positions (`trading-on-ticko/margin-and-leverage.md`)

- **Two margin modes, usable simultaneously in the same account:** Cross (all available balance is shared margin; unrealized PnL of one position offsets others' requirements) and Isolated (margin allocated per position; losses limited to the assigned margin).
- **Position modes:** One-way (one position per contract per direction; same-direction orders increase, opposite reduce) and Hedge (simultaneous long and short on the same contract, each side managed independently).
- **Leverage is set per position**, capped by the **tiered leverage limit** for the contract; higher position sizes require lower leverage. (Tier breakpoints and max leverage per contract are not published in the docs — gap, §6.)
- **USDT is the sole collateral asset.**
- **Effective margin** = account equity (collateral balance + unrealized PnL) minus amounts frozen by open orders, isolated position margins, and estimated closing fees.
- **Initial margin (IM)** = position notional value / selected leverage; each open order also reserves IM.
- **Maintenance margin (MM)** = per position tier: each tier's notional × that tier's MM rate **plus the taker fee rate**; larger positions span multiple tiers and accumulate higher requirements. (Tier rates are not published — gap, §6.)
- **Available margin** = effective margin − sum of all IM requirements (positions + open orders); determines additional exposure.
- **Margin ratio** = effective margin / total maintenance margin. **A ratio at or below 100% triggers liquidation.** Higher = safer.

### 2.5 Liquidations (`trading-on-ticko/liquidations.md`)

- Trigger: margin ratio ≤ 100% (effective margin ≤ maintenance margin).
- **Liquidation price:** the price at which effective margin equals the MM requirement. For cross-margin accounts it depends on all positions and collateral; for isolated positions only on the assigned margin.
- **Progressive liquidation (cross margin), in order; the process stops as soon as account health is restored (partial liquidation):**
  1. Cancel orders — all open orders cancelled to release reserved margin.
  2. Net hedge positions — opposing long/short on the same contract netted to reduce gross exposure without market impact.
  3. Reduce positions — positions reduced in chunks via IOC limit orders.
  4. Backstop liquidation — if the margin ratio falls below the **takeover threshold** (value not published — gap, §6) despite the above, all remaining positions and collateral transfer to a Ticko backstop liquidator at the bankruptcy price.
- **Isolated liquidation:** same progressive steps, scoped to the individual position and its assigned margin; losses contained to the isolated margin and do not affect the rest of the account.
- **Bankruptcy price:** the price at which closing the position leaves the account with exactly zero equity after fees; the worst execution price during liquidation; any loss beyond it is absorbed by the backstop liquidator.

### 2.6 Auto-deleveraging (`trading-on-ticko/auto-deleveraging.md`)

- ADL is a last resort: closes positions of profitable traders against liquidated positions when the backstop liquidator cannot absorb the loss; keeps the system solvent without socializing losses.
- Triggers: (1) at takeover — backstop cannot safely absorb a new position at liquidation time; (2) during holding — the backstop's existing positions deteriorate beyond its risk limits.
- **Ranking:** traders with open positions on the affected contract are ranked by a **combination of profitability and leverage**; higher unrealized profit + higher effective leverage are deleveraged first. (Formula/weights not published — gap, §6.)
- Execution: the selected counterparty's position may be reduced at a price differing from the current mark price, or outside the kline range.

### 2.7 Funding (`trading-on-ticko/funding.md`)

- Funding is a periodic payment exchanged directly between long and short holders; anchors the perp price to the oracle price.
- **Settlement schedule:** every `funding_interval` hours; default 1-hour interval settles every hour on the hour, 00:00–23:00 UTC. **Only positions open at the settlement instant participate**; a position opened and closed between settlements pays/receives nothing.
- **Funding rate** = `clamp((P + clamp(I − P, −d, +d)) × (funding_interval / 8) × funding_rate_coef, Floor, Cap)`, where `I` = interest rate per 8h (default 0.01%), `d` = clamp deviation (default 5 bps), `funding_rate_coef` per symbol (default 1.0), Cap/Floor = per-interval max/min (values not published — gap, §6).
- **Premium index `P`:** average of samples `P_i = [Max(0, impact_bid_price − oracle_price) − Max(0, oracle_price − impact_ask_price)] / oracle_price`, sampled every `premium_sample_interval` (default 5s) across the funding interval (720 samples at 1h). Impact prices = average price to fill a fixed `impact_margin_notional` against the book (per-symbol, not published — gap, §6).
- **Payment** = `oracle_price × abs(open_size) × Funding Rate` (notional uses the oracle price). Positive rate: longs pay, shorts receive; negative: reversed. Cross-position funding is collected against the cross balance; isolated-position funding against that position's isolated margin.

### 2.8 Oracle and mark price (`trading-on-ticko/oracles-and-mark-prices.md`)

- **Oracle price** updates **every second**. Two prices computed continuously: **external** (weighted average of a symbol's configured third-party sources: `Sum(price_i × weight_i) / Sum(weight_i)`; weights can be updated without prior notice) and **internal** (derived from Ticko's own order book; starts from the last published oracle price and drifts toward one-sided book pressure, EMA-smoothed).
- **Internal-price pressure:** `IPD = Max(0, impact_bid_price − oracle_price) − Max(0, oracle_price − impact_ask_price)`. Impact bid above current price → IPD positive → drifts up; impact ask below → negative → drifts down; current price between impact bid/ask → zero → holds.
- **Which price is published:** symbols without a trading calendar (typically crypto) publish the **external** price; the internal price is published when external pricing is unavailable. Symbols with a trading calendar (typically TradFi): `Regular` → external; `Extended` → static weighted blend `external × w + internal × (1 − w)` with per-symbol `external_pricing_weight` in [0,1] (pre/post-market share the same weight; if external is unavailable during extended hours, effective external weight becomes 0 → internal fallback); `Closed` → internal.
- **Mark price** determines unrealized PnL, margin requirements, and liquidation triggers. It is the **median of three signals**: (1) funding-implied price `oracle × (1 + last_funding_rate × time_to_next_funding / funding_interval)`; (2) oracle + EMA basis `oracle + EMA(ticko_mid − oracle, τ)` (continuous-time EMA, configurable τ; samples skipped when the book spread exceeds a per-tier width threshold); (3) market consensus price (weighted median of perpetual mid prices from external venues). Mark price updates at the same frequency as the oracle price (every second).
- **Discovery band** (certain symbols): mark price clamped to a band around a reference price; `discovery_band = 1 / max_leverage` (default, per-symbol configurable); `oracle_threshold = 0.9` (default); bounds/triggers derived from the reference price. **Re-anchoring:** when the oracle price reaches a trigger, the reference moves to that bound, that direction's counter increments, all four levels recalculate; up/down counters are independent. Once a direction's counters are exhausted, the mark price stays at that bound. Reference price initializes from the last external oracle price (or the configured listing price for symbols with no external history) and resets to the current external oracle price when regular external pricing resumes. (Which symbols have a band, and the counter limits, are not published — gap, §6.)

### 2.9 Fees (`trading-on-ticko/trading-fees.md`)

- Fee depends on **VIP tier** (total trading volume over the previous 14 complete UTC days; maker + taker volume count; volume combined across main + sub-accounts, which share the tier) and maker/taker side. Same schedule across all markets. Tiers update daily at 00:00 UTC; the trader qualifies for the highest tier whose threshold they meet.
- VIP0 (<$2M): taker 0.0500%, maker 0.0200%. VIP1 (≥$2M): 0.0450% / 0.0180%. VIP2 (≥$5M): 0.0400% / 0.0160%. VIP3 (≥$10M): 0.0375% / 0.0120%. VIP4 (≥$25M): 0.0350% / 0.0100%. VIP5 (≥$100M): 0.0300% / 0.0060%. VIP6 (≥$250M): 0.0250% / 0.0000%.
- Fee = executed trade value (USDT) × fee rate, calculated and settled in USDT at each execution. Example given: 10,000 USDT taker execution at VIP0 = 5 USDT.
- (A "market maker" tier schedule is referenced from the sub-accounts page but no such schedule exists in the docs index — gap, §6.)

### 2.10 Sub-accounts (`trading-on-ticko/sub-accounts.md`)

- Each main account can create **up to 10 sub-accounts** to separate strategies; each has its own account address and is controlled by the main account's wallet; sub-accounts have **no separate private keys**.
- Creating a sub-account **requires a signature from the main account's wallet**; each sub-account gets a unique label.
- Sub-accounts **share the main account's VIP and market-maker tiers**; volume is combined for qualification; a new sub-account immediately uses the main account's current tiers. Each trade is charged/rebated in the account where it executes.
- The main account controls transfers into/out of sub-accounts; to withdraw sub-account funds, first transfer available funds back to the main account, then withdraw from the main account. (Withdrawals are unavailable on testnet — §2.12.)

### 2.11 Contracts (`trading-on-ticko/contract-specifications.md`, `trading-on-ticko/overview.md`)

- Linear perpetual contracts only; USDT quote and settlement; no expiry, no physical delivery; funding-rate mechanism tracks spot.
- Per-contract parameters: underlying, quote/settlement currency (USDT), price step, qty step, min/max order size, max leverage, funding interval (1h/2h/4h/8h), funding interest rate, funding rate coefficient, funding cap/floor, impact margin notional, OI cap. (**Per-contract values are not published in the docs** — gap, §6; record observed values in Phase 2.)
- Fully on-chain order matching; all trades execute on-chain and can be independently verified by any full node; one unified account supports cross + isolated simultaneously.

### 2.12 Testnet mechanics (`testnet-guide.md`, FAQ)

- Access: `testnet.ticko.xyz` → sign in with a **supported wallet** (recommended per FAQ) or **email** → **enter an invitation code** (claimed from the `#access-code` channel on Ticko Discord, `discord.com/invite/ticko`) → claim **testnet USDT from the faucet** → **sign to create a gasless trading session** → trade.
- Faucet: funds arrive **within one minute** of claiming; **24-hour cooldown** before the next claim. (Claim amount is not stated — gap, §6.)
- Trading session: **one signature creates a gasless trading session** so orders can be placed without approving each transaction. If the session expires or a reconnect prompt appears, enable trading again. (**No session expiry duration, permission list, revocation method, or scope is documented** — the largest docs gap; see §6. Session-key tests in Phase 3a must be built from behavior observed in Phase 2 plus the bounty page's examples.)
- Testnet uses **mock USDT**; **deposits and withdrawals are unavailable** on testnet (FAQ). No real assets are at risk on testnet.
- Mainnet (Beta) uses the same invite-code flow at `app.ticko.xyz` — **never test there** (§1.1).

### 2.13 Secondary-source notes (NOT from the docs pages read — treat as unverified)

From SCOPE.md (Medium articles / homepage, 2026-11-13): Beta deposits/withdrawals in USDT on Arbitrum One only, min 5 USDT, 0.2 USDT network fee, beta guidance not to deposit more than 500 USDT; Beta launched 20 Oct 2026 with 5 perps (BTC, ETH, XAU, SKHYNIX, QQQ); public Mainnet expected Q4 2026; chain anchored to Ethereum for verification/settlement/DA; >200,000 TPS / sub-10ms / sub-150ms targets. None of this appears in the docs pages read for this plan. Do not use these values as test expectations; record what the testnet actually shows.

---

## 3. Phased plan

### 3.0 Global rules (apply to every phase)

- **Authorization:** each phase — and each Phase 3 sub-class separately — starts only after an explicit user authorization in chat for that phase. A "Gas" for one phase never authorizes the next.
- **Own account only.** All authenticated actions use the user's own testnet account, established by the user (browser takeover; the agent never holds credentials, private keys, seed phrases, or session material). Never act as, or on behalf of, another user.
- **Minimum sizes.** Use the smallest order sizes and notionals that demonstrate a behavior. Cancel resting test orders promptly.
- **Human pace.** Manual actions only; no scripts, scanners, or automated request loops against the testnet deployment. No parallel request bursts.
- **Stop conditions (any one stops the phase immediately — record what happened and report to the user before any further action):**
  1. Any `429`, block, CAPTCHA, or access-denied response.
  2. Any response, redirect, or UI state suggesting the action reached a production/Mainnet system or real funds.
  3. Any other user's credentials, private keys, session keys, or personal data becoming visible — do not use, copy, or act on them; stop and report.
  4. Any unexpected live-service behavior: errors naming internal systems, stack traces, unexpected balance changes, orders affecting other accounts, or state that does not match the documented baseline in a way that suggests wider impact.
  5. Any prompt asking for a signature/approval whose contents do not match the intended action — do not sign; stop and report.
  6. Any sign that a test is affecting other users (e.g., a book, position, or balance that is not the user's own changing because of a test action).
- **Evidence for every phase** (stored under `~/workspace/ticko-audit/evidence/<phase>-<date>/`, never containing credentials or keys): timestamps in WIB + UTC, the exact action taken, screenshots of relevant UI states, request/response details visible in normal browser use (redact any tokens/signatures), order IDs, before/after balances and positions, and the observed-vs-documented comparison. Evidence must be sufficient for the parent agent to re-verify the finding without re-running the test.
- **Confidentiality:** findings are never posted, shared, or discussed outside the private report channel until Ticko authorizes disclosure. Draft reports live only in `~/workspace/ticko-audit/`.

---

### Phase 0 — Docs recon (DONE — this document)

- **Goal:** establish the scope boundaries and the documented-behavior baseline before any live contact.
- **Actions:** read SCOPE.md + all docs pages (§2); write this plan. Completed 2026-11-13.
- **Not allowed:** any request to a Ticko service outside `docs.ticko.xyz`; any account/Discord action.
- **Authorization needed:** none beyond the plan-writing order (already given).
- **Evidence:** this file + SCOPE.md.
- **Stop conditions:** n/a (read-only docs work).

### Phase 1 — Unauthenticated observation of the testnet deployment

- **Goal:** confirm the testnet deployment is reachable and map its public surface without logging in: landing page, market list, order-book/price displays visible without auth, public docs links, and any client-side endpoints the page itself loads during normal browsing.
- **Exact actions:**
  1. Open `https://testnet.ticko.xyz/` in the browser (read-only browsing, no sign-in, no invite code entry, no wallet connection).
  2. Record: page structure, visible markets/symbols, whether order-book, recent-trades, oracle/mark prices, and funding data are visible without auth; any version/build identifiers shown; any links to an explorer, status page, or API.
  3. Note the network requests the page itself makes during normal load (visible in the browser's own tooling) — hostnames and paths only, to map the API surface for Phase 2. Do not replay, modify, or probe those endpoints.
  4. Confirm the sign-in options shown (wallet providers listed, email option) and the invite-code prompt text, without entering anything.
- **NOT allowed:** signing in; connecting a wallet; entering an invite code; claiming the faucet; creating any account; submitting any form; replaying or fuzzing observed endpoints; any request to `app.ticko.xyz` or `ticko.xyz` beyond what the testnet page itself loads.
- **Authorization needed:** explicit user authorization for Phase 1 in chat.
- **Evidence to capture:** screenshots of the landing/trading views, the observed market list, the list of hostnames/paths the page loads, and notes on what is visible without auth.
- **Stop conditions:** §3.0 global stops, plus: stop if the page redirects to a production domain, asks for a wallet signature before any sign-in action, or shows another user's data.

### Phase 2 — Authenticated mapping (user's own testnet account)

- **Goal:** map the authenticated app, the trading-session creation flow, order flows, and any API surface visible during normal use — using only the user's own account, with the session established by the user.
- **Exact actions:**
  1. **Session handoff:** the user takes over the browser window, signs in with their own wallet (recommended) or email, enters their own invite code, and confirms the session is theirs. The agent never sees or handles credentials, keys, or the invite code value. The user confirms in chat when the session is established and ready for mapping.
  2. **Faucet (user's action):** the user claims testnet USDT from the faucet (or confirms a prior claim). Record the credited amount and the cooldown message shown — this fills docs gap §6.5.
  3. **Session creation observation:** the user enables trading (signs the session creation) in their own browser. Record what the signature prompt shows (permissions, scope, expiry if displayed — screenshot the prompt text, not the signature itself), and what the UI shows afterward (session status, expiry countdown if any, revoke/disconnect control if any). The agent does not sign anything.
  4. **App mapping:** navigate the signed-in UI (markets, order entry, positions, orders, history, account, sub-accounts, settings). Record: per-market parameters shown (price/qty steps, min/max order size, max leverage, funding interval, OI cap if shown), margin-mode and position-mode controls, order-type/TIF/STP controls offered, TP/SL controls, fee tier shown, and any API-key/token management UI if present.
  5. **Order-flow walkthrough (minimum size, own account only):** place one small limit order, observe its lifecycle (open → amend price → amend quantity down → cancel); place one small market order and close it; attach a TP/SL to a small position and close it. Record order IDs, fills, fees charged vs the §2.9 schedule, and margin figures shown vs the §2.4 formulas.
  6. **API surface note:** record any API endpoints the signed-in app calls during the above normal use (hostnames/paths/methods visible in the browser), and how requests are authenticated (header/cookie/session pattern as visible — redact values). Do not call endpoints directly.
- **NOT allowed:** using anyone else's account/keys; creating sub-accounts beyond one test sub-account if needed for mapping (and only with explicit authorization for that step); any order size beyond the minimum needed; leaving resting orders open after the walkthrough; any deposit/withdrawal attempt (unavailable on testnet — if a withdrawal control appears, do not use it; record and stop); any direct API calls; any action on `app.ticko.xyz`.
- **Authorization needed:** explicit user authorization for Phase 2 in chat + the user-established session via browser takeover. The user may end the session at any time; if the session drops, mapping stops until the user re-establishes it.
- **Evidence to capture:** session prompt text (permissions/expiry as displayed), faucet amount + cooldown, per-market parameter table, order lifecycle records, fee/margin figures vs documented formulas, API endpoint inventory (paths only, values redacted), and a list of controls whose behavior differs from the docs.
- **Stop conditions:** §3.0 global stops, plus: stop if the session prompt requests permissions beyond placing orders (e.g., withdrawals, transfers, unlimited approvals) — do not sign, record the prompt, and report; stop if any balance/position shown does not belong to the user's account.

### Phase 3 — Vuln-class testing (each sub-class separately authorized)

General: each sub-class below is its own authorization. Tests run only on the testnet deployment, only with the user's own account, at minimum sizes, human-paced. A test that succeeds in demonstrating a deviation is run **once** to capture evidence, then stopped — no repeated exploitation, no extraction of value, no persistence. Every candidate finding goes through the triage/validation gate (parent agent re-verifies from the evidence) before any report is drafted; nothing is filed without a separate user order.

#### 3a. Session-key permission boundaries + signature replay (priority 1)

Bounty-page anchor: "Misuse of trading session keys or signatures, such as placing orders or withdrawing beyond the granted permissions, or replaying signatures" — Critical-tier example: "bypassing trading session key permissions to place orders or withdraw as another user."

| # | Test | Documented expectation | Pass / fail signal |
|---|---|---|---|
| 3a-1 | Attempt an action outside the session's granted permissions using the active session (e.g., if the session prompt grants order placement only: attempt a transfer/withdrawal/sub-account action through the normal UI while the session is active) | Action outside granted permissions is refused | Refused = pass. Executed = candidate finding. |
| 3a-2 | After the session expires (or after the user revokes/disconnects it, if a control exists), attempt to place an order with the stale session state without re-signing | Expired/revoked session cannot place orders; re-signing is required | Re-sign required = pass. Order placed on stale session = candidate finding. |
| 3a-3 | Replay: capture the exact request the browser sends for one order placement (own account, own session), then re-submit the identical request a second time through the browser's own replay in the same session | Replayed request is rejected (nonce/expiry/single-use binding) or produces no duplicate effect | Rejected / no duplicate = pass. Duplicate order executed = candidate finding. |
| 3a-4 | Parameter tampering on a replayed own request: re-submit an order request with one field changed (price, quantity, or side) while keeping the original signature/auth material | Modified request is rejected (signature binds the parameters) | Rejected = pass. Modified order executes = candidate finding. |
| 3a-5 | Cross-account binding: attempt to use the session/auth material of the user's own account A against a second own account B (only if the user has two own testnet accounts and authorizes this specific test) | Session material is bound to one account and refused for another | Refused = pass. Accepted = candidate finding. Never test with any account that is not the user's own. |
| 3a-6 | Session scope across markets/permissions: if the session prompt limits scope (e.g., specific markets), attempt an order outside that scope | Out-of-scope order refused | Refused = pass. Executed = candidate finding. |

**NOT allowed:** replaying or using any signature/session material belonging to another user; extracting or exporting private keys; signing anything the user has not reviewed; testing on `app.ticko.xyz`; withdrawing anything (unavailable on testnet — treat any withdrawal path that appears as a stop-and-report event).

#### 3b. Matching / margin / liquidation behavior vs documented rules (priority 2)

Bounty-page anchors: "Incorrect order matching"; "Incorrect margin, liquidation, funding rate, or settlement calculations"; Critical example: incorrect matching/margin/liquidation/funding/settlement producing an incorrect final state or loss of funds.

| # | Test | Documented expectation | Pass / fail signal |
|---|---|---|---|
| 3b-1 | **Price-time priority:** place two own limit orders at the same price on the same market (minimum size), then a matching opposite order; observe fill order | Same-price orders fill FIFO (§2.1) | FIFO observed = pass. Out-of-order fill = candidate finding. |
| 3b-2 | **Price modification loses queue position:** place a limit order, then modify its price; check its queue position against another own order at the new price placed earlier | Modified order goes behind earlier orders at the new price (§2.1) | Queue position lost = pass. Position retained = candidate finding. |
| 3b-3 | **Quantity reduction preserves queue position:** place a limit order, reduce quantity only; check queue position | Position preserved (§2.1) | Preserved = pass. Lost = deviation (reportable as a bug; severity per impact). |
| 3b-4 | **FOK/IOC/post-only semantics:** submit a FOK order that cannot fill entirely (expect whole-order rejection); an IOC order with partial fill (expect partial fill + remainder cancelled); a post-only order that would cross (expect rejection) | Behaviors per §2.2 | As documented = pass. Any deviation (e.g., FOK partially filling, post-only taking) = candidate finding. |
| 3b-5 | **STP modes:** with own orders on both sides at crossing prices (minimum size, cancel promptly), verify each STP mode's documented behavior (default cancel-maker; cancel-taker; cancel-both) | Behavior per §2.3; no self-trade executes | As documented = pass. A self-trade executes = candidate finding. |
| 3b-6 | **Reduce-only cap:** submit a reduce-only order larger than the current position (minimum sizes) | Quantity capped to current position size; never increases/opens a position (§2.2) | Capped / position unchanged = pass. Position increased or flipped = candidate finding. |
| 3b-7 | **Attached TP/SL activation:** place a limit order with attached TP/SL, let it partially fill, then check whether the TP/SL activated | TP/SL stays dormant until the parent is fully filled (§2.2) | Dormant = pass. Activated on partial fill = candidate finding. |
| 3b-8 | **Margin math:** record effective margin, IM, MM, available margin, and margin ratio shown for a small position; recompute from the §2.4 formulas with observed values | Displayed figures match the documented formulas | Match = pass. Mismatch = candidate finding (severity depends on whether it enables excess exposure). |
| 3b-9 | **Leverage cap:** attempt to set leverage above the tier limit for a position size (own account, minimum size) | Excess leverage refused or capped at the tier limit (§2.4) | Refused/capped = pass. Excess leverage accepted = candidate finding. |
| 3b-10 | **Liquidation trigger + sequence:** drive a small isolated position's margin ratio to ≤100% (minimum size, isolated mode to contain losses); observe trigger point and the progressive steps (cancel orders → net hedges → reduce via IOC → backstop) | Trigger at ≤100% and steps in documented order, stopping when health is restored (§2.5); isolated losses contained to assigned margin | As documented = pass. Early/late trigger, skipped steps, or losses leaking to the rest of the account = candidate finding. |
| 3b-11 | **Funding settlement:** hold a small position across one funding settlement; verify payment direction/amount vs the §2.7 formula (using observed oracle price and size) and that a position opened and closed between settlements pays/receives nothing | Payment matches formula; intra-interval round trip pays nothing | Match = pass. Mismatch = candidate finding. |
| 3b-12 | **Fee math:** verify fees charged on executions against the §2.9 VIP0 schedule (or the tier shown for the account) | Fee = executed value × tier rate | Match = pass. Mismatch = candidate finding (likely Others/low severity unless it enables fee avoidance at scale). |

**NOT allowed:** large sizes; holding positions across settlements with sizes beyond the minimum; any attempt to trigger ADL affecting other traders (ADL closes *other* traders' positions — do not engineer a liquidation large enough to reach the backstop/ADL; 3b-10 stays at minimum isolated size and stops at the first liquidation step that restores health); wash-trading patterns beyond the minimal STP checks; any test that requires another user's position.

#### 3c. Oracle / mark-price behavior (priority 3)

Bounty-page anchor: "Oracle or mark prices that can be manipulated or misused because of a flaw in Ticko's logic (excluding price moves driven solely by extreme market conditions or large amounts of capital)."

| # | Test | Documented expectation | Pass / fail signal |
|---|---|---|---|
| 3c-1 | **Update cadence:** observe the oracle and mark prices for one symbol over several minutes; record update timestamps | Both update every second (§2.8) | ~1s cadence = pass. Stale/frozen prices = deviation (severity per impact on PnL/liquidation). |
| 3c-2 | **Internal-price drift:** on a thin testnet book, place small resting orders that create one-sided book pressure (minimum size, cancel promptly) and observe whether the internal price drifts in the documented direction and holds when the price sits between impact bid/ask | Drift per the IPD rules (§2.8) | As documented = pass. No drift / wrong-direction drift / drift without book pressure = candidate finding. |
| 3c-3 | **Mark = median of three signals:** where the UI exposes the three signals (or enough inputs to recompute them), verify the displayed mark price equals the median | Mark = median (§2.8) | Match = pass. Mismatch = candidate finding. If signals are not exposed, record the gap and do not guess. |
| 3c-4 | **Discovery band (if a banded symbol exists on testnet):** observe the mark price near the band bounds during normal price movement; check clamping and re-anchoring behavior | Clamp + re-anchor per §2.8; counters independent per direction | As documented = pass. Mark escaping the band, or a re-anchor consuming the wrong direction's counter = candidate finding. |
| 3c-5 | **Calendar states (TradFi symbols, if listed on testnet):** observe oracle behavior across a Regular/Extended/Closed transition if one occurs during the test window | Behavior per the calendar table (§2.8); Extended blend uses the configured weight; external outage falls back to internal | As documented = pass. Wrong state behavior = candidate finding. Do not wait days for a transition — observe only if it falls in the window. |

**NOT allowed:** attempting to move the external price (third-party venues are out of scope); large orders or capital deployment to move the book; spoofing/layering; any cross-market or cross-venue manipulation; relying on extreme market conditions (ineligible per §1.3).

#### 3d. Invite-code / faucet abuse (priority 4, tightly bounded)

Bounty-page anchor: testnet-only features and their interaction with Ticko Core, nodes, and APIs. These are access controls, so this sub-class is the most constrained (see the Terms-of-Use boundary in §1.4).

| # | Test | Documented expectation | Pass / fail signal |
|---|---|---|---|
| 3d-1 | **Faucet cooldown:** after a successful claim, attempt one additional claim inside the 24-hour cooldown | Second claim refused with a cooldown message (§2.12) | Refused = pass. Second claim credited = candidate finding. Stop after one attempt; do not drain. |
| 3d-2 | **Faucet replay:** re-submit the identical faucet-claim request (own account, same session) a second time | Duplicate claim rejected | Rejected = pass. Double credit = candidate finding. |
| 3d-3 | **Invite-code reuse:** attempt to reuse the user's own already-consumed invite code on a second own sign-in (only if the user authorizes this specific check and the UI permits a second entry) | Consumed code refused | Refused = pass. Reuse accepted = candidate finding. |
| 3d-4 | **Invite-code validation:** enter a malformed/empty code in the invite field (no guessing of valid codes — no brute force, no enumeration) | Invalid input refused with a generic error | Refused = pass. Acceptance of malformed input, or an error that leaks valid-code information = candidate finding. |

**NOT allowed:** creating additional Discord accounts; claiming codes for other people; sharing or reselling codes; brute-forcing or enumerating codes; automated claiming; more than one extra claim attempt per check; any attempt to bypass Discord verification or the invite gate as an end in itself. If any check succeeds in bypassing a control, stop immediately, do not repeat it, and report.

#### 3e. API authentication / authorization (priority 5, contingent)

Bounty-page anchor: Medium-tier "API authentication or authorization issues." The API is undocumented ("Coming Soon"), so this sub-class exists only if Phase 2 observes a real API surface.

| # | Test | Documented expectation | Pass / fail signal |
|---|---|---|---|
| 3e-1 | **Unauthenticated access:** request an endpoint observed in Phase 2 without authentication (read-only GET of public-looking data only) | Endpoints requiring auth refuse unauthenticated requests | Refused = pass. Authenticated-only data returned without auth = candidate finding (except public-by-design account state, §1.3). |
| 3e-2 | **Cross-account authorization (own accounts only):** request account B's data using account A's session (only if the user has two own accounts and authorizes this specific test) | Cross-account access refused | Refused = pass. Accepted = candidate finding. Never test with another user's account. |
| 3e-3 | **IDOR-style parameter change (own data only):** change an account/order identifier in a request to another identifier belonging to the same user | Requests are bound to the authenticated account; other-account identifiers refused | Refused = pass. Other-account data returned = candidate finding. |

**NOT allowed:** any endpoint probing beyond what Phase 2 observed in normal use; fuzzing; any POST/PUT/DELETE against endpoints whose purpose is unknown; any request that modifies state other than the user's own test orders; any attempt to access admin/internal endpoints if any appear (stop and report instead).

---

## 4. User-side prerequisites checklist

Nothing in Phases 1–3 can start until the items for that phase are done. All of these are the user's own steps — the agent cannot do them.

- [ ] **Discord:** join the Ticko Discord (`discord.com/invite/ticko`), complete verification, and claim an invitation/access code in the `#access-code` channel. (FAQ: "Claim one in the access-code channel on Ticko Discord. We recommend signing in with a wallet.") The user keeps the code to themselves — never paste it in chat, and the agent never asks for it.
- [ ] **Eligibility self-check:** the user is not a Restricted Person under the Terms of Use §3 (Indonesia is not in the Restricted Jurisdictions list; the user confirms their own status). No VPN/proxy/location concealment will be used.
- [ ] **Sign-in method chosen:** wallet (recommended by Ticko) or email. The user signs in themselves via browser takeover in their own browser session. The agent never receives credentials, private keys, or seed phrases.
- [ ] **Testnet sign-in + invite code:** the user signs in at `testnet.ticko.xyz` and enters their invite code in their own session, and confirms in chat that the session is established.
- [ ] **Faucet claim:** the user claims testnet USDT from the faucet (funds arrive within ~1 minute; 24-hour cooldown). The user reports the credited amount so the plan's baseline can be completed.
- [ ] **Trading session:** the user enables trading (signs the session creation) in their own browser, and shares what the signature prompt displayed (permissions/scope/expiry as shown) — a screenshot of the prompt text is enough; never the signature value.
- [ ] **Per-phase authorization:** the user authorizes each phase (and each Phase 3 sub-class) explicitly in chat before it starts, and can stop any phase at any time.
- [ ] **KYC awareness:** the user understands payout requires KYC/KYB + sanctions screening and USDT receipt via a Ticko-designated method/network (bounty page). No payout details are needed until a finding is filed.
- [ ] **Confidentiality:** the user will keep any finding confidential until Ticko authorizes disclosure, and will not discuss findings in Discord, X, or other public channels.

## 5. Reporting template

Reports go **by email to `security@ticko.market`** (direct submission; no platform). One issue per report. Filing needs a **separate user order** after the finding passes the triage/validation gate — this plan authorizes testing only, never filing.

```
Subject: [Ticko Bug Bounty] <Severity> — <short title>
         (e.g. [Ticko Bug Bounty] High — Session key accepts orders after revocation on testnet)

1. Summary
   - One-paragraph description of the vulnerability and its impact.
   - Severity claimed + why (map to the bounty page's tier examples, §1.5).
   - Environment: Ticko Testnet (testnet.ticko.xyz), date/time of demonstration (WIB + UTC).
   - State plainly: demonstrated on testnet only; whether the same flaw plausibly
     affects Mainnet is unknown (closed source) — do not overclaim.

2. Description
   - What the flaw is, which component it affects (session keys, matching,
     margin/liquidation, funding, oracle/mark price, faucet/invite, API auth).
   - The documented behavior it violates (cite the docs page + quote).

3. Impact assessment
   - Who is affected and how (funds, state, availability, integrity).
   - Worst realistic case on Mainnet if the same code path serves it, stated
     as a conditional ("if the same logic serves Mainnet, then ...").
   - What the flaw does NOT allow (scope the claim honestly).

4. Detailed reproduction steps
   - Numbered steps from a clean state, using only the reporter's own testnet
     account. Include exact values (market, order type, size, prices),
     the invite/faucet/session setup, and every click/request.
   - Expected result vs actual result at each step.
   - Evidence: order IDs, timestamps, screenshots, before/after balances,
     request/response excerpts (redact any secrets/signatures).

5. Proof of concept (where applicable)
   - Minimal PoC: exact steps, or a minimal script/request sequence that
     reproduces the issue on testnet with the reporter's own account only.
   - No PoC may touch Mainnet, other users' accounts, or real funds.

6. Suggested fix / mitigation (optional but valued)
   - Concrete suggestion tied to the root cause.

7. Reporter notes
   - Confirmation that testing was testnet-only, own account only, and
     complied with the program rules (no production testing, no other
     users' credentials/keys, no exploitation for gain, no public disclosure).
   - Whether public acknowledgment is requested (opt-in: name/handle + link,
     or anonymous), per the bounty page.
   - Payout: the reporter will complete KYC/KYB + sanctions screening and
     receive USDT via the method/network Ticko designates. (Payout details
     are the user's own step — never include wallet details in drafts
     the agent prepares; the user adds them at send time.)
```

**After sending:** expect an acknowledgment within one business day (FAQ). Only fund-security reports receive further follow-up. Do not disclose publicly before a fix ships and Ticko authorizes disclosure. If Ticko asks for more detail or a re-test, that is a new authorization — re-testing follows the same phase rules.

---

## 6. Docs gaps found (Phase 0)

Gaps are facts about the documentation, not findings. Each gap limits what can be asserted without observation; Phase 2 must fill the observable ones.

| # | Gap | Impact on testing |
|---|---|---|
| 6.1 | **No session-key documentation at all.** No permissions model, no scope list, no expiry duration, no revocation method, no statement of what a session key can/cannot do. Only the testnet guide's one line ("Sign to create a gasless trading session") and the bounty page's misuse examples exist. | Phase 3a tests must be built from the signature prompt observed in Phase 2. The prompt text is the de-facto permission spec — capture it verbatim. |
| 6.2 | **No API documentation** ("Coming Soon"). No endpoints, auth scheme, rate limits, or WebSocket spec published. | Phase 3e is contingent on Phase 2 observation. No API test may assume an endpoint exists. |
| 6.3 | **No per-symbol parameter values**: leverage tiers, MM rates, taker fee rate used in MM, funding cap/floor, `impact_margin_notional`, `external_pricing_weight`, discovery-band symbol list and counter limits, price/qty steps, min/max order sizes, max leverage, OI caps. | Tests must record observed values and compare behavior against formulas, not against assumed constants. |
| 6.4 | **No contract addresses, chain ID, RPC, or explorer published.** The docs claim on-chain verifiability and independent replay, but provide no endpoint to do it. | On-chain state cannot be independently verified from docs alone. If Phase 1/2 surfaces an explorer/RPC, record it; do not probe chain infrastructure beyond normal use. |
| 6.5 | **Faucet amount not stated** (only "within one minute" + 24h cooldown). | Record the credited amount in Phase 2. |
| 6.6 | **Session expiry duration not stated.** | Record any countdown/expiry shown in Phase 2; if none is shown, note that. |
| 6.7 | **Invite-code rules not fully stated.** The FAQ says only to claim a code in `#access-code`; no written one-per-account rule, expiry, or reuse policy was found in the docs pages read. (SCOPE.md's "one code per Discord account" comes from scoping notes, not from a docs page read for this plan — treat as unverified.) | Phase 3d tests must not assume a rule the docs do not state; report observed behavior only. |
| 6.8 | **Oracle sources unnamed.** "Configured third-party sources" / "industry-leading providers" — no provider names, feed addresses, or weights. | External-price manipulation cannot be tested (and is out of scope — third parties). Phase 3c is limited to internal-price/book-derived behavior. |
| 6.9 | **Conditional-order trigger ambiguity.** "Mark price or last traded price" — which one triggers, and whether the trader chooses, is not stated. | Record observed behavior in Phase 2; test both trigger readings only if the UI exposes a choice. |
| 6.10 | **Liquidation takeover threshold value not published; ADL ranking formula not published** ("combination of profitability and leverage", no weights). | 3b-10/ADL expectations are qualitative only. Do not engineer ADL (it affects other traders). |
| 6.11 | **Order-modification gap:** quantity *increase* behavior is not addressed (only price change loses position; quantity reduction preserves it). | Record observed behavior if encountered; do not assume. |
| 6.12 | **"Market maker" tier schedule referenced but absent** (sub-accounts page links to Trading Fees for "VIP and market maker schedules"; only VIP tiers exist). | Fee tests use the VIP schedule only. |
| 6.13 | **Testnet market list not published.** (Beta's 5 perps come from secondary sources — §2.13.) | Record the actual testnet market list in Phase 1/2. |
| 6.14 | **No documented rate limits, testnet reset schedule, or maintenance windows.** | Human pace + §3.0 stop conditions are the guardrail. Stop on any 429/block. |
| 6.15 | **Terms-of-Use / bounty-program tension.** The Terms prohibit scraping, reverse engineering, exploiting bugs, and circumventing eligibility/rate-limit controls (§§3.7, 6.2), while the bounty program authorizes good-faith testnet research. | This plan resolves it conservatively: manual observation only, no automation, no decompilation, bounded invite/faucet checks, no eligibility/geofencing bypass attempts. If a test would cross a Terms boundary, it needs a fresh explicit decision — default is to not run it. |

## 7. Re-check triggers

- **Source publication:** when Ticko publishes contract source + API docs (watch `@tickoxyz` + the FAQ), re-run discovery per SCOPE.md and re-scope for a source audit; the in-progress audit's report becomes the exclusion list.
- **Audit report publication:** any published Ticko audit immediately becomes "already known" exclusions — re-check before filing anything.
- **Bounty page changes:** the page states changes are announced on the page and reports are assessed under the terms in effect at submission. Re-read the bounty page + FAQ before each phase and before filing.
- **Program end:** the FAQ says the program is ongoing with no set end date; if that changes, stop and reassess.

## Sources (all read 2026-11-13, docs.ticko.xyz .md versions)

- `resources/ticko-bug-bounty.md` — scope, eligibility, tiers, prohibitions, safe harbour
- `resources/ticko-bug-bounty/ticko-bug-bounty-faq.md` — live status, access codes, testnet-only rule, public-state rule, payouts
- `resources/ticko-bug-bounty/ticko-paladin-program.md` — related program (scope separation)
- `resources/terms-of-use.md` (§§1–9 read; §§3, 6 carry the testing-relevant boundaries)
- `testnet-guide.md` — access flow, faucet, session creation
- `mainnet-beta-guide.md` — Mainnet flow (reference only; never to be tested)
- `about-ticko.md`, `trading-on-ticko/overview.md` — platform characteristics
- `trading-on-ticko/contract-specifications.md`, `order-types.md`, `matching-rules.md`, `self-trade-prevention.md`, `margin-and-leverage.md`, `oracles-and-mark-prices.md`, `funding.md`, `liquidations.md`, `auto-deleveraging.md`, `trading-fees.md`, `sub-accounts.md` — trading mechanics baseline
- `api-documentation/overview.md` — "Coming Soon" (no API surface documented)
- `llms.txt` — docs index (22 pages; all pages above cover the full index except Contact Us and Privacy Policy, which carry no testing-relevant content)
- `SCOPE.md` (same directory) — closed-source verdict, live status, secondary-source notes
