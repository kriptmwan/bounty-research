# DAO Harness Audit — `xeprotocol/dao` — 2026-11-12

**Auditor role:** subagent, audit-only (find, verify, dedup, draft). Nothing was filed,
no login was performed, no one was contacted, no issue/PR/POC was created, no
volume or attack traffic was sent.

**Commit audited:** `2efbfee704646392c4d906546ae1e2d70f1be62e`
("test: the difficulty format test no longer asserts what the band refuses"),
2026-11-10 10:34:23 +0000. Shallow clone at `~/workspace/xe-desk-audit/dao/`
(read-only; `git status` clean at end of audit).

**Verdict: NO surviving novel candidates.** A full-tree audit of the DAO harness
(~13,020 lines of Python across `dao/`, `xe/`, `tests/`, plus all 19 Jinja
templates, `dao/static/signer.js`, config, migrations and docs) found no
code-confirmed, novel, filing-worthy flaw at MEDIUM confidence or higher.
Every hypothesis that survived first reading was killed by code trace, by an
executed local harness against the real code, or by cross-checking the XE node
source. The two DAO flaws already on file (XE-0462, XE-0494) were verified
fixed in this commit. The near-misses below are recorded with their killing
evidence so the coordinator does not re-litigate them.

Counts: Critical 0 · Severe 0 · High 0 · Medium 0 · Minor 0 · Held 0.

No draft bounty-report text is included because there is nothing to file. No
Critical/Severe flag applies. No dedup API queries were run: dedup applies to
candidates, and no candidate reached that stage (see §6).

---

## 1. Repo overview — what the DAO codebase is

The XE DAO operating harness (GPL-3.0, Python/FastAPI + PostgreSQL). It is the
company's public portal and members-direct operations console for the XE
testnet-0005 network, and it holds no member keys and no treasury keys.

- `xe/` — a minimal Python port of the XE protocol surfaces the harness needs,
  kept byte-identical to the Go node: addresses/keys (`keys.py`), block
  hashing/signing (`encoding.py`), PoW (`pow.py`), state-chain encoding and
  keysets (`statechain.py`), chat envelopes (`chat.py`), directory
  registrations (`directory.py`), chat auth proofs (`chat_auth.py`), and a
  bounded, strictly-validating HTTP client for one configured node
  (`client.py`).
- `dao/` — the harness: settings/config-as-data (`settings.py`, `config.py`),
  signed-request auth (`auth.py`, `canonical.py`, `signatures.py`), the
  encrypted three-key signer (`signer.py`: `harness`, `dao`, `fee`),
  the hash-chained signed event log (`log.py`), chain operations
  (`chainops.py`), services (`services/portal.py` proposals/votes,
  `resolutions.py`, `sessions.py` two-step state-chain signing sessions,
  `pause.py`, `fees.py` exactly-once fee settlement, `inbox.py`, `records.py`),
  API routers (`api/public.py`, `api/members.py`, `api/legal.py`), UI pages
  (`ui.py` + 19 Jinja templates), the worker (`worker.py`,
  `worker_schedule.py`), rate limits (`ratelimit.py`), text rules
  (`text.py`), the markdown mirror (`mirror.py`), and the CLI (`cli.py`).
- `config/` — Schedule B/C, registry, charter, copy registers, seat prompts.
- `alembic/` — migrations 0001–0005. `tests/` — 156 tests across 6 files.

Core security design, as audited: nobody logs in; every write is a
`SignedRequest {payload, timestamp, pub_key, signature}` with
`signature = ed25519(sha256(domain ‖ 0x00 ‖ canonical_json({payload,
timestamp})))`, a per-endpoint domain, a ±10 minute timestamp window, and
single-use signatures claimed in the same DB transaction as the write they
authorise. Votes weigh XE balance at a snapshot 1h05m before a proposal opens;
quorum is 20 participating wallets; agent weight is capped at 1% of the human
decided weight; open votes are not self-executing. State-chain writes go
through two-step signing sessions (member approvals → keyset signatures →
timelock → submit), with a 72h pause mechanism. The fee flow (10 XE proposal
fee) settles exactly once via chain reads. The event log is hash-chained,
signed by the harness key, and anchored weekly on the state chain.

Threat model applied (per the repo's own documented assumptions, confirmed in
`docs/MAINNET_REQS.md` §1): the configured XE node is trusted infrastructure
("a node the DAO is happy to trust for reads… it does not cross-check against
a second"). A lying or compromised node is therefore out of scope except
where the harness claims to defend against malformed node data; those
defences were still checked. Operator configuration (schedules, seats,
keyfile) is trusted; attacker-reachable paths are the public/member HTTP
surface, the chat stream, and stored data re-read from the DB.

---

## 2. Surviving novel candidates

**None.** No finding met the filing bar (code-confirmed + novel +
dedup-checked + confidence MEDIUM or higher). The sections below record what
was checked, what was already filed, and what was rejected and why.

---

## 3. HELD — needs parent decision

**None.** Every hypothesis raised during the audit was resolved to a firm
conclusion (clean, already-filed, or rejected near-miss) by code trace,
executed harness, or node-source evidence. Nothing remains uncertain,
low-confidence, or partially verified that would benefit from a parent
decision. The two closest calls — the `_parse` non-finite-number gap (§5.1)
and the `signer.js` seed-parsing quirk (§5.6) — were fully characterised and
are recorded as near-misses with their killing evidence, not held.

---

## 4. Areas checked and clean

Each area below was read in full and, where the logic is subtle, verified with
an executed local harness against the real code (pure-logic, no DB, no live
services; venv `/tmp/dao-audit-venv`, since wiped with `/tmp`). Harness
scripts were throwaway; their results are summarised here.

### 4.1 Signed-request authentication (`dao/auth.py`, `dao/canonical.py`)

- Domain separation: a signature over one domain is rejected under every
  other domain (harness-verified: proposal signature rejected as vote,
  timestamp+1 rejected, mutated payload rejected).
- Timestamp window ±10 min (`MAX_SKEW_NS`); purge cutoff is 2× the window, so
  a purged claim can never be presented again.
- Replay key is the lower-cased signature; the model pattern rejects
  non-canonical spellings (whitespace, short signatures) — XE-0699.
  `claim_signature` uses `INSERT … ON CONFLICT DO NOTHING … RETURNING`, so
  concurrent replays cannot both land, and a failed write rolls the claim
  back with it (signature reusable only because nothing happened).
- `pow_nonce` is masked to u64 in `http_pow_hash`, so out-of-range or negative
  values cannot raise; PoW is bound to the signing digest.
- `bind()` requires the signed payload to name the acted-on id/hash; routes
  that do not call `bind()` perform equivalent payload-vs-URL checks inside
  `decide`/`approve` (verified per route, §4.10).
- Pydantic coercions checked: `timestamp: true` coerces to 1 (rejected by the
  window check), string timestamps coerce, uppercase pub_keys are lower-cased
  in `Verified`, non-dict payloads are rejected. No coercion bypasses any
  check.
- `canonical_json` distinguishes `1` from `1.0` from `true`, sorts keys by
  code point, and escapes non-ASCII; NaN/Infinity/surrogate outputs are
  unreachable from stored data because every payload field is validated as a
  string or through `normalise_ops` before storage (§5.8).

### 4.2 Vote snapshot and causality (`dao/chainops.py`) — the most intricate area

Verified with a 12-case mock-chain harness against `account_snapshot`:

- Balances are read from per-block post-state `balance` fields, not summed
  from amounts, so unknown future block types cannot corrupt the figure.
- Non-causal receives (source send dated after the snapshot) are excluded and
  carried as `tainted`, which later sends/burns spend first; harness cases
  confirmed exact figures (80 → 70 on exclusion; 70 after a partial spend;
  0 after a full spend).
- Missing (404) or empty sources are excluded; receives older than the 2h
  causal window skip the lookup, as designed.
- `lease_settle` causality (XE-1789) confirmed: a settle for a lease opened
  after the snapshot is excluded; a causal one counts.
- `ARRIVALS = ("receive", "lease_settle")` is complete for XE weight:
  `mint` is minter-authorised issuance with no counterpart wallet (counting
  it is correct); `lease_accept`/`lease_renew` subtract XUSD stake;
  `lease_force_settle` adds pending XUSD only (weight asset is XE per
  Schedule B, "never XUSD"); `multisig_update`/`lease_cancel` have no balance
  effect. Verified against the node's balance rules in the sparse checkout
  (node commit `89a542ea`, see §5.2).
- Lookup cap: 32 largest-first causal lookups; beyond the cap, remaining
  windowed receives are excluded without a lookup, which can only lower
  weight (harness case 11: capped, 8 excluded, balance 320 as expected).
- The 1h05m snapshot lead defeats post-opening transfers: a block made after
  the open cannot be dated before the snapshot given the node's ±1h
  acceptance window (documented proof in `chainops.py`, XE-0352/XE-1098).
- `full_chain` page bound: an unreadable over-long chain yields an explicit
  `unreadable` snapshot, not a silent partial figure (XE-1706).

### 4.3 Tally (`dao/services/portal.py::tally`)

Harness-verified: agent weight of 10,000,000 against 100 human decided weight
counts as 1 (1% cap, pro rata); agent-only votes count 0 and the proposal
fails on `decided == 0`; human abstains do not feed the cap; pass mark is a
strict `>`; stale rows (derived under another snapshot/rule) are excluded
from published figures when `ctx` is passed and re-derived at close
(XE-1617/XE-1664). Agents counting toward the 20-wallet quorum is the
documented rule (quorum counts wallets, the cap counts weight), and agents
alone can never pass a proposal.

### 4.4 Ops validation and the keyset gate (`dao/services/sessions.py`)

- All three ops entry points (proposal submit, resolution create, session
  create) go through `normalise_ops`, which runs `StateOp.validate()` plus
  `check_ops_fit` (whole-block size bound, XE-1917). Values are stored as the
  exact compact JSON text that will be hashed, never as parsed objects.
- Harness matrix: `NaN`, `1e400`, float NaN, lone surrogates, and oversize
  values are all rejected with 400; missing `value` on `set` defaults to
  `null` (by design); extra op keys are dropped; `sys.*` deletes rejected.
- `same_ops` (proposal-vs-resolution ops equality) is key-order-insensitive
  but distinguishes `1`/`1.0`/`true`, extra keys, and delete-vs-set
  (10-case harness matrix, all as documented).
- `_check_keyset` (for `sys.dao_keyset` writes): harness matrix of 16 cases —
  good 2-of-2/2-of-3 accepted; threshold bool/float/string, uppercase keys,
  duplicate keys, threshold 1, threshold > n, empty keys, extra fields, the
  zero key (invalid curve point), 17 keys, and keysets whose keys are not
  all held by seats are all rejected. `validate_keyset`'s own leniency
  (`int()` coercion) is unreachable because `_check_keyset` pre-validates
  strictly at every entry point (§5.5).

### 4.5 Resolutions, sessions, pause (`dao/services/resolutions.py`, `sessions.py`, `pause.py`)

Read in full with sibling/edge-case checks: thresholds; the set-aside /
re-signature rule (`dao/signatures.py::counting`/`add` — a rotated-away key
or departed seat carries nothing, XE-0600/XE-0646/XE-1761/XE-1966); session
opening/deferral; withdraw-cancels-session; live-keyset approval and
signature counting; timelock; rebuild/stale/landed/submit classification;
cancel-when-landed-becomes-submitted (XE-1843); pause singleton index,
`in_force` clock rule, consent counting, extend/lift/post gates; anchor
numbering with in-flight counting and one-open-session-per-kind serialisation
(XE-1435/XE-2439). Rebuild failure after approval defers the build without
losing the approval (XE-1713). No guard was found missing or bypassable.

### 4.6 Fees (`dao/services/fees.py`, `chainops.py::placed`/`offer`)

Exactly-once settlement via chain reads: `placed()` distinguishes
submitted/landed/lost; never-received fees are refused; excess is returned;
pause state is re-read before acting. Read in full; no double-spend,
double-refund, or stuck-fee path found. Fee-block verification requires a
finalised send to the fee account from the proposing account for at least the
fee, serialised per fee-block hash.

### 4.7 Event log (`dao/log.py`, `dao/canonical.py`)

- Hash chain: `event_hash` covers index/ts/kind/actor/payload/prev_hash plus
  `public`/`ref` under the v2 domain; `verify()` replays gap/prev/hash/
  signer/signature checks and cross-checks the head row.
- `append` fails closed on signer failure (XE-0462 fix verified, §6) and
  reads the head under lock with `populate_existing` every time.
- `verify_cached` (60s) ignores `expected_signer` in its cache key, but both
  call sites pass the identical expression, so the gap is unreachable; the
  staleness window is a documented DoS trade-off.
- SSE phantom-event concern killed: the queue is a wakeup only; the generator
  yields solely from `EventLog.since()` polls, so rolled-back events are
  never yielded.

### 4.8 Signer and boot (`dao/signer.py`, `dao/context.py`)

- `build_context` refuses to run without a loadable keyfile containing the
  `harness` key (XE-0494 fix verified, §6). Scope enforcement on key use
  reviewed; no keyset/treasury/member keys are held on the server.
- The unsigned-event path in `append` (when no harness key is present) is
  reachable only in degenerate/test contexts; production boot guarantees the
  key.

### 4.9 XE client and wire formats (`xe/client.py`, `xe/encoding.py`, `xe/statechain.py`, `xe/chat.py`, `xe/pow.py`, `xe/directory.py`, `xe/chat_auth.py`, `xe/keys.py`, `xe/amounts.py`)

- `_parse` refuses NaN literals, NUL bytes/escapes, lone surrogates, and
  non-UTF-8 bodies, and catches `RecursionError` (harness-verified). The one
  gap — `1e400` parsing to float `inf` — is recorded at §5.1 with its
  (nil) impact.
- Every client consumer re-validates with `_typed`/`_u64`/`_keyset`/
  typed `from_json` parsers before storage or hashing (verified per method,
  including `pending_for`, `balances`, `statechain_tip`, `dao_keyset`,
  `chat_messages`, stream items). `_u64` rejects bools, floats, negatives,
  and values ≥ 2⁶³; `_keyset` enforces 1 ≤ threshold ≤ n.
- `compact_json` is Go-compatible (escapes `<`, `>`, `&`, U+2028/U+2029,
  leaves `/` and non-ASCII raw; rejects non-finite numbers; lone surrogates
  raise `UnicodeEncodeError`, caught as 400 at the ops boundary).
  `StateOp.validate` additionally requires values to be in compact form.
- `strict_loads` (statechain) uses `parse_constant` + `parse_float` guards,
  unlike the lenient `_parse` — the strict path is used where it matters.
- PoW: `parse_difficulty` enforces the band around the harness default
  (malformed, below-minimum, and >MAX_WORK_FACTOR values rejected;
  harness-verified); `compute_pow`/`validate_pow` round-trip confirmed.
- Chat envelopes: id recomputation, tamper rejection, freshness window, PoW
  enforcement, and byte-length (not char-length) message bound all verified;
  `store_envelope` verifies before storing, with dedup by envelope id.
- Block hashing/signing: `sign_block` refuses to sign for a mismatched
  account; open-block signature verification checks hash, declared key, and
  derivation.
- Size/deadline caps on reads, stream line/idle caps, `_seg` path encoding,
  and the single configured node URL (no user-controlled URLs, no SSRF
  surface) all reviewed.

### 4.10 API surface — all 23 POST routes authenticated

Every POST handler in `api/public.py` (6) and `api/members.py` (17) takes a
`SignedRequest` and calls `verify_and_claim` (or `verify_signed` +
`claim_signature`); member routes additionally call `require_seat`, and
`proposal_decision` additionally requires member or `operational_review`
officer. `legal.py` has no POST routes. GET routes are reads; the
node-costly ones (`/v1/snapshot/*`, node reads) carry their own rate-limit
classes. No unauthenticated write exists. No raw SQL (all SQLAlchemy ORM,
bound parameters); no user-controlled file IO (config/template paths are
fixed or operator settings); no `eval`/`exec`/subprocess/`pickle`/unsafe
YAML anywhere; no hard-coded secrets (grep-verified).

### 4.11 Rate limiting and DoS (`dao/ratelimit.py`, `dao/main.py`)

Token buckets per route class, keyed by IP and by signing account, with
separate classes so one class cannot spend another's budget (XE-0478);
harness-verified burst/refill/isolation behaviour. Body-size limit,
security headers, CSP, CORS, and `FORWARDED_ALLOW_IPS` restricted to the
bridge range (never `*`, XE-0196) reviewed. Member POST routes are
unthrottled but each request costs one ed25519 verify + one insert attempt
with no node-read amplification — weak DoS only, rejected at §5.7.
`STREAMS` held-connection cap reviewed.

### 4.12 Templates, browser signer, markdown (`dao/templates/*`, `dao/static/signer.js`, `dao/ui.py`, `dao/mirror.py`)

- Jinja autoescape confirmed ON by rendering probes: hostile titles, bodies,
  vote reasons, and ops values are escaped; `tojson` escapes `<`/`>`; no
  `|safe` filter exists in any template; the only `Markup` is the markdown
  filter, fed config-authored text only, with HTML disabled and linkify off
  (XE-0702) — harness-verified that `<script>`, `javascript:` links,
  `data:` links, and `onerror` attributes do not survive `_render_md`.
- `members.html`/`live.html` client-side `esc()` escapes `&<>"` in the
  contexts used (element content and double-quoted attributes); server data
  inserted via `textContent`/`say()` where appropriate.
- `signer.js` canonical JSON (code-point key sort, surrogate-pair escaping),
  `body()`/`pow()`/`offlineTarget()` reviewed against server `canonical_json`
  and found consistent. The `hexToBytes` quirk is at §5.6.
- Markdown mirror: `<pre>` blocks fenced with longest-backtick-run + 1,
  scripts/forms/inputs dropped, titles neutralised for comment breakout
  (`--`, `>`), responses served as `text/markdown; charset=utf-8`; Host-header
  reflection into the markdown head is cosmetic only at that content type.

### 4.13 Inbox privacy and records/health (`dao/services/inbox.py`, `dao/services/records.py`)

Verified-only publicity, HTTP privacy until triage, ack rationing,
one-envelope outbox rule, cursor derivation, shared-read cache with TTL,
keyset-change detection, anchor numbering, uptime math. `onchain_registry`
(`statechain_key("dao.registry")`) is display-only; state-chain writes
require keyset-signed blocks enforced by the node, so arbitrary accounts
cannot forge registry content. Health legs record per-leg errors and degrade
`ok` rather than raising.

### 4.14 Text rules (`dao/text.py`)

Harness-verified: ZWSP, RLO/bidi controls, lone surrogates, DEL, C1 controls,
and soft hyphen are rejected; ZWJ and variation selectors (needed for emoji)
are allowed; tab/newline allowed; U+2028/U+2029 normalised to newline;
non-string inputs rejected. Op values bypass `clean_text` by design (they
are JSON, validated by `StateOp.validate`, which rejects surrogates —
§5.3).

### 4.15 Config, deploy, migrations

`settings.py` (env-aliased, no secret defaults), `config.py` (seat
validation, `require_distinct_seats`, schedule loading), `Dockerfile` /
`docker-compose.yml` / `.env.example` / `docs/DEPLOY.md` (no privileged or
host-network exposure, keyfile via secret mount), `alembic/env.py`
(standard, URL from settings), migration headers 0001–0005, and
`docs/MAINNET_REQS.md` (trusted-node assumption, §1) reviewed. Dead code
noted but harmless: `chainops.account_pub_key` and `config.Config.seat`
have no callers; `xe/directory.py::verify_registration` is unused by the
harness.

### 4.16 Tests

Test inventory read (156 tests: `test_dao_core` 62, `test_hardening_db` 65,
`test_log_db` 6, `test_mirror` 5, `test_templates` 4, `test_xe_wire` 14),
including the XE-1789 snapshot test and tally/ops tests. DB-backed tests
could not be executed (no PostgreSQL in this environment — see §7); the
pure-logic harnesses above substitute for the units they cover.

---

## 5. Near-misses rejected (with killing evidence)

### 5.1 `_parse` accepts `1e400` as float `inf` despite its docstring — REJECTED (no impact)

`xe/client.py::_parse` (L138) documents refusing "NaN and Infinity (not JSON,
and not storable as JSON)". `parse_constant=_refuse_constant` refuses the
*bare tokens* `NaN`/`Infinity`, but a numeric literal that overflows, `1e400`,
parses to float `inf` without touching `parse_constant`. Harness-confirmed:
`_parse(b'{"a":1e400}')` returns `{'a': inf}`.

Killed as a finding because: (a) the node is trusted infrastructure, so a
malicious response is out of the threat model; (b) every typed consumer
rejects floats (`_u64`, `_typed`, `from_json` parsers — §4.9), so `inf`
cannot reach storage, hashing, or vote weights; (c) the single untyped
passthrough, `records.health()` storing the raw `/ready` body into
`HealthCheck.detail`, would at worst fail one background health write per
cadence (Postgres JSONB rejects non-finite numbers) — a self-healing worker
error, not a security boundary. The strict path (`strict_loads`, used for
state-chain values) already guards `parse_float`. This is a docstring/behaviour
nit, not a bounty finding. No dedup check run: nothing to file.

### 5.2 Snapshot `break` hides later past-dated blocks if chain timestamps were non-monotonic — REJECTED (node enforces monotonicity)

`account_snapshot` (`dao/chainops.py` L261) breaks out of the chain scan at
the first block with `ts > at_ns`. If a chain contained a later block dated
*before* the snapshot, that block's balance effect would be invisible, and a
receive could be counted in one wallet while its send was hidden in another.

Killed by node evidence, re-verified 2026-11-12 against a read-only sparse
checkout of `xeprotocol/xe` `core/` at commit
`89a542ea51d38375299aee54c6c99102e9bfa666` (2026-11-10): every block-type
validator rejects a block whose timestamp precedes the last block of the same
account chain (`chain.Blocks[len(chain.Blocks)-1].Timestamp`) — 12 sites:
`core/ledger.go` L988 (send), L1050 (burn), L1129 (receive), L1229 (mint),
L1334 (multisig_update), L1568 (lease), L1656 (lease_accept), L1848
(lease_cancel), L1965 (force_settle), L2207 (settle); `core/mint.go` L64;
`core/lease_renew.go` L120. Chains served by an honest (trusted) node are
therefore non-decreasing, and `break` equals "last block with ts ≤ at". A
lying node could serve a non-monotonic chain, but the configured node is
trusted infra (§1). Harness case 8 documents the `break` behaviour explicitly.

### 5.3 Op values bypass `clean_text` — REJECTED (surrogates rejected by `StateOp.validate`)

Op `value`s are JSON, not prose, so they skip `clean_text`. A lone-surrogate
string inside an op value was hypothesised to reach storage/hashing and
break cross-node re-marshalling.

Killed by harness: `normalise_ops` rejects a value containing `\ud800` with
HTTP 400 (`UnicodeEncodeError` from the UTF-8 encode inside validation),
and `compact_json` raises on surrogates as well. No surrogate-bearing op
value can be stored. The residual cross-node question is moot.

### 5.4 Deeply-nested JSON `RecursionError` → 500 — REJECTED (generic framework behaviour, no state effect)

A deeply-nested op *value string* was hypothesised to raise `RecursionError`
in `normalise_ops`/`strict_loads`. Harness-killed: string values are stored
verbatim without parsing (a 5,000-deep bracket string passes through
`normalise_ops` unchanged). A deeply-nested *parsed structure* would fail
earlier, inside FastAPI/Starlette's own `json.loads` — behaviour generic to
every FastAPI app, not DAO-specific. Either way: no leak, no state change
(the signature claim rolls back), and the endpoint is rate-limited.
Robustness-only, consistent with the desk audit's treatment of similar 500s.

### 5.5 `validate_keyset` accepts lenient threshold spellings — REJECTED (unreachable)

`xe/statechain.py::validate_keyset` coerces the threshold with `int(...)`,
so `"2"`, `2.5` (truncated), and `True` would pass its checks. Killed: every
untrusted entry point for a keyset value passes `_check_keyset`
(`dao/services/sessions.py`) first, which strictly requires an integer
threshold (harness matrix, §4.4). `validate_keyset` only ever sees
pre-validated values or node-served keysets (which pass through the strict
client `_keyset` parser).

### 5.6 `signer.js` `hexToBytes` silently maps invalid hex to zero bytes — REJECTED (self-harm only)

`parseInt` on a non-hex pair yields `NaN`, stored as `0` in the `Uint8Array`,
so pasting an invalid seed silently derives a wrong key — potentially the
well-known all-zero seed's key. Killed: no trust boundary is crossed (the
user harms only their own session), the derived account is displayed for
verification before any signature, and a wrong key fails closed at
`require_seat` on member routes. A UX hardening suggestion (reject
non-hex input loudly), not a bounty finding.

### 5.7 Member POST routes have no rate limiting — REJECTED (weak DoS only)

Unlike the public writes, `dao/api/members.py` POSTs are unthrottled. Killed:
each request costs one ed25519 verify plus one DB insert attempt (a failed
signature rolls its claim back, so it is replayable but harmless), the seat
check precedes any node read (no amplification), and a proxy layer is
documented as the second line. No resource exhaustion beyond what any
authenticated endpoint bears.

### 5.8 `canonical_json` renders NaN/Infinity/surrogates — REJECTED (unreachable)

Python's `json.dumps` with default `allow_nan=True` renders `NaN`/`Infinity`,
and lone surrogates as `\ud800` escapes (harness-confirmed). Killed: no
payload field carrying such a value can reach storage — text fields pass
`clean_text` (rejects surrogates/controls), ops pass `normalise_ops`
(rejects non-finite/surrogates), and the payload itself is never stored,
only its digest and the extracted fields. The digest is computed identically
by the only verifier (this server), so no cross-implementation confusion
arises.

### 5.9 `counting()` indexes `s["seat"]` without `.get` — REJECTED (server-written data only)

`dao/signatures.py::counting` would raise `KeyError` on a stored signature
entry lacking `"seat"`. Killed: every entry is written by server code
(`signatures.add`, pause extensions/lifts, resolution `decide`) which always
includes `seat`; no API path lets a caller inject a stored entry. A 500
requiring direct DB corruption is not a finding.

### 5.10 `verify_cached` cache ignores `expected_signer` — REJECTED (unreachable)

See §4.7: both call sites pass the identical expression. No caller can poison
the cache for another.

### 5.11 Operator misconfiguration: `weight_asset: XUSD` would leave `lease_force_settle` arrivals unguarded — REJECTED (not attacker-reachable)

`ARRIVALS` omits `lease_force_settle` because it adds XUSD, and Schedule B
fixes the weight asset to XE ("never XUSD"). If an operator configured XUSD
weight, force-settle causality would be unchecked. Killed: configuration is
operator-trusted, the documented rule forbids it, and no attacker can change
it. Noted here only so the reasoning is on record.

---

## 6. Duplicates found / already-filed items confirmed

No NEW duplicates were found (no candidate reached the dedup stage, so no
desk-API queries were run — see §7). The following registry items were
confirmed present-and-fixed in this commit, and must not be re-reported:

- **XE-0462** ("Event log swallows SignerError and writes unsigned events",
  assessed Medium): FIXED. `dao/log.py::EventLog.append` (L80–85) raises
  `LogError` when the configured harness key will not sign ("a configured
  key that will not sign is an outage, not a reason to write an unsigned
  row"); the raise rolls back the caller's transaction, so no unsigned row
  is written.
- **XE-0494** ("service runs unsigned when the keyfile is unavailable"):
  FIXED. `dao/context.py::build_context` (L90–95) raises `SystemExit` if the
  keyfile cannot be loaded or holds no `harness` key ("the harness does not
  run without its keys").
- The five desk candidates (XE-10091, XE-10093, XE-10095, XE-10097,
  XE-10100) concern the desk repo, not this one; none has a DAO analogue
  (the DAO's equivalents — signature replay, bulk-adopt-style guards,
  reply rate limits, draft bounds, signer fail-open — were each checked in
  their DAO form and found guarded; see §4).
- The many XE citations embedded in code comments (XE-0032, XE-0033, XE-0352,
  XE-0462, XE-0478, XE-0494, XE-0507, XE-0590, XE-0600, XE-0646, XE-0650,
  XE-0652, XE-0699, XE-0702, XE-0775, XE-0990, XE-1003, XE-1098, XE-1435,
  XE-1459, XE-1460, XE-1504, XE-1548, XE-1589, XE-1617, XE-1664, XE-1706,
  XE-1713, XE-1761, XE-1789, XE-1843, XE-1917, XE-1966, XE-2073, XE-2439,
  XE-0196, and others) were treated as already-filed by construction: each
  names the guard that closed it, and each guard was re-verified rather than
  re-reported.

---

## 7. Coverage limitations (explicit)

1. **No live instance.** No PostgreSQL, no running harness, and no live node
   were available. DB-backed behaviour (transactions, locks, constraint
   races, `verify()` replay, worker jobs) was assessed by code trace only;
   the 156 unit/hardening tests could not be executed. Pure-logic paths
   (auth, canonical JSON, ops, keyset gate, snapshot, tally, rate limits,
   templates, markdown, PoW, wire formats) were executed locally against
   the real code.
2. **No dedup queries were needed or run.** Dedup against the live desk API
   applies to candidates; since no candidate survived verification, no
   `/v1/tickets` queries were issued. Had any candidate survived, it would
   have been dedup-checked before inclusion. The residual limitation from
   the brief stands in general: private/undisclosed tickets are
   unsearchable, so a private duplicate can never be fully excluded — but
   with zero candidates, nothing in this report depends on that.
3. **Trusted-node assumption.** Findings requiring a malicious or
   compromised configured node were treated as out of scope per
   `docs/MAINNET_REQS.md` §1, except where the harness claims a defence
   against malformed node data (checked, §4.9/§5.1).
4. **Node cross-check was read-only and narrow.** Only `core/` of
   `xeprotocol/xe` at commit `89a542ea` was consulted, solely to verify DAO
   assumptions (timestamp monotonicity, balance rules). No node findings are
   reported here; the node is a sibling auditor's target.
5. **No browser, no login, no authenticated probing.** Template/JS behaviour
   was assessed by rendering and code review, not by driving a live browser;
   the browser signer's runtime behaviour (WebCrypto, `nacl` bundle) was not
   executed.
6. **Configuration-as-data not exhaustively validated.** Schedule YAMLs,
   charter, copy registers, and seat prompts were skimmed for security
   relevance, not line-audited; they are operator-authored and trusted.
7. **Prior-audit reliance.** The desk audit report
   (`~/workspace/xe-desk-audit/report-2026-11-12.md`) was read in full at the
   start and its dedup registry honoured; its verdicts were not re-audited.

---

## 8. Method note

Systematic full-tree read (every `.py` file in `dao/` and `xe/`, every
template, `signer.js`, config, migrations, docs), followed by targeted
executed harnesses for the subtle logic (snapshot/causality 12 cases,
`same_ops` 10 cases, keyset gate 16 cases, ops validation 11 cases,
canonical/digest/signature round-trips, client `_parse` 11 cases, PoW,
state-chain hashing/signing, chat envelopes, tally 4 cases, rate limits,
Jinja/markdown escaping), plus grep sweeps (dangerous functions, raw SQL,
secrets, route inventory, dead code) and a node-source cross-check. All
harness work was local and read-only; no file in the repo checkout was
modified.

*End of report.*
