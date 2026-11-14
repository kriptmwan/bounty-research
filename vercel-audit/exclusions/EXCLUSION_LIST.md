# better-auth — Public-Advisory Exclusion List (Dedup Reference)

- **Target:** `better-auth/better-auth`, pinned HEAD `0a014aef61c83a293da224b5d926a0e43253b732`
  (commit 2026-11-12), package version **1.7.22** (`packages/better-auth/package.json`,
  `packages/core/package.json` — both `1.7.22` at this HEAD).
- **Scope of this list:** the strict core library **plus** all in-package plugins and
  `@better-auth/*` scoped packages. Several "plugin" advisories live in shared core code
  (origin check, session handling, account linking), and the core-vs-plugin bounty
  boundary is UNVERIFIED (see `../SCOPE.md` §3.3) — so nothing was dropped for being
  plugin-scoped. The Referee/gate decides scope; this list decides *known vs new*.
- **Built:** 2026-11-13 (WIB) by the DEDUP agent. Read-only; no live testing; no submissions.
- **GitHub API: NEVER used** (shared-IP rate limit, per task constraint).

## Verdict rule

- **EXCLUDED** — the vulnerability is already known AND its fix version is below the
  audited version (1.7.22), i.e. the fix is in the audited code by version ordering.
  Do not re-report the same flaw. A *variant* that bypasses the fix is a different
  finding, but the Referee must check it against the entry here first.
- **OPEN/UNKNOWN** — fixed status could not be established from the allowed sources.
  Flag for Hunter/Referee; do not assume fixed or unfixed.

Fix-version comparison is the verdict basis. The local checkout is a **shallow clone
(`--depth 1`, single commit)**, so fix-commit ancestry against HEAD could NOT be
verified from git history (see Gaps). No advisory below was verified by reading
patched code — that is the Hunter's job for any variant claim.

## Counts

- **Advisories checked: 48** (all with a GHSA identifier).
- **EXCLUDED: 48. OPEN/UNKNOWN (advisories): 0.**
- **Unverified third-party mention (not an advisory): 1** — GitHub issue #6863,
  recorded separately below as OPEN/UNKNOWN.
- Sources: OSV API package queries (22 npm packages, paged) returned 34 unique GHSA
  records; 2 more GHSAs were verified via their OSV CVE records (GHSA-ID lookup 404);
  12 November-2026 advisories were verified via the in-repo release post plus direct
  reads of all 12 GitHub advisory pages (1 of the 12 also has an OSV CVE record).
  In-repo June-2026 post covers 14 advisories, all 14 independently present in OSV.

## Source key

- `[OSV-GHSA]` — OSV API `GET /v1/vulns/{GHSA}` full record (SEMVER affected ranges,
  aliases, details). Raw JSON kept under `../evidence/osv-better-auth-2026-11-13/`.
- `[OSV-CVE]` — OSV API `GET /v1/vulns/{CVE}` record (GIT range + extracted version
  range); the GHSA ID is listed as an alias. Used where the GHSA-ID lookup 404s.
- `[ADV]` — GitHub advisory page read with `browser.open` (page text, no API).
  URL pattern: `https://github.com/better-auth/better-auth/security/advisories/{GHSA}`.
- `[BLOG-NOV]` — in-repo `docs/content/blogs/security-release-2026-11-03.mdx`.
- `[BLOG-JUN]` — in-repo `docs/content/blogs/security-update-june-2026.mdx`.
- `[CL]` — in-repo CHANGELOG corroboration (file:line in the Notes column).

## Exclusion table

| # | Advisory | CVE | Title | Component / file area | Affected range | Fixed in | Verdict | Verified via |
|---|---|---|---|---|---|---|---|---|
| 1 | GHSA-8jhw-6pjj-8723 | CVE-2024-56734 | Open redirect in verify-email endpoint | Core: email verification redirect (`/verify-email`) | `better-auth` 0 – 1.1.6 | 1.1.6 | EXCLUDED | [OSV-GHSA] |
| 2 | GHSA-9x4v-xfq5-m8x5 | CVE-2025-71404 | URL parameter HTML injection (reflected XSS) on error page | Core: `packages/better-auth/src/api/routes/error.ts`, `/api/auth/error` (`error` param reflected as HTML) | `better-auth` 0.0.2 – 1.1.16 | 1.1.16 | EXCLUDED | [OSV-GHSA] |
| 3 | GHSA-hjpm-7mrm-26w8 | CVE-2025-27143 | Open redirect via scheme-less callback parameter | Core: `callbackURL` validation (any endpoint accepting callback URL); `//evil.com` allowed | `better-auth` 0 – 1.1.20 | 1.1.20 | EXCLUDED | [OSV-GHSA] |
| 4 | GHSA-vp58-j275-797x | CVE-2025-71403 | trustedOrigins protection bypass leading to ATO | Core: `trustedOrigins` validation (absolute URLs + wildcard patterns); callbackURL open redirect, token leakage | `better-auth` 0 – 1.1.21 | 1.1.21 | EXCLUDED | [OSV-GHSA] |
| 5 | GHSA-36rg-gfq2-3h56 | CVE-2025-53535 | Open redirect in originCheck middleware, multiple routes | Core: `originCheck` middleware, `matchesPattern` (`startsWith` deception); `/verify-email`, `/reset-password/:token`, `/delete-user/callback`, `/magic-link/verify`, `/oauth-proxy-callback` | `better-auth` 0 – 1.2.10 | 1.2.10 | EXCLUDED | [OSV-GHSA] |
| 6 | GHSA-99h5-pjcv-gr6v | CVE-2025-61928 | Unauthenticated API key creation through api-key plugin | Plugin (in-package): api-key create/update endpoints; authenticated-user derivation fallback treated attacker input as user object | `better-auth` 0 – 1.3.26 | 1.3.26 | EXCLUDED | [OSV-GHSA] |
| 7 | GHSA-wmjr-v86c-m9jj | CVE-2025-71402 | Multi-session sign-out hook: forged cookies revoke arbitrary sessions | Plugin: multi-session `/sign-out` after-hook; raw `_multi-*` cookies forwarded to `internalAdapter.deleteSessions` without signature check (`getSignedCookie`) | `better-auth` 1.3.34 – 1.4.0 | 1.4.0 | EXCLUDED | [OSV-GHSA] |
| 8 | GHSA-4vcf-q4xf-f48m | CVE-2025-71400 | Passkey plugin allows passkey deletion through IDOR | Scoped package `@better-auth/passkey`: `POST /passkey/delete-passkey`; `ctx.body.id` trusted in deletion query | `@better-auth/passkey` 0 – 1.4.0 | 1.4.0 | EXCLUDED | [OSV-GHSA] |
| 9 | GHSA-569q-mpph-wgww | CVE-2025-71401 | External request basePath modification DoS | Core: `baseURL` taken from first request when unconfigured; router base-path poisoning → all routes 404 | `better-auth` 0 – 1.4.2 | 1.4.2 | EXCLUDED | [OSV-GHSA] |
| 10 | GHSA-x732-6j76-qmhm | CVE-2025-71399 | rou3 double-slash path normalization bypasses disabledPaths and rate limits | Core routing dependency (better-call/rou3): `/path` vs `//path` treated identically | `better-auth` 0 – 1.4.5 | 1.4.5 | EXCLUDED | [OSV-GHSA] |
| 11 | GHSA-xg6x-h9c9-2m83 | CVE-2026-67337 | Two-factor authentication bypass via premature session caching (`session.cookieCache`) | Core session + two-factor plugin: session considered valid before 2FA completed when `cookieCache` enabled | `better-auth` 0 – 1.4.9 | 1.4.9 | EXCLUDED | [OSV-GHSA] |
| 12 | GHSA-p6v2-xcpg-h6xw | CVE-2026-45364 | Rate limiter keys IPv6 addresses individually, bypassable via prefix rotation | Core: rate limiting, leftmost `X-Forwarded-For` keying | `better-auth` 0 – 1.4.17; 1.5.0-beta.1 – 1.5.0-beta.9 | 1.4.17 / 1.5.0-beta.9 | EXCLUDED | [OSV-GHSA] |
| 13 | GHSA-wxw3-q3m9-c3jr | CVE-2026-67335 | OAuth callback accepts mismatched `state` with cookie-backed state storage without PKCE | Core OAuth: `account.storeStateStrategy: "cookie"` + `genericOAuth` with `pkce: false` (or custom `getToken`/`tokenUrl`); `/oauth2/callback/:id` | `better-auth` 0 – 1.6.2 | 1.6.2 | EXCLUDED | [OSV-GHSA], [CL] `packages/better-auth/CHANGELOG.md:2396` (PR #8949 state-vs-cookie-nonce check) |
| 14 | GHSA-xr8f-h2gw-9xh6 | CVE-2026-41427 | OAuth 2.1 Provider: unprivileged users can register OAuth clients | Scoped package `@better-auth/oauth-provider`: `clientPrivileges` not gating `/oauth2/create-client`, `/admin/oauth2/create-client` | `@better-auth/oauth-provider` 1.4.8-beta.7 – 1.6.5; 1.7.0-beta.0 – 1.7.0-beta.1 (last_affected, no fixed event — see Notes) | 1.6.5 (stable) | EXCLUDED | [OSV-GHSA], [BLOG-JUN] L52 |
| 15 | GHSA-2vg6-77g8-24mp | CVE-2026-67334 | Stale sessions persist after user deletion across admin, anonymous, and SCIM flows | Core session + admin/anonymous/SCIM plugins; `secondaryStorage` + `storeSessionInDatabase: false`; `/delete-user`, `/delete-anonymous-user` | `better-auth` 0.3.4 – 1.6.11; `@better-auth/scim` 1.6.0 – 1.6.11 | 1.6.11 | EXCLUDED | [OSV-GHSA], [BLOG-JUN] L34 |
| 16 | GHSA-g38m-r43w-p2q7 | CVE-2026-53516 | Account takeover via OAuth auto-link to unverified pre-registered email | Core OAuth account linking: implicit linking, `/sign-up/email`, `/link-social`; email+password + OAuth/SSO, `disableImplicitLinking` unset | `better-auth` 0 – 1.6.11 | 1.6.11 | EXCLUDED | [OSV-GHSA], [BLOG-JUN] L33 |
| 17 | GHSA-fmh4-wcc4-5jm3 | CVE-2026-53514 | Unauthorized invitation acceptance via unverified email match in organization plugin | Plugin: organization invitations; email-string equality without verified ownership; `requireEmailVerificationOnInvitation` unset | `better-auth` 0 – 1.6.11 | 1.6.11 (compat. follow-up 1.6.14 per [BLOG-JUN]) | EXCLUDED | [OSV-GHSA], [BLOG-JUN] L40 |
| 18 | GHSA-cq3f-vc6p-68fh | CVE-2026-45337 | Device authorization approve/deny accept any authenticated session while user code pending | Plugin: `deviceAuthorization()`; owner binding missing on approve/deny | `better-auth` 1.6.0 – 1.6.11 | 1.6.11 | EXCLUDED | [OSV-GHSA], [BLOG-JUN] L46 |
| 19 | GHSA-7w99-5wm4-3g79 | CVE-2026-53518 | OAuth authorization-code grant allows concurrent redemption (find-then-delete race) | `@better-auth/oauth-provider` + embedded/legacy `oidc-provider`, `mcp` plugins; `/oauth2/token`, `/mcp/token` | `@better-auth/oauth-provider` 1.6.0 – 1.6.11; `better-auth` 0 – 1.6.11 | 1.6.11 | EXCLUDED | [OSV-GHSA], [BLOG-JUN] L53 |
| 20 | GHSA-392p-2q2v-4372 | CVE-2026-53517 | OAuth refresh-token rotation forks token family on concurrent redemption | `@better-auth/oauth-provider` + embedded plugin; `offline_access` refresh tokens | `@better-auth/oauth-provider` 1.6.0 – 1.6.11; `better-auth` 1.4.8-beta.7 – 1.6.0 | 1.6.11 / 1.6.0 | EXCLUDED | [OSV-GHSA], [BLOG-JUN] L54 |
| 21 | GHSA-pw9m-5jxm-xr6h | CVE-2026-53512 | OAuth refresh-token replay via missing client authentication on oidc-provider and mcp plugins | Plugins: legacy `oidcProvider()`, `mcp()`; `refresh_token` grant accepted refresh-token row + public `client_id` without `client_secret`; `/oauth2/token`, `/mcp/token` | `better-auth` 0 – 1.6.11 | 1.6.11 | EXCLUDED | [OSV-GHSA], [BLOG-JUN] L76 |
| 22 | GHSA-9h47-pqcx-hjr4 | CVE-2026-67336 | Insecure cryptographic defaults in oidcProvider: alg=none advertised, plain PKCE accepted by default | Plugins: `oidcProvider()`, `mcp()` (delegates to oidcProvider); JWT alg negotiation + PKCE defaults | `better-auth` 0 – 1.6.11 | 1.6.11 | EXCLUDED | [OSV-GHSA], [BLOG-JUN] L78 |
| 23 | GHSA-5rr4-8452-hf4v | CVE-2026-53513 | SSO provider registration SSRF via unvalidated OIDC endpoints | Scoped package `@better-auth/sso`: provider registration OIDC endpoint URL validation | `@better-auth/sso` 0.1.0 – 1.6.11 | 1.6.11 | EXCLUDED | [OSV-GHSA], [BLOG-JUN] L67 |
| 24 | GHSA-gv74-j8m3-fg5f | CVE-2026-53515 | SSO provider registration allowed for any org member without role check | Scoped package `@better-auth/sso` + organization plugin; `providersLimit` default 10 | `@better-auth/sso` 1.2.10 – 1.6.11 | 1.6.11 | EXCLUDED | [OSV-GHSA], [BLOG-JUN] L68 |
| 25 | GHSA-86j7-9j95-vpqj | CVE-2026-67333 | Stored XSS in auth-server origin via `javascript:` redirect_uri in oidc-provider and mcp | Plugins: `oidc-provider`, `mcp`; client registration accepted `javascript:` `redirect_uri`, later navigated to in consent UI | `better-auth` 0 – 1.6.13; 1.7.0-beta.0 – 1.7.0-beta.4 | 1.6.13 / 1.7.0-beta.4 | EXCLUDED | [OSV-GHSA], [BLOG-JUN] L77 |
| 26 | GHSA-prpr-5gj3-qqhg | CVE-2026-67328 | Four SSO flaws let an attacker sign in as another user | Scoped package `@better-auth/sso`: (1) domain-verification parser mismatch, (2) deleted provider leaves linked accounts (providerId reuse), (3) SAML assertion not bound to SP (no Audience/Recipient/Destination check), (4) SAML SLO auto-submit form `javascript:`/`data:` action XSS | `@better-auth/sso` 0 – 1.6.20; 1.7.0-beta.0 – 1.7.0-beta.9 | 1.6.21 / 1.7.0-beta.10 | EXCLUDED | [OSV-CVE] CVE-2026-67328, [ADV], [CL] `packages/sso/CHANGELOG.md:511` (1.6.21, PRs #10224–10226) |
| 27 | GHSA-h3rm-78g3-j7cp | CVE-2026-67329 | Cross-organization billing tampering in organization subscription actions | Scoped package `@better-auth/stripe`: subscription actions with `subscription.enabled` | `@better-auth/stripe` 1.4.11 – 1.6.21; 1.7.0-beta.0 – 1.7.0-beta.10 | 1.6.21 / 1.7.0-beta.10 | EXCLUDED | [OSV-GHSA] |
| 28 | GHSA-rjg6-39jm-rgg4 | CVE-2026-67330 | Account takeover and stale access via SCIM provider-id collision | Scoped package `@better-auth/scim`: SCIM token generation, provider IDs colliding with other accounts' providers; default `canGenerateToken` policy | `@better-auth/scim` 1.4.0-beta.27 – 1.6.22; 1.7.0-beta.0 – 1.7.0-beta.10 | 1.6.22 / 1.7.0-beta.10 | EXCLUDED | [OSV-GHSA] |
| 29 | GHSA-qq9h-g4jm-xgf3 | CVE-2026-67327 | Account takeover via pre-account hijacking on magic-link and email-OTP sign-in | Plugins: magic-link, email-OTP + email/password open registration; attacker keeps password access after victim starts using the account | `better-auth` 1.1.3 – 1.6.22; 1.7.0-beta.0 – 1.7.0-beta.10 | 1.6.22 / 1.7.0-beta.10 | EXCLUDED | [OSV-GHSA] |
| 30 | GHSA-p2fr-6hmx-4528 | CVE-2026-67332 | oauth-provider may provide access tokens for unauthorized audiences via unbound resource indicators | Scoped package `@better-auth/oauth-provider`: RFC 8707 `resource` indicators not bound to grant; `validAudiences` with multiple audiences | `@better-auth/oauth-provider` 1.4.8 – 1.7.0-beta.4 (stable 1.6.x NOT patched — see Notes) | 1.7.0-beta.4 | EXCLUDED | [OSV-GHSA], [BLOG-JUN] L55 |
| 31 | GHSA-j8v8-g9cx-5qf4 | CVE-2026-67331 | SCIM account/provider takeover via missing owner binding on non-org SCIM providers | Scoped package `@better-auth/scim`: providers without `organizationId` (personal providers) | `@better-auth/scim` 1.5.0 – 1.7.0-beta.4 | 1.7.0-beta.4 | EXCLUDED | [OSV-GHSA], [BLOG-JUN] L61 |
| 32 | GHSA-q84f-53jg-9ppm | CVE-2026-109346 | Device login approval does not show the requesting client or permissions | Plugin: `deviceAuthorization()`; approval page lacked server-checked client/permissions (RFC 8628 phishing); `/device/code`, `/device/token` | `better-auth` 1.3.8-beta.3 – 1.7.0-rc.3 (includes all 1.6.x; no 1.6 release contains the fix) | 1.7.0-rc.3 | EXCLUDED | [OSV-GHSA] |
| 33 | GHSA-mx9r-x6ww-qjw9 | CVE-2026-110863 | Personal SSO providers can sign in as another provider's users | Scoped package `@better-auth/sso`: linked-account lookup by issuer + account identifier only, ignoring `providerId`; attacker registers personal provider copying a real OIDC issuer/SAML entity ID | `@better-auth/sso` 1.7.0-rc.2 – 1.7.0-rc.6 and 1.7.0 – 1.7.2 | 1.7.3 | EXCLUDED | [OSV-CVE] CVE-2026-110863, [ADV], [CL] `packages/sso/CHANGELOG.md:81` (1.7.3, PR #11153 `(providerId, accountId)` lookup) |
| 34 | GHSA-965c-763c-88jm | CVE-2026-110862, CVE-2026-114607 | OAuth state can be used as a Magic Link to sign in as another user | Core OAuth state + magic-link plugin: OAuth sign-in `state` value accepted as magic-link token; `storeToken: "plain"` (or hashed + hashed `storeIdentifier`); social/generic OAuth | `better-auth` 1.4.0-beta.18 – 1.7.7 | 1.7.7 | EXCLUDED | [OSV-GHSA] |
| 35 | GHSA-r4xp-prcw-77qf | CVE-2026-110864 | OAuth Proxy lets an attacker sign in as another user | Plugin: OAuth Proxy; forged encrypted profiles when proxy has no dedicated `secret` or shares the global secret; cookie state storage (`storeStateStrategy: "cookie"`) | `better-auth` 1.5.0-beta.12 – 1.7.7 | 1.7.7 | EXCLUDED | [OSV-GHSA] |
| 36 | GHSA-44jh-23m7-hpcf | CVE-2026-110861 | Concurrent requests can exceed rate limits on PostgreSQL | Adapters `@better-auth/drizzle-adapter`, `@better-auth/kysely-adapter` (+ `better-auth`): DB-backed rate-limit check not atomic on PostgreSQL | drizzle 1.6.17 – 1.7.7; kysely 1.6.17 – 1.7.0; `better-auth` 1.6.17 – 1.7.7 | 1.7.7 / 1.7.0 | EXCLUDED | [OSV-GHSA] |
| 37 | GHSA-4wq4-2ppv-q3hg | CVE-2026-121802 | Authorization proxy can sign values it did not issue | Scoped package `@better-auth/expo` + core trusted-origins: `/expo-authorization-proxy` signed caller-supplied `state` with the app secret (HMAC-SHA256 = HS256/cookie-cache signature); same endpoint open-redirect; wildcard `trustedOrigins` matching outside scheme/host/path | `@better-auth/expo` 1.4.0-beta.6 – 1.7.16; beta 1.8.0-beta.0 – 1.8.0-beta.5 | 1.7.16 / 1.8.0-beta.5 | EXCLUDED | [ADV], [BLOG-NOV] L33, [OSV-CVE] CVE-2026-121802, [CL] `packages/expo/CHANGELOG.md:27` (1.7.16) |
| 38 | GHSA-q747-mqgr-4gh7 | None found in this pass | Phone numbers can be claimed before they are verified | Plugin: phone-number + shared OTP code storage; sign-up/sign-in saved unverified numbers, phone sign-in matched by number alone; phone codes shared namespace with other flows | `better-auth` phone-number plugin 0.4.12-beta.7+; shared-code problem 1.2.6-beta.8+ (no custom `verifyOTP`) | 1.7.16 / 1.8.0-beta.5 (see Notes — beta line has one extra hardening) | EXCLUDED | [ADV], [BLOG-NOV] L41, [CL] `packages/better-auth/CHANGELOG.md:173` (1.7.16, PR #12198) |
| 39 | GHSA-9p5w-h4pr-fcrc | None found in this pass | Desktop sign-in can return the server secret and skip two-factor | Scoped package `@better-auth/electron`: signed transfer cookie accepted under wrong name (signature covers value, not name); after-hook returned whole endpoint context incl. auth secret + social client secrets; desktop code created before 2FA when `electron()` precedes `twoFactor()` | `@better-auth/electron` 1.5.0-beta.12 – 1.7.16; beta 1.8.0-beta.0 – 1.8.0-beta.5 | 1.7.16 / 1.8.0-beta.5 | EXCLUDED | [ADV], [BLOG-NOV] L47 |
| 40 | GHSA-hwq2-v29r-p69r | None found in this pass | Email-change links stay valid after the address changes hands | Core: email verification/change-email links carried old+new addresses but not the requesting user ID; opening a link acted on whoever then owned the old address and created a session | `better-auth` 1.4.0 – 1.7.16 (needs `user.changeEmail.enabled` + `sendVerificationEmail`); beta 1.8.0-beta.0 – 1.8.0-beta.5 | 1.7.16 / 1.8.0-beta.5 | EXCLUDED | [ADV], [BLOG-NOV] L55, [CL] `packages/better-auth/CHANGELOG.md:173` (1.7.16) |
| 41 | GHSA-9hm7-xhfp-cx58 | None found in this pass | OAuth sign-in can treat an unverified provider email as verified | Core OAuth linking: truthiness test on `emailVerified` (string `"false"` passed); generic OAuth profile-vs-ID-token `sub` mismatch; direct ID-token sign-in loading profile from submitted access token; Zoom provider ignoring options | `better-auth` 0.4.9 – 1.7.16; beta 1.8.0-beta.0 – 1.8.0-beta.5 | 1.7.16 / 1.8.0-beta.5 | EXCLUDED | [ADV], [BLOG-NOV] L58, [CL] `packages/better-auth/CHANGELOG.md:173` (1.7.16) |
| 42 | GHSA-48c2-w96j-mv3m | None found in this pass | MySQL serial IDs can return another request's record | Adapters `@better-auth/kysely-adapter` (default) / `@better-auth/drizzle-adapter` (pooled): insert then separate `LAST_INSERT_ID()` query on a pooled connection; `generateId: "serial"`, MySQL/MariaDB | (no introduced version stated on advisory page; condition-gated) – 1.7.16; beta – 1.8.0-beta.5 | 1.7.16 / 1.8.0-beta.5 | EXCLUDED | [ADV], [BLOG-NOV] L61 |
| 43 | GHSA-fvxx-76fc-893x | None found in this pass | Revoked sessions can stay valid with secondary storage or the cookie cache | Core session: secondary-storage session-list read/write race drops tokens from bulk revocation; cookie-cached revoked sessions accepted to create passkeys/stored sessions (passkey registration, device auth, 2FA enrollment/verification, social linking, phone changes) | `secondaryStorage` from 0.8.1-beta.5; cookie-cache path from 1.6.25 – 1.7.16; beta – 1.8.0-beta.5 | 1.7.16 / 1.8.0-beta.5 (see Notes — API-key-session behavior differs by line) | EXCLUDED | [ADV], [BLOG-NOV] L64, [CL] `packages/better-auth/CHANGELOG.md:173` (1.7.16) |
| 44 | GHSA-2f9c-7xj7-gh55 | None found in this pass | Email OTP attempt limit can be raced and codes are loosely bound to addresses | Plugin: `emailOTP()`; attempt counter read/write race; change-email codes keyed by address pair (collisions across accounts); accent-insensitive collation returns wrong account on email lookup, reset code sent to requested address | `emailOTP()` 1.3.7+; change-email codes from 1.5.0 – 1.7.16; beta – 1.8.0-beta.5 | 1.7.16 / 1.8.0-beta.5 | EXCLUDED | [ADV], [BLOG-NOV] L70, [CL] `packages/better-auth/CHANGELOG.md:173` (1.7.16) |
| 45 | GHSA-g95c-wqvr-8c3j | None found in this pass | Admin roles with user:update can change another user's phone number | Plugin: admin `/admin/update-user`; `user:set-email` checked for email but phone fields passed with only `user:update`; new `user:set-phone` permission added | admin + phone-number plugins (no introduced version stated) – 1.7.16; beta – 1.8.0-beta.5 | 1.7.16 / 1.8.0-beta.5 | EXCLUDED | [ADV], [BLOG-NOV] L76, [CL] `packages/better-auth/CHANGELOG.md:173` (1.7.16) |
| 46 | GHSA-c85h-5mrr-mgx4 | None found in this pass | Organization admins can invite an owner with a padded role name | Plugin: organization invitations; creator-role check compared raw role string while later checks split/trimmed (`" owner"` → `owner`) | organization plugin 1.5.5 – 1.7.16; beta – 1.8.0-beta.5 | 1.7.16 / 1.8.0-beta.5 | EXCLUDED | [ADV], [BLOG-NOV] L82, [CL] `packages/better-auth/CHANGELOG.md:173` (1.7.16) |
| 47 | GHSA-x8j7-xh58-rv6x | None found in this pass | Billing actions can target another customer's Stripe account | Scoped package `@better-auth/stripe`: `stripeCustomerId` accepted from sign-up/profile-update requests (no `input: false`); billing portal/checkout/webhooks then treated that customer as the user's | `@better-auth/stripe` 1.2.0-beta.18 – 1.7.16; beta – 1.8.0-beta.5 | 1.7.16 / 1.8.0-beta.5 | EXCLUDED | [ADV], [BLOG-NOV] L88 |
| 48 | GHSA-gv75-j3v8-3crm | None found in this pass | Passkey verification does not enforce origin or user verification | Scoped package `@better-auth/passkey` (and built-in passkey plugin pre-1.4.0): expected WebAuthn origin taken from request, not config; `userVerification: "required"` not confirmed on authentication | `@better-auth/passkey` 1.4.0-beta.16+; built-in plugin before 1.4.0 – 1.7.16; beta – 1.8.0-beta.5 | 1.7.16 / 1.8.0-beta.5 | EXCLUDED | [ADV], [BLOG-NOV] L96 |

## Notes on specific entries (Referee must read before clearing a variant)

1. **GHSA-xr8f-h2gw-9xh6 (#14):** the OSV record's second range (`1.7.0-beta.0`,
   `last_affected: 1.7.0-beta.1`) carries no `fixed` event. The stable fix (1.6.5) and
   the June post's fixed path are established; HEAD is stable 1.7.22, far past the
   beta.1 bound. EXCLUDED on that basis; if a candidate re-tests client-registration
   privilege checks, verify against 1.7.22 code, not against the OSV range gap.
2. **GHSA-p2fr-6hmx-4528 (#30) / GHSA-j8v8-g9cx-5qf4 (#31):** fixed ONLY on the 1.7
   pre-release line (1.7.0-beta.4); the stable 1.6.x line was never patched for
   p2fr (advisory says so). 1.7.22 is on the 1.7 stable line, which descends from
   1.7.0-beta.4, so the fixes are in. Do not treat "1.6.x unpatched" as "1.7.22
   affected".
3. **GHSA-q747-mqgr-4gh7 (#38):** the advisory states 1.8.0-beta.5 *additionally*
   requires proof of account ownership before a pending (pre-upgrade) number is
   verified; 1.7.16 stops *new* unverified numbers and requires manual clearing of
   pre-upgrade numbers (workaround SQL in the advisory). Whether 1.7.17–1.7.22
   backported the beta.5 extra was NOT checked in this pass. A candidate about
   pre-upgrade unverified numbers on the 1.7.x line needs a changelog/code check
   for 1.7.17–1.7.22 before being treated as new — flag, don't assume.
4. **GHSA-fvxx-76fc-893x (#43):** on 1.7.16, sessions created from API keys are
   refused on the hardened routes *except* two-factor enrollment and phone-number
   changes; on 1.8.0-beta.5 they are refused on all of them. Whether 1.7.17–1.7.22
   backported the stricter beta behavior was NOT checked. Same handling as #3 for
   any API-key-session candidate on those two routes.
5. **GHSA-965c-763c-88jm (#34):** carries TWO CVE aliases (CVE-2026-110862 and
   CVE-2026-114607) in its OSV record. Both refer to this one advisory; do not
   double-count.
6. **GHSA-44jh-23m7-hpcf (#36):** one advisory, three packages, two fix versions
   (drizzle 1.7.7, kysely 1.7.0, better-auth 1.7.7). All are below 1.7.22.
7. **GHSA-4wq4-2ppv-q3hg (#37):** the fix does not invalidate pre-fix signatures —
   the advisory requires secret rotation after upgrade. That is a deployment
   hygiene note, not a live code flaw at HEAD.
8. **November batch CVE IDs:** only GHSA-4wq4-2ppv-q3hg had a CVE ID surface in this
   pass (CVE-2026-121802, confirmed in OSV). The other 11 November advisories show
   "None found in this pass" — meaning no CVE was found via OSV or web search on
   2026-11-13, NOT that no CVE exists. Do not invent CVE mappings for them.
9. **Severity labels** were not uniformly recorded: the June/November posts give
   Critical/High/Medium/Low per advisory; OSV records carry CVSS vectors. Severity
   is not part of the exclusion verdict and is omitted from the table to avoid
   mixing two rating sources. See the advisory/OSV record for the rating.

## In-repo known-issue / intended-behavior statements

These are documented behaviors that LOOK like bugs. A candidate finding that merely
re-states one of these is not new. File paths are relative to the repo root
(`/home/hatch/workspace/vercel-audit/repos/better-auth`); line numbers are from the
pinned HEAD.

### Security policy scope

- `SECURITY.md:29-32` — "We only support the latest version of Better Auth. Older
  versions are not supported." Version-gated behavior on old lines is not a finding.
- `SECURITY.md:3-27` — private reporting via GitHub Security Advisories or
  `security@better-auth.com`; 72-hour response; patch-then-disclose; 90-day
  disclosure fallback. (Process, not a vulnerability statement.)
- No `.github/SECURITY.md` exists in this repo; the root `SECURITY.md` is the only
  policy file (checked 2026-11-13).

### Threat model / out-of-scope statements (`.oss-scanner/threat_model.md`)

- L8-12 — Trust boundaries: "Every request is untrusted, including OAuth callbacks,
  SAML responses, and webhooks. The application's configuration and server-side code
  are trusted. Organization admins and the identity providers they register are not
  trusted like the application operator."
- L20 — Out of scope for the scanner workstream: `docs/`, `demo/`, `e2e/`, `test/`,
  `packages/test-utils`, `packages/release-tooling`, test files. (Note: this is the
  repo's own scanner scope, NOT the HackerOne scope — the Vercel program scope
  governs bounty eligibility; see `../SCOPE.md`.)
- L47-57 — "Anything to leave alone": (a) usage docs describe as invalid, e.g.
  calling `auth.api` without request headers; (b) findings that need a protection
  turned off (`disableCSRFCheck`, `disableOriginCheck`); (c) missing authorization
  checks in *application* code around `auth.api` calls; (d) reproductions that write
  sessions/roles/accounts directly to the DB instead of going through endpoints;
  (e) hardcoded secrets in tests, and the `DEFAULT_SECRET` fallback outside
  production when no secret is set.
- L44-45 — "Findings that need a non-default setting are rated lower, not excluded.
  Denial of service is low." (Rating guidance, not exclusion.)

### Documented security behaviors (`docs/content/docs/reference/security.mdx`)

- L42 — Some routes *intentionally* accept `application/x-www-form-urlencoded`
  (simple requests) for progressive enhancement / protocol interop (sign-in/sign-up
  email flows, some callback/token endpoints), relying on origin validation, Fetch
  Metadata checks, and protocol state/nonce validation instead. Form-acceptance
  alone is not a CSRF finding.
- L47 — `Origin: null` (e.g. `Referrer-Policy: no-referrer` same-origin form) is
  accepted ONLY when `Sec-Fetch-Site` confirms same-origin, falling back to
  validating the request URL's origin against `trustedOrigins`.
- L63 — Requests carrying NEITHER Fetch Metadata headers NOR `Origin`/`Referer`
  fall back to permissive behavior (non-browser clients). Only first-login
  (no-cookie) sign-in/sign-up routes use this fallback path.
- L74-75 — CSRF/origin checks run ONLY for requests reaching `auth.handler`. A
  direct `auth.api` call skips them (including `trustedOrigins` checks on
  `callbackURL`, `errorCallbackURL`, `newUserCallbackURL`, `redirectTo`) even with
  browser headers passed. Application routes calling `auth.api` must validate
  themselves. An `auth.api`-only bypass is documented application responsibility,
  not a library flaw — unless the bypass is reachable through `auth.handler`.
- L91-141 — `disableCSRFCheck` disables CSRF protection only; `disableOriginCheck`
  disables URL validation AND CSRF protection (backward compat, L133). Findings
  requiring either flag are out (see threat-model leave-alone list above).
- L143-147 — OAuth state/PKCE: default stores state payload in verification storage
  + state value in a signed cookie; `storeStateStrategy: "cookie"` encrypts the
  full payload into a short-lived cookie instead. Both are supported designs.
- L165-172 — Client IP defaults to `X-Forwarded-For`, which "Clients can set
  themselves." Per-client rate limits only work with a proxy that overwrites/appends
  correctly + `trustedProxies`. Spoofed `X-Forwarded-For` without that setup is
  documented misconfiguration, not a library flaw.
- L174-196 — `trustedProxyHeaders: true` derives baseURL from `X-Forwarded-Host` /
  `X-Forwarded-Proto` when no static `baseURL`/env is set. Documented warning:
  enable only if the proxy is trusted and end users cannot set these headers.
  Header-forged baseURL under this opt-in flag is documented risk, not a finding.
- L209 — Relative callback/redirect URLs must begin with a single `/`; Better Auth
  rejects protocol-relative URLs, backslashes, control characters, and encoded path
  separators. (Current intended validation — compare against GHSA-36rg/hjpm/vp58
  fixes when testing variants.)
- L292 — Outbound OAuth/OIDC requests (token exchange/refresh, introspection, JWKS)
  do NOT follow HTTP redirects, so a provider endpoint cannot steer a server-side
  request to an internal address. SSRF-via-redirect on these paths is already
  mitigated by design.
- L296 — Email enumeration protection applies on sign-up/change-email ONLY when
  `requireEmailVerification` is enabled or `autoSignIn` is `false` (same `200`
  either way + simulated password hashing). Enumeration outside those settings is
  documented conditional behavior.

### Other documented intended behaviors

- `docs/content/docs/concepts/session-management.mdx:240` — "When `cookieCache` is
  enabled, revoked sessions may remain active on other devices until the cookie
  cache expires (`maxAge`)." Plain cache-delayed revocation is documented and
  intended; GHSA-fvxx-76fc-893x (#43) covers only the *escalation* paths (creating
  lasting credentials/sessions from a cached revoked session). See also the fvxx
  advisory: "a revoked session keeps working until the cache `maxAge` ends, which
  is documented."
- `docs/content/docs/plugins/sso/saml-security.mdx:68` — With the default
  `requireTimestamps: false`, "Better Auth accepts an assertion with neither
  condition [`NotBefore`/`NotOnOrAfter`] and logs a warning." Missing-timestamp
  acceptance under the default is documented; the fix is the documented opt-in
  (`requireTimestamps: true`).
- GHSA-gv75-j3v8-3crm advisory ([ADV]) — "The default `"preferred"` setting allows
  responses without this [user-verification] check by design." Only
  `userVerification: "required"` being unenforced was the flaw (#48).
- GHSA-9hm7-xhfp-cx58 advisory ([ADV]) — "You are not affected for providers listed
  in `account.accountLinking.trustedProviders`, where linking by email is
  intended." Email-linking for explicitly trusted providers is intended behavior.
- In-repo `.postmortem/` files (4: client-side import, Cloudflare `createRequire`,
  RSC header detection, TanStack Start server-core) are engineering postmortems,
  NOT security advisories. No security content was taken from them.

## Other-repo CVEs (NOT better-auth — recorded only because independently verified)

Per task instruction, these are included ONLY because each was independently
verified in this pass against the sibling repo's own changelog. They belong to
other repos; do not confuse them with better-auth advisories.

| CVE | Repo / area | Verification in this pass |
|---|---|---|
| CVE-2023-29008 (GHSA-gv7g-x59x-wf8f) | sveltejs/kit — CSRF header-value check, case-insensitive comparison | `repos/sveltejs-kit/packages/kit/CHANGELOG.md:5363` — "fix: address security advisory CVE-2023-29008 … case-insensitive comparison when checking header value" |
| CVE-2023-29003 (GHSA-5p75-vc5g-8rv2) | sveltejs/kit — CSRF: `text/plain` + PUT/PATCH/DELETE in blocked cross-origin set | `repos/sveltejs-kit/packages/kit/CHANGELOG.md:5371` — "fix: address security advisory CVE-2023-29003 … including `text/plain` and `PUT`/`PATCH`/`DELETE` requests in set of blocked cross-origin requests" |
| CVE-2024-12905 / CVE-2025-48387 | vercel/vercel CLI — tar link-following path traversal in `vercel init` example archives | `repos/vercel-vercel/packages/cli/CHANGELOG.md:3307` — "`vercel init` no longer materializes symlink or hardlink entries from downloaded example archives (blocking tar link-following path traversal, CVE-2024-12905 / CVE-2025-48387, and upgrading `tar-fs` to 1.16.5)" |

## Unverified third-party mention — OPEN/UNKNOWN (not an advisory)

| ID | Claim | Why it is recorded | Verdict |
|---|---|---|---|
| GitHub issue better-auth/better-auth#6863 (no GHSA/CVE found) | Stripe `hasEverTrialed` bypass: `findOne` returns whichever subscription the DB returns first; if it is a new incomplete subscription, `hasEverTrialed` returns false and the user can trial again. Mentioned (Dec 2025) in third-party pentest-skill files that cite the GitHub issue. | It is the ONLY better-auth-specific "disclosed" item surfaced by the HackerOne/disclosure web searches that is not already an advisory above. No advisory, no CVE, no fix version, and no first-party confirmation were found in this pass. The underlying code/fix status was NOT checked (dedup scope is advisories, and the issue itself was not read — GitHub API is banned and the issue page was not opened). | **OPEN/UNKNOWN** — flag for Hunter/Referee. Do NOT treat as a known vulnerability and do NOT treat as fixed. If the Hunter finds the same behavior live at HEAD, it still needs the normal finding workflow (repro + variant check against #47/#27 Stripe advisories). |

## Deliberately NOT listed (to prevent confusion)

- **Auth.js advisories (July 2026 post):** the in-repo
  `docs/content/blogs/security-update-july-2026.mdx` covers FOUR advisories for
  **Auth.js/NextAuth** (`@auth/core`, `next-auth` v4/v5) — GHSA-7rqj-j65f-68wh,
  GHSA-xmf8-cvqr-rfgj, GHSA-x445-f3h2-j279, GHSA-8fpg-xm3f-6cx3 — fixed in
  `@auth/core@0.41.3` / `next-auth@4.24.15` / `next-auth@5.0.0-beta.32`. These are
  a DIFFERENT project maintained by the same team. They are not better-auth
  vulnerabilities and are excluded from the table. (The OAuth check-cookie
  advisory GHSA-x445-f3h2-j279 is thematically adjacent to better-auth OAuth
  state handling — a Hunter variant claim must still prove itself in better-auth
  code; the Auth.js fix does not exclude a better-auth finding.)
- **Dependency-bump CVE mentions:** the `better-auth` CHANGELOG contains a
  `drizzle-orm`/`kysely` peer-range note "track[ing] the minor line that carries
  the vulnerability fix" (CHANGELOG.md:2003, 2325, duplicated across release
  lines). No CVE ID is named; it is an ORM dependency matter, not a better-auth
  advisory. Not listed.
- **HackerOne disclosed reports:** web searches for `"better-auth" HackerOne
  disclosed reports` returned NO HackerOne-disclosed better-auth report. The
  Vercel program page mirror confirms better-auth is in scope for "core library
  issues" but lists no disclosed reports. Absence from search results is NOT
  proof no undisclosed/duplicate reports exist (see Gaps).

## Gaps — sources that could NOT be checked, and why

1. **GitHub API (api.github.com) — NOT USED, by constraint.** The GitHub Advisory
   Database listing endpoint and the repo's advisory list API were never queried.
   Mitigation: all 48 GHSAs were verified through OSV and/or direct advisory-page
   reads; but an advisory that exists ONLY in the GitHub Advisory Database (never
   mirrored to OSV, never blogged, never indexed by search) would be missed.
   Residual risk: LOW but nonzero. The gate should re-check the advisory tab
   before filing.
2. **OSV GHSA-ID 404s (13 IDs):** `GET /v1/vulns/{GHSA}` returned HTTP 404 for all
   12 November-2026 GHSAs and for GHSA-mx9r-x6ww-qjw9 (OSV ingestion lag — a
   third-party analysis noted the same 404s in October 2026 for the September
   batch; 3 of those 4 have since appeared in OSV). Mitigation: all 13 were
   verified via direct advisory-page reads; 2 additionally via OSV CVE records
   (CVE-2026-121802, CVE-2026-110863). Affected ranges for the 12 November
   advisories therefore come from advisory prose, not OSV SEMVER ranges.
3. **OSV package-query shape:** OSV `v1/query` by package name returns only
   records with SEMVER package ranges. CVE-sourced records with GIT-only ranges
   (no `package` field) do NOT appear in package queries — this is exactly how
   GHSA-mx9r-x6ww-qjw9 and GHSA-prpr-5gj3-qqhg were initially missed and only
   found via web search + CVE-record fetch. Other GIT-only better-auth CVE
   records could exist that neither the package queries nor the web searches
   surfaced. Residual risk: LOW-MEDIUM. Mitigation applied: CVE-number
   continuity checks on the known runs (CVE-2026-53512–53518 complete;
   CVE-2026-67327–67337 complete with 67328 found; CVE-2026-110861–110864
   complete) found no further gaps in those runs.
4. **HackerOne (Vercel program) disclosed reports — NOT directly checked.** No
   HackerOne login/API access was available or used; only public web search was
   run, which found no disclosed better-auth reports. Undisclosed reports and
   reports filed but not yet triaged are invisible to this pass by design.
   A duplicate-of-an-existing-report rejection remains possible for any filing.
5. **NVD / CVE.org — NOT directly queried.** CVE details were taken from OSV
   records (which mirror NVD/CVE data) and third-party mirrors (Tenable,
   radar.offseq, Aikido). No NVD API calls were made. CVE↔GHSA mappings stated
   here are exactly the `aliases` fields of the OSV records fetched, plus the
   two CVE→GHSA alias links in the CVE records.
6. **Shallow clone — fix-commit ancestry unverified.** The checkout has 1 commit;
   whether each advisory's fix commit is an ancestor of HEAD could not be checked
   in git. Verdicts rest on released-version ordering (fix version < 1.7.22 and
   HEAD carries version 1.7.22). If HEAD were somehow a pre-release branch
   missing a fix, the verdict would be wrong — but package version + changelog
   top entry (1.7.22) + commit date (2026-11-12, after the 1.7.16 security
   release) all corroborate the ordering.
7. **CHANGELOG gap:** `packages/better-auth/CHANGELOG.md` (and the `core`, `sso`,
   `oauth-provider`, `scim` changelogs checked) contain NO `## 1.6.11` or
   `## 1.6.12` sections — headings jump from 1.6.13 to 1.6.10. The June-batch fix
   version 1.6.11 therefore could NOT be changelog-corroborated; it rests on OSV
   ranges + the June post. (The 1.7.16 security release IS changelog-corroborated:
   `packages/better-auth/CHANGELOG.md:173`, PR #12198.)
8. **Third-party mirror inconsistency (noted, not relied on):** one advisory
   mirror (Patchwire) showed a garbled range for GHSA-gv75-j3v8-3crm mixing it
   with the older passkey fix (1.4.0); press coverage of the November batch
   variously reported "3 advisories" vs the actual 12. Where a third-party source
   conflicted with the maintainer advisory/blog, the maintainer source governed
   and the third-party claim was discarded.
9. **`.github/SECURITY.md` absent; no in-repo `advisories/` directory.** Checked:
   `.github/` listing, repo root, `docs/content/blogs/`, all 22 package
   CHANGELOGs (security grep on `better-auth` + `core` full; others via the
   targeted 1.6.11/1.6.12/1.7.16/1.7.3/1.6.21 heading checks). A full line-by-line
   read of all 22 changelogs was NOT done — only security-keyword greps and the
   version sections named above. A security fix described without security
   keywords in an unscanned changelog section could exist; it would still be
   covered if it has a GHSA (OSV/advisory checks above), but a fix with NO
   advisory would be missed. Residual risk: LOW.
10. **Post-cutoff advisories:** this list is current as of the checks run on
    2026-11-13 ~11:30 UTC (OSV queries, advisory-page reads, web searches).
    Advisories published after that moment are not covered. Re-run the OSV
    package query + advisory-tab check before filing.

## Method summary (for audit trail)

1. Verified pin: `git rev-parse HEAD` = `0a014aef…` (matches task); versions
   `1.7.22` in `packages/better-auth/package.json` and `packages/core/package.json`.
2. Read: `SECURITY.md`, `docs/content/docs/reference/security.mdx`,
   `docs/content/blogs/security-release-2026-11-03.mdx`,
   `docs/content/blogs/security-update-june-2026.mdx`,
   `docs/content/blogs/security-update-july-2026.mdx` (Auth.js — excluded, see
   above), `.oss-scanner/threat_model.md`, `.postmortem/` titles,
   `docs/content/docs/plugins/sso/saml-security.mdx` (grep).
3. Grepped: `packages/better-auth/CHANGELOG.md` + `packages/core/CHANGELOG.md`
   for security/CVE/GHSA/advisory/vulnerability; confirmed `.github/SECURITY.md`
   absent; read the 1.7.16 changelog section; confirmed 1.6.11/1.6.12 headings
   absent.
4. OSV API (`https://api.osv.dev/v1/query`, POST, paged): 22 npm packages —
   `better-auth` (26), `@better-auth/core` (0), `oauth-provider` (4), `scim` (3),
   `sso` (2), `expo` (0), `electron` (0), `passkey` (1), `stripe` (1),
   `kysely-adapter` (1), `drizzle-adapter` (1), `mcp` (0), `cimd` (0),
   `api-key` (0), `cli` (0), `i18n` (0), `memory-adapter` (0),
   `mongo-adapter` (0), `prisma-adapter` (0), `redis-storage` (0),
   `telemetry` (0), `test-utils` (0) → union 34. Full records fetched via
   `GET /v1/vulns/{id}` for all 34 + direct fetches for 12 November GHSAs (all
   404), GHSA-mx9r-x6ww-qjw9 (404), CVE-2026-110863, CVE-2026-121802,
   CVE-2026-67328, CVE-2026-110861, CVE-2026-110864. Raw JSON: see below.
5. Web search (`browser.search`, 5 queries): GHSA list, CVE/npm, HackerOne
   disclosed, GHSA-mx9r-x6ww-qjw9, November-batch CVEs. One third-party page
   opened in full (Aikido AIKIDO-2026-95917 → CVE-2026-67328).
6. Advisory pages (`browser.open`, 14 pages, no API): all 12 November advisories
   + GHSA-mx9r-x6ww-qjw9 + GHSA-prpr-5gj3-qqhg. All readable; affected ranges
   and patch versions taken from the "Am I affected?" / "Patches" sections.
7. Sibling-repo verification (other-repo CVEs only): greps in
   `repos/sveltejs-kit/packages/kit/CHANGELOG.md` and
   `repos/vercel-vercel/packages/cli/CHANGELOG.md` (see table above).

Raw OSV evidence retained at: `../evidence/osv-better-auth-2026-11-13/`
(full `v1/vulns` JSON for the 34 package-query records, the 8 scoped-package
records, and the 5 CVE records fetched directly, plus the paged query union map).

---
*This list answers "is it already known?" only. It does not assess any candidate
finding — there were none at build time. The Referee and gate check candidates
against this list; anything matching an EXCLUDED entry's flaw (not merely its
area) must not be reported as new.*
