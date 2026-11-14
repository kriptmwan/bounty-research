# Ticko Bug Bounty — Scoping Report

**Date:** 2026-11-13 (WIB)
**Mode:** Read-only research. No testing, no accounts, no Discord, no filing, no GitHub API calls.
**Verdict: BLOCK for a source-code audit — Ticko is closed source. The program is LIVE, but the only possible track is testnet black-box testing, which needs user-side Discord/invite-code steps and a separate authorization.**

## 1. Public code: NO — closed source (confirmed by Ticko itself)

The decisive evidence is Ticko's own Bug Bounty FAQ (crawled 2026-11-13):

> "Where can I find the API documentation and source code? — Ticko's contracts are undergoing an audit. We'll publish the contract source code and API documentation once it is complete. Follow @tickoxyz for updates."

Corroborating evidence (all checked 2026-11-13):

| Check | Result |
|---|---|
| Docs index (docs.ticko.xyz/llms.txt) | 22 pages, all user-facing trading guides + legal. No developer section, no repo links, no contract addresses. |
| API documentation page | Single line: "API access and documentation — Coming Soon". |
| ticko.xyz homepage | Marketing only. No GitHub link anywhere on the page. |
| Web search: "Ticko derivatives github repository Ticko Core" | No Ticko repo. Only the Medium bounty article + unrelated projects (tiktoken, Tock OS, TokTok). |
| Web search: `"ticko" github.com organization "Ticko Chain"` | No org. Only Medium articles. |
| Web search: `site:github.com ticko` | No Ticko-org result. Unrelated accounts (Ticko-Grey, TickoSpy, evanswanjau/Ticko ticket-booking, TheCodeNinja254 "Ticko" event system). Only Ticko-related hits: DefiLlama/chainlist PR titles "feat(chain): add Ticko Testnet (#2952)" and "feat: add ticko mainnet" — chain-registry entries, not Ticko code. |
| GitHub REST API | NOT used (rate-limited on this VM's egress IP until ~16:03 WIB). Not needed: the FAQ answer settles it. |

**No repos cloned. No HEAD pins exist. There is nothing to audit in source form.**

Re-check trigger: when Ticko publishes the contract source (announced via @tickoxyz), re-run discovery. The in-progress audit's report will then also be an exclusion list.

## 2. Live status: YES — program is live and ongoing

- **Bug Bounty FAQ** (governing docs, crawled 2026-11-13): "Is the Bug Bounty program still active? — Yes. It is ongoing with no set end date, separate from the previous limited-time Closed Alpha Testnet campaign."
- The X article's "starts 13 November 2026, at a time to be announced" is superseded by the FAQ's current statement. The program accepts reports at security@ticko.market "at any time".
- Supporting: Ticko Paladin article (Medium, 10 Nov 2026) describes the bounty + Opening Session as open now; rewards distributed in weekly batches after review (FAQ).
- Not checked: a newer X post from @tickoxyz (x.com is blocked for text fetch from this environment; no browser in this task). Not needed — the FAQ is authoritative and current.

## 3. Audit history: none published; one audit in progress (unnamed)

- **No published audit report found.** Searches for "Ticko security audit auditor report" returned only noise about Taiko (a different project) and TikToken.
- The FAQ says the contracts "are undergoing an audit" — no auditor named, no date, no scope published.
- Medium article (3 Nov 2026) claims "ongoing penetration testing and independent audits" and an internal review after "a recent security incident at another exchange" (signature verification, session key boundaries, matching/margin/liquidation, deposit/withdrawal paths, extreme-market stress tests). No auditor names, no report links.
- **Exclusion implication:** when the in-progress audit report is published, its findings become "already known" exclusions. Until then, no exclusion list can be built.

## 4. Architecture (from docs + official articles)

**Ticko Chain — app-specific chain anchored to Ethereum.**
- Ethereum is the underlying verification, settlement, and data-availability layer (ticko.xyz).
- Ticko VM + onchain central limit order book (CLOB). Orders, balances, positions, margin, clearing, and settlement live in one unified, verifiable state; anyone can independently rebuild state and verify the state root (deterministic execution, independent replay → matching state roots).
- Performance targets: >200,000 TPS, sub-10ms execution, sub-150ms finality; pipelined block production ("execution packs") processing a continuous order stream.
- The trading interface is operated by Fusio Digital Limited; the chain is provided separately (interface is not the only way to access the chain).
- Investors named on ticko.xyz: Vertex Ventures (Temasek), LTP, Primitive Ventures, Summer Ventures.

**Matching:** onchain, price-time priority; sequential execution within a block (each order fully processed before the next); price modification loses queue position (cancel + re-place); quantity reduction preserves it.

**Margin:** cross + isolated modes usable simultaneously in one account; one-way and hedge position modes; leverage per position capped by tiered limits (larger positions → lower leverage); **USDT is the sole collateral**; liquidation when margin ratio (effective margin / total maintenance margin) ≤ 100%.

**Oracle / mark price (the most fully documented subsystem):**
- Oracle price updates every second: external price (weighted average of configured third-party sources) + internal price (derived from Ticko's own order book via impact-price imbalance, EMA-smoothed).
- Crypto symbols publish the external price (internal as fallback); TradFi symbols follow a trading calendar: Regular → external, Extended → static blend, Closed → internal.
- Mark price = median of three signals: funding-implied price, oracle + EMA basis, market consensus (weighted median of external perp mids). Discovery band clamps the mark price around a reference price with re-anchoring counters.
- Oracle sources are "industry-leading providers" + Ticko's own pricing from CEX/DEX published prices (Town Hall). No provider names, no feed addresses published.

**Session keys:** gasless trading sessions — the user signs once to create a session key that places orders within granted permissions; session-key/signature misuse and replay are explicitly in bounty scope.

**Deposits/withdrawals (Beta):** USDT on Arbitrum One only; min 5 USDT, 0.2 USDT network fee; beta guidance "do not deposit more than 500 USDT". Beta launched 20 Oct 2026 with 5 perps: BTC, ETH, XAU (gold), SKHYNIX, QQQ. Public Mainnet expected Q4 2026.

**Trust boundaries / notable rules:**
- Onchain account state and trading records are **public by design** — unauthenticated read-only access by wallet address is intended behavior and explicitly NOT a vulnerability (FAQ).
- Beta deposit caps published before a report are not vulnerabilities; bypassing them is.
- Mainnet (Beta) uses real funds and is assessed by Mainnet standards — but **testing on Mainnet/production is prohibited and disqualifies reports**. All testing must be on testnet or another non-production environment.

## 5. Testnet access path (all steps need the user's own action)

1. Join Ticko Discord (discord.com/invite/ticko) and verify; claim an **invitation/access code** in the `#access-code` channel (channel 1539210978510643231, per FAQ). One code per Discord account.
2. Go to testnet.ticko.xyz; sign in with a wallet (recommended) or email; enter the invitation code.
3. Claim testnet USDT from the faucet (arrives within ~1 minute; 24-hour cooldown). Testnet uses **mock USDT**; deposits and withdrawals are **unavailable** on testnet.
4. Sign to create a gasless trading session; trade test markets.
5. Beta Mainnet uses the same invite-code flow at app.ticko.xyz — but bounty testing there is prohibited.

User-side blockers: Discord join + verification + code claim cannot be done by the agent (no Discord automation in this task; the user's Discord account exists but joining/claiming is their step). No credentials were created or requested.

## 6. Verdict and ranked targets

### BLOCK — no source audit possible today

| Target | Status | Effort | Notes |
|---|---|---|---|
| Ticko Core / VM / order-book source audit | **BLOCKED** | n/a | No public source; audit in progress; source promised "once complete". |
| Contract audit (deployed bytecode) | **BLOCKED** | n/a | No contract addresses published; no explorer/RPC endpoints found in public registries (chainlist entries exist but chain ID/RPC/explorer were not surfaced by search; unverified). |
| API/backend black-box | **BLOCKED** | n/a | API docs "Coming Soon"; no public API surface documented. |
| Testnet black-box testing | POSSIBLE with user steps + authorization | 1–3 days | Needs: user claims invite code, testnet account, per-phase authorization. Realistic surface: trading-session permissions, order/margin/liquidation logic vs docs, oracle behavior, invite/faucet abuse. Cannot touch deposits/withdrawals (unavailable on testnet). |
| Web-app testing (ticko.xyz / app.ticko.xyz) | POSSIBLE with authorization | 1–2 days | Production web app is in scope per the X article, but testing rules say testnet only — the bounty page's "do not test on production" rule governs; web testing would need to target the testnet deployment only. |
| Re-check when source publishes | RECOMMENDED | 30 min | Watch @tickoxyz + FAQ; re-scope when source + API docs appear. The in-progress audit report becomes the exclusion list. |

**Recommendation:** PARK the code-audit track. Do not spend audit effort on a closed codebase. If the user wants action now, the only legitimate path is the testnet black-box track, gated on (a) the user claiming an invite code from Discord, and (b) a separate per-phase testing authorization. Otherwise, wait for the source publication and re-scope then.

## 7. Program terms (verified, for the record)

- Submission: email to security@ticko.market, direct, no platform, no fee. Acknowledgment within 1 business day; only fund-security reports get further follow-up.
- Rewards (governing page): Critical up to 200,000 / High up to 25,000 / Medium up to 3,000 / Others 50 USDT. Sole discretion. Weekly batch distribution after review.
- Eligibility: first valid report; not already known (incl. published audits, internal records, earlier reports — Ticko decides); reproducible; confidential until authorized; KYC/KYB + sanctions screening at payout; USDT via Ticko-designated method/network.
- Safe harbour: no legal action against good-faith compliant research.
- Related programs (not the bounty): Opening Session feedback event (20 USDT/bug, 10 slots; 10 USDT/suggestion, 20 slots; on Beta Mainnet, ends at Public Mainnet launch) and Ticko Paladin (monthly 1,000 USDT stars for high-quality feedback; Discord role + private hub). Both need the same Discord invite-code path.

## Sources

- https://docs.ticko.xyz/resources/ticko-bug-bounty (bounty page, read by parent)
- https://docs.ticko.xyz/resources/ticko-bug-bounty/ticko-bug-bounty-faq.md (FAQ — live status + closed-source statement)
- https://docs.ticko.xyz/llms.txt (docs index)
- https://docs.ticko.xyz/about-ticko.md, /trading-on-ticko/oracles-and-mark-prices.md, /trading-on-ticko/matching-rules.md, /trading-on-ticko/margin-and-leverage.md, /mainnet-beta-guide.md, /testnet-guide.md (read by parent), /api-documentation/overview.md
- https://ticko.xyz/ (homepage)
- Medium @ticko: bug bounty announcement (31 Oct 2026), "No Winter Lasts Forever" (3 Nov 2026), "Welcome to Beta" (20 Oct 2026), Town Hall recap (22 Oct 2026), Paladin (10 Nov 2026), Beta getting-started (23 Oct 2026)
- Web searches (6 queries, 2026-11-13): GitHub org discovery, audit history, chain registry — all negative for public code/audits.
