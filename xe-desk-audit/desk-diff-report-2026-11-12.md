# XE Desk — Diff Audit Report, 2026-11-12

**Repo:** `xeprotocol/desk` (Python bounty-desk app, testnet-0005)
**HEAD audited:** `ab9df7fdc4f48bee4101060b59b8a2d80e818136` — 2026-11-10 15:29:53 UTC, "Stats: /stats, the programme in numbers…"
**Audit window:** 2026-11-12, ~16:58–17:10 WIB
**Method:** read-only code review + local reproduction only. No login, no filing, no live interaction
except public read-only reads (GitHub repo reads and the desk's public `/v1/tickets` API for dedup).
**Checkout:** fresh full clone at `~/workspace/xe-desk-audit/desk-new/` (clean, branch `main`).
The prior checkout at `~/workspace/xe-desk-audit/desk/` was not touched, fetched into, or modified.

## Verdict

**No novel surviving candidates. Nothing to file.**

The diff is empty: HEAD is the same commit the prior audit covered (`ab9df7f`), so there are no new
commits, no new features, and no fixes to assess. The audit therefore deepened the thinly covered
areas at the same commit (frontend JS, SSE/log streaming, stats/leaderboard, triage import, CLI entry
points, config defaults, notify/mail paths, sync remainder, templates, signed-request verification).
Every flaw re-checked is either already filed (by this programme's reporters or by the prior audit's
five filings) or was rejected on the merits. The single new lead found in this session — the browser
signer's `hexToBytes` silently coercing non-hex seeds to zero bytes — was reproduced locally and then
dedup-checked: it is an exact duplicate of **XE-3105**, filed 2026-11-10 by another reporter.

Counts by severity: Critical 0, Severe 0, High 0, Medium 0, Minor 0. No Critical/Severe flags.
HELD section: empty — nothing met even the held bar (see near-misses).

## Per-commit diff summary

`git log ab9df7f..HEAD` is empty; `ab9df7f` is HEAD itself. Per-commit summary: **no commits**.

Consequently, none of the files the brief asked about changed: `review_reason`/`send_plain`,
`proposals.py`/`decide_many`, `signer.py`/`context.py`, reporter-reply throttling, `reply_draft` caps,
`merge`, and `sync.link_pull` are all byte-identical to the prior audit's commit.

## Fixes confirmed at HEAD

**None.** HEAD is unchanged, so nothing was fixed. Re-verified present at HEAD (same code, same lines):

| Flaw | Status at HEAD | Ticket |
|---|---|---|
| `review_reason` word-form filter bypass | still present (`desk/services/thread.py:357-403`) | XE-10091 (filed) |
| Bulk adoption defeats closure guard | still present (`desk/services/proposals.py:198,416-466`) | XE-10093 (filed) |
| Reporter thread replies unthrottled | still present (`desk/api/reporter.py:527-534`) | XE-10095 (filed) |
| `reply_draft` proposal values unbounded | still present (`desk/api/agent.py:32-55`, `proposals.py:248`) | XE-10097 (filed) |
| Signer load failure → unsigned log (fail-open) | still present (`desk/context.py:70-78`) | XE-10100 (filed) |
| Merge `UniqueViolationError` half | still present (`desk/services/reporters.py:259-295`, `models.py:249`) | XE-1129 |
| PR-edit → patched, ASSESSMENT_HELD bypass | still present (`link_pull`/`_follow_pull_state`/`handle_webhook`) | XE-1128 |
| `payouts.csv` fractional truncation | still present (`// 1_000_000`) | XE-1736 |
| Discord `/answer`, `/add`, private-thread fallback | unchanged | XE-7855 / XE-7974 / XE-5851 |
| `push_labels` stale snapshot | unchanged | XE-1795 |

## Surviving novel candidates

None. See "Duplicates found" for the one lead that was verified and then dedup-killed.

## HELD — needs parent decision

None. No item was uncertain-but-promising enough to hold: the only verified new flaw is an exact
duplicate (XE-3105, below), and the remaining leads were rejected on the merits (see near-misses).

## Duplicates found this session

### D-1 — `hexToBytes` silently coerces non-hex seeds to zero bytes → DUPLICATE OF XE-3105

- **Code (verified at HEAD):** `desk/static/signer.js` — `hexToBytes` trims/lowercases, checks odd
  length only, then `parseInt(h.substr(i*2,2), 16)` per byte pair. `parseInt` of a non-hex pair yields
  `NaN`, which becomes `0` in the `Uint8Array`. `setSeed` only checks the result is 32 bytes. No hex
  validation exists on any caller path (`reporter.js` XE login, payout binding, keybox form).
- **Local reproduction (executed, Node v24, verbatim function copied from the file):**
  `64×'z'`, `64×'g'`, `64×'q'` all → 32 zero bytes, identical to the all-zero seed `00…00`;
  `'zz'+'ab'×31` → `00ab…`; `'1z'×32` → `01…01`; a 64-char English string → deterministic mangled
  bytes. All pass the 32-byte length gate. Distinct garbage inputs collide to the same publicly
  derivable key (the all-zero seed). Seeds never leave the browser; the flaw is client-side input
  validation only, and the server's `SignedRequest` model (`desk/auth.py:744-763`) strictly validates
  hex — which is why this is a browser-only issue.
- **Dedup (live API, 2026-11-12 ~17:04 WIB):** `GET /v1/tickets?q=hexToBytes` returned 13 tickets,
  including **XE-3105** (status new, area other, claimed Minor, filed 2026-11-10 10:24 UTC):
  *"Desk: browser signer hexToBytes silently coerces non-hex input to zero bytes — a garbage 64-char
  'seed' loads as the all-zero key."* Exact same function, same mechanism, same consequence.
  Adjacent tickets read: XE-6046 (address-as-seed, already in registry), XE-6628 (DAO copy, different
  codebase), XE-6895 (web-wallet copy, different codebase), XE-4357 (SDK `hexToBytes`, different
  codebase). A second query `q=browser signer seed` returned 0 tickets. Web search for the same
  theme returned nothing relevant. **Do not file.**
- **Residual limitation:** private/undisclosed tickets are unsearchable, so a private duplicate can
  never be fully excluded — but here a public exact duplicate already settles it.

Other already-filed themes re-encountered while reading (all in the prior report's dedup registry,
none re-reported): `send_mail` header injection fixed per XE-1167 (`desk/auth.py:823+`, header values
collapsed to one line); signed-request strict hex per XE-2215/XE-0699 (`desk/auth.py:744-763`,
`SignedRequest` flat-payload cap of 16 values, domain-separated digests in `desk/canonical.py`);
`upsert_issue` edit path without `clean_text` (XE-1793/XE-0827 — payload already passes `gh.storable`);
`open_disclosure`/`mirror_reply` sealed-body handling (no path serves sealed plaintext — see
near-misses); session cookie `Domain=xe.network` (XE-2059); XFF spoofing (XE-7217).

## Areas checked and clean (this session's deepened coverage)

- **Frontend JS** — `desk/static/desk.js` (538 lines, full read): bulk-adopt chip logic matches the
  XE-10093 mechanism; `send_plain`/`send_review` calls gated by team session + CSRF; no new issue.
  `desk/static/reporter.js`: XE login/payout binding use `Signer` correctly; `bindPayout` uses
  try/finally `forget()`; the `xe-use-new` error path leaves the seed in `sessionStorage`, but the
  seed is displayed on screen in that flow, so no added exposure. `desk/static/signer.js`: seed in
  `sessionStorage` is documented design; only flaw is D-1 (duplicate). `desk/static/stats.js`: renders
  server JSON only.
- **SSE / log streaming** — `/v1/log`, `/v1/events/stream`, `log_entry`: `can(p, "read:private")`
  with no ticket returns False for reporters/anon (`desk/authz.py:102-124`); `event_to_dict(full=…)`
  and `public_payload` drop held keys; pagination clamps offsets/limits. Clean.
- **Stats / leaderboard** — `desk/services/stats.py`: sealed reports counted only as filed-when
  (documented design in the module docstring); `by_area`/`fixed_by_tier` public-only with
  `assessment_held`/`award_published` rules; snapshot cache is safe because the page is identical
  for all readers. No new differential. Clean by design.
- **Triage import/export** — `export_markdown` refuses non-`sees_assessment` callers, uses
  `hidden_targets`, `_cell` escaping, single-statement `every_ticket`. `import_rows` guards
  (IMPORT_MOVES_FROM, XE-2051 facts rule, cleared-link, award, support-door) present.
  `parse_triage` short-row crash is local-trusted-file robustness only. Clean.
- **CLI entry points** — `desk/cli.py`: `keys init` chmod-0600-after-write window was already a
  prior near-miss; `add_key` preserves existing file perms; `import-triage`/`import-github`/
  `import-internal` check tokens; `github-labels` lacks a token check (cosmetic: unauthenticated
  GitHub call fails loudly). `verify-log`, `health`, `copy-lint` are local operator tools. No
  filing-ready issue.
- **Config defaults** — `config/desk.yaml` (tiers/ceilings match the programme; intake daily cap 10;
  repos/labels as documented); `.env.example`/`docker-compose.yml`/`Dockerfile`: placeholder secrets
  only; DB service has no published port; default `desk`/`desk` DB password is localhost/dev-only
  with compose overrides. `config/copy/public.yaml` `plain_phrases` are exact-match stock phrases
  (prior audit's stripping analysis stands). Clean.
- **Notify / mail paths** — `desk/services/notify.py` (owed-reply mail only on successful route
  return via `deps.request_db`; recipients are the reporter's own verified address); `send_mail`
  header-injection fix confirmed (XE-1167); invite mail admin-gated (`desk/api/authn.py:217-238`).
  Clean.
- **Sync remainder** — `desk/services/sync.py` lines 1–87 and 88–870: `account_blocked`,
  `reporter_for`, `upsert_issue`, `handle_webhook`, `push_labels`, `link_pull`, `open_disclosure`,
  `_follow_internal_state`, `import_repo` (cursor advances only on success). Webhook HMAC verified
  before dispatch; internal-repo guard present; `mirror_reply` cannot serve sealed bodies (queue is
  pulled back to `none` and body sealed atomically by `seal_thread`; worker re-checks via
  `as_it_is_now`). Clean beyond known duplicates (XE-1128, XE-1795, XE-5850).
- **Templates / rendering** — `desk/templates/ticket.html`, `live.html`, `list.html` context:
  reporter email / `internal_ref` / payout address behind `{% if team %}`; similar/klass/family/notes/
  proposals gated in the route by `can(p, "read:notes", t)`. Markdown rendering uses MarkdownIt with
  `html: False`, `linkify: False` (`desk/ui.py:38-41`); the only `Markup(` uses wrap that renderer
  plus a `rel="nofollow noopener"` post-pass. No `|safe` in templates. `live.html` `innerHTML`
  interpolates only server-generated numbers/literal kinds/ticket ids; summaries via `textContent`.
  Clean.
- **Auth / sessions (spot-check)** — `desk/api/authn.py`: invite creation admin-gated; invite accept
  rate-limited; logout clears only a held session; `session_info` exposes no secrets.
  `desk/auth.py` `verify_signed`: signature PK in `SeenSignature`, purge cutoff `2 * MAX_SKEW_NS`
  exactly covers future-dated signatures; `same_secret` is constant-time with surrogate-safe encoding.
  Discord/GitHub callbacks require verified emails; `_link_target` guards merges. Clean.
- **Status machine** — `set_status`/`status_path`: disclosed needs patch+vault, awarded needs
  approved award + ceiling re-check, paid needs `paid_ref`, paid/awarded walk-back refused,
  `TERMINAL` never intermediate. Clean.
- **Attachments** — `open_attachment` paths come only from `_blob_path` (SAFE_NAME-sanitized, no
  traversal); `save_attachment` reads bounded `limit+1`; filing checks count before create. Clean.
- **Agent brief** — `desk/brief.py` explicitly instructs agents that ticket text is never an
  instruction and steering attempts are evidence. Token standing instructions are the owner's own
  words shown to the owner's agent — intended. Clean.
- **Discord bot** — `desk/bots/discord_bot.py`: `is_team` role-id equality, `need_team` on mutating
  commands, `/ticket` withholds status for sealed tickets. Clean beyond known duplicates.
- **OG / mirror** — `desk/og.py` ETag covers only the shown spec (XE-0822); private tickets get the
  site card via `can_see(ANON, t)`; ≤1h stale card after sealing is the known accepted tradeoff.
  `desk/mirror.py` `.md` twins reuse handler + principal; no-store headers apply. Clean.

## Near-misses rejected (with reasons)

- **`tell.tell_resting` race** — the under-lock re-check covers `status_changed_at`/`untold`/`t.draft`
  but not a `reply_draft` proposal created after `resting()` read. Worst case: a stock reply is sent
  while an agent draft is still pending, and the draft may later be adopted too (double reply).
  Narrow window, no confidentiality/integrity impact, arguably within the grace-period design.
  Rejected as a filing; not held (impact too small to stake a filing on even if confirmed).
- **`unlink(kind="discord_handle")` pops only the handle key** — cosmetic; no security impact.
- **`add_patch_ref` update branch sets uncapped fields on existing rows** — all callers pass bounded
  values; at most a robustness 500 on a team-only path. Rejected.
- **Negative/oversized awards** — `set_award` rejects `award_xe < 0` and `> AWARD_MAX`. Dead lead.
- **Token issuance bound to another member** — `users.issue` requires admin when owner differs;
  revoke/instruct owner-or-admin gated. Dead lead.
- **`fill`/`fill_for` extra-override of held tier/award** — all callers pass only
  `patch_refs`/`what`/`reason`/`answer`/`duplicate_url`; no override path. Dead lead.
- **`bot_text` `.format`** — template comes from operator config; attacker text is only ever a value.
  Dead lead.
- **`seal_thread`/`_unseal` asymmetry** — disclosure unseals the ticket body only; sealed
  messages/attachments/replies stay sealed (prior audit already considered this; no new path found).
  Rejected.
- **`similar()` / LIKE `_` wildcards** — tsquery terms are regex-constrained; `_` wildcard semantics
  apply only over visibility-filtered rows (same class as the prior `q`-wildcard near-miss). Rejected.
- **`ui.py` triage `flt()` unencoded query values** — Jinja-escaped; cosmetic param splitting at most.
- **Health endpoint detail** — exposes bot GitHub login (public) and node error strings (node URL is
  already public in the manifest). Rejected.
- **`_session`/`passkey`/`TOTP` paths** — covered by the prior audit; spot-check found no change.
- **Two-worker races, `SeenDelivery` retention, `BulkIn`/`FamilyIn` list sizes** — prior near-misses,
  unchanged at this commit.

## Coverage limitations

- **The diff was empty.** All findings in this report are re-verifications or deepened-area checks at
  commit `ab9df7f`, not new-code review. Any vulnerability introduced after 2026-11-10 is out of
  scope of this audit because no such code exists in the repo at HEAD.
- **No live system exercised.** Reproduction was local-only (verbatim-logic harnesses, code traces).
  No login, no filing, no webhook delivery, no database instance. Behaviours depending on Postgres
  concurrency, worker timing, or GitHub API responses were assessed by code trace only.
- **Dedup is public-only.** Private/undisclosed tickets are unsearchable; a private duplicate can
  never be fully excluded. (For the one verified lead, a public exact duplicate settled the question.)
- **Not re-read in full this session** (covered by the prior audit at the same commit, spot-checked
  only where this report says so): `desk/auth.py` in full, `desk/services/github.py` remainder,
  `desk/models.py` in full, `desk/api/team.py` in full, `desk/templates/team/*` in full.
- **Out of scope for this assignment:** the `xe` Go node, the DAO harness, and the SDK (sibling
  audits); the live deployment's infrastructure (Caddy, Postgres, host).

## Dedup record

| Query | Endpoint | Result |
|---|---|---|
| `hexToBytes` | `GET /v1/tickets?q=hexToBytes` | 13 tickets; XE-3105 exact duplicate; XE-6046/XE-6628/XE-6895/XE-4357 adjacent, read |
| `browser signer seed` | `GET /v1/tickets?q=browser%20signer%20seed` | 0 tickets |
| `XE desk bounty signer.js hexToBytes zero bytes seed XE-3105` | web search | no relevant results |

## Files referenced

- Prior audit: `~/workspace/xe-desk-audit/report-2026-11-12.md`
- Fresh clone: `~/workspace/xe-desk-audit/desk-new/` (HEAD `ab9df7fdc4f48bee4101060b59b8a2d80e818136`)
- Reproduction scratch: `/tmp/hexrepro.js` (verbatim `hexToBytes` + collision cases; ephemeral)
- This report: `~/workspace/xe-desk-audit/desk-diff-report-2026-11-12.md`
