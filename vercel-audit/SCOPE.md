# Vercel HackerOne — Scoping Report

- **Date:** 2026-11-13 (WIB)
- **Mode:** READ-ONLY scoping. No live testing, no account creation, no submissions, no credentials, no scanners. Git clones via git protocol only; the GitHub API was never used.
- **Method:** `adversarial_code_audit` recon/evidence discipline — exact pins recorded, claims verified in the cloned sources, unverifiable items marked UNVERIFIED, fail closed.
- **Clones:** `~/workspace/vercel-audit/repos/` (18/18 succeeded, shallow `--depth 1`, HEAD at clone time). Clone log: `clone-log.txt`. Inventory outputs: `inventory.txt`, `inventory2.txt`.

## 1. Program facts (verified 2026-11-13 from public HackerOne pages, no login)

- Program page: https://hackerone.com/vercel?type=team — public bounty program, launched Sep 2026. 358 reports resolved; $688,015 total paid; average bounty $1,198–$1,500; top bounty $2,842–$9,500; response efficiency 100%; managed, with Retesting and Collaboration.
- Bounty tiers (per asset tier on the Scope page):
  - **Vercel Platform:** Low $50–500, Medium $750–1,750, High $2,000–3,000, Critical $3,500–5,500.
  - **Open Source Tier 1:** Low $200–500, Medium $550–1,000, High $1,250–5,000, Critical $5,250–10,000.
  - **Open Source Tier 2:** Low $50–200, Medium $250–500, High $750–2,500, Critical $2,750–5,000.
- Platform scope (7 assets): vercel.com, vercel.app, Vercel Sandbox, v0.dev, v0.app, *.vercel.live, *.vercel.com.
- OSS scope (18 repos — 15 Tier 1 + 3 Tier 2; see inventory below). better-auth added 31 Oct 2026, **core library only**.
- Rules: test accounts self-provisioned (free Vercel Hobby account, own accounts/data only); no destructive or high-volume testing; no automated scanning that degrades service; out of scope: contacting staff/phishing, feedback forms, SSRF with no demonstrable impact, example/reference/test code; coordinated disclosure only; Safe Harbor for good-faith research; no minimum Signal/reputation; Vercel employees/contractors/immediate family ineligible. A separate VDP covers no-impact vulnerabilities.
- ⚠️ **Filing-route ambiguity (UNVERIFIED):** `vercel/chat`'s SECURITY.md says bounty eligibility is governed by a *different* program slug, https://hackerone.com/vercel-open-source, while the parent brief verified the `vercel` program page carries the OSS tiers. Confirm which program page governs a filing before submitting anything. Do not assume.

## 2. Repo inventory

LOC method: lines in tracked source files (ts/tsx/js/jsx/mjs/cjs/mts/cts/rs/go/py/svelte/vue/css/scss), excluding tests, examples, docs, fixtures, benchmarks, playgrounds, and build output. Approximate; next.js includes Rust (Turbopack) crates. Pins are the shallow-clone HEADs.

| Repo | Tier | Pin (short) | Core LOC | Last commit | SECURITY.md? | Notes |
|---|---|---|---|---|---|---|
| vercel/workflow | 1 | `87cde0b5` | ~271k | 2026-11-13 | No | Workflow SDK (durable workflows, quickjs-wasi); 27 packages incl. framework adapters; changelog CVE mentions are dependency bumps |
| vercel/vercel | 1 | `155eacfa` | ~546k | 2026-11-12 | No | CLI + runtimes + build utils (TS/Rust/Go/Python); CLI changelog records a real fix: tar link-following traversal CVE-2024-12905 / CVE-2025-48387 |
| vercel/turborepo | 1 | `621eafe9` | ~419k | 2026-11-12 | Yes (points to security.vercel.com) | Build system (Rust + TS); Go toolchain absent on VM → Go parts static-only |
| vercel/swr | 1 | `8148ef01` | ~9k | 2026-10-16 | Yes (.github) | React data-fetching lib; small, mature |
| vercel/next.js | 1 | `e242b0c3` | ~1,702k | 2026-11-13 | No | Branch **canary** (default). Framework + Turbopack Rust. Largest target; heavily audited, heavy researcher competition |
| vercel/flags | 1 | `072184fb` | ~22k | 2026-11-11 | No | Flags SDK + 12 provider adapters; OIDC clients noted in recent commit |
| vercel/chat | 1 | `68f20fb7` | ~115k | 2026-11-13 | Yes (.github, detailed) | Chat SDK + 17 messaging-platform adapters + state stores; SECURITY.md lists valid-report classes (webhook forgery, cross-tenant routing, credential exfil, SSRF via attachments) |
| vercel/async-sema | 1 | `603842b8` | 381 | 2021-08-16 | No | **Dormant** — untouched since 2021; tiny semaphore lib |
| vercel/ai | 1 | `8bc7652c` | ~550k | 2026-11-13 | Yes (.github) | AI SDK + ~70 provider/integration packages; changelog CVE-2025-55182 is a React RSC dep bump, not an AI SDK flaw |
| vercel-labs/skills | 1 | `b716f9dc` | ~22k | 2026-11-13 | No | CLI for the agent-skills ecosystem (installs skill packages — supply-chain-adjacent surface) |
| vercel-labs/agent-skills | 1 | `1a2c79d4` | ~16k | 2026-10-27 | No | Collection of agent skills (mostly Markdown + .mjs scripts); content, not a library — low audit value |
| sveltejs/svelte | 1 | `0156c5fe` | ~78k | 2026-11-12 | No | Compiler + runtime (JS); no in-repo security policy found (policy may live on svelte.dev — UNVERIFIED) |
| nuxt/nuxt | 1 | `850bce0e` | ~81k | 2026-11-13 | Yes (detailed) | Framework; SECURITY.md explicitly scopes integration bugs with Nitro/h3/Vue and lists accepted classes (SSR cross-user leaks, access-control bypass, XSS via own APIs, island-request handling) |
| nitrojs/nitro | 1 | `0f2a7f49` | ~34k | 2026-11-12 | No | Server engine (Nuxt's runtime); no security-contact file found in repo — UNVERIFIED how Nitro-only reports are routed |
| better-auth/better-auth | 1 | `0a014aef` | ~22k strict core / ~34k plugins | 2026-11-12 | Yes | Auth library; scope = **core library only** (see §3). Own disclosure channel (GitHub advisories / security@better-auth.com) differs from Vercel's |
| vercel/ms | 2 | `4ff48cec` | 283 | 2026-05-20 | No | Tiny time-parsing lib; near-zero attack surface |
| vercel/eve | 2 | `1b237a57` | ~368k | 2026-11-12 | Yes + security-model doc | Filesystem-first framework for durable AI agents; documented trust boundaries (trusted app runtime vs isolated sandbox microVM); includes browser/desktop/computer-use agents |
| sveltejs/kit | 2 | `03c5f4b8` | ~55k | 2026-11-12 | No | Web framework + adapters; changelog records fixed CSRF issues CVE-2023-29003 / CVE-2023-29008 (exclusions — do not re-report) |

Full pins (40-char), branch, and per-repo file counts: `inventory.txt` / `inventory2.txt`.

### better-auth core breakdown (measured, not estimated)

- `packages/better-auth/src` total: 155,943 lines / 393 files (includes tests).
- Strict core (src minus `plugins/`, minus test files): **22,349 lines / 130 files** — `api/`, `auth/`, `cookies/`, `crypto/`, `db/`, `oauth2/`, `social-providers/`, `utils/`, `client/`, `context/`.
- Plugins (non-test): 33,666 lines / 137 files across 28 plugin dirs (admin, organization, two-factor, jwt, magic-link, email-otp, phone-number, siwe, …).
- Other packages (`core`, adapters, expo, electron, mcp, sso, stripe, …) are separate packages and are NOT the "core library" on any reading.

## 3. Exclusion-relevant facts

1. **Program-level (HackerOne policy governs bounty eligibility):** example/reference/test code is OUT. Every monorepo below has `examples/`, `docs/`, `playgrounds`/`playground`, test fixtures, and benchmarks — all excluded from bounty scope. Do not report findings in those paths.
2. **Chat SDK conflict:** `vercel/chat` SECURITY.md says "Security issues in our documented setup instructions and examples are also in scope" *for investigation* — but the HackerOne policy excludes example code from *bounty* scope. HackerOne governs eligibility; treat chat examples as out of scope for bounty unless the program page says otherwise.
3. **better-auth "core library only" — boundary UNVERIFIED:** it is not established whether the 28 in-package plugins count as "core library". The strict-core slice (§2) is the safe audit surface. Plugin findings must be held until the boundary is confirmed (ask via the program, or file only strict-core findings).
4. **Nuxt composition scope:** Nuxt's SECURITY.md explicitly accepts *integration bugs* (Nuxt's composition of Nitro/h3/Vue creating a gap) even when the code lives in a dependency, and gives a real precedent (GHSA-mm7m-92g8-7m47, case-sensitivity route-rule bypass). Nitro itself is separately in scope (Tier 1), so a Nitro-rooted bug can be filed against Nitro; a composition-only bug belongs to Nuxt.
5. **Known/fixed — do not re-report:** SvelteKit CSRF CVE-2023-29003 / CVE-2023-29008 (fixed, changelog-verified); Vercel CLI tar traversal CVE-2024-12905 / CVE-2025-48387 (fixed, changelog-verified). Changelog CVE mentions in `vercel/ai` and `vercel/workflow` are dependency version bumps (React RSC etc.), not own-code flaws — verify any future CVE mention in context before treating it as an exclusion or a finding.
6. **No public audit reports found inside any cloned repo** (no `audit*`/`advisories` docs at depth ≤2 except Eve's security-model doc and the SECURITY.md files noted). Audit history beyond the repos was NOT checked (no GitHub API, no web advisories search in this scoping pass) — mark as UNVERIFIED, not as "no audits exist". A dedup pass against public advisories is required before any filing.
7. **Platform scope is separate:** vercel.com/v0/Sandbox black-box testing needs a self-provisioned Hobby account and separate per-phase authorization; it is not covered by this code scoping.

## 4. Ranked audit options

### Option 1 — better-auth strict core (RECOMMENDED)
- **Surface:** `packages/better-auth/src` minus plugins/tests — 22k LOC: session/cookie handling, OAuth2 + social providers, crypto, DB/adapters, auth endpoints.
- **Why first:** highest value density — authentication is the CRITICAL risk class; Tier 1 Critical pays up to $10,000; added to the program 31 Oct 2026, so it is the freshest target and least picked over by Vercel-program researchers; single-pass feasible.
- **Effort:** ~1 day single-pass Hunter→Skeptic→Referee + local repro (Node available; no build needed for most logic repros).
- **Caveat:** hold plugin findings pending the §3.3 boundary question; dedup against better-auth's public advisories before filing (UNVERIFIED in this pass).

### Option 2 — Nitro server engine
- **Surface:** `src/` — 34k LOC: routing, route rules, static/public serving, proxy, prerender, dev server, presets.
- **Why:** Tier 1; server request handling is a HIGH/CRITICAL surface; no SECURITY.md and lower profile than Nuxt/Next means less researcher attention; pairs naturally with Nuxt composition bugs (§3.4).
- **Effort:** ~1 day single-pass.
- **Caveat:** no in-repo security contact found; filing route is the Vercel program page (confirm at filing time).

### Option 3 — SvelteKit core (`packages/kit`)
- **Surface:** ~55k LOC core (adapters excluded from the count's core but present in repo): CSRF protection, form actions, cookies, CSP, data serialization, server/client boundary.
- **Why:** Tier 2 but a proven vuln class history (CSRF CVEs fixed in 2023 — the same code families remain the highest-yield area); self-contained JS codebase.
- **Effort:** ~1–1.5 days single-pass.
- **Caveat:** Tier 2 caps Critical at $5,000; must dedup against SvelteKit's advisory history (UNVERIFIED here).

### Option 4 — Small-target sweep: SWR + Flags core + ms + async-sema
- **Surface:** SWR 9k + flags core ~22k (adapters excluded) + ms 283 lines + async-sema 381 lines.
- **Why:** half-day sweep; ms/async-sema are fully readable in one pass each; flags has OIDC/adapter config surface.
- **Effort:** ~0.5 day total.
- **Caveat:** low ceiling — tiny mature libs are heavily depended upon and likely well-picked-over; async-sema dormant since 2021 (a finding there may be judged low-impact/stale).

### NOT recommended as a first audit
- **next.js whole-repo:** 1.7M LOC incl. Rust; only viable as a tightly-sliced sub-audit (e.g. middleware/cookies/headers handling) with an explicit file list — and it is the most heavily audited target on the program. Defer unless the user orders a specific slice.
- **vercel/ai, vercel/vercel, vercel/turborepo, vercel/eve, vercel/chat, vercel/workflow:** 115k–550k LOC each; need domain slicing before any pass. Eve is the most interesting of these (documented trust boundaries + sandbox escapes) but Tier 2 and very large — a bounded slice (e.g. sandbox/host boundary) is a possible second-phase option.
- **vercel-labs/agent-skills:** prompt/skill content, not library code — no meaningful code-audit surface.
- **Platform black-box testing:** needs a Hobby account + separate per-phase authorization; not started, not authorized by this scoping task.

## 5. Gaps and unverified items

- Public advisory/dedup history for all 18 repos: UNVERIFIED (no GitHub API use; no advisories search in this pass). Required before any filing.
- Whether better-auth plugins count as "core library": UNVERIFIED (§3.3).
- Which HackerOne program slug governs OSS filings (`vercel` vs `vercel-open-source`): UNVERIFIED (§1).
- Nitro-only and Svelte/SvelteKit security-contact routes: UNVERIFIED (no in-repo policy found).
- next.js clone is on branch `canary` (the repo default); the program does not pin a branch — confirm the audited branch matches a released version before filing version-sensitive claims.
- Go toolchain is absent on this VM (per skill §14): Go code (turborepo parts, vercel CLI Go parts) is static-review only; Rust is also absent (noted in prior session context — re-verify before relying on it for any Rust repro).

## DECISION

DECISION: CAUTION — proceed to an audit of Option 1 (better-auth strict core) first; the program, scope, and code are all verified and free to pursue, but confirm the better-auth plugin boundary and the correct HackerOne filing route before filing anything, and run a public-advisory dedup pass before any report.
