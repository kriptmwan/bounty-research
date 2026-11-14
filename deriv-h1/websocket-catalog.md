# Deriv WebSocket API — message catalog (PASSIVE, public-source only)

> **Status: DOCUMENTED, not live-verified.** Every entry below comes from public GitHub repositories read locally. **Zero requests were sent to any Deriv asset** (no websocket connections, no HTTP calls to deriv.com / deriv.cloud / derivws.com, no token creation, no sign-ins). Nothing here was verified against the live API. Entries inferred from the Phase 3 UI surface map are marked **INFERRED** and are guesses about which calls a UI flow uses — not observations.

## Sources (exact pins)

| Repo | HEAD | HEAD date | Content used |
|---|---|---|---|
| `deriv-com/deriv-api-schemas` | `44dd4457b82582f68b2ace2f4b8cf9ff1db44481` | 2026-11-12 (release `production_v20261112_0`) | `schemas/*.schema.json` (63 request + 63 response schemas) + `schemas/rest-api-openapi.json` (OpenAPI 3.1.0, Third Party API v1.1.0) |
| `deriv-com/deriv-api` | `fbf51f6ed7698e6c6164fb0eda4183bb27253546` | 2026-05-28 | `src/deriv_api/DerivAPICalls.js` (131 call wrappers with JSDoc), `src/deriv_api/DerivAPIBasic.js` (connection), `README.md`, `docs/DerivAPI.md`, `examples/` |
| Local clones | `~/workspace/deriv-h1/repos/deriv-api-schemas`, `~/workspace/deriv-h1/repos/deriv-api` | cloned 2026-11-14 (depth 1, git protocol, public, no auth) | — |

**Coverage reality (read this first):** the two repos do NOT cover the same API. The schemas repo is the current **Third Party API subset**: 30 websocket call schemas + 33 REST-style schemas. The JS client is older (May 2026) but much broader: 131 websocket call wrappers, including `authorize`, `cashier`, all `p2p_*`, all `mt5_*`, and account-management calls that have **no** JSON schema in the schemas repo. Union: **172 unique call/endpoint names** (22 in both sources, 41 schema-only, 109 client-only). The client may retain deprecated calls (it still references binary.com-era URLs); treat client-only entries as DOCUMENTED-in-client, and re-check before any live use.

## 1. Connection setup (DOCUMENTED, deriv-api)

- **Endpoint (default):** `wss://ws.derivws.com/websockets/v3?app_id=<APP_ID>&l=<LANG>&brand=<BRAND>` — built in `DerivAPIBasic.connect()` from `endpointUrl + 'websockets/v3?app_id=...&l=...&brand=...'`. Default endpoint `ws.derivws.com`; protocol forced to `wss://` unless `ws://` is given explicitly. `README.md` examples use test `app_id` **1089** with the note 'create your own app_id' (register at api.deriv.com). An `app_id` is **required** — the constructor throws without one.
- **Request envelope:** one JSON object per message. The call name is the first key (e.g. `{"ping": 1}`, `{"authorize": "<token>"}`). Every request gets an auto-incremented `req_id` (unless supplied) used to match responses. `passthrough` (any object) round-trips through the `echo_req` response field. `subscribe: 1` on supported calls turns the request into a stream; streams are ended with `forget` (by subscription id) / `forget_all` (by type). Responses carry `msg_type`, `req_id`, `echo_req`, and either a payload field named after the call or an `error` object.
- **Auth flow (classic WS):** connect (public, unauthenticated) → send `authorize` with an API token (created on the API-token page; see `api_token` call) → the session is then authorized for that token's scopes. `authorize` must precede any account-accessing call (buy/sell/portfolio). The client exempts `website_status` and `authorize` from its request-blocking flag.
- **Keep-alive / reconnect (client behavior):** on open, a 30-second interval sends `ping: 1`; if no `pong` arrives within 5 seconds the client reconnects. `shouldReconnect` is true unless `disconnect()` was called. Reconnect re-runs `connect()` with the same args (a fresh session — re-authorization is the caller's job; the client does not auto re-send `authorize`).
- **OAuth / third-party flow (DOCUMENTED, OpenAPI + REST schemas):** OAuth2 authorization-code flow at `https://oauth.deriv.com/oauth2/authorize` and `https://oauth.deriv.com/oauth2/token`, scopes: `trade` (trading operations), `account_manage` (account creation/management), `application_read` (registered applications, read-only), `payment` (payment-agent deposit/withdrawal). REST calls authenticate with `Authorization: Bearer <token>` plus a `Deriv-App-ID` header (required for Personal Access Token auth, not required for OAuth bearer tokens).
- **OTP-authenticated WS URLs (DOCUMENTED, REST schemas):** `POST /trading/v1/options/accounts/{accountId}/otp` issues a short-lived OTP plus a ready-to-use websocket URL; the URL is then opened as `GET /trading/v1/options/ws/demo|real` with `?otp=...` (HTTP upgrade to a websocket scoped to that account). `GET /trading/v1/options/ws/public` is the unauthenticated public websocket. This is a separate, newer connection path from the classic `authorize`-token flow — which one the Deriv web UIs use was NOT determined (no live observation; see Gaps).
- **Rate limits:** **none documented** in either repo. No 429/rate-limit handling exists in the client. Per-call `limit` parameters in several calls are paging caps (max records returned), not rate limits. The `get_limits` call returns *account* trading limits, not API rate limits. Any throttling behavior is unknown without live observation.
- **Demo vs real (DOCUMENTED):** separate WS upgrade paths (`ws/demo` vs `ws/real`), separate bulk-purchase endpoints (`/bulk-purchase/demo`, `/bulk-purchase/real`), `reset_demo_balance` (REST) and `topup_virtual` (WS) for demo funds. The classic WS endpoint does not separate demo/real in the URL — the account is selected by the authorized token / account id. Demo-vs-real behavioral differences beyond endpoint names are NOT documented in these repos.

## 2. Auth model summary (DOCUMENTED)

| Mechanism | Where documented | Notes |
|---|---|---|
| API token + `authorize` | deriv-api `authorize` JSDoc + `api_token` call | Token created on the API-token page; scopes set at creation (`new_token_scopes`); optional `valid_for_current_ip_only`; `add_to_login_history` opt-in. |
| OAuth2 bearer | OpenAPI `securitySchemes` | Authorization-code flow; 4 scopes (above). |
| Personal Access Token (PAT) + `Deriv-App-ID` header | REST request schemas | Per-account PATs, e.g. bulk-purchase body carries one PAT per account; no OAuth token needed on that endpoint. |
| Short-lived OTP + WS URL | `websocket` / `ws_*` REST schemas | OTP from the OTP endpoint, passed as `otp` query param on WS upgrade. |
| Unauthenticated | schemas with `auth_required: 0` | 12 WS calls: market data, `ping`, `time`, `forget`/`forget_all`, `proposal` (price quote without auth — buy still needs auth). |

Schema `auth_required`/`auth_scopes` exist only for the 30 WS-style schemas: 18 require auth (all with scope `trade`), 12 do not. The 109 client-only calls carry **no** auth metadata in the client — their auth requirements are UNKNOWN from these sources (most account/trading ones almost certainly need `authorize`, but that is inference, not documentation).

## 3. Catalog — all calls by area

Conventions: **req** = required field; **opt** = optional. Field types/descriptions are verbatim-ish from the source (trimmed). `[schema]` = JSON-schema source (authoritative field detail, incl. `auth_required`/`auth_scopes` where present). `[client]` = JSDoc/config from the JS client wrapper (no auth metadata). `[REST]` = REST-style schema (headers/body/query), not a websocket message. `passthrough`/`req_id` appear on nearly every call and are listed where the source lists them.

### 1. Auth, session & security

#### `authorize` [client] — JS method `authorize`; auth: unknown from source
Authorize current WebSocket session to act on behalf of the owner of a given token. Must precede requests that need to access client account, for example purchasing and selling contracts or viewing portfolio.
- `add_to_login_history` (Number, opt) — [Optional] Send this when you use api tokens for authorization and want to track activity using `login_history` call.
- `authorize` (String, **req**) — Authentication token. May be retrieved from https://www.binary.com/en/user/security/api_tokenws.html
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `logout` [schema] +client — auth_required=1, scopes=['trade']
Logout the session
- `logout` (integer, **req**) — Must be `1` — enum: [1]
- `loginid` (string, opt) — [Optional] The login id of the user. Mandatory when multiple tokens were provided during authorize.
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `logout, echo_req, msg_type, req_id`

#### `ping` [schema] +client — auth_required=0
To send the ping request to the server. Mostly used to test the connection or to keep it alive.
- `ping` (integer, **req**) — Must be `1` — enum: [1]
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `ping, echo_req, msg_type, req_id`

#### `website_status` [client] — JS method `websiteStatus`; auth: unknown from source
Request server status.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `subscribe` (Number, opt) — [Optional] `1` to stream the server/website status updates.
- `website_status` (Number, **req**) — Must be `1`

#### `forget` [schema] +client — auth_required=0
Immediately cancel the real-time stream of messages with a specific ID.
- `forget` (string, **req**) — ID of the real-time stream of messages to cancel.
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `forget, echo_req, msg_type, req_id`

#### `forget_all` [schema] +client — auth_required=0
Immediately cancel the real-time streams of messages of given type.
- `forget_all` (?, **req**) — Cancel all streams by type. The value can be either a single type e.g. `"ticks"`, or an array of multiple types e.g. `["candles", "ticks"]`.
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `forget_all, echo_req, msg_type, req_id`

#### `health` [REST schema] — endpoint: `GET /v1/health`
GET /v1/health requires no request body or parameters.
- *(no fields in source)*

#### `service_token` [client] — JS method `serviceToken`; auth: unknown from source
Retrieves the authorization token for the specified service.
- `country` (String, opt) — [Optional] The 2-letter country code.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `referrer` (String, opt) — [Optional] The URL of the web page where the Web SDK will be used.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `server` (String, opt) — Server (dxtrade only).
- `service` (Any, **req**) — The service(s) to retrieve token(s) for.
- `service_token` (Number, **req**) — Must be `1`

#### `api_token` [client] — JS method `apiToken`; auth: unknown from source
This call manages API tokens
- `api_token` (Number, **req**) — Must be `1`
- `delete_token` (String, opt) — [Optional] The token to remove.
- `new_token` (String, opt) — [Optional] The name of the created token.
- `new_token_scopes` (Any, opt) — [Optional] List of permission scopes to provide with the token.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `valid_for_current_ip_only` (Number, opt) — [Optional] If you set this parameter during token creation, then the token created will only work for the IP address that was used to create the token

#### `oauth_apps` [client] — JS method `oauthApps`; auth: unknown from source
List all my used OAuth applications.
- `oauth_apps` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `revoke_oauth_app` [client] — JS method `revokeOauthApp`; auth: unknown from source
Used for revoking access of particular app.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `revoke_oauth_app` (Number, **req**) — The application ID to revoke.

#### `login_history` [client] — JS method `loginHistory`; auth: unknown from source
Retrieve a summary of login history for user.
- `limit` (Number, opt) — [Optional] Apply limit to count of login history records.
- `login_history` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `account_security` [client] — JS method `accountSecurity`; auth: unknown from source
This call manages two-factor account authentication
- `account_security` (Number, **req**) — Must be `1`
- `otp` (String, opt) — [Optional] OTP (one-time passcode) generated by a 2FA application like Authy, Google Authenticator or Yubikey.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `totp_action` (String, opt) — [Optional] Action to be taken for managing TOTP (time-based one-time password, RFC6238). Generate will create a secret key which is then returned in the secret_

#### `verify_email` [client] — JS method `verifyEmail`; auth: unknown from source
Verify an email address for various purposes. The system will send an email to the address containing a security code for verification.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `type` (String, **req**) — Purpose of the email verification call.
- `url_parameters` (Any, opt) — * @param {String} args.verify_email - Email address to be verified.

#### `reset_password` [client] — JS method `resetPassword`; auth: unknown from source
Reset Password.
- `date_of_birth` (String, opt) — [Optional] Date of birth format: `yyyy-mm-dd`. Only required for clients with real-money accounts.
- `new_password` (String, **req**) — New password. For validation (Accepts any printable ASCII character. Must be within 8-25 characters, and include numbers, lowercase and uppercase letters. Must
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `reset_password` (Number, **req**) — Must be `1`
- `verification_code` (String, **req**) — Email verification code (received from a `verify_email` call, which must be done first)

#### `change_password` [client] — JS method `changePassword`; auth: unknown from source
Change Password. Note: This call is only available when authenticated using an OAuth token.
- `change_password` (Number, **req**) — Must be `1`
- `new_password` (String, **req**) — New password (Accepts any printable ASCII character. Must be within 8-25 characters, and include numbers, lowercase and uppercase letters. Must not be the same
- `old_password` (String, **req**) — Old password for validation (non-empty string, accepts any printable ASCII character)
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `change_email` [client] — JS method `changeEmail`; auth: unknown from source
Change Email.
- `change_email` (String, **req**) — Must be `verify` or `update`.
- `new_email` (String, **req**) — Email address to be verified.
- `new_password` (String, opt) — [Optional] New password (Accepts any printable ASCII character. Must be within 8-25 characters, and include numbers, lowercase and uppercase letters. Must not b
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `verification_code` (String, **req**) — Email verification code (received from a `verify_email` call, which must be done first)

#### `tnc_approval` [client] — JS method `tncApproval`; auth: unknown from source
To approve the latest version of terms and conditions.
- `affiliate_coc_agreement` (Number, opt) — [Optional] For Affiliate's Code of Conduct Agreement.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `tnc_approval` (Number, **req**) — Must be `1`
- `ukgc_funds_protection` (Number, opt) — [Optional] For `ASK_UK_FUNDS_PROTECTION` in `cashier`.

#### `get_account_status` [client] — JS method `getAccountStatus`; auth: unknown from source
Get Account Status
- `get_account_status` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `time` [schema] +client — auth_required=0
Request back-end server epoch time.
- `time` (integer, **req**) — Must be `1` — enum: [1]
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `time, echo_req, msg_type, req_id`

### 2. Account, settings & KYC

#### `get_settings` [client] — JS method `getSettings`; auth: unknown from source
Get User Settings (email, date of birth, address etc)
- `get_settings` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `set_settings` [client] — JS method `setSettings`; auth: unknown from source
Set User Settings (this call should be used in conjunction with `get_settings`)
- `account_opening_reason` (String, opt) — [Optional] Purpose and reason for requesting the account opening. Only applicable for real money account. Required for clients that have not set it yet. Can onl
- `address_city` (String, opt) — [Optional] Note: not applicable for virtual account. Required field for real money account.
- `address_line_1` (String, opt) — [Optional] Note: not applicable for virtual account. Required field for real money account.
- `address_line_2` (Any, opt) — [Optional] Note: not applicable for virtual account. Optional field for real money account.
- `address_postcode` (String, opt) — [Optional] Note: not applicable for virtual account. Optional field for real money account.
- `address_state` (String, opt) — [Optional] Note: not applicable for virtual account. Optional field for real money account.
- `allow_copiers` (Number, opt) — [Optional] Boolean value 1 or 0, indicating permission to allow others to follow your trades. Note: not applicable for Virtual account. Only allow for real mone
- `citizen` (Any, opt) — [Optional] Country of legal citizenship, 2-letter country code.
- `date_of_birth` (String, opt) — [Optional] Date of birth format: yyyy-mm-dd (can only be changed on unauthenticated svg accounts).
- `email_consent` (Number, opt) — [Optional] Boolean value 1 or 0, indicating permission to use email address for any contact which may include marketing
- `feature_flag` (Any, opt) — * @param {String} args.first_name - [Optional] Within 2-50 characters, use only letters, spaces, hyphens, full-stops or apostrophes (can only be changed on unau
- `last_name` (String, opt) — [Optional] Within 2-50 characters, use only letters, spaces, hyphens, full-stops or apostrophes (can only be changed on unauthenticated svg accounts).
- `non_pep_declaration` (Number, opt) — [Optional] Indicates client's self-declaration of not being a PEP/RCA (Politically Exposed Person/Relatives and Close Associates). Effective for real accounts o
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `phone` (Any, opt) — [Optional] Note: not applicable for virtual account. Starting with `+` followed by 9-35 digits, hyphens or space.
- `place_of_birth` (String, opt) — [Optional] Place of birth, 2-letter country code.
- `preferred_language` (Any, opt) — [Optional] User's preferred language, ISO standard language code
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `request_professional_status` (Number, opt) — [Optional] Required when client wants to be treated as professional. Applicable for financial accounts only.
- `residence` (Any, opt) — [Optional] 2-letter country code. Note: not applicable for real money account. Only allow for Virtual account without residence set.
- `salutation` (String, opt) — [Optional] Accept any value in enum list (can only be changed on unauthenticated svg accounts).
- `secret_answer` (String, opt) — [Optional] Answer to secret question, within 4-50 characters. Required for new account and existing client details will be used if client opens another account.
- `secret_question` (String, opt) — [Optional] Accept any value in enum list. Required for new account and existing client details will be used if client opens another account.
- `set_settings` (Number, **req**) — Must be `1`
- `tax_identification_number` (String, opt) — [Optional] Tax identification number. Only applicable for real money account. Required for maltainvest landing company.
- `tax_residence` (String, opt) — [Optional] Residence for tax purpose. Comma separated iso country code if multiple jurisdictions. Only applicable for real money account. Required for maltainve

#### `get_limits` [client] — JS method `getLimits`; auth: unknown from source
Trading and Withdrawal Limits for a given user
- `get_limits` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `get_self_exclusion` [client] — JS method `getSelfExclusion`; auth: unknown from source
Allows users to exclude themselves from the website for certain periods of time, or to set limits on their trading activities. This facility is a regulatory requirement for certain Landing Companies.
- `get_self_exclusion` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `set_self_exclusion` [client] — JS method `setSelfExclusion`; auth: unknown from source
Set Self-Exclusion (this call should be used in conjunction with `get_self_exclusion`)
- `exclude_until` (Any, opt) — [Optional] Exclude me from the website (for a minimum of 6 months, up to a maximum of 5 years). Note: uplifting this self-exclusion may require contacting the c
- `max_30day_deposit` (Any, opt) — [Optional] 7-day limit on deposits.
- `max_30day_losses` (Any, opt) — [Optional] 30-day limit on losses.
- `max_30day_turnover` (Any, opt) — [Optional] 30-day turnover limit.
- `max_7day_deposit` (Any, opt) — [Optional] 7-day limit on deposits.
- `max_7day_losses` (Any, opt) — [Optional] 7-day limit on losses.
- `max_7day_turnover` (Any, opt) — [Optional] 7-day turnover limit.
- `max_balance` (Any, opt) — [Optional] Maximum account cash balance.
- `max_deposit` (Any, opt) — [Optional] Daily deposit limit.
- `max_losses` (Any, opt) — [Optional] Daily limit on losses.
- `max_open_bets` (Any, opt) — [Optional] Maximum number of open positions.
- `max_turnover` (Any, opt) — [Optional] Daily turnover limit.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `session_duration_limit` (Any, opt) — [Optional] Session duration limit, in minutes.
- `set_self_exclusion` (Number, opt) — Must be `1`
- `timeout_until` (Any, opt) — [Optional] Exclude me from the website (for up to 6 weeks). Requires time in epoch format. Note: unlike `exclude_until`, this self-exclusion will be lifted auto

#### `get_financial_assessment` [client] — JS method `getFinancialAssessment`; auth: unknown from source
This call gets the financial assessment details. The 'financial assessment' is a questionnaire that clients of certain Landing Companies need to complete, due to regulatory and KYC (know your client) requirements.
- `get_financial_assessment` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `set_financial_assessment` [client] — JS method `setFinancialAssessment`; auth: unknown from source
This call sets the financial assessment details based on the client's answers to analyze whether they possess the experience and knowledge to understand the risks involved with binary options trading.
- `account_turnover` (String, opt) — [Optional] The anticipated account turnover.
- `binary_options_trading_experience` (String, opt) — [Optional] Binary options trading experience.
- `binary_options_trading_frequency` (String, opt) — [Optional] Binary options trading frequency.
- `cfd_trading_experience` (String, opt) — [Optional] CFDs trading experience.
- `cfd_trading_frequency` (String, opt) — [Optional] CFDs trading frequency.
- `education_level` (String, **req**) — Level of Education.
- `employment_industry` (String, **req**) — Industry of Employment.
- `employment_status` (String, opt) — [Optional] Employment Status.
- `estimated_worth` (String, **req**) — Estimated Net Worth.
- `forex_trading_experience` (String, opt) — [Optional] Forex trading experience.
- `forex_trading_frequency` (String, opt) — [Optional] Forex trading frequency.
- `income_source` (String, **req**) — Income Source.
- `net_income` (String, **req**) — Net Annual Income.
- `occupation` (String, **req**) — Occupation.
- `other_instruments_trading_experience` (String, opt) — [Optional] Trading experience in other financial instruments.
- `other_instruments_trading_frequency` (String, opt) — [Optional] Trading frequency in other financial instruments.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `set_financial_assessment` (Number, **req**) — Must be `1`
- `source_of_wealth` (String, opt) — [Optional] Source of wealth.

#### `residence_list` [client] — JS method `residenceList`; auth: unknown from source
This call returns a list of countries and 2-letter country codes, suitable for populating the account opening form.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `residence_list` (Number, **req**) — Must be `1`

#### `states_list` [client] — JS method `statesList`; auth: unknown from source
For a given country, returns a list of States of that country. This is useful to populate the account opening form.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `states_list` (String, **req**) — Client's 2-letter country code (obtained from `residence_list` call)

#### `landing_company` [client] — JS method `landingCompany`; auth: unknown from source
The company has a number of licensed subsidiaries in various jurisdictions, which are called Landing Companies. This call will return the appropriate Landing Company for clients of a given country. The landing company may differ for Gaming contracts (Synthetic Indices) and Financial contracts (Forex
- `landing_company` (String, **req**) — Client's 2-letter country code (obtained from `residence_list` call).
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `landing_company_details` [client] — JS method `landingCompanyDetails`; auth: unknown from source
The company has a number of licensed subsidiaries in various jurisdictions, which are called Landing Companies (and which are wholly owned subsidiaries of the Deriv Group). This call provides information about each Landing Company.
- `landing_company_details` (String, **req**) — Landing company shortcode.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `get_account_types` [client] — JS method `getAccountTypes`; auth: unknown from source
Types of accounts available to create or link to.
- `get_account_types` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `new_account_real` [client] — JS method `newAccountReal`; auth: unknown from source
This call opens a new real-money account. This call can be made from a virtual-money or a real-money account. If it is the latter, client information fields in this call will be ignored and data from your existing real-money account will be used.
- `account_opening_reason` (String, opt) — [Optional] Purpose and reason for requesting the account opening.
- `account_turnover` (String, opt) — [Optional] The anticipated account turnover.
- `address_city` (String, opt) — [Optional] Within 100 characters.
- `address_line_1` (String, opt) — Within 70 characters, with no leading whitespaces and may contain letters/numbers and/or any of following characters '.,:;()@#/-
- `address_line_2` (String, opt) — [Optional] Within 70 characters.
- `address_postcode` (String, opt) — [Optional] Within 20 characters and may not contain '+'.
- `address_state` (String, opt) — [Optional] Possible value receive from `states_list` call.
- `affiliate_token` (String, opt) — [Optional] Affiliate token, within 32 characters.
- `citizen` (Any, opt) — [Optional] Country of legal citizenship, 2-letter country code.
- `client_type` (String, opt) — [Optional] Indicates whether this is for a client requesting an account with professional status.
- `currency` (String, opt) — [Optional] To set currency of the account. List of supported currencies can be acquired with `payout_currencies` call.
- `date_of_birth` (String, opt) — Date of birth format: `yyyy-mm-dd`.
- `first_name` (String, opt) — Within 2-50 characters, use only letters, spaces, hyphens, full-stops or apostrophes.
- `last_name` (String, opt) — Within 2-50 characters, use only letters, spaces, hyphens, full-stops or apostrophes.
- `new_account_real` (Number, **req**) — Must be `1`
- `non_pep_declaration` (Number, opt) — [Optional] Indicates client's self-declaration of not being a PEP/RCA (Politically Exposed Person/Relatives and Close Associates).
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `phone` (Any, opt) — [Optional] Starting with `+` followed by 9-35 digits, hyphens or space.
- `place_of_birth` (String, opt) — [Optional] Place of birth, 2-letter country code.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `residence` (String, opt) — 2-letter country code, possible value receive from `residence_list` call.
- `salutation` (String, opt) — [Optional] Accept any value in enum list.
- `secret_answer` (String, opt) — [Optional] Answer to secret question, within 4-50 characters. Required for new account and existing client details will be used if client open another account.
- `secret_question` (String, opt) — [Optional] Accept any value in enum list. Required for new account and existing client details will be used if client open another account.
- `tax_identification_number` (String, opt) — [Optional] Tax identification number. Only applicable for real money account. Required for `maltainvest` landing company.
- `tax_residence` (String, opt) — [Optional] Residence for tax purpose. Comma separated iso country code if multiple jurisdictions. Only applicable for real money account. Required for `maltainv

#### `new_account_virtual` [client] — JS method `newAccountVirtual`; auth: unknown from source
Create a new virtual-money account.
- `affiliate_token` (String, opt) — [Optional] Affiliate token, within 32 characters.
- `client_password` (String, opt) — Password (Accepts any printable ASCII character. Must be within 8-25 characters, and include numbers, lowercase and uppercase letters. Must not be the same as t
- `date_first_contact` (String, opt) — [Optional] Date of first contact, format: `yyyy-mm-dd` in GMT timezone.
- `email_consent` (Number, opt) — [Optional] Boolean value: 1 or 0, indicating whether the client has given consent for marketing emails.
- `gclid_url` (String, opt) — [Optional] Google Click Identifier to track source.
- `new_account_virtual` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `residence` (String, opt) — 2-letter country code (obtained from `residence_list` call).
- `signup_device` (String, opt) — [Optional] Show whether user has used mobile or desktop.
- `type` (String, opt) — Account type
- `utm_ad_id` (Any, opt) — [Optional] Identifier of particular ad. Value must match Regex pattern to be recorded
- `utm_adgroup_id` (Any, opt) — [Optional] Identifier of ad group in the campaign. Value must match Regex pattern to be recorded
- `utm_adrollclk_id` (Any, opt) — [Optional] Unique identifier of click on AdRoll ads platform. Value must match Regex pattern to be recorded
- `utm_campaign` (Any, opt) — [Optional] Identifies a specific product promotion or strategic campaign such as a spring sale or other promotions. Value must match Regex pattern to be recorde
- `utm_campaign_id` (Any, opt) — [Optional] Identifier of paid ad campaign. Value must match Regex pattern to be recorded
- `utm_content` (Any, opt) — [Optional] Used to differentiate similar content, or links within the same ad. Value must match Regex pattern to be recorded
- `utm_fbcl_id` (Any, opt) — [Optional] Unique identifier of click on Facebook ads platform. Value must match Regex pattern to be recorded
- `utm_gl_client_id` (Any, opt) — [Optional] Unique visitor identifier on Google Ads platform. Value must match Regex pattern to be recorded
- `utm_medium` (Any, opt) — [Optional] Identifies the medium the link was used upon such as: email, CPC, or other methods of sharing. Value must match Regex pattern to be recorded
- `utm_msclk_id` (Any, opt) — [Optional] Unique click identifier on Microsoft Bing ads platform. Value must match Regex pattern to be recorded
- `utm_source` (Any, opt) — [Optional] Identifies the source of traffic such as: search engine, newsletter, or other referral. Value must match Regex pattern to be recorded
- `utm_term` (Any, opt) — [Optional] Used to send information related to the campaign term like paid search keywords. Value must match Regex pattern to be recorded
- `verification_code` (String, opt) — Email verification code (received from a `verify_email` call, which must be done first).

#### `new_account_wallet` [client] — JS method `newAccountWallet`; auth: unknown from source
Create a new account real-money wallet account.
- `address_city` (String, opt) — [Optional] Within 35 characters.
- `address_line_1` (String, opt) — [Optional] Mailing address.
- `address_line_2` (String, opt) — [Optional] Within 70 characters.
- `address_postcode` (String, opt) — [Optional] Within 20 characters and may not contain '+'.
- `address_state` (String, opt) — [Optional] Possible value receive from `states_list` call.
- `currency` (String, **req**) — [Optional] To set currency of the account. List of supported currencies can be acquired with `payout_currencies` call.
- `date_of_birth` (String, opt) — [Optional] Date of birth format: `yyyy-mm-dd`.
- `first_name` (String, opt) — [Optional] Within 2-50 characters, use only letters, spaces, hyphens, full-stops or apostrophes.
- `last_name` (String, opt) — [Optional] Within 2-50 characters, use only letters, spaces, hyphens, full-stops or apostrophes.
- `new_account_wallet` (Number, **req**) — Must be `1`
- `non_pep_declaration` (Number, opt) — [Optional] Indicates client's self-declaration of not being a PEP/RCA (Politically Exposed Person/Relatives and Close Associates).
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `payment_method` (String, **req**) — To set method which is used to transfer to/from wallet.
- `phone` (String, opt) — [Optional] Starting with `+` followed by 8-35 digits, allowing hyphens or space.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `new_account_maltainvest` [client] — JS method `newAccountMaltainvest`; auth: unknown from source
This call opens a new real-money account with the `maltainvest` Landing Company. This call can be made from a virtual-money account or real-money account at Deriv (Europe) Limited. If it is the latter, client information fields in this call will be ignored and data from your existing real-money acco
- `accept_risk` (Number, **req**) — Show whether client has accepted risk disclaimer.
- `account_opening_reason` (String, opt) — [Optional] Purpose and reason for requesting the account opening.
- `account_turnover` (String, opt) — [Optional] The anticipated account turnover.
- `address_city` (String, **req**) — Within 100 characters
- `address_line_1` (String, **req**) — Within 70 characters, with no leading whitespaces and may contain letters/numbers and/or any of following characters '.,:;()@#/-
- `address_line_2` (String, opt) — [Optional] Within 70 characters.
- `address_postcode` (String, opt) — [Optional] Within 20 characters and may not contain '+'.
- `address_state` (String, opt) — [Optional] Possible value receive from `states_list` call.
- `affiliate_token` (String, opt) — [Optional] Affiliate token, within 32 characters.
- `binary_options_trading_experience` (String, opt) — [Optional] Binary options trading experience.
- `binary_options_trading_frequency` (String, opt) — [Optional] Binary options trading frequency.
- `cfd_trading_experience` (String, opt) — [Optional] CFDs trading experience.
- `cfd_trading_frequency` (String, opt) — [Optional] CFDs trading frequency.
- `citizen` (String, opt) — [Optional] Country of legal citizenship, 2-letter country code. Possible value receive from `residence_list` call.
- `client_type` (String, opt) — [Optional] Indicates whether this is for a client requesting an account with professional status.
- `currency` (String, opt) — [Optional] To set currency of the account. List of supported currencies can be acquired with `payout_currencies` call.
- `date_of_birth` (String, **req**) — Date of birth format: yyyy-mm-dd.
- `education_level` (String, **req**) — Level of Education
- `employment_industry` (String, **req**) — Industry of Employment.
- `employment_status` (String, opt) — [Optional] Employment Status.
- `estimated_worth` (String, **req**) — Estimated Net Worth.
- `first_name` (String, **req**) — Within 2-50 characters, use only letters, spaces, hyphens, full-stops or apostrophes.
- `forex_trading_experience` (String, opt) — [Optional] Forex trading experience.
- `forex_trading_frequency` (String, opt) — [Optional] Forex trading frequency.
- `income_source` (String, **req**) — Income Source.
- `last_name` (String, **req**) — Within 2-50 characters, use only letters, spaces, hyphens, full-stops or apostrophes.
- `net_income` (String, **req**) — Net Annual Income.
- `new_account_maltainvest` (Number, **req**) — Must be `1`
- `non_pep_declaration` (Number, opt) — [Optional] Indicates client's self-declaration of not being a PEP/RCA.
- `occupation` (String, **req**) — Occupation.
- `other_instruments_trading_experience` (String, opt) — [Optional] Trading experience in other financial instruments.
- `other_instruments_trading_frequency` (String, opt) — [Optional] Trading frequency in other financial instruments.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `phone` (Any, opt) — [Optional] Starting with `+` followed by 9-35 digits, hyphens or space.
- `place_of_birth` (String, opt) — [Optional] Place of birth, 2-letter country code.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `residence` (String, **req**) — 2-letter country code, possible value receive from `residence_list` call.
- `salutation` (String, **req**) — Accept any value in enum list.
- `secret_answer` (String, opt) — [Optional] Answer to secret question, within 4-50 characters.
- `secret_question` (String, opt) — [Optional] Accept any value in enum list.
- `source_of_wealth` (String, opt) — [Optional] Source of wealth.
- `tax_identification_number` (String, **req**) — Tax identification number. Only applicable for real money account. Required for `maltainvest` landing company.
- `tax_residence` (String, **req**) — Residence for tax purpose. Comma separated iso country code if multiple jurisdictions. Only applicable for real money account. Required for `maltainvest` landin

#### `create_account` [REST schema] — endpoint: `POST /trading/v1/options/accounts`
Request to create a new Options trading account
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
  - `Content-Type` (string, **req**) — Content type
- `body` (object, **req**)
  - `currency` (string, **req**) — Account currency
  - `group` (string, **req**) — Account group
  - `account_type` (string, **req**) — Account type

#### `topup_virtual` [client] — JS method `topupVirtual`; auth: unknown from source
When a virtual-money's account balance becomes low, it can be topped up using this call.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `topup_virtual` (Number, **req**) — Must be `1`

#### `reset_demo_balance` [REST schema] — endpoint: `POST /trading/v1/options/accounts/{account_id}/reset-demo-balance`
Request to reset balance for Options trading demo account
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
- `path` (object, **req**)
  - `account_id` (string, **req**) — Options trading account ID

#### `account_nickname` [REST schema] — endpoint: `GET /account/v1/nickname`
Request for the GET /account/v1/nickname endpoint. Requires the Authorization header, plus Deriv-App-ID when authenticating with a Personal Access Token (PAT); takes no query parameters or body. The caller's brand and identity are resolved by the gateway from the X-Brand and X-Client-ID request head
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
- Response top-level keys: `data, errors, metadata`

#### `get_accounts` [REST schema] — endpoint: `GET /trading/v1/options/accounts`
Request to get all Options trading accounts
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
- Response top-level keys: `data, meta`

#### `reality_check` [client] — JS method `realityCheck`; auth: unknown from source
Retrieve summary of client's trades and account for the Reality Check facility. A 'reality check' means a display of time elapsed since the session began, and associated client profit/loss. The Reality Check facility is a regulatory requirement for certain landing companies.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `reality_check` (Number, **req**) — Must be `1`
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `document_upload` [client] — JS method `documentUpload`; auth: unknown from source
Request KYC information from client
- `document_format` (String, **req**) — Document file format
- `document_id` (String, opt) — [Optional] Document ID (required for Passport, Proof of ID and Driver's License)
- `document_issuing_country` (String, opt) — [Optional] 2-letter country code
- `document_type` (String, **req**) — Document type
- `document_upload` (Number, **req**) — Must be `1`
- `expected_checksum` (String, **req**) — The checksum of the file to be uploaded
- `expiration_date` (String, opt) — [Optional] Document expiration date (required for Passport, Proof of ID and Driver's License)
- `file_size` (Number, **req**) — Document size (should be less than 10MB)
- `lifetime_valid` (Number, opt) — [Optional] Boolean value that indicates whether this document is lifetime valid (only applies to POI document types, cancels out the expiration_date given if an
- `page_type` (String, opt) — [Optional] To determine document side
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `proof_of_ownership` (Any, **req**) — * @param {Number} args.req_id - [Optional] Used to map request to response.

#### `identity_verification_document_add` [client] — JS method `identityVerificationDocumentAdd`; auth: unknown from source
Adds document information such as issuing country, id and type for identity verification processes.
- `document_number` (String, **req**) — The identification number of the document.
- `document_type` (String, **req**) — The type of the document based on provided `issuing_country` (can obtained from `residence_list` call).
- `identity_verification_document_add` (Number, **req**) — Must be `1`
- `issuing_country` (String, **req**) — 2-letter country code (can obtained from `residence_list` call).
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `account_closure` [client] — JS method `accountClosure`; auth: unknown from source
This call allows clients to close all their accounts (including virtual-money account). It is assumed that all their accounts (excluding virtual) have no balance left.
- `account_closure` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `reason` (String, opt) — Reason for closing off accounts.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `account_statistics` [client] — JS method `accountStatistics`; auth: unknown from source
Send request to get account statistics
- `account_statistics` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `notification_event` [client] — JS method `notificationEvent`; auth: unknown from source
Notify the backend about a specific event.
- `args` (Any, opt) — * @param {String} args.category - The category or nature of the event.
- `event` (String, **req**) — The name of the event.
- `notification_event` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `link_wallet` [client] — JS method `linkWallet`; auth: unknown from source
Link a wallet to a trading app.
- `client_id` (String, **req**) — The unique identifier for this trading account.
- `link_wallet` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `wallet_id` (String, **req**) — The unique identifier for this wallet.

#### `set_account_currency` [client] — JS method `setAccountCurrency`; auth: unknown from source
Set account currency, this will be default currency for your account i.e currency for trading, deposit. Please note that account currency can only be set once, and then can never be changed.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `set_account_currency` (String, **req**) — Currency of the account. List of supported currencies can be acquired with `payout_currencies` call.

#### `legacy_accounts` [REST schema] — endpoint: `GET /trading/v1/options/legacy/accounts`
Request headers for GET /trading/v1/options/legacy/accounts. Returns the authenticated user's legacy accounts grouped by loginid.
- `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer tokens. Passed as a request header.
- `Authorization` (string, **req**) — Bearer token for authentication. Passed as a request header.
- Response top-level keys: `loginids`

#### `legacy_migration_status` [REST schema] — endpoint: `GET /trading/v1/options/legacy/migration-status`
Request headers for GET /trading/v1/options/legacy/migration-status. Returns the current state of the user's platform upgrade.
- `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer tokens. Passed as a request header.
- `Authorization` (string, **req**) — Bearer token for authentication. Passed as a request header.
- Response top-level keys: `status`

#### `legacy_statement` [REST schema] — endpoint: `GET /trading/v1/options/legacy/statement`
Query parameters for GET /trading/v1/options/legacy/statement. Returns the historical transaction statement from the legacy options platform for the default account of the supplied loginid.
- `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer tokens. Passed as a request header.
- `Authorization` (string, **req**) — Bearer token for authentication. Passed as a request header.
- `loginid` (string, **req**) — Legacy loginid whose default-account statement to return. Must match `^[A-Z]+[0-9]+$`.
- `date_from` (integer, opt) — Inclusive lower bound as epoch seconds. A row is included iff its true `transaction_time` is `>= date_from`. Defaults to 0 (all history). Values above 214748364
- `date_to` (integer, opt) — Exclusive upper bound as epoch seconds. A row is included iff its true `transaction_time` is `< date_to`. Defaults to current time. Values above 2147483647 (the
- `action_type` (string, opt) — Filter by transaction type. Defaults to all types. — enum: ['buy', 'sell', 'deposit', 'withdrawal', 'transfer', 'hold', 'release', 'adjustment', 'escrow']
- `limit` (integer, opt) — Maximum number of transactions to return. Defaults to 100, maximum 999.
- `offset` (integer, opt) — Number of transactions to skip before returning results. Use with `limit` for pagination.
- Response top-level keys: `transactions, count`

### 3. Market data (mostly public)

#### `active_symbols` [schema] +client — auth_required=0
Retrieve a list of all currently active symbols (underlying markets upon which contracts are available for trading).
- `active_symbols` (string, **req**) — If you use `brief`, only a subset of fields will be returned. — enum: ['full', 'brief']
- `contract_type` (array, opt) — [Optional] The proposed contract type
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `active_symbols, echo_req, msg_type, req_id`

#### `ticks` [schema] +client — auth_required=0
Initiate a continuous stream of spot price updates for a given symbol.
- `ticks` (?, **req**) — The short symbol name or array of symbols (obtained from `active_symbols` call).
- `subscribe` (integer, opt) — [Optional] If set to 1, will send updates whenever a new tick is received. — enum: [1]
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `tick, subscription, echo_req, msg_type, req_id`

#### `ticks_history` [schema] +client — auth_required=0
Get historic tick data for a given symbol.
- `ticks_history` (string, **req**) — Short symbol name (obtained from the `active_symbols` call).
- `adjust_start_time` (integer, opt) — [Optional] 1 - if the market is closed at the end time, or license limit is before end time, adjust interval backwards to compensate. — enum: [1]
- `count` (integer, opt) — [Optional] An upper limit on ticks to receive.
- `end` (string, **req**) — Epoch value representing the latest boundary of the returned ticks. If `latest` is specified, this will be the latest available timestamp.
- `granularity` (integer, opt) — [Optional] Only applicable for style: `candles`. Candle time-dimension width setting. (default: `60`). — enum: [60, 120, 180, 300, 600, 900, 1800, 3600, 7200, 14400, 28800, 86400]
- `start` (integer, opt) — [Optional] Epoch value representing the earliest boundary of the returned ticks.  - For `"style": "ticks"`: this will default to 1 day ago. - For `"style": "can
- `style` (string, opt) — [Optional] The tick-output style. — enum: ['candles', 'ticks']
- `subscribe` (integer, opt) — [Optional] 1 - to send updates whenever a new tick is received. — enum: [1]
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `candles, history, pip_size, subscription, echo_req, msg_type, req_id`

#### `trading_times` [schema] +client — auth_required=0
Receive a list of market opening times for a given date.
- `trading_times` (string, **req**) — Date to receive market opening times for. Can be specified in `yyyy-mm-dd` format or `today` can also be specified, in both cases the date is in UTC timezone.
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `trading_times, echo_req, msg_type, req_id`

#### `trading_durations` [client] — JS method `tradingDurations`; auth: unknown from source
Retrieve a list of all available underlyings and the corresponding contract types and trading duration boundaries. If the user is logged in, only the assets available for that user's landing company will be returned.
- `landing_company` (String, opt) — [Optional] If specified, will return only the underlyings for the specified landing company.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `trading_durations` (Number, **req**) — Must be `1`

#### `asset_index` [client] — JS method `assetIndex`; auth: unknown from source
Retrieve a list of all available underlyings and the corresponding contract types and duration boundaries. If the user is logged in, only the assets available for that user's landing company will be returned.
- `asset_index` (Number, **req**) — Must be `1`
- `landing_company` (String, opt) — [Optional] If specified, will return only the underlyings for the specified landing company.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `contracts_for` [schema] +client — auth_required=0
For a given symbol, get the list of currently available contracts, and the latest barrier and duration limits for each contract.
- `contracts_for` (string, **req**) — The short symbol name (obtained from `active_symbols` call).
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `contracts_for, echo_req, msg_type, req_id`

#### `contracts_list` [schema] — auth_required=0
Get the list of all contract categories available for the trading platform.
- `contracts_list` (integer, **req**) — Must be 1 — enum: [1]
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `contracts_list, echo_req, msg_type, req_id`

#### `exchange_rates` [client] — JS method `exchangeRates`; auth: unknown from source
Retrieves the exchange rates from a base currency to all currencies supported by the system.
- `base_currency` (String, **req**) — Base currency (can be obtained from `payout_currencies` call)
- `exchange_rates` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `subscribe` (Number, opt) — [Optional] 1 - to initiate a realtime stream of exchange rates relative to base currency.
- `target_currency` (String, opt) — [Optional] Local currency

#### `economic_calendar` [client] — JS method `economicCalendar`; auth: unknown from source
Specify a currency to receive a list of events related to that specific currency. For example, specifying USD will return a list of USD-related events. If the currency is omitted, you will receive a list for all currencies.
- `currency` (String, opt) — [Optional] Currency symbol.
- `economic_calendar` (Number, **req**) — Must be `1`
- `end_date` (Number, opt) — [Optional] End date.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `start_date` (Number, opt) — [Optional] Start date.

#### `payout_currencies` [client] — JS method `payoutCurrencies`; auth: unknown from source
Retrieve a list of available option payout currencies. If a user is logged in, only the currencies available for the account will be returned.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `payout_currencies` (Number, **req**) — Must be `1`
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `trading_servers` [client] — JS method `tradingServers`; auth: unknown from source
Get the list of servers for a trading platform.
- `account_type` (String, opt) — [Optional] Trading account type.
- `environment` (String, opt) — [Optional] Pass the environment (installation) instance. Currently, there are one demo and two real environments. Defaults to 'all'.
- `market_type` (String, opt) — [Optional] Market type.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `platform` (String, opt) — [Optional] Pass the trading platform name, default to mt5
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `trading_servers` (Number, **req**) — Must be `1`

#### `trading_platform_product_listing` [client] — JS method `tradingPlatformProductListing`; auth: unknown from source
Get list of Trading Platform products for client
- `app_id` (Any, opt) — [Optional] Specific application `app_id`.
- `country_code` (String, **req**) — [Optional] Country of legal citizenship, 2-letter country code.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `trading_platform_product_listing` (Number, **req**) — Must be 1.

#### `markup_statistics` [REST schema] — endpoint: `GET /applications/v1/markup-statistics`
Query parameters for the GET /applications/v1/markup-statistics endpoint.
- `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer tokens. Passed as a request header.
- `date_from` (string, **req**) — Interval start date (YYYY-MM-DD), inclusive, UTC.
- `date_to` (string, **req**) — Interval end date (YYYY-MM-DD), inclusive, UTC.
- Response top-level keys: `data, meta`

### 4. Trading: proposal, buy, sell, portfolio

#### `proposal` [schema] +client — auth_required=0
Gets latest price for a specific contract.
- `proposal` (integer, **req**) — Must be `1` — enum: [1]
- `amount` (number, opt) — [Optional] Proposed contract payout or stake.
- `barrier` (string, opt) — [Optional] Barrier for the contract (or last digit prediction for digit contracts). Contracts less than 24 hours in duration would need a relative barrier (barr
- `barrier2` (string, opt) — [Optional] Low barrier for the contract (for contracts with two barriers). Contracts less than 24 hours in duration would need a relative barrier (barriers whic
- `basis` (string, opt) — [Optional] Indicates type of the `amount`. — enum: ['payout', 'stake']
- `cancellation` (string, opt) — Cancellation duration option (only for `MULTUP` and `MULTDOWN` contracts).
- `contract_type` (string, **req**) — The proposed contract type — enum: ['HIGHER', 'LOWER', 'MULTUP', 'MULTDOWN', 'UPORDOWN', 'EXPIRYRANGE', 'ONETOUCH', 'CALLE', 'ASIAND', 'EXPIRYRANGEE', 'DIGITDIFF', 'DIGITMATCH', 'DIGITOVER', 'PUTE', 'DIGITUNDER', 'NOTOUCH', 'CALL', 'RANGE', 'DIGITODD', 'PUT', 'ASIANU', 'EXPIRYMISSE', 'EXPIRYMISS', 'DIGITEVEN', 'TICKHIGH', 'TICKLOW', 'RESETCALL', 'RESETPUT', 'RUNHIGH', 'RUNLOW', 'ACCU', 'VANILLALONGCALL', 'VANILLALONGPUT', 'TURBOSLONG', 'TURBOSSHORT']
- `currency` (string, **req**) — This can only be the account-holder's currency (obtained from `payout_currencies` call).
- `date_expiry` (integer, opt) — [Optional] Epoch value of the expiry time of the contract. Either date_expiry or duration is required.
- `duration` (integer, opt) — [Optional] Duration quantity. Either date_expiry or duration is required.
- `duration_unit` (string, opt) — [Optional] Duration unit - `s`: seconds, `m`: minutes, `h`: hours, `d`: days, `t`: ticks. — enum: ['d', 'm', 's', 'h', 't']
- `growth_rate` (number, opt) — [Optional] Growth rate of an accumulator contract.
- `limit_order` (object, opt) — Add an order to close the contract once the order condition is met (only for `MULTUP` and `MULTDOWN` and 'ACCU' contracts). Supported orders: `take_profit`, `st
  - `stop_loss` (number, opt) — Contract will be automatically closed when the value of the contract reaches a specific loss.
  - `take_profit` (number, opt) — Contract will be automatically closed when the value of the contract reaches a specific profit.
- `multiplier` (number, opt) — [Optional] The multiplier for non-binary options. E.g. lookbacks.
- `payout_per_point` (number, opt) — [Optional] Clients can provide payout_per_point directly, and the barrier will be calculated based on this payout_per_point value.
- `selected_tick` (integer, opt) — [Optional] The tick that is predicted to have the highest/lowest value - for `TICKHIGH` and `TICKLOW` contracts.
- `subscribe` (integer, opt) — [Optional] 1 - to initiate a realtime stream of prices. Note that tick trades (without a user-defined barrier), digit trades and less than 24 hours at-the-money — enum: [1]
- `underlying_symbol` (string, **req**) — The symbol code (obtained from `active_symbols` call).
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `proposal, subscription, echo_req, msg_type, req_id`

#### `buy` [schema] +client — auth_required=1, scopes=['trade']
Buy a Contract
- `buy` (string, **req**) — Either the ID received from a Price Proposal (`proposal` call), or `1` if contract buy parameters are passed in the `parameters` field.
- `parameters` (object, opt) — [Optional] Used to pass the parameters for contract buy.
  - `amount` (number, opt) — [Optional] Proposed payout or stake value
  - `barrier` (string, opt) — [Optional] Barrier for the contract (or last digit prediction for digit contracts). Contracts less than 24 hou
  - `barrier2` (string, opt) — [Optional] Low barrier for the contract (for contracts with two barriers). Contracts less than 24 hours in dur
  - `basis` (string, opt) — [Optional] Indicates whether amount is 'payout' or 'stake' for binary options.
  - `cancellation` (string, opt) — Cancellation duration option (only for `MULTUP` and `MULTDOWN` contracts).
  - `contract_type` (string, **req**) — A valid contract-type
  - `currency` (string, **req**) — This can only be the account-holder's currency
  - `date_expiry` (integer, opt) — [Optional] Epoch value of the expiry time of the contract. You must either specify date_expiry or duration.
  - `duration` (integer, opt) — [Optional] Duration quantity
  - `duration_unit` (string, opt) — [Optional] Duration unit is `s`: seconds, `m`: minutes, `h`: hours, `d`: days, `t`: ticks
  - `growth_rate` (number, opt) — [Optional] Growth rate of an accumulator contract.
  - `limit_order` (object, opt) — Add an order to close the contract once the order condition is met (only for `MULTUP` and `MULTDOWN` and `ACCU
  - `multiplier` (number, opt) — [Optional] The multiplier for non-binary options. E.g. lookbacks.
  - `payout_per_point` (number, opt) — [Optional] Clients can provide payout_per_point directly, and the barrier will be calculated based on this pay
  - `selected_tick` (integer, opt) — [Optional] The tick that is predicted to have the highest/lowest value - for tickhigh and ticklow contracts.
  - `underlying_symbol` (string, **req**) — Symbol code
- `price` (number, **req**) — Maximum price at which to purchase the contract.
- `subscribe` (integer, opt) — [Optional] `1` to stream. — enum: [1]
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `buy, subscription, echo_req, msg_type, req_id`

#### `sell` [schema] +client — auth_required=1, scopes=['trade']
Sell a Contract as identified by the `contract_id`.
- `sell` (integer, **req**) — Pass contract_id received from the `portfolio` call.
- `price` (number, **req**) — Minimum price at which to sell the contract, or `0` for 'sell at market'.
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `sell, echo_req, msg_type, req_id`

#### `cancel` [schema] +client — auth_required=1, scopes=['trade']
Cancel contract with contract id
- `cancel` (integer, **req**) — Value should be the `contract_id` which received from the `portfolio` call.
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `cancel, echo_req, msg_type, req_id`

#### `contract_update` [schema] +client — auth_required=1, scopes=['trade']
Update a contract condition.
- `contract_update` (integer, **req**) — Must be `1` — enum: [1]
- `contract_id` (integer, **req**) — Internal unique contract identifier.
- `limit_order` (object, **req**) — Specify limit order to update.
  - `stop_loss` (['null', 'number'], opt) — New stop loss value for a contract. To cancel, pass `null`.
  - `take_profit` (['null', 'number'], opt) — New take profit value for a contract. To cancel, pass `null`.
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `contract_update, echo_req, msg_type, req_id`

#### `contract_update_history` [schema] +client — auth_required=1, scopes=['trade']
Request for contract update history.
- `contract_update_history` (integer, **req**) — Must be `1` — enum: [1]
- `contract_id` (integer, **req**) — Internal unique contract identifier.
- `limit` (number, opt) — [Optional] Maximum number of historical updates to receive.
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `contract_update_history, echo_req, msg_type, req_id`

#### `proposal_open_contract` [schema] +client — auth_required=1, scopes=['trade']
Get the latest price (and other information) for contract(s) in the account's portfolio
- `proposal_open_contract` (integer, **req**) — Must be `1` — enum: [1]
- `contract_id` (integer, opt) — [Optional] Contract ID received from a `portfolio` request. If not set, you will receive stream of all open contracts.
- `subscribe` (integer, opt) — [Optional] `1` to stream. — enum: [1]
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `proposal_open_contract, subscription, echo_req, msg_type, req_id`

#### `bulk_purchase` [REST schema] — endpoint: `POST /trading/v1/options/contracts/bulk-purchase/demo | /real`
Request to buy the same options contract across multiple end-user accounts in a single call
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier used for Personal Access Token (PAT) authentication. No OAuth access token is required
  - `Content-Type` (string, **req**) — Content type
- `body` (object, **req**)
  - `contract_parameters` (object, **req**) — Opaque options contract parameters applied to every account in the request (e.g. contract_type, symbol, amount
  - `accounts` (array, **req**) — List of end-user token / account pairs to buy the contract for. Duplicate pairs are honoured and result in rep
- Response top-level keys: `data, meta`

#### `buy_contract_for_multiple_accounts` [client] — JS method `buyContractForMultipleAccounts`; auth: unknown from source
Buy a Contract for multiple Accounts specified by the `tokens` parameter. Note, although this is an authorized call, the contract is not bought for the authorized account.
- `buy_contract_for_multiple_accounts` (String, **req**) — Either the ID received from a Price Proposal (`proposal` call), or `1` if contract buy parameters are passed in the `parameters` field.
- `parameters` (Any, opt) — * @param {Any} args.passthrough - [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `price` (Number, opt) — Maximum price at which to purchase the contract.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `tokens` (Any, **req**) — List of API tokens identifying the accounts for which the contract is bought. Note: If the same token appears multiple times or if multiple tokens designate the

#### `sell_contract_for_multiple_accounts` [client] — JS method `sellContractForMultipleAccounts`; auth: unknown from source
Sell contracts for multiple accounts simultaneously. Uses the shortcode response from `buy_contract_for_multiple_accounts` to identify the contract, and authorisation tokens to select which accounts to sell those contracts on. Note that only the accounts identified by the tokens will be affected. Th
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `price` (Number, opt) — Minimum price at which to sell the contract, or `0` for 'sell at market'.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `sell_contract_for_multiple_accounts` (Number, **req**) — Must be `1`
- `shortcode` (String, **req**) — An internal ID used to identify the contract which was originally bought. This is returned from the `buy` and `buy_contract_for_multiple_accounts` calls.
- `tokens` (Any, **req**) — Authorisation tokens which select the accounts to sell use for the affected accounts.

#### `sell_expired` [client] — JS method `sellExpired`; auth: unknown from source
This call will try to sell any expired contracts and return the number of sold contracts.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `sell_expired` (Number, **req**) — Must be `1`

#### `portfolio` [schema] +client — auth_required=1, scopes=['trade']
Receive information about my current portfolio of outstanding options.
- `portfolio` (integer, **req**) — Must be `1` — enum: [1]
- `contract_type` (array, opt) — Return only contracts of the specified types
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `portfolio, echo_req, msg_type, req_id`

#### `statement` [schema] +client — auth_required=1, scopes=['trade']
Retrieve a summary of account transactions, according to given search criteria
- `statement` (integer, **req**) — Must be `1` — enum: [1]
- `action_type` (string, opt) — [Optional] To filter the statement according to the type of transaction. — enum: ['buy', 'sell', 'deposit', 'withdrawal']
- `date_from` (integer, opt) — [Optional] Start date (epoch)
- `date_to` (integer, opt) — [Optional] End date (epoch)
- `description` (integer, opt) — [Optional] If set to 1, will return full contracts description. — enum: [0, 1]
- `limit` (number, opt) — [Optional] Maximum number of transactions to receive.
- `offset` (integer, opt) — [Optional] Number of transactions to skip.
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `statement, echo_req, msg_type, req_id`

#### `profit_table` [schema] +client — auth_required=1, scopes=['trade']
Retrieve a summary of account Profit Table, according to given search criteria
- `profit_table` (integer, **req**) — Must be `1` — enum: [1]
- `contract_type` (array, opt) — Return only contracts of the specified types
- `date_from` (string, opt) — [Optional] Start date (epoch or YYYY-MM-DD)
- `date_to` (string, opt) — [Optional] End date (epoch or YYYY-MM-DD)
- `description` (integer, opt) — [Optional] If set to 1, will return full contracts description. — enum: [0, 1]
- `limit` (number, opt) — [Optional] Apply upper limit to count of transactions received.
- `offset` (integer, opt) — [Optional] Number of transactions to skip.
- `sort` (string, opt) — [Optional] Sort direction. — enum: ['ASC', 'DESC']
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `profit_table, echo_req, msg_type, req_id`

#### `transaction` [schema] +client — auth_required=1, scopes=['trade']
Subscribe to transaction notifications
- `transaction` (integer, **req**) — Must be `1` — enum: [1]
- `subscribe` (integer, **req**) — If set to 1, will send updates whenever there is an update to transactions. If not to 1 then it will not return any records. — enum: [1]
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `transaction, subscription, echo_req, msg_type, req_id`

#### `balance` [schema] +client — auth_required=1, scopes=['trade']
Get the account's balance
- `balance` (integer, **req**) — Must be `1` — enum: [1]
- `subscribe` (integer, opt) — [Optional] If set to 1, will send updates whenever the balance changes. — enum: [0, 1]
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `balance, subscription, echo_req, msg_type, req_id`

#### `copy_start` [client] — JS method `copyStart`; auth: unknown from source
Start copy trader bets
- `assets` (Any, opt) — [Optional] Used to set assets to be copied. E.x ["frxUSDJPY", "R_50"]
- `copy_start` (String, **req**) — API tokens identifying the accounts of trader which will be used to copy trades
- `max_trade_stake` (Number, opt) — [Optional] Used to set maximum trade stake to be copied.
- `min_trade_stake` (Number, opt) — [Optional] Used to set minimal trade stake to be copied.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `trade_types` (Any, opt) — [Optional] Used to set trade types to be copied. E.x ["CALL", "PUT"]

#### `copy_stop` [client] — JS method `copyStop`; auth: unknown from source
Stop copy trader bets
- `copy_stop` (String, **req**) — API tokens identifying the accounts which needs not to be copied
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `copytrading_list` [client] — JS method `copytradingList`; auth: unknown from source
Retrieves a list of active copiers and/or traders for Copy Trading
- `copytrading_list` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `copytrading_statistics` [client] — JS method `copytradingStatistics`; auth: unknown from source
Retrieve performance, trading, risk and copiers statistics of trader.
- `copytrading_statistics` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `trader_id` (String, **req**) — The ID of the target trader.

#### `auto_get` [schema] — auth_required=1, scopes=['trade']
Retrieve details for a specific automated trading run, with optional subscription to real-time updates
- `auto_get` (integer, **req**) — Must be `1` — enum: [1]
- `run_id` (string, **req**) — The run ID to retrieve.
- `subscribe` (integer, opt) — [Optional] If set to `1`, will stream run updates (new contracts purchased, status changes) until the run ends or `forget` is called. — enum: [1]
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `auto_get, subscription, echo_req, msg_type, req_id`

#### `auto_list` [schema] — auth_required=1, scopes=['trade']
Retrieve the list of automated trading runs for the current account
- `auto_list` (integer, **req**) — Must be `1` — enum: [1]
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `auto_list, echo_req, msg_type, req_id`

#### `auto_list_strategies` [schema] — auth_required=0
Retrieve the list of available automated trading strategies
- `auto_list_strategies` (integer, **req**) — Must be `1` — enum: [1]
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `auto_list_strategies, echo_req, msg_type, req_id`

#### `auto_pause` [schema] — auth_required=1, scopes=['trade']
Pause an automated trading run. No further contracts will be purchased until the run is resumed.
- `auto_pause` (integer, **req**) — Must be `1` — enum: [1]
- `run_id` (string, **req**) — The run ID to pause.
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `auto_pause, echo_req, msg_type, req_id`

#### `auto_resume` [schema] — auth_required=1, scopes=['trade']
Resume a paused automated trading run
- `auto_resume` (integer, **req**) — Must be `1` — enum: [1]
- `run_id` (string, **req**) — The run ID to resume.
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `auto_resume, echo_req, msg_type, req_id`

#### `auto_start` [schema] — auth_required=1, scopes=['trade']
Start an automated trading run following a predefined strategy
- `auto_start` (integer, **req**) — Must be `1` — enum: [1]
- `contract_template` (object, **req**) — Template defining the contract parameters to be used for each purchase in this run
  - `amount` (number, opt) — [Optional] Initial stake or payout value
  - `barrier` (string, opt) — [Optional] Barrier for the contract (or last digit prediction for digit contracts)
  - `barrier2` (string, opt) — [Optional] Low barrier for the contract (for contracts with two barriers)
  - `basis` (string, opt) — [Optional] Indicates whether amount is 'payout' or 'stake' for binary options
  - `contract_type` (string, **req**) — A valid contract type
  - `currency` (string, **req**) — The account-holder's currency
  - `duration` (integer, opt) — [Optional] Duration quantity
  - `duration_unit` (string, opt) — [Optional] Duration unit: `s` seconds, `m` minutes, `h` hours, `d` days, `t` ticks
  - `growth_rate` (number, opt) — [Optional] Growth rate of an accumulator contract
  - `limit_order` (object, opt) — [Optional] Order to close the contract once the order condition is met (only for `MULTUP`, `MULTDOWN`, and `AC
  - `multiplier` (number, opt) — [Optional] The multiplier for non-binary options
  - `selected_tick` (integer, opt) — [Optional] The tick predicted to have the highest/lowest value - for tickhigh and ticklow contracts
  - `underlying_symbol` (string, **req**) — Symbol code
- `strategy_id` (string, **req**) — Identifier of the strategy to run
- `strategy_parameters` (object, **req**) — Parameters specific to the selected strategy (e.g. martingale multiplier, max rounds)
- `subscribe` (integer, opt) — [Optional] If set to `1`, will stream run updates (new contracts purchased, status changes) until the run ends or `forget` is called. — enum: [1]
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `auto_start, subscription, echo_req, msg_type, req_id`

#### `auto_stop` [schema] — auth_required=1, scopes=['trade']
Stop an automated trading run. No further contracts will be purchased; contracts already open continue to run.
- `auto_stop` (integer, **req**) — Must be `1` — enum: [1]
- `run_id` (string, **req**) — The run ID to stop.
- `passthrough` (object, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (integer, opt) — [Optional] Used to map request to response.
- Response top-level keys: `auto_stop, echo_req, msg_type, req_id`

#### `request_report` [client] — JS method `requestReport`; auth: unknown from source
Send report to client's registered e-mail
- `date_from` (Number, **req**) — Start date of the report
- `date_to` (Number, **req**) — End date of the report
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `report_type` (String, **req**) — Type of report to be sent to client's registered e-mail address
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `request_report` (Number, **req**) — Must be `1`

### 5. Cashier, payments, wallets & payment agents

#### `cashier` [client] — JS method `cashier`; auth: unknown from source
Request the cashier info for the specified type.
- `address` (String, opt) — [Optional] Address for crypto withdrawal. Only applicable for `api` type.
- `amount` (Number, opt) — [Optional] Amount for crypto withdrawal. Only applicable for `api` type.
- `cashier` (String, **req**) — Operation which needs to be requested from cashier
- `dry_run` (Number, opt) — [Optional] If set to `1`, only validation is performed. Only applicable for `withdraw` using `crypto` provider and `api` type.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `provider` (String, opt) — [Optional] Cashier provider. `crypto` will be default option for crypto currency accounts.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `type` (String, opt) — [Optional] Data need to be returned from cashier. `api` is supported only for `crypto` provider.
- `verification_code` (String, opt) — [Optional] Email verification code (received from a `verify_email` call, which must be done first)

#### `cashier_payments` [client] — JS method `cashierPayments`; auth: unknown from source
List pending transactions. This can only be used for crypto transactions.
- `cashier_payments` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `provider` (String, opt) — [Optional] Cashier provider. `crypto` will be default option for crypto currency accounts.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `subscribe` (Number, opt) — [Optional] If set to 1, will send updates whenever there is update to crypto payments.
- `transaction_type` (String, opt) — [Optional] Type of transactions to receive.

#### `cashier_withdrawal_cancel` [client] — JS method `cashierWithdrawalCancel`; auth: unknown from source
Request for cancelling a withdrawal. This can only be used for crypto transactions.
- `cashier_withdrawal_cancel` (Number, **req**) — Must be `1`
- `id` (String, **req**) — The unique identifier for the transaction.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `payment_methods` [client] — JS method `paymentMethods`; auth: unknown from source
Will return a list payment methods available for the given country. If the request is authenticated the client's residence country will be used.
- `country` (String, opt) — [Optional] 2-letter country code (ISO standard).
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `payment_methods` (Number, **req**) — Must be `1`
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `payment_agent_client_settings` [REST schema] — endpoint: `GET /payment-agents/v1/clients/me`
Request the authenticated client's current payment agent settings
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
- Response top-level keys: `data, errors, metadata`

#### `payment_agent_client_settings_update` [REST schema] — endpoint: `PATCH /payment-agents/v1/clients/me`
Update the authenticated client's payment agent privacy preference
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
  - `Content-Type` (string, **req**) — Content type
- `body` (object, **req**)
  - `data` (object, **req**) — Settings to update.
- Response top-level keys: `data, errors, metadata`

#### `payment_agent_get` [REST schema] — endpoint: `GET /payment-agents/v1/agents/{id}`
Request for the full profile of a single payment agent
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
- `path` (object, **req**)
  - `id` (string, **req**) — Numeric ID of the payment agent (as returned by the list endpoint) or the literal string `me` to return the au
- Response top-level keys: `data, errors, metadata`

#### `payment_agent_list` [REST schema] — endpoint: `GET /payment-agents/v1/agents`
Request to list active payment agents that support a currency
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
- `query` (object, **req**)
  - `currency` (string, **req**) — Currency code. Only agents that support this currency are returned.
  - `country` (string, opt) — ISO 3166-1 alpha-2 country code in lowercase (e.g. `id`). When supplied, only agents whose `countries` list in
  - `page` (integer, opt) — Page number for pagination. Defaults to 1.
  - `per_page` (integer, opt) — Number of results per page. Defaults to 25.
- Response top-level keys: `data, errors, metadata`

#### `payment_agent_statistics` [REST schema] — endpoint: `GET /payment-agents/v1/agent-statistics`
Request for the aggregate countries and currencies covered by active payment agents
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
- Response top-level keys: `data, errors, metadata`

#### `payment_agent_transfer` [REST schema] — endpoint: `POST /payment-agents/v1/transfer`
Request for a payment agent to deposit funds into a client's Deriv wallet
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
  - `Content-Type` (string, **req**) — Content type
- `body` (object, **req**)
  - `data` (object, **req**) — Transfer parameters.
- Response top-level keys: `data, errors, metadata`

#### `payment_agent_transfer_status` [REST schema] — endpoint: `GET /payment-agents/v1/transfer/{request_id}`
Request the current status of a transfer previously initiated with a request_id
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
- `path` (object, **req**)
  - `request_id` (string, **req**) — The `request_id` previously passed to the transfer endpoint (1-128 characters: letters, digits, underscore, hy
- Response top-level keys: `data, errors, metadata`

#### `payment_agent_withdraw` [REST schema] — endpoint: `POST /payment-agents/v1/withdraw`
Withdraw funds from the authenticated client's account through a payment agent
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
  - `Content-Type` (string, **req**) — Content type
- `body` (object, **req**)
  - `data` (object, **req**) — Withdrawal parameters.
- Response top-level keys: `data, errors, metadata`

#### `payment_agent_withdraw_status` [REST schema] — endpoint: `GET /payment-agents/v1/withdraw/{request_id}`
Request the current status of a withdrawal previously submitted with a request_id
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
- `path` (object, **req**)
  - `request_id` (string, **req**) — The `request_id` previously passed to the withdraw endpoint (1-128 characters: letters, digits, underscore, hy
- Response top-level keys: `data, errors, metadata`

#### `payment_agent_withdraw_verification` [REST schema] — endpoint: `POST /payment-agents/v1/withdraw/verification_code`
Request a one-time verification code to be sent to the client's registered contact before submitting a withdrawal
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
  - `Content-Type` (string, **req**) — Content type
- `body` (object, **req**)
  - `data` (object, **req**) — Verification code request parameters. Must match the intended withdrawal.
- Response top-level keys: `data, errors, metadata`

#### `paymentagent_create` [client] — JS method `paymentagentCreate`; auth: unknown from source
Saves client's payment agent details.
- `affiliate_id` (String, opt) — [Optional] Client's My Affiliate id, if exists.
- `code_of_conduct_approval` (Number, **req**) — Indicates client's agreement with the Code of Conduct.
- `commission_deposit` (Number, **req**) — Commission  (%) the agent wants to take on deposits
- `commission_withdrawal` (Number, **req**) — Commission  (%) the agent wants to take on withdrawals
- `email` (String, **req**) — Payment agent's email address.
- `information` (String, **req**) — [Optional] Information about payment agent and their proposed service.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `payment_agent_name` (String, **req**) — The name with which the payment agent is going to be identified.
- `paymentagent_create` (Number, **req**) — Must be 1
- `phone_numbers` (Any, opt) — Payment agent's phone number(s) with country code.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `supported_payment_methods` (Any, **req**) — A list of supported payment methods.
- `urls` (Any, **req**) — The URL(s) of payment agent's website(s).

#### `paymentagent_details` [client] — JS method `paymentagentDetails`; auth: unknown from source
Gets client's payment agent details.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `paymentagent_details` (Number, **req**) — Must be 1
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `paymentagent_list` [client] — JS method `paymentagentList`; auth: unknown from source
Will return a list of Payment Agents for a given country for a given currency. Payment agents allow users to deposit and withdraw funds using local payment methods that might not be available via the main website's cashier system.
- `currency` (String, opt) — [Optional] If specified, only payment agents that supports that currency will be returned (obtained from `payout_currencies` call).
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `paymentagent_list` (String, **req**) — Client's 2-letter country code (obtained from `residence_list` call).
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `paymentagent_transfer` [client] — JS method `paymentagentTransfer`; auth: unknown from source
Payment Agent Transfer - this call is available only to accounts that are approved Payment Agents.
- `amount` (Number, **req**) — The amount to transfer.
- `currency` (String, **req**) — Currency code.
- `description` (String, opt) — [Optional] Remarks about the transfer.
- `dry_run` (Number, opt) — [Optional] If set to `1`, just do validation.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `paymentagent_transfer` (Number, **req**) — Must be `1`
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `transfer_to` (String, **req**) — The loginid of the recipient account.

#### `paymentagent_withdraw` [client] — JS method `paymentagentWithdraw`; auth: unknown from source
Initiate a withdrawal to an approved Payment Agent.
- `amount` (Number, **req**) — The amount to withdraw to the payment agent.
- `currency` (String, **req**) — The currency code.
- `description` (String, opt) — [Optional] Remarks about the withdraw. Only letters, numbers, space, period, comma, - ' are allowed.
- `dry_run` (Number, opt) — [Optional] If set to 1, just do validation.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `paymentagent_loginid` (String, **req**) — The payment agent loginid received from the `paymentagent_list` call.
- `paymentagent_withdraw` (Number, **req**) — Must be `1`
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `verification_code` (String, **req**) — Email verification code (received from a `verify_email` call, which must be done first)

#### `mt5_deposit` [client] — JS method `mt5Deposit`; auth: unknown from source
This call allows deposit into MT5 account from Binary account.
- `amount` (Number, opt) — Amount to deposit (in the currency of from_binary); min = $1 or an equivalent amount, max = $20000 or an equivalent amount
- `from_binary` (String, opt) — Binary account loginid to transfer money from
- `mt5_deposit` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `to_mt5` (String, **req**) — MT5 account login to deposit money to

#### `mt5_withdrawal` [client] — JS method `mt5Withdrawal`; auth: unknown from source
This call allows withdrawal from MT5 account to Binary account.
- `amount` (Number, **req**) — Amount to withdraw (in the currency of the MT5 account); min = $1 or an equivalent amount, max = $20000 or an equivalent amount.
- `from_mt5` (String, **req**) — MT5 account login to withdraw money from
- `mt5_withdrawal` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `to_binary` (String, **req**) — Binary account loginid to transfer money to

#### `transfer_between_accounts` [client] — JS method `transferBetweenAccounts`; auth: unknown from source
This call allows transfers between accounts held by a given user. Transfer funds between your fiat and cryptocurrency accounts (for a fee). Please note that account_from should be same as current authorized account.
- `account_from` (String, opt) — [Optional] The loginid of the account to transfer funds from.
- `account_to` (String, opt) — [Optional] The loginid of the account to transfer funds to.
- `accounts` (String, opt) — [Optional] To control the list of accounts returned when `account_from` or `account_to` is not provided. `brief` (default value) means that accounts with `mt5`
- `amount` (Number, opt) — [Optional] The amount to transfer.
- `currency` (String, opt) — [Optional] Currency code.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `transfer_between_accounts` (Number, **req**) — If `account_from` or `account_to` is not provided, it just returns the available accounts.

#### `get_available_accounts_to_transfer` [client] — JS method `getAvailableAccountsToTransfer`; auth: unknown from source
Get Available Accounts to Transfer.
- `get_available_accounts_to_transfer` (Number, **req**) — Must be `1`
- `loginid` (String, **req**) — The unique identifier for this trading/wallet account.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `wallet_exchange_rate` [REST schema] — endpoint: `GET /wallet/v1/exchange-rate`
Request a quote for converting between two currencies.
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
- `query` (object, **req**)
  - `source_currency` (string, **req**) — Currency to convert from.
  - `destination_currency` (string, **req**) — Currency to convert to.
- Response top-level keys: `data`

#### `wallet_list` [REST schema] — endpoint: `GET /wallet/v1/wallets`
Request to list the wallets belonging to the authenticated client, with balances in each wallet's native currency and an optional currency conversion.
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
- `query` (object, opt)
  - `conversion_currency` (string, opt) — 3-letter ISO currency code. When supplied, balance amounts are additionally returned converted to this currenc
  - `start_date_time` (['string', 'integer'], opt) — ISO 8601 timestamp or epoch seconds. Lower bound of the `balance as of` window.
  - `end_date_time` (['string', 'integer'], opt) — ISO 8601 timestamp or epoch seconds. Upper bound of the `balance as of` window.
- Response top-level keys: `data`

#### `wallet_transactions` [REST schema] — endpoint: `GET /wallet/v1/transactions/{wallet_type}`
Request a cursor-paginated list of transactions for one of the authenticated client's wallets, identified by wallet_type.
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
- `path` (object, **req**)
  - `wallet_type` (string, **req**) — Wallet type to return transactions for. Resolved server-side against the caller's client identity.
- `query` (object, opt)
  - `request_id` (string, opt) — Filter by the transaction's `request_id`.
  - `transaction_currency` (string, opt) — 3-letter ISO currency code. Restricts the response to transactions in this currency.
  - `start_date_time` (['string', 'integer'], opt) — ISO 8601 timestamp or epoch seconds. Lower bound of the transaction window.
  - `end_date_time` (['string', 'integer'], opt) — ISO 8601 timestamp or epoch seconds. Upper bound of the transaction window.
  - `per_page` (integer, opt) — Page size. Between 100 and 1000. Defaults to 100.
  - `page_cursor` (string, opt) — Opaque cursor returned in `links.next` / `links.prev`. When present, other filters are ignored — the cursor en
- Response top-level keys: `data, links`

#### `wallet_transfer` [REST schema] — endpoint: `POST /wallet/v1/transfers`
Same-currency transfer between two wallets owned by the authenticated client. The body is a strict whitelist - fields not listed here are rejected with 400.
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
  - `Content-Type` (string, **req**) — Content type
- `body` (object, **req**)
  - `currency` (string, **req**) — Currency of the transfer. Both wallets must hold a balance in this currency.
  - `amount` (string, **req**) — Transfer amount as a decimal string. Any applicable fee is deducted from this amount.
  - `source_wallet_id` (string, **req**) — Wallet to debit. Must belong to the authenticated client.
  - `destination_wallet_id` (string, **req**) — Wallet to credit. Must belong to the authenticated client.
  - `request_id` (string, **req**) — Idempotency key. Reusing a request_id you have already submitted does not create a duplicate transfer.
  - `description` (string, opt) — Optional free-text note attached to the transfer.
- Response top-level keys: `data`

#### `wallet_transfer_exchange` [REST schema] — endpoint: `POST /wallet/v1/transfers/exchange`
Cross-currency transfer between two wallets owned by the authenticated client. Quote the rate first with GET /wallet/v1/exchange-rate. The body is a strict whitelist - fields not listed here are rejected with 400.
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
  - `Content-Type` (string, **req**) — Content type
- `body` (object, **req**)
  - `source_wallet_id` (string, **req**) — Wallet to debit, in source_currency. Must belong to the authenticated client.
  - `source_currency` (string, **req**) — Currency debited from the source wallet.
  - `amount` (string, **req**) — Amount to convert, in source_currency, as a decimal string. Any applicable currency-exchange fee is deducted f
  - `destination_wallet_id` (string, **req**) — Wallet to credit, in destination_currency. Must belong to the authenticated client.
  - `destination_currency` (string, **req**) — Currency credited to the destination wallet.
  - `exchange_rate` (string, **req**) — Quoted exchange rate as a positive decimal string, taken from an exchange-rate quote obtained beforehand.
  - `rate_token` (string, **req**) — Token attesting to the quoted exchange rate, issued together with the quote.
  - `request_id` (string, **req**) — Idempotency key. Reusing a request_id you have already submitted does not create a duplicate transfer.
  - `description` (string, opt) — Optional free-text note attached to the transfer.
- Response top-level keys: `data`

#### `wallet_transfer_platforms` [REST schema] — endpoint: `POST /wallet/v1/transfers/platforms`
Transfer between a wallet and a trading platform account owned by the authenticated client. The body is a strict whitelist - fields not listed here are rejected with 400.
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
  - `Content-Type` (string, **req**) — Content type
- `body` (object, **req**) — Send wallet_currency, exchange_rate and rate_token together, or none of them. Supplying one without the other two is rejected with 400.
  - `wallet_id` (string, **req**) — Wallet on the wallet side of the transfer. Must belong to the authenticated client.
  - `amount` (string, **req**) — Transfer amount as a decimal string, in currency. Any applicable fee is deducted from this amount.
  - `currency` (string, **req**) — Currency of the platform account. Must match the account's actual currency.
  - `direction` (string, **req**) — from_wallet debits the wallet to fund the platform account; to_wallet debits the platform account to fund the
  - `platform_name` (string, **req**) — Trading platform of the account.
  - `platform_account_id` (string, **req**) — Login or account identifier on the platform. Must belong to the authenticated client and be a real account, no
  - `request_id` (string, **req**) — Idempotency key. Reusing a request_id you have already submitted is rejected with DuplicateRequestID.
  - `description` (string, opt) — Optional free-text note attached to the transfer.
  - `wallet_currency` (string, opt) — The wallet's currency. Send only for cross-currency platform transfers, when it differs from currency; exchang
  - `exchange_rate` (string, opt) — Quoted exchange rate as a positive decimal string. Required together with rate_token when wallet_currency diff
  - `rate_token` (string, opt) — Token attesting to the quoted exchange rate. Required together with exchange_rate when wallet_currency differs
- Response top-level keys: `data`

#### `wallet_transfer_validate` [REST schema] — endpoint: `POST /wallet/v1/transfers/validate`
Transfer to validate before executing it. The body is a strict whitelist - fields not listed here are rejected with 400.
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
  - `Content-Type` (string, **req**) — Content type
- `body` (object, **req**)
  - `source_type` (string, **req**) — Type of the source account.
  - `destination_type` (string, **req**) — Type of the destination account.
  - `source_id` (string, **req**) — Identifier of the source account: the wallet UUID, or the platform account ID such as MTR5312343 when source_t
  - `destination_id` (string, **req**) — Identifier of the destination account: the wallet UUID, or the platform account ID such as MTR5312343 when des
  - `amount` (string, **req**) — Transfer amount as a decimal string, zero or greater.
  - `balance` (string, **req**) — Current spendable balance of the source account, in source_currency. Same format as amount. Used to check the
  - `source_currency` (string, **req**) — Currency code of the source account.
  - `destination_currency` (string, **req**) — Currency code of the destination account.
  - `rate` (string, opt) — Exchange rate as a positive decimal string. Required when source_currency and destination_currency differ; omi
  - `source_platform_name` (string, opt) — Platform name. Send when source_type is platform.
  - `destination_platform_name` (string, opt) — Platform name. Send when destination_type is platform.
- Response top-level keys: `data`

#### `crypto_config` [client] — JS method `cryptoConfig`; auth: unknown from source
The request for cryptocurrencies configuration.
- `crypto_config` (Number, **req**) — Must be `1`
- `currency_code` (String, opt) — [Optional] Cryptocurrency code. Sending request with currency_code provides crypto config for the sent cryptocurrency code only.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

### 6. MT5 / trading platforms

#### `mt5_get_settings` [client] — JS method `mt5GetSettings`; auth: unknown from source
Get MT5 user account settings
- `login` (String, **req**) — MT5 user login
- `mt5_get_settings` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `mt5_login_list` [client] — JS method `mt5LoginList`; auth: unknown from source
Get list of MT5 accounts for client
- `mt5_login_list` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `mt5_new_account` [client] — JS method `mt5NewAccount`; auth: unknown from source
This call creates new MT5 user, either demo or real money user.
- `account_type` (String, **req**) — Account type. If set to 'financial', setting 'mt5_account_type' is also required.
- `address` (String, opt) — [Optional] The address of the user. The maximum length of this address field is 128 characters.
- `city` (String, opt) — [Optional] User's city of residence.
- `company` (String, opt) — [Optional] Name of the client's company. The maximum length of the company name is 64 characters.
- `country` (String, opt) — [Optional] 2-letter country code (value received from `residence_list` call).
- `currency` (String, opt) — [Optional] MT5 account currency, the default value will be the qualified account currency.
- `dry_run` (Number, opt) — [Optional] If set to 1, only validation is performed.
- `email` (String, **req**) — Email address
- `investPassword` (String, opt) — [Optional] The investor password of the account. For validation (Accepts any printable ASCII character. Must be within 8-25 characters, and include numbers, low
- `leverage` (Number, **req**) — Client leverage (from 1 to 1000).
- `mainPassword` (String, **req**) — The master password of the account. For validation (Accepts any printable ASCII character. Must be within 8-25 characters, and include numbers, lowercase and up
- `mt5_account_category` (String, opt) — [Optional] To choose whether account is conventional or not. Unavailable for financial_stp MT5_account_type
- `mt5_account_type` (String, opt) — [Optional] Financial: Variable spreads, High leverage. Financial STP: Variable spreads, Medium Leverage, more products. If 'account_type' set to 'financial', se
- `mt5_new_account` (Number, **req**) — Must be `1`
- `name` (String, **req**) — Client's name. The maximum length here is 101 characters.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `phone` (String, opt) — [Optional] User's phone number.
- `phonePassword` (String, opt) — [Optional] The user's phone password.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `server` (Any, opt) — [Optional] Trade server.
- `state` (String, opt) — [Optional] User's state (region) of residence.
- `zipCode` (String, opt) — [Optional] User's zip code.

#### `mt5_password_change` [client] — JS method `mt5PasswordChange`; auth: unknown from source
To change passwords of the MT5 account.
- `login` (String, **req**) — MT5 user login
- `mt5_password_change` (Number, **req**) — Must be `1`
- `new_password` (String, **req**) — New password of the account. For validation (Accepts any printable ASCII character. Must be within 8-25 characters, and include numbers, lowercase and uppercase
- `old_password` (String, **req**) — Old password for validation (non-empty string, accepts any printable ASCII character)
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `password_type` (String, opt) — [Optional] Type of the password to change.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `mt5_password_check` [client] — JS method `mt5PasswordCheck`; auth: unknown from source
This call validates the main password for the MT5 user
- `login` (String, **req**) — MT5 user login
- `mt5_password_check` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `password` (String, opt) — The password of the account.
- `password_type` (String, opt) — [Optional] Type of the password to check.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `mt5_password_reset` [client] — JS method `mt5PasswordReset`; auth: unknown from source
To reset the password of MT5 account.
- `login` (String, **req**) — MT5 user login
- `mt5_password_reset` (Number, **req**) — Must be `1`
- `new_password` (String, **req**) — New password of the account. For validation (Accepts any printable ASCII character. Must be within 8-25 characters, and include numbers, lowercase and uppercase
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `password_type` (String, opt) — [Optional] Type of the password to reset.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `verification_code` (String, **req**) — Email verification code (received from a `verify_email` call, which must be done first)

#### `trading_platform_accounts` [client] — JS method `tradingPlatformAccounts`; auth: unknown from source
Get list of Trading Platform accounts for client
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `platform` (String, opt) — Trading platform name
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `trading_platform_accounts` (Number, **req**) — Must be `1`

#### `trading_platform_deposit` [client] — JS method `tradingPlatformDeposit`; auth: unknown from source
Deposit funds from wallet account to trading platform account
- `amount` (Number, opt) — Amount to deposit (in the currency of from_wallet).
- `from_account` (String, opt) — Wallet account to transfer money from.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `platform` (String, opt) — Name of trading platform.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `to_account` (String, **req**) — Trading account login to deposit money to.
- `trading_platform_deposit` (Number, **req**) — Must be `1`

#### `trading_platform_investor_password_change` [client] — JS method `tradingPlatformInvestorPasswordChange`; auth: unknown from source
Change the Trading Platform investor password
- `account_id` (String, **req**) — Trading account ID.
- `new_password` (String, **req**) — New investor password. Accepts any printable ASCII character. Must be within 8-25 characters, and include numbers, lowercase and uppercase letters. Must not be
- `old_password` (String, **req**) — Old investor password for validation (non-empty string, accepts any printable ASCII character)
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `platform` (String, opt) — Name of trading platform.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `trading_platform_investor_password_change` (Number, **req**) — Must be `1`

#### `trading_platform_investor_password_reset` [client] — JS method `tradingPlatformInvestorPasswordReset`; auth: unknown from source
Reset the investor password of a Trading Platform Account
- `account_id` (String, **req**) — Trading account ID.
- `new_password` (String, **req**) — New password of the account. For validation (Accepts any printable ASCII character. Must be within 8-25 characters, and include numbers, lowercase and uppercase
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `platform` (String, opt) — Name of trading platform.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `trading_platform_investor_password_reset` (Number, **req**) — Must be `1`
- `verification_code` (String, **req**) — Email verification code (received from a `verify_email` call, which must be done first)

#### `trading_platform_new_account` [client] — JS method `tradingPlatformNewAccount`; auth: unknown from source
This call creates new Trading account, either demo or real money.
- `account_type` (String, **req**) — Account type.
- `currency` (String, opt) — [Optional] Trading account currency, the default value will be the qualified account currency.
- `dry_run` (Number, opt) — [Optional] If set to 1, only validation is performed.
- `market_type` (String, **req**) — Market type
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `password` (String, opt) — The master password of the account. For validation (Accepts any printable ASCII character. Must be within 8-25 characters, and include numbers, lowercase and up
- `platform` (String, **req**) — Name of trading platform.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `sub_account_type` (String, opt) — [Optional] Sub account type.
- `trading_platform_new_account` (Number, **req**) — Must be `1`

#### `trading_platform_password_change` [client] — JS method `tradingPlatformPasswordChange`; auth: unknown from source
Change the Trading Platform password
- `new_password` (String, **req**) — New trading password. Accepts any printable ASCII character. Must be within 8-25 characters, and include numbers, lowercase and uppercase letters. Must not be t
- `old_password` (String, opt) — Old password for validation. Must be empty if a password has not been set yet.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `platform` (String, opt) — Name of trading platform.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `trading_platform_password_change` (Number, **req**) — Must be `1`

#### `trading_platform_password_reset` [client] — JS method `tradingPlatformPasswordReset`; auth: unknown from source
Reset the password of a Trading Platform Account
- `new_password` (String, **req**) — New password of the account. For validation (Accepts any printable ASCII character. Must be within 8-25 characters, and include numbers, lowercase and uppercase
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `platform` (String, opt) — Name of trading platform.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `trading_platform_password_reset` (Number, **req**) — Must be `1`
- `verification_code` (String, **req**) — Email verification code (received from a `verify_email` call, which must be done first)

#### `trading_platform_withdrawal` [client] — JS method `tradingPlatformWithdrawal`; auth: unknown from source
This call allows withdrawal from Trading account to a wallet account.
- `amount` (Number, **req**) — Amount to withdraw (in the currency of the Trading account).
- `from_account` (String, **req**) — Trading account login to withdraw money from.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `platform` (String, opt) — Name of trading platform.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `to_account` (String, **req**) — Wallet account loginid to transfer money to.
- `trading_platform_withdrawal` (Number, **req**) — Must be `1`

### 7. Deriv P2P

#### `p2p_advert_create` [client] — JS method `p2pAdvertCreate`; auth: unknown from source
Creates a P2P (Peer to Peer) advert. Can only be used by an approved P2P advertiser.
- `amount` (Number, **req**) — The total amount of the advert, in advertiser's account currency.
- `contact_info` (String, opt) — [Optional] Advertiser contact information.
- `description` (String, opt) — [Optional] General information about the advert.
- `local_currency` (String, opt) — [Optional] Local currency for this advert. If not provided, will use the currency of client's residence by default.
- `max_order_amount` (Number, **req**) — Maximum allowed amount for the orders of this advert, in advertiser's `account_currency`. Should be more than or equal to `min_order_amount`
- `min_order_amount` (Number, **req**) — Minimum allowed amount for the orders of this advert, in advertiser's `account_currency`. Should be less than or equal to `max_order_amount`.
- `p2p_advert_create` (Number, **req**) — Must be 1
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `payment_info` (String, opt) — [Optional] Payment instructions.
- `payment_method` (String, opt) — [Optional] Payment method name (deprecated).
- `payment_method_ids` (Any, opt) — IDs of previously saved payment methods as returned from p2p_advertiser_payment_methods, only applicable for sell ads.
- `payment_method_names` (Any, opt) — Payment method identifiers as returned from p2p_payment_methods, only applicable for buy ads.
- `rate` (Number, opt) — Conversion rate from advertiser's account currency to `local_currency`. An absolute rate value (fixed), or percentage offset from current market rate (floating)
- `rate_type` (String, opt) — Type of rate, fixed or floating.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `type` (String, **req**) — The advertisement represents the intention to perform this action on your Deriv account funds.

#### `p2p_advert_info` [client] — JS method `p2pAdvertInfo`; auth: unknown from source
Retrieve information about a P2P advert.
- `id` (String, opt) — [Optional] The unique identifier for this advert. Optional when subscribe is 1. If not provided, all advertiser adverts will be subscribed.
- `p2p_advert_info` (Number, **req**) — Must be 1
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `subscribe` (Number, opt) — [Optional] If set to 1, will send updates when changes occur. Optional when id is provided.
- `use_client_limits` (Number, opt) — [Optional] If set to 1, the maximum order amount will be adjusted to the current balance and turnover limits of the account.

#### `p2p_advert_list` [client] — JS method `p2pAdvertList`; auth: unknown from source
Returns available adverts for use with `p2p_order_create` .
- `advertiser_id` (String, opt) — [Optional] ID of the advertiser to list adverts for.
- `advertiser_name` (String, opt) — [Optional] Search for advertiser by name. Partial matches will be returned.
- `amount` (Number, opt) — [Optional] How much to buy or sell, used to calculate prices.
- `counterparty_type` (String, opt) — [Optional] Filter the adverts by `counterparty_type`.
- `favourites_only` (Number, opt) — [Optional] Only show adverts from favourite advertisers. Default is 0.
- `limit` (Number, opt) — [Optional] Used for paging.
- `local_currency` (String, opt) — [Optional] Currency to conduct payment transaction in, defaults to the main currency for the client's country.
- `offset` (Number, opt) — [Optional] Used for paging.
- `p2p_advert_list` (Number, **req**) — Must be 1
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `payment_method` (Any, opt) — [Optional] Search by supported payment methods.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `sort_by` (String, opt) — [Optional] How the results are sorted.
- `use_client_limits` (Number, opt) — [Optional] If set to 1, ads that exceed this account's balance or turnover limits will not be shown.

#### `p2p_advert_update` [client] — JS method `p2pAdvertUpdate`; auth: unknown from source
Updates a P2P advert. Can only be used by the advertiser.
- `contact_info` (String, opt) — [Optional] Advertiser contact information.
- `delete` (Number, opt) — [Optional] If set to 1, permanently deletes the advert.
- `description` (String, opt) — [Optional] General information about the advert.
- `id` (String, **req**) — The unique identifier for this advert.
- `is_active` (Number, opt) — [Optional] Activate or deactivate the advert.
- `local_currency` (String, opt) — [Optional] Local currency for this advert.
- `max_order_amount` (Number, opt) — [Optional] Maximum allowed amount for the orders of this advert, in advertiser's `account_currency`. Should be more than or equal to `min_order_amount`.
- `min_order_amount` (Number, opt) — [Optional] Minimum allowed amount for the orders of this advert, in advertiser's `account_currency`. Should be less than or equal to `max_order_amount`.
- `p2p_advert_update` (Number, **req**) — Must be 1
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `payment_info` (String, opt) — [Optional] Payment instructions.
- `payment_method_ids` (Any, opt) — [Optional] IDs of previously saved payment methods as returned from p2p_advertiser_payment_methods, only applicable for sell ads. Exisiting methods will be repl
- `payment_method_names` (Any, opt) — [Optional] Payment method identifiers as returned from p2p_payment_methods, only applicable for buy ads. Exisiting methods will be replaced.
- `rate` (Number, opt) — [Optional] Conversion rate from advertiser's account currency to `local_currency`. An absolute rate value (fixed), or percentage offset from current market rate
- `rate_type` (String, opt) — [Optional] Type of rate, fixed or floating.
- `remaining_amount` (Number, opt) — [Optional] The total available amount of the advert, in advertiser's account currency.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `p2p_advertiser_adverts` [client] — JS method `p2pAdvertiserAdverts`; auth: unknown from source
Returns all P2P adverts created by the authorized client. Can only be used by a registered P2P advertiser.
- `limit` (Number, opt) — [Optional] Used for paging. This value will also apply to subsription responses.
- `offset` (Number, opt) — [Optional] Used for paging. This value will also apply to subsription responses.
- `p2p_advertiser_adverts` (Number, **req**) — Must be 1
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `p2p_advertiser_create` [client] — JS method `p2pAdvertiserCreate`; auth: unknown from source
Registers the client as a P2P advertiser.
- `contact_info` (String, opt) — [Optional] Advertiser's contact information, to be used as a default for new sell adverts.
- `default_advert_description` (String, opt) — [Optional] Default description that can be used every time an advert is created.
- `name` (String, **req**) — The advertiser's displayed name.
- `p2p_advertiser_create` (Number, **req**) — Must be 1
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `payment_info` (String, opt) — [Optional] Advertiser's payment information, to be used as a default for new sell adverts.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `subscribe` (Number, opt) — [Optional] If set to 1, will send updates whenever there is an update to advertiser

#### `p2p_advertiser_info` [client] — JS method `p2pAdvertiserInfo`; auth: unknown from source
Retrieve information about a P2P advertiser.
- `id` (String, opt) — [Optional] The unique identifier for this advertiser. If not provided, returns advertiser information about the current account.
- `p2p_advertiser_info` (Number, **req**) — Must be 1
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `subscribe` (Number, opt) — [Optional] If set to 1, will send updates whenever there is an update to advertiser

#### `p2p_advertiser_payment_methods` [client] — JS method `p2pAdvertiserPaymentMethods`; auth: unknown from source
Manage or list P2P advertiser payment methods.
- `create` (Any, opt) — Contains new payment method entries.
- `delete` (Any, opt) — Contains payment methods to delete.
- `p2p_advertiser_payment_methods` (Number, **req**) — Must be 1
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `update` (Any, opt) — Contains payment methods to update.

#### `p2p_advertiser_relations` [client] — JS method `p2pAdvertiserRelations`; auth: unknown from source
Updates and returns favourite and blocked advertisers of the current user.
- `add_blocked` (Any, opt) — IDs of advertisers to block.
- `add_favourites` (Any, opt) — IDs of advertisers to add as favourites.
- `p2p_advertiser_relations` (Number, **req**) — Must be 1
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `remove_blocked` (Any, opt) — IDs of advertisers to remove from blocked.
- `remove_favourites` (Any, opt) — IDs of advertisers to remove from favourites.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `p2p_advertiser_update` [client] — JS method `p2pAdvertiserUpdate`; auth: unknown from source
Update the information of the P2P advertiser for the current account. Can only be used by an approved P2P advertiser.
- `contact_info` (String, opt) — [Optional] Advertiser's contact information, to be used as a default for new sell adverts.
- `default_advert_description` (String, opt) — [Optional] Default description that can be used every time an advert is created.
- `is_listed` (Number, opt) — [Optional] Used to set if the advertiser's adverts could be listed. When `0`, adverts won't be listed regardless of they are active or not. This doesn't change
- `p2p_advertiser_update` (Number, **req**) — Must be 1
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `payment_info` (String, opt) — [Optional] Advertiser's payment information, to be used as a default for new sell adverts.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `show_name` (Number, opt) — [Optional] When `1`, the advertiser's real name will be displayed on to other users on adverts and orders.

#### `p2p_chat_create` [client] — JS method `p2pChatCreate`; auth: unknown from source
Creates a P2P chat for the specified order.
- `order_id` (String, **req**) — The unique identifier for the order to create the chat for.
- `p2p_chat_create` (Number, **req**) — Must be 1
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `p2p_order_cancel` [client] — JS method `p2pOrderCancel`; auth: unknown from source
Cancel a P2P order.
- `id` (String, **req**) — The unique identifier for this order.
- `p2p_order_cancel` (Number, **req**) — Must be 1
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `p2p_order_confirm` [client] — JS method `p2pOrderConfirm`; auth: unknown from source
Confirm a P2P order.
- `id` (String, **req**) — The unique identifier for this order.
- `p2p_order_confirm` (Number, **req**) — Must be 1
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `p2p_order_create` [client] — JS method `p2pOrderCreate`; auth: unknown from source
Creates a P2P order for the specified advert.
- `advert_id` (String, **req**) — The unique identifier for the advert to create an order against.
- `amount` (Number, **req**) — The amount of currency to be bought or sold.
- `contact_info` (String, opt) — [Optional] Seller contact information. Only applicable for 'sell orders'.
- `p2p_order_create` (Number, **req**) — Must be 1
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `payment_info` (String, opt) — [Optional] Payment instructions, only applicable for sell orders.
- `payment_method_ids` (Any, opt) — IDs of payment methods, only applicable for sell orders.
- `rate` (Number, opt) — [Optional] Conversion rate from account currency to local currency, only applicable for floating rate adverts.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `subscribe` (Number, opt) — [Optional] If set to 1, will send updates whenever there is an update to the order.

#### `p2p_order_dispute` [client] — JS method `p2pOrderDispute`; auth: unknown from source
Dispute a P2P order.
- `dispute_reason` (String, **req**) — The predefined dispute reason
- `id` (String, **req**) — The unique identifier for this order.
- `p2p_order_dispute` (Number, **req**) — Must be 1
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `p2p_order_info` [client] — JS method `p2pOrderInfo`; auth: unknown from source
Retrieves the information about a P2P order.
- `id` (String, **req**) — The unique identifier for the order.
- `p2p_order_info` (Number, **req**) — Must be 1
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `subscribe` (Number, opt) — [Optional] If set to 1, will send updates whenever there is an update to order

#### `p2p_order_list` [client] — JS method `p2pOrderList`; auth: unknown from source
List active orders.
- `active` (Number, opt) — [Optional] Should be 1 to list active, 0 to list inactive (historical).
- `advert_id` (String, opt) — [Optional] If present, lists orders applying to a specific advert.
- `limit` (Number, opt) — [Optional] Used for paging.
- `offset` (Number, opt) — [Optional] Used for paging.
- `p2p_order_list` (Number, **req**) — Must be 1
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `subscribe` (Number, opt) — [Optional] If set to 1, will send updates whenever there is a change to any order belonging to you.

#### `p2p_order_review` [client] — JS method `p2pOrderReview`; auth: unknown from source
Creates a review for the specified order.
- `order_id` (String, **req**) — The order identification number.
- `p2p_order_review` (Number, **req**) — Must be 1
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `rating` (Number, opt) — Rating for the transaction, 1 to 5.
- `recommended` (Any, opt) — [Optional] `1` if the counterparty is recommendable to others, otherwise `0`.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `p2p_payment_methods` [client] — JS method `p2pPaymentMethods`; auth: unknown from source
List all P2P payment methods.
- `p2p_payment_methods` (Number, **req**) — Must be 1
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `p2p_ping` [client] — JS method `p2pPing`; auth: unknown from source
Keeps the connection alive and updates the P2P advertiser's online status. The advertiser will be considered offline 60 seconds after a call is made.
- `p2p_ping` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

### 8. Apps, markup & affiliates

#### `app_delete` [client] — JS method `appDelete`; auth: unknown from source
The request for deleting an application.
- `app_delete` (Number, **req**) — Application app_id
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `app_get` [client] — JS method `appGet`; auth: unknown from source
To get the information of the OAuth application specified by 'app_id'
- `app_get` (Number, **req**) — Application app_id
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `app_list` [client] — JS method `appList`; auth: unknown from source
List all of the account's OAuth applications
- `app_list` (Number, **req**) — Must be `1`
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.

#### `app_markup_details` [client] — JS method `appMarkupDetails`; auth: unknown from source
Retrieve details of `app_markup` according to criteria specified.
- `app_id` (Number, opt) — [Optional] Specific application `app_id` to report on.
- `app_markup_details` (Number, **req**) — Must be `1`
- `client_loginid` (String, opt) — [Optional] Specific client loginid to report on, like CR12345
- `date_from` (String, **req**) — Start date (epoch or YYYY-MM-DD HH:MM:SS). Results are inclusive of this time.
- `date_to` (String, **req**) — End date (epoch or YYYY-MM-DD HH::MM::SS). Results are inclusive of this time.
- `description` (Number, opt) — [Optional] If set to 1, will return `app_markup` transaction details.
- `limit` (Number, opt) — [Optional] Apply upper limit to count of transactions received.
- `offset` (Number, opt) — [Optional] Number of transactions to skip.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `sort` (String, opt) — [Optional] Sort direction on `transaction_time`. Other fields sort order is ASC.
- `sort_fields` (Any, opt) — [Optional] One or more of the specified fields to sort on. Default sort field is by `transaction_time`.

#### `app_register` [client] — JS method `appRegister`; auth: unknown from source
Register a new OAuth application
- `app_markup_percentage` (Number, opt) — [Optional] Markup to be added to contract prices (as a percentage of contract payout).
- `app_register` (Number, **req**) — Must be `1`
- `appstore` (String, opt) — [Optional] Application's App Store URL (if applicable).
- `github` (String, opt) — [Optional] Application's GitHub page (for open-source projects).
- `googleplay` (String, opt) — [Optional] Application's Google Play URL (if applicable).
- `homepage` (String, opt) — [Optional] Application's homepage URL.
- `name` (String, **req**) — Application name.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `redirect_uri` (String, opt) — [Optional] The URL to redirect to after a successful login. Required if charging markup percentage
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `scopes` (Any, **req**) — List of permission scopes to grant the application.
- `verification_uri` (String, opt) — [Optional] Used when `verify_email` called. If available, a URL containing the verification token will be sent to the client's email, otherwise only the token w

#### `app_update` [client] — JS method `appUpdate`; auth: unknown from source
Update a new OAuth application
- `app_markup_percentage` (Number, opt) — [Optional] Markup to be added to contract prices (as a percentage of contract payout).
- `app_update` (Number, **req**) — Application app_id.
- `appstore` (String, opt) — [Optional] Application's App Store URL (if applicable).
- `github` (String, opt) — [Optional] Application's GitHub page (for open-source projects).
- `googleplay` (String, opt) — [Optional] Application's Google Play URL (if applicable).
- `homepage` (String, opt) — [Optional] Application's homepage URL.
- `name` (String, **req**) — Application name.
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `redirect_uri` (String, opt) — [Optional] The URL to redirect to after a successful login. Required if charging markup percentage.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `scopes` (Any, **req**) — Change scopes will revoke all user's grants and log them out.
- `verification_uri` (String, opt) — [Optional] Used when `verify_email` called. If available, a URL containing the verification token will send to the client's email, otherwise only the token will

#### `affiliate_account_add` [client] — JS method `affiliateAccountAdd`; auth: unknown from source
Register a new affiliate
- `address_city` (String, **req**) — City name within 50 characters.
- `address_line_1` (String, **req**) — Within 70 characters, with no leading whitespaces and may contain letters/numbers and/or any of following characters '.,:;()@#/-
- `address_line_2` (String, opt) — [Optional] Within 70 characters.
- `address_postcode` (String, **req**) — Within 20 characters and may not contain '+'.
- `address_state` (String, **req**) — Possible value receive from `states_list` call.
- `affiliate_account_add` (Number, **req**) — [Required] Must be `1`
- `country` (String, **req**) — Country of legal citizenship, 2-letter country code.
- `first_name` (String, **req**) — The official first name of the affiliate. Within 2-50 characters, use only letters, spaces, hyphens, full-stops or apostrophes.
- `last_name` (String, **req**) — The official last name of the affiliate. Within 2-50 characters, use only letters, spaces, hyphens, full-stops or apostrophes.
- `non_pep_declaration` (Number, **req**) — Indicates client's self-declaration of not being a PEP/RCA (Politically Exposed Person/Relatives and Close Associates).
- `passthrough` (Any, opt) — [Optional] Used to pass data through the websocket, which may be retrieved via the `echo_req` output field.
- `password` (String, opt) — Password for the affiliate account. (Accepts any printable ASCII character. Must be between 6-50 characters, and include numbers, lowercase and uppercase letter
- `phone` (String, **req**) — Registered phone number of the affiliate. Starting with `+` followed by 8-35 digits, allowing hyphens or space.
- `req_id` (Number, opt) — [Optional] Used to map request to response.
- `tnc_accepted` (Number, **req**) — Indicates client has agreed to the terms and conditions.
- `username` (String, **req**) — Desired username for the affiliate account. Within 2-50 characters, use only letters, spaces, hyphens, full-stops or apostrophes.

#### `partners_analytics_overview` [REST schema] — endpoint: `GET /partners/analytics/v1/overview`
Request the authenticated partner's sign-up, master-partner, and activity summaries for an inclusive reporting period.
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
- `query` (object, **req**)
  - `start_date` (string, **req**) — Inclusive start of the reporting period. The period may span at most 730 days.
  - `end_date` (string, **req**) — Inclusive end of the reporting period. Must fall on or after start_date, and no more than 730 days later.
- Response top-level keys: `period, currency, has_lifetime_referred_client, signups, master_partner, activity`

#### `partners_client_tags_check` [REST schema] — endpoint: `POST /partners/client-tags/check`
Check whether the supplied client IDs are tagged directly to the authenticated partner.
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
  - `Content-Type` (string, **req**) — Content type
- `body` (object, **req**)
  - `client_ids` (array, **req**) — Client IDs to check. Numeric, UUID, and alphanumeric external ID values are supported.
- Response top-level keys: `partner_id, total_checked, tagged_count, clients`

### 9. Connection / WS-URL endpoints (REST)

#### `websocket` [REST schema] — endpoint: `POST /trading/v1/options/accounts/{accountId}/otp`
Request to obtain an OTP-authenticated WebSocket URL for Options trading
- `headers` (object, **req**)
  - `Deriv-App-ID` (string, **req**) — Application identifier. Required for Personal Access Token (PAT) authentication; not required for OAuth Bearer
  - `Authorization` (string, **req**) — Bearer token for authentication
- `path` (object, **req**)
  - `accountId` (string, **req**) — Options Trading account ID that the OTP is requested for
- Response top-level keys: `data, meta`

#### `ws_demo` [REST schema] — endpoint: `GET /trading/v1/options/ws/demo`
Request to upgrade the connection to a WebSocket scoped to a demo Options Trading account.
- `query` (object, **req**)
  - `otp` (string, **req**) — One-time password generated by POST /trading/v1/options/accounts/{accountId}/otp
- Response top-level keys: `status, headers`

#### `ws_public` [REST schema] — endpoint: `GET /trading/v1/options/ws/public`
Request to upgrade the connection to a WebSocket streaming public market data. No authentication, OTP, or query parameters are required.
- *(no fields in source)*
- Response top-level keys: `status, headers`

#### `ws_real` [REST schema] — endpoint: `GET /trading/v1/options/ws/real`
Request to upgrade the connection to a WebSocket scoped to a real-money Options Trading account.
- `query` (object, **req**)
  - `otp` (string, **req**) — One-time password generated by POST /trading/v1/options/accounts/{accountId}/otp
- Response top-level keys: `status, headers`

## 4. Inferred UI mappings (INFERRED — from the Phase 3 surface map, NOT verified live)

Source UI observations: `~/workspace/deriv-h1/phase3-surface-map-2026-11-14.md` (2026-11-14 08:50–08:57 WIB, read-only browser navigation; no network capture, no crafted requests). Each mapping below is the author's inference about which catalog calls a flow *plausibly* uses. Do not treat any mapping as observed traffic.

| UI flow observed (Phase 3) | Plausibly used calls (INFERRED) | Notes |
|---|---|---|
| Traders Hub dashboard — account list, demo balances ($10,000 Options + $10,000 CFDs Standard) | `balance` (subscribe), `get_accounts`, `website_status`, `landing_company` | Balances update live in the UI, consistent with a `balance` subscription; account list shape matches `get_accounts`. |
| DTrader trade ticket — Volatility 100 (1s), Rise/Fall, 5 ticks, $2 stake | `active_symbols`, `contracts_for`, `proposal`, `proposal_open_contract` (subscribe), `buy`, `ticks` (subscribe), `ticks_history`, `trading_times`, `payout_currencies` | The classic quote-then-buy flow: `proposal` returns a price + id, `buy` consumes the id (or `parameters`). `proposal` needs no auth per schema; `buy` needs auth + `trade` scope. |
| DBot builder — default strategy, 'Bot is not running' | `proposal`, `buy`, `sell`, `ticks`, `proposal_open_contract`, `balance`, possibly `auto_*` | The `auto_*` calls (start/stop/pause/resume/list/strategies) plausibly back Deriv Bot automation, but their exact role is undocumented in the schemas — INFERRED only. |
| SmartTrader — same ticket shape as DTrader | Same as DTrader | Different frontend, same API surface. |
| Cashier (view only) — Deposit/Withdrawal (USD, Crypto, P2P, Payment agent), gated by profile completion | `cashier`, `cashier_payments`, `payment_methods`, `crypto_config`, `wallet_list`, `wallet_transfer*`, `payment_agent_list`, `get_limits`, `get_account_status`, `verify_email` | `cashier` takes `cashier` (operation), `provider`, `type`, `amount`, `address`, `verification_code` (email code from `verify_email` first). Withdrawal verification-code step is DOCUMENTED in the `cashier` JSDoc. |
| Deriv P2P — buy ads list (IDR), wallet $0.00 | `p2p_advert_list`, `p2p_advertiser_info`, `p2p_payment_methods`, `p2p_ping` | Order placement would use `p2p_order_create` / `p2p_order_confirm` / `p2p_order_cancel` / `p2p_order_dispute` / `p2p_chat_create` — none exercised. |
| API token page — 'Create your first API token', scopes section, no tokens exist | `api_token`, `oauth_apps`, `app_list`, `app_register`, `service_token` | `api_token` manages tokens (`new_token`, `new_token_scopes`, `delete_token`, `valid_for_current_ip_only`). |
| Profile / security — personal details (blank), phone not added, 2FA not enabled | `get_settings`, `set_settings`, `get_account_status`, `change_password`, `change_email`, `account_security` (TOTP/otp), `login_history`, `residence_list`, `states_list`, `landing_company`, `document_upload`, `identity_verification_document_add`, `get_financial_assessment`, `set_financial_assessment`, `get_self_exclusion`, `set_self_exclusion`, `tnc_approval` | 2FA setup plausibly uses `account_security` (`otp`, `totp_action` per docs). |
| CFDs page — MT5 Standard account; uncreated options (TradingView, cTrader, Swap-Free, Zero Spread, Financial, Financial STP, Gold) | `mt5_login_list`, `mt5_get_settings`, `trading_platform_accounts`, `trading_platform_product_listing`, `trading_servers`, `mt5_deposit`, `mt5_withdrawal`, `trading_platform_deposit`, `trading_platform_withdrawal`, `mt5_new_account`, `trading_platform_new_account` | cTrader/Deriv X account creation would go through `trading_platform_new_account` variants; no Deriv X option was visible in the UI. |

## 5. Gaps — what cannot be known without live verification

1. **Auth gating for the 109 client-only calls.** The client documents no `auth_required`/scope metadata. Which calls work unauthenticated, which need `authorize`, and which scopes each needs, can only be settled live (or from Deriv API docs pages, which were out of scope for this passive pass).
2. **Which connection path the Deriv web UIs actually use** — classic `wss://ws.derivws.com/websockets/v3` + `authorize`, or the newer OTP-scoped WS URLs (`/ws/demo|real`), or both (different apps). No network capture was taken (that would be live observation, not this task).
3. **Error taxonomy.** Neither repo documents error codes/messages (e.g. `error.code` values, `InvalidToken`, rate-limit errors). The client only surfaces `response.error` opaquely.
4. **Rate limits / throttling.** Undocumented in both repos (see §1). Unknown: per-connection message rates, per-app_id quotas, subscription caps, `ticks` stream cadence.
5. **Subscription semantics.** Which calls accept `subscribe`, update cadence, `forget`/`forget_all` exact behavior, and `proposal_open_contract` parent/child subscription quirks (the client code comments hint at special handling) are only partially documented.
6. **`auto_*` calls.** Present in schemas with `trade` scope (except `auto_list_strategies`, public) but no semantic documentation of what 'auto' strategies are or how they relate to DBot. INFERRED link to bot automation only.
7. **Deprecation drift.** The client (May 2026) still documents binary.com-era calls (`copytrading_*`, `buy_contract_for_multiple_accounts`, binary.com token URL). Some may be dead on the live server; the schemas repo (Nov 2026) omitting them is weak evidence either way. `legacy_*` REST endpoints exist for migrated accounts.
8. **Demo-vs-real behavior.** Beyond separate endpoints, no documented differences (validation strictness, available symbols, limits). `get_limits` / `trading_times` / `contracts_for` responses may differ per account type — unverified.
9. **P2P/cashier parameter validation.** Field lists are documented, but server-side validation, idempotency, and state-machine rules (order lifecycle, dispute windows) are not in these repos.
10. **KYC/identity flows.** `document_upload` / `identity_verification_document_add` field lists exist in the client, but upload mechanics (chunking, file types, verification states via `get_account_status`) are not documented here.

## 6. What a future separately-authorized live-verification pass would need

This section is a requirements list only — **no live work was done or is authorized by this document.** Any live pass needs its own explicit user authorization naming the phase, targets, and call classes, per RECON-PLAN.md §3–§4, plus the standing program rules (header `X-HackerOne-Research: mosul` on every testing request, own demo accounts only, no destructive testing, no value movement without a per-action order). Phase 2 (fingerprint/WAF/probing) stays HALTED and is not part of any such pass.

- **API token creation (user step):** a token must exist before `authorize` can be exercised — Phase 3 confirmed none exist. Token scope choice matters (read-only vs `trade`); creation is a settings change on the user's own demo account and needs the user's go-ahead. Prefer the narrowest scope that answers the question (e.g. read-only for catalog verification; `trade` scope only if buy/sell flows are in scope).
- **Header wrapper use:** the existing `bin/h1curl` wrapper injects the research header for HTTP. Websocket handshakes from a browser cannot carry custom headers — a scripted WS client (Node/Python) would be needed to attach the header to the HTTP upgrade request. Whether the WS upgrade accepts/ignores extra headers is itself unverified.
- **Demo-only calls, in this order:** (1) public calls first (`ping`, `time`, `website_status`, `active_symbols`, `ticks` subscribe + `forget`) — no auth, no state; (2) `authorize` with the demo token, then read-only authorized calls (`balance`, `statement`, `portfolio`, `get_settings`, `get_limits`, `proposal_open_contract`); (3) `proposal` (public quote) and — only with a separate per-action order — `buy`/`sell` on the demo account with minimum stake, and `cashier` read paths only (deposit/withdraw actions need their own per-action orders and the profile-completion gate blocks them on this account anyway).
- **Evidence standard:** record exact request/response pairs (redact tokens), timestamps UTC, account used, and the catalog entry each observation confirms or contradicts; update this catalog's INFERRED mappings to VERIFIED only where traffic was actually observed.
- **Stop conditions:** any 429/block, any unexpected auth behavior, any surface that looks internal-only (backoffice/vault/admin) — stop and ask, do not force. No subdomain claiming, no dumps, no enumeration beyond existence, no other users' data.

---
*Generated 2026-11-14 from local clones only. No Deriv asset was contacted. Cross-references: `~/workspace/deriv-h1/RECON-PLAN.md`, `~/workspace/deriv-h1/phase3-surface-map-2026-11-14.md`.*
