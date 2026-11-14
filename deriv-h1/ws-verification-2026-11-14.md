# Deriv WebSocket public-call verification — 2026-11-14 (BLOCKED: no connection)

> **Outcome: NO live verification was possible.** The WebSocket upgrade to
> `wss://ws.derivws.com/websockets/v3?app_id=1089` was rejected with HTTP 520
> (Cloudflare) on both attempts. **Zero Deriv API calls were made** — no WS
> message was ever sent, because the connection never established. Every
> catalog entry and every INFERRED mapping in `websocket-catalog.md` remains
> **unverified**. This file records the attempt honestly so it is not repeated
> blindly.

## Authorization and scope

- User-authorized 2026-11-14 (chat order "Deriv silahkan verifikasi lewat socket"):
  read-only verification of PUBLIC websocket calls only.
- Program rules honored: header `X-HackerOne-Research: mosul` was set on the
  upgrade request (both attempts). No `authorize` call, no API token (none
  exists, none created), no account/transaction/cashier/p2p/mt5 calls, no
  trades, no parameter tampering, no fuzzing, no high volume.
- Single host only: `ws.derivws.com`. No other host was contacted for Deriv
  traffic. No browser was used.

## What was attempted

Target: `wss://ws.derivws.com/websockets/v3?app_id=1089` (documented test
app_id 1089 from the deriv-api README).

Planned call sequence (NEVER SENT — connection never established):

| # | Call | Planned payload |
|---|---|---|
| 1 | `ping` | `{"ping": 1, "req_id": 1}` |
| 2 | `active_symbols` | `{"active_symbols": "brief", "req_id": 2}` |
| 3 | `ticks` subscribe | `{"ticks": "R_100", "subscribe": 1, "req_id": 3}` then `forget` with the returned subscription id |
| 4 | `proposal` (quote only, NO buy) | `{"proposal": 1, "contract_type": "CALL", "currency": "USD", "duration": 5, "duration_unit": "t", "amount": 10, "basis": "stake", "underlying_symbol": "R_100", "req_id": 5}` |
| 5 | `trading_times` | `{"trading_times": "today", "req_id": 6}` |

Note on call 5: the JSON schema defines `trading_times` as a DATE string
(`"today"` or `yyyy-mm-dd`), not a symbol. The planned payload follows the
schema.

## What actually happened

Two identical attempts, ~7 minutes apart (2026-11-14 ~16:06 and ~16:08 WIB /
09:06 and 09:08 UTC). Both failed at the same step, identically:

1. TCP to the VM egress proxy: OK.
2. HTTP CONNECT to `ws.derivws.com:443`: **200 Connection Established**.
3. TLS handshake: OK — certificate CN `derivws.com`, cipher
   `TLS_AES_256_GCM_SHA384`.
4. WebSocket upgrade request sent (with `X-HackerOne-Research: mosul` header).
5. Server response: **HTTP 520** (Cloudflare "unknown error"). No `101
   Switching Protocols`. Client error: `Unexpected server response: 520`.

Cross-checks showing the 520 is not specific to the upgrade request or to
the research header:

- Plain HTTPS `GET /` to `ws.derivws.com` through the same tunnel: **520**.
- Plain HTTPS `GET /websockets/v3?app_id=1089` via curl through the proxy:
  **520**.
- The 520 persisted across all probes in the ~09:03–09:08 UTC window.

Interpretation: Cloudflare in front of `ws.derivws.com` is returning 520 for
requests arriving via this VM's egress route (or the origin is erroring for
this edge). The failure is server-side / network-path-side, not a client
defect: the tunnel, TLS, and upgrade request are all proven working up to the
point where the server answers 520.

Per the task's stop rule, no other route was tried: no different host, no
browser, no repeated hammering (2 upgrade attempts total, plus 2 plain-GET
cross-checks).

## Environment finding (for any future retry)

- Direct outbound TLS from this VM fails (the `ws` library's direct connect
  produced a TLS "wrong version number" error): all egress must go through
  the VM's HTTP proxy via `CONNECT`. The `ws` library does not honor proxy
  env vars, so the verification script implements a CONNECT-tunnel agent
  with Node built-ins only (`net` + `tls` + `https.Agent`). Proxy credentials
  are read from the environment in-process and are never logged.
- The tunnel approach is proven: CONNECT 200 + valid TLS to `derivws.com`.
  A future retry from this VM should reuse it; a retry from a different
  network route (e.g. the user's device browser, or a later time when the
  520 clears) is a parent decision, not something this task attempted.

## Schema comparison

None possible — no live response was received for any call. Expected shapes
(recorded from `deriv-api-schemas` @ 44dd4457 for the retry) remain as
documented in `websocket-catalog.md`:

| Call | Expected top-level response keys (schema) |
|---|---|
| `ping` | `ping, echo_req, msg_type, req_id` |
| `active_symbols` | `active_symbols, echo_req, msg_type, req_id` |
| `ticks` | `tick, subscription, echo_req, msg_type, req_id` |
| `forget` | `forget, echo_req, msg_type, req_id` |
| `proposal` | `proposal, subscription, echo_req, msg_type, req_id` |
| `trading_times` | `trading_times, echo_req, msg_type, req_id` |

## INFERRED mappings: status unchanged

The 9 UI-to-WS mapping rows in `websocket-catalog.md` §4 remain **INFERRED**.
This pass confirms or contradicts none of them: confirming that a public call
exists would not by itself prove the UI uses it (that needs traffic
observation), and no call was even reached. In particular, the DTrader /
SmartTrader / DBot rows that plausibly use `active_symbols`, `proposal`,
`ticks`, and `trading_times` are still guesses.

## Explicit negatives

- Authenticated endpoints were NOT verified (no token exists; none created).
- Nothing was traded, bought, sold, subscribed (no live subscription was ever
  established), or modified. No account state changed. No Deriv API call was
  executed.
- No secrets were involved, sent, or recorded. The research header value is
  the public program handle `mosul`, as required by program rules.

## Artifacts

- This report: `~/workspace/deriv-h1/ws-verification-2026-11-14.md`
- Verification script (with CONNECT-tunnel agent + staged debug logging):
  `~/workspace/deriv-h1/ws-verify/verify-public.js`
- Tunnel proof script: `~/workspace/deriv-h1/ws-verify/tunnel-debug.js`
- Raw attempt log (fatal entries only — no Deriv messages exist):
  `~/workspace/deriv-h1/ws-verify/raw-2026-11-14.jsonl`
- `ws` npm package installed into `~/workspace/deriv-h1/ws-verify/node_modules`
  (only package installed, per task allowance).
