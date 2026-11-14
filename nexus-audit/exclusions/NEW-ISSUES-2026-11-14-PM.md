# Nexus (bcnmy/nexus) — Issue-tracker RE-SWEEP (PM), 2026-11-14

**Sweep date:** 2026-11-14. **Baseline:** `NEW-ISSUES-2026-11-14.md`
(list crawl 2026-11-14 02:48 UTC / 09:48 WIB; 14 new issues #325–#338;
Open (31); merged into `EXCLUSION_LIST.md` §I as EX-122–EX-135, total
176 entries). **This file covers the window AFTER that snapshot only:**
02:48 UTC → 03:19 UTC (09:48 → 10:19 WIB), ~31 minutes, plus a
boundary re-verification that the #325–#338 set is complete.

**Verdict: COMPLETE for new-issue enumeration — ZERO new issues.**
The fresh list crawl (03:19 UTC, see Methods) shows the same Open (31)
count and the same highest issue number (#338) as the 02:48 UTC
snapshot, with #325–#338 present, contiguous, and title-identical; an
independent fresh probe of issue #339 returned HTTP 404 (no such item).
No issue numbered above #338 exists as of this sweep, and no issue
number in range #325–#338 was missed by the prior sweep. Status-change
detection carries the same page-2/closed-tab limit as the prior sweep
(see Status changes); that limit does not affect the new-issue
conclusion, because any newly filed issue would appear at the top of
the newest-first page 1 and would consume a number ≥ #339 — neither
happened.

**Method (read-only):** `browser.open` text fetches of public
github.com pages + `browser.search` only. **Zero `api.github.com`
calls** (rate-limited/stopped from this VM — no calls, no retries, no
endpoint-switching). No contact with Biconomy, no filing, no login.
Git protocol was not used: it cannot list issues, and no repo-state
question arose. Issue comments were NOT read.

## Methods used and their success/failure

| # | Method | Time (UTC / WIB) | Result |
|---|---|---|---|
| 1 | `browser.open` on `https://github.com/bcnmy/nexus/issues` | ~03:11 / ~10:11 | Rendered, but STALE: header said "Page crawled 22 minutes ago (2026-11-14 02:48 UTC)" — the prior sweep's own snapshot, not a fresh read. Not relied on as fresh evidence. |
| 2 | `browser.search`, 4 queries (see Cross-checks) | ~03:11–03:12 / ~10:11–10:12 | All succeeded; none surfaced any bcnmy/nexus issue numbered above #338. Search indexes are days stale for this repo and cannot settle a ~30-minute window — corroboration only. |
| 3 | `browser.open` probe of `https://github.com/bcnmy/nexus/issues/339` | ~03:12 / ~10:12 | FRESH HTTP 404 (`upstream_status=404`, "Page not found"). URL follows the verified `.../issues/<n>` pattern of the 14 source URLs in the prior delta file; #339 had never been fetched before, so no cached copy existed. A filed-then-closed issue or PR would still render (not 404), so this rules out any item numbered #339 existing at probe time — and, since GitHub numbers are assigned sequentially, any item numbered above #339 as well. Probe was NOT repeated (single 404 is the evidence; no retry). |
| 4 | Wait for the cached list copy to age past 30 minutes, then `browser.open` on the issues list with `max_age_minutes=30` | 03:19 / 10:19 | FRESH RENDER: header "Page crawled less than a minute ago (2026-11-14 03:19 UTC)". Page 1, 25 entries, newest-first. This is the primary fresh evidence. |
| 5 | Pagination / Closed tab | — | NOT reachable: as in the prior sweep, the text rendering exposes neither page-2 nor Closed-tab links as followable outlinks, and no URLs were guessed beyond the single #339 probe in row 3. Page-2 open issues (6 oldest) and the closed list were not directly re-rendered. See Status changes. |

## Counts

| Category | Count |
|---|---|
| New issues numbered above #338 | **0** |
| Issues in range #325–#338 missed by the prior sweep | **0** (all 14 present, contiguous, titles match the prior delta file) |
| New closed issues (numbered above #324) | **0 observed** (see Status changes — limits apply) |
| Status changes (open→closed or closed→reopened) after 02:48 UTC | **0 observed** (see Status changes — limits apply) |
| New published security advisories (GHSA) | Not re-swept in this pass (out of scope for this re-sweep task; prior sweep found none beyond GHSA-q47q-h6x2-f5qg) |
| New audit-report mentions | Not re-swept in this pass (prior sweep found none dated after 2026-11-13) |

## New issues

**None.** No issue numbered above #338 exists as of 03:19 UTC
2026-11-14. There is no list to enumerate, no body to summarize, and
no Option 3 / Option 4 scope tag to assign. The highest issue number
seen on the fresh list render is **#338** ("[Low]
validateSignatureWithData accepts address(0) as owner — any garbage
signature validates", opened Nov 13, 2026), identical to the 02:48 UTC
snapshot.

## Boundary re-verification (#325–#338 complete)

The fresh 03:19 UTC page-1 render lists, newest-first, all 14 issues
#338, #337, #336, #335, #334, #333, #332, #331, #330, #329, #328,
#327, #326, #325 — contiguous, no gaps, no number in that range
unaccounted for, and every title matches the prior delta file
verbatim. Below them, the same 11 previously recorded open issues
appear as in the prior sweep: #321, #320, #319, #316, #312, #310,
#309, #308, #307, #306, #305. Page 1 shows 25 entries total, as
before. The prior sweep's #325–#338 set is confirmed complete; no
deduplication action is needed and nothing was added twice.

## Status changes after 02:48 UTC

**Observed: none.** Evidence and limits, stated honestly:

- The fresh list crawl (03:19 UTC) shows **Open (31)** — unchanged
  from 02:48 UTC. 31 = 17 baseline open + 14 new (#325–#338),
  consistent with zero closures and zero reopenings in the window.
- All 25 page-1 entries are identical (numbers, titles, order) to the
  02:48 UTC snapshot, including all 14 of #325–#338 still shown open.
- The #339 404 independently rules out a file-and-close (or
  file-and-reopen) event consuming a new number in the window.
- **Limit:** the 6 oldest open issues (arithmetically #304, #303,
  #300, #298, #296, #106, on unrendered page 2) and the closed list
  (baseline: 30) could NOT be directly re-rendered in this pass, for
  the same rendering reason as the prior sweep. A close and a reopen
  of the same page-2 issue within the window, with no net count
  change, would not be visible to this method. No such event was
  observed; none is asserted either way beyond the evidence above.
  The coordinator should re-verify the closed count and the 6 oldest
  open issues via a live browser before any filing.

## Cross-checks (web search)

Four `browser.search` queries, all returning no bcnmy/nexus issue
above #338:

1. `bcnmy nexus github issues 339 340` — unrelated repos/commits only.
2. `"bcnmy/nexus" issue opened November 14 2026` — unrelated results;
   the only bcnmy/nexus hits were SECURITY.md and old issue #298.
3. `site github.com bcnmy nexus issues` — SECURITY.md, audit PDFs, an
   old PR, and the stx-contracts issues list; nothing new.
4. `bcnmy nexus bug bounty issue NexusBootstrap K1Validator November
   2026` — 2024 CodeHawks submissions only (already-recorded audit
   lineage; no GitHub issue numbers above #338).

Search corroboration is weak by nature here (index crawls days old);
the conclusion rests on the fresh list render + the fresh #339 404,
not on search.

## Scope impact for the Option 3/4 run

**None.** Zero new issues means zero new Option 3 scope items
(factories/bootstrap/proxy: NexusAccountFactory,
BiconomyMetaFactory, K1ValidatorFactory, NexusBootstrap,
BootstrapLib, NexusProxy, Initializable), zero new Option 4 scope
items (K1Validator, Nexus.sol ERC-7739 paths, RegistryAdapter), and
zero new out-of-scope tracker items. No status change affecting
Option 3/4 scope was observed. The Option 3/4-relevant items from
the prior delta remain as already recorded in `EXCLUSION_LIST.md`
§I (notably EX-122/#325 bootstrap, EX-126/#329 bootstrap init,
EX-131/#334 K1Validator, EX-128/EX-132 `isValidSignature`
variants); this re-sweep adds nothing to them and changes none of
their statuses as far as could be verified.

## EXCLUSION_LIST.md

**NOT touched.** Per the task instructions, with zero genuinely new
issues the exclusion list is left unchanged: total remains **176
entries** (EX-001–EX-136 security/tracker/advisory + EX-G01–G07 gas
+ EX-I01–I33 info). No numbering was consumed by this sweep; the
next genuinely new security/tracker entry, if any, would continue
at EX-137.

## Sweep limits

1. **No API.** All GitHub API access was stopped/rate-limited; this
   sweep used page reads and one direct-URL probe only. Counts above
   are page-render counts, not API counts.
2. **Cache behavior.** The first list fetch returned the prior
   sweep's 02:48 UTC cached copy; freshness was obtained only by
   waiting past the 30-minute cache age and re-fetching with
   `max_age_minutes=30`. Any re-sweep sooner than ~30 minutes after
   a crawl risks reading the same cached copy — always check the
   "Page crawled" header.
3. **Issue comments not read.** A maintainer triage note posted in
   the window (e.g. closing one of #325–#338 as a duplicate) would
   not be captured beyond the open-count/list evidence above.
   Re-check immediately before filing.
4. **PRs not separately swept.** GitHub issue/PR numbers share one
   sequence; the #339 404 covers both (no PR numbered #339+ exists
   either, as of probe time ~03:12 UTC).
5. **Snapshot time.** Fresh evidence ends 03:19 UTC (10:19 WIB).
   Issues filed after that moment are not covered. The tracker filed
   14 issues in ~6.5 hours before the prior sweep — re-sweep before
   filing.
6. **Private reports unsearchable.** As in the baseline §H:
   SECURITY.md routes Critical/High reports to private email; #303's
   unknown contents and any other private reports cannot be ruled
   out by any public sweep.

*End of re-sweep delta. 0 new issues, 0 missed boundary issues, 0
status changes observed. EXCLUSION_LIST.md unchanged at 176 entries.
No coordinator merge needed for this file beyond noting the
re-verification.*
