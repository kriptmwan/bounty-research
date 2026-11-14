# Deriv alive check — 2026-11-13 (Phase 1)

Method: one `HEAD https://<host>/` per host via `bin/h1curl` (header
`X-HackerOne-Research: mosul` on every request), 10s timeout, sequential,
~0.3s pacing. `GET` fallback only on 405; `http://` fallback only on hard
connection-refused (exit 7) on 443 — no host needed the HTTP fallback.
No payloads, no auth attempts, no retries on 403/429. Window: 2026-11-13
15:34–15:50 WIB (08:34–08:50 UTC), covering a first pass whose status
column was lost to a parsing bug (preserved as
`alive-check-2026-11-13-pass1-status-bug.tsv`) and a corrected second pass
over all 404 hosts, which governs this file. Request log:
`logs/h1curl-requests.log`. Machine-readable data: `alive-check-2026-11-13.tsv`.

## Summary

- Hosts probed: **404** (21 scope-priority hosts + 394 CT hostnames, deduped;
  includes 3 `derivws.com` names found via crt.sh: apex, `api`, `staging-api`).
- **Alive: 291** (HTTP response received, status other than 403/429/503).
- **Blocked: 113** (HTTP 403 — edge/WAF refusal; origin state unknown).
- **Dead: 0** (no DNS/connect failure anywhere — wildcard DNS +
  Cloudflare edge answers every name; "dead" here would mean no HTTP response).

Status distribution: 223×200, 113×403, 26×301, 21×404, 13×302, 4×530, 1×520, 1×401, 1×400, 1×307.

By zone: `deriv.com` 233 alive / 32 blocked; `deriv.cloud` 52 alive / 79 blocked;
`derivws.com` 2 alive / 1 blocked; other scope hosts (slack/mql5/atlassian/ae/partners) 4 alive / 1 blocked.

## Notable

- `oauth.deriv.com` EXISTS (302 → `https://deriv.com/`) despite being absent from the CT
  snapshot — the plan §2.3 open question is resolved: it sits behind a wildcard cert.
- `app.deriv.com` 302 → `https://deriv.com/`; `smarttrader.deriv.com` 301 →
  `dsmarttrader.deriv.com`; `api.deriv.com` 301 → `developers.deriv.com`. The live app
  surface has moved since the CT snapshot — Phase 2/3 mapping must start from these.
- API roots return 404 on `/` (expected, they are alive): `cashier.deriv.com`,
  `core-api.deriv.com`, `api-core.deriv.com`, `api.derivws.com`.
- `derivws.com` apex returns **520** (Cloudflare unknown/origin error); four hosts return
  **530** (Cloudflare origin-DNS error): `api-core-aws`, `dx-demo`, `dx`,
  `staging-api-core-aws`. Edge alive, origin unreachable — pre-screen these for the
  Phase 1 dangling/takeover check (detection only, no claiming).
- `id-ct-uat.deriv.com` returns **401** (nginx, HTTP-auth challenge). Flagged, not forced.
- `secure-dfadmin.deriv.com` (Important tier) is **403**; `staging-api.derivws.com` 403.
- Cloudflare Access gating confirmed by redirect on `staging-dx.deriv.com` and
  `test-api.deriv.com` (302 → `derivcom.cloudflareaccess.com`). 18 internal-flagged
  hosts answer 200 with an empty Server header (`rancher`, `portainer-test`,
  `registry-test`, 4× `vault-*`, 3× `win-mgmt*`, `internaltools`, `internal-*-ai*`,
  `dx-admin`, `dx-dealer`, 2× backoffice staging) — a 200 on HEAD does NOT mean the
  app is exposed (likely an Access login page); flag-don't-force, no further probing
  without authorization. 24 other internal-flagged hosts are 403.
- Xano: 30/34 blocked (403), incl. all 26 random instance subdomains; 4 answer 200
  (`xano.pl`, `www.xano.pl`, `xano-pii.pl`, `xanoproxytest`). Tenant-ownership caveat
  from the plan still applies.
- MT5: 4 alive (`mt5-demo-sg` 200, `mt5-demo-web` 400, `www.mt5-demo-web` 200,
  `prod-mt5-connection-manager` 200), 7 blocked. MT5 stays DEFERRED per the plan.
- `cashier-crypto-iframe.deriv.com` and `cashier-demo.deriv.com` serve from Vercel (200).
- `home.deriv.com` 301 redirects HTTPS → `http://home.deriv.com/dashboard` (scheme
  downgrade on the redirect target — minor observation, not a finding).
- Redirect targets are otherwise all Deriv-owned or expected third parties
  (`metatraderweb.app`, `derivai.substack.com` from `tech.deriv.com`,
  `chsandbox.id.ctrader.com` from `id-ct-uat2/3`). No unexpected takeover-shaped target.
- Most `staging.*.deriv.com` hosts are 403 from this network — staging mirrors are
  largely gated, which limits the plan's staging-first detection idea; Phase 2 must
  confirm per-host before assuming staging is testable.
- Pass-1 anomaly (does not affect this file): the first pass saw 135 `curl` exit-52
  (empty reply) results; the corrected second pass saw zero. Treated as transient
  edge/proxy behavior; the second pass governs.

## Caveats

- HEAD-only: no bodies, titles, or TLS details were fetched. A 200 means "the edge
  answered", not "the application is reachable/usable". A 403 means "the edge refused
  this request", not "the origin is dead". Re-check any host before relying on it in a
  later phase — edge behavior can differ by path, method, and source network.
- No host was contacted more than the scripted pattern (HEAD + at most one 405/HTTP
  fallback), except hosts covered by both passes after the first pass's status column
  was lost to the parsing bug (disclosed above).

## Full results

| Host | Scheme | Status | Server | Location | CF-Ray | Verdict | Flags |
|---|---|---|---|---|---|---|---|
| app.deriv.com | https | 302 | cloudflare | https://deriv.com/ | yes | alive | - |
| smarttrader.deriv.com | https | 301 | cloudflare | https://dsmarttrader.deriv.com/ | yes | alive | - |
| cashier.deriv.com | https | 404 | cloudflare | - | yes | alive | - |
| oauth.deriv.com | https | 302 | cloudflare | https://deriv.com/ | yes | alive | - |
| api.deriv.com | https | 301 | cloudflare | https://developers.deriv.com/ | yes | alive | - |
| secure-dfadmin.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| home.deriv.com | https | 301 | cloudflare | http://home.deriv.com/dashboard | yes | alive | - |
| core-api.deriv.com | https | 404 | cloudflare | - | yes | alive | - |
| api-core.deriv.com | https | 404 | cloudflare | - | yes | alive | - |
| derivws.com | https | 520 | cloudflare | - | yes | alive | - |
| api.derivws.com | https | 404 | cloudflare | - | yes | alive | - |
| staging-api.derivws.com | https | 403 | cloudflare | - | yes | blocked | - |
| deriv.slack.com | https | 403 | Apache | - | no | blocked | - |
| tradingview.deriv.com | https | 301 | cloudflare | https://charts.deriv.com/ | yes | alive | - |
| trade.mql5.com | https | 301 | Caddy | https://metatraderweb.app/ | no | alive | - |
| community.deriv.com | https | 200 | nginx | - | no | alive | - |
| ct.deriv.com | https | 200 | nginx/1.31.3 | - | no | alive | - |
| deriv.atlassian.net | https | 302 | AtlassianEdge | https://deriv.atlassian.net/login.jsp?os_destination=https%3A%2F%2Fderiv.atlassian.net%2F | no | alive | - |
| deriv.ae | https | 301 | cloudflare | https://deriv.com/ae/ | yes | alive | - |
| deriv.partners | https | 301 | cloudflare | https://home.deriv.com/partners-app | yes | alive | - |
| partners.deriv.com | https | 302 | cloudflare | https://home.deriv.com/partners-app/login | yes | alive | - |
| academy-test.deriv.com | https | 200 | - | - | no | alive | - |
| academy.deriv.com | https | 301 | cloudflare | https://traders-academy.deriv.com/ | yes | alive | - |
| accounts.staging-home.deriv.com | https | 200 | - | - | no | alive | - |
| ae-academy.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| ae.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| af-com-deriv-nakala.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| api-core-aws.deriv.com | https | 530 | cloudflare | - | yes | alive | - |
| api-gateway.deriv.com | https | 404 | cloudflare | - | yes | alive | - |
| apigateway.deriv.com | https | 200 | - | - | no | alive | - |
| assets.deriv.com | https | 404 | cloudflare | - | yes | alive | - |
| auth.deriv.com | https | 404 | cloudflare | - | yes | alive | - |
| besquare.deriv.com | https | 301 | cloudflare | https://deriv.com/careers/ | yes | alive | - |
| beta-api.deriv.com | https | 301 | cloudflare | http://developers.deriv.com/ | yes | alive | - |
| beta-bot.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| beta-dtrader.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| beta-eu.deriv.com | https | 200 | - | - | no | alive | - |
| beta.deriv.com | https | 200 | - | - | no | alive | - |
| blog.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| blox.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| bot.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| bug-bounty.deriv.com | https | 200 | - | - | no | alive | - |
| careers.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| cashier-crypto-iframe-demo.deriv.com | https | 200 | - | - | no | alive | - |
| cashier-crypto-iframe.deriv.com | https | 200 | Vercel | - | no | alive | - |
| cashier-demo.deriv.com | https | 200 | Vercel | - | no | alive | - |
| cf-pages-app.deriv.com | https | 200 | - | - | no | alive | - |
| cf-pages-binary-bot.deriv.com | https | 200 | - | - | no | alive | - |
| cf-pages-binary-static.deriv.com | https | 200 | - | - | no | alive | - |
| cf-pages-deriv-app.deriv.com | https | 200 | - | - | no | alive | - |
| cf-pages-deriv-binary-bot.deriv.com | https | 200 | - | - | no | alive | - |
| cf-pages-deriv-binary-static.deriv.com | https | 200 | - | - | no | alive | - |
| cf-pages-deriv-com.deriv.com | https | 200 | - | - | no | alive | - |
| cf-pages-deriv-components.deriv.com | https | 200 | - | - | no | alive | - |
| cf-pages-deriv-developers-portal.deriv.com | https | 200 | - | - | no | alive | - |
| cf-pages-deriv-static-content.deriv.com | https | 200 | - | - | no | alive | - |
| cf-pages-firstsource-io.deriv.com | https | 200 | - | - | no | alive | - |
| cf-pages-sinbad.deriv.com | https | 200 | - | - | no | alive | - |
| cf-pages-smart-charts.deriv.com | https | 200 | - | - | no | alive | - |
| cf-pages-staging.deriv.com | https | 200 | - | - | no | alive | - |
| cf-pages-tradingview.deriv.com | https | 200 | - | - | no | alive | - |
| cf-pages-webtrader.deriv.com | https | 200 | - | - | no | alive | - |
| cf-pages.deriv.com | https | 200 | - | - | no | alive | - |
| cf.api.deriv.com | https | 200 | - | - | no | alive | - |
| cf.bot.deriv.com | https | 200 | - | - | no | alive | - |
| cf.deriv.com | https | 200 | - | - | no | alive | - |
| charts.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| clerk.staging-home.deriv.com | https | 200 | - | - | no | alive | - |
| cms.deriv.com | https | 200 | - | - | no | alive | - |
| contest.deriv.com | https | 301 | cloudflare | https://deriv.com/ | yes | alive | - |
| ct-uat.deriv.com | https | 200 | nginx/1.31.3 | - | no | alive | - |
| ct-uat2.deriv.com | https | 200 | nginx/1.31.3 | - | no | alive | - |
| ct-uat3.deriv.com | https | 200 | nginx/1.31.3 | - | no | alive | - |
| dashboard-preview.deriv.com | https | 200 | - | - | no | alive | - |
| datahub.deriv.com | https | 200 | - | - | no | alive | - |
| dbot.deriv.com | https | 301 | cloudflare | https://bot.deriv.com/ | yes | alive | - |
| demo-partnershub.deriv.com | https | 200 | - | - | no | alive | - |
| deriv-home-2-5-preview.test-home-agent.deriv.com | https | 404 | cloudflare | - | yes | alive | - |
| deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| derivatives-bot.deriv.com | https | 200 | - | - | no | alive | - |
| dev-home.deriv.com | https | 200 | - | - | no | alive | - |
| dev-hub.deriv.com | https | 200 | - | - | no | alive | - |
| dev-partners-app.deriv.com | https | 200 | - | - | no | alive | - |
| developer.deriv.com | https | 301 | cloudflare | https://developers.deriv.com/ | yes | alive | - |
| developers.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| development-api-core.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| discourse.deriv.com | https | 200 | - | - | no | alive | - |
| docs-core.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| docs.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| dp2p.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| dr-api-docs.deriv.com | https | 200 | - | - | no | alive | - |
| dr-deriv-app.deriv.com | https | 200 | - | - | no | alive | - |
| dr-staging-app.deriv.com | https | 200 | - | - | no | alive | - |
| dr.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| dsmarttrader.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| dtrader.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| dx-api.deriv.com | https | 200 | - | - | no | alive | - |
| dx-demo.deriv.com | https | 530 | cloudflare | - | yes | alive | - |
| dx-mobile.deriv.com | https | 200 | - | - | no | alive | - |
| dx.deriv.com | https | 530 | cloudflare | - | yes | alive | - |
| e360-assets.deriv.com | https | 404 | cloudflare | - | yes | alive | - |
| e360.deriv.com | https | 200 | - | - | no | alive | - |
| eu.cf-pages-deriv-com.deriv.com | https | 200 | - | - | no | alive | - |
| eu.cf-pages.deriv.com | https | 200 | - | - | no | alive | - |
| eu.cf.deriv.com | https | 200 | - | - | no | alive | - |
| eu.deriv.com | https | 301 | cloudflare | https://deriv.com/eu/ | yes | alive | - |
| event.deriv.com | https | 200 | - | - | no | alive | - |
| experiment.deriv.com | https | 200 | - | - | no | alive | - |
| experiments.deriv.com | https | 200 | - | - | no | alive | - |
| experts.deriv.com | https | 301 | cloudflare | /insights | yes | alive | - |
| fix.deriv.com | https | 200 | - | - | no | alive | - |
| fixtls.deriv.com | https | 200 | - | - | no | alive | - |
| flags.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| help.deriv.com | https | 200 | - | - | no | alive | - |
| hub.deriv.com | https | 302 | cloudflare | https://deriv.com/ | yes | alive | - |
| id-ct-uat.deriv.com | https | 401 | nginx | - | no | alive | - |
| id-ct-uat2.deriv.com | https | 302 | nginx | https://chsandbox.id.ctrader.com/ | no | alive | - |
| id-ct-uat3.deriv.com | https | 302 | nginx | https://chsandbox.id.ctrader.com/ | no | alive | - |
| id-ct.deriv.com | https | 302 | nginx | https://ct.deriv.com | no | alive | - |
| idv.staging-auth.deriv.com | https | 200 | - | - | no | alive | - |
| join.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| kyc-adaptor-staging.deriv.com | https | 200 | - | - | no | alive | - |
| kyc-adaptor.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| kyc.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| landing.deriv.com | https | 200 | - | - | no | alive | - |
| learning.deriv.com | https | 200 | - | - | no | alive | - |
| legacy-api.deriv.com | https | 301 | cloudflare | https://developers.deriv.com/ | yes | alive | - |
| legacy-docs.deriv.com | https | 302 | cloudflare | /docs | yes | alive | - |
| link.deriv.com | https | 404 | cloudflare | - | yes | alive | - |
| login.deriv.com | https | 302 | cloudflare | https://login.deriv.com/signin.php | yes | alive | - |
| lp.deriv.com | https | 200 | - | - | no | alive | - |
| media.deriv.com | https | 404 | cloudflare | - | yes | alive | - |
| molink.deriv.com | https | 200 | - | - | no | alive | - |
| mt5-demo-sg.deriv.com | https | 200 | - | - | no | alive | mt5 |
| mt5-demo-web.deriv.com | https | 400 | cloudflare | - | yes | alive | mt5 |
| mta-sts.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| no404.cf-pages-deriv-app.deriv.com | https | 200 | - | - | no | alive | - |
| notfound.cf-pages-deriv-app.deriv.com | https | 200 | - | - | no | alive | - |
| okta.deriv.com | https | 200 | - | - | no | alive | - |
| options.deriv.com | https | 200 | - | - | no | alive | - |
| outsystems.deriv.com | https | 200 | - | - | no | alive | - |
| p2p-dev1.deriv.com | https | 200 | - | - | no | alive | - |
| p2p-dev2.deriv.com | https | 200 | - | - | no | alive | - |
| p2p-dev3.deriv.com | https | 200 | - | - | no | alive | - |
| p2p-dev4.deriv.com | https | 200 | - | - | no | alive | - |
| p2p-dev5.deriv.com | https | 200 | - | - | no | alive | - |
| p2p.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| partner-academy.deriv.com | https | 200 | - | - | no | alive | - |
| partners-academy.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| partners-app.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| partnersapp-preview.deriv.com | https | 200 | - | - | no | alive | - |
| partnershub-assets.deriv.com | https | 404 | cloudflare | - | yes | alive | - |
| preview.deriv.com | https | 200 | - | - | no | alive | - |
| prince.cf-pages-binary-static.deriv.com | https | 200 | - | - | no | alive | - |
| region-assets.deriv.com | https | 404 | cloudflare | - | yes | alive | - |
| remote-config.deriv.com | https | 404 | cloudflare | - | yes | alive | - |
| seo.deriv.com | https | 200 | - | - | no | alive | - |
| signup.deriv.com | https | 200 | - | - | no | alive | - |
| ssd.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-ae.deriv.com | https | 200 | - | - | no | alive | - |
| staging-api-core-aws.deriv.com | https | 530 | cloudflare | - | yes | alive | - |
| staging-api-core.deriv.com | https | 404 | cloudflare | - | yes | alive | - |
| staging-api-gateway.deriv.com | https | 200 | - | - | no | alive | - |
| staging-api-partners.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-api.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| staging-app-agent.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-app.deriv.com | https | 302 | cloudflare | https://deriv.com/ | yes | alive | - |
| staging-auth-proxy.deriv.com | https | 200 | - | - | no | alive | - |
| staging-auth.deriv.com | https | 404 | cloudflare | - | yes | alive | - |
| staging-blog.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-blox.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-bot.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-cashier-crypto-iframe.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-charts.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| staging-dbot.deriv.com | https | 301 | cloudflare | https://staging-bot.deriv.com/ | yes | alive | - |
| staging-developer.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-developers.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-dp2p.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-dsmarttrader.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-dtrader.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-dx.deriv.com | https | 302 | cloudflare | https://derivcom.cloudflareaccess.com/cdn-cgi/access/login/staging-dx.deriv.com?kid=3da24ed0867833cac23d9c0e147cc2d4c8518e750c0a254ad228820a89dc7498&meta=eyJ0eX | yes | alive | - |
| staging-eu.cf-pages-deriv-com.deriv.com | https | 200 | - | - | no | alive | - |
| staging-eu.cf-pages.deriv.com | https | 200 | - | - | no | alive | - |
| staging-eu.deriv.com | https | 200 | - | - | no | alive | - |
| staging-event.deriv.com | https | 200 | - | - | no | alive | - |
| staging-experts.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-home.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-hub.deriv.com | https | 404 | cloudflare | - | yes | alive | - |
| staging-join.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-kyc-adaptor.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-kyc.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| staging-legacy-api.deriv.com | https | 200 | - | - | no | alive | - |
| staging-p2p.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| staging-partner-academy.deriv.com | https | 200 | - | - | no | alive | - |
| staging-partner.deriv.com | https | 200 | - | - | no | alive | - |
| staging-partners-academy.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-partners-app.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-partners.deriv.com | https | 307 | cloudflare | /welcome | yes | alive | - |
| staging-partnershub.deriv.com | https | 200 | - | - | no | alive | - |
| staging-sg-hub.deriv.com | https | 200 | - | - | no | alive | - |
| staging-smartcharts.deriv.com | https | 200 | - | - | no | alive | - |
| staging-smarttrader.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-static.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-store.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-swipe.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-templates-preview-developers.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-trade.deriv.com | https | 301 | cloudflare | https://staging.deriv.com/ | yes | alive | - |
| staging-trader.deriv.com | https | 200 | - | - | no | alive | - |
| staging-traders-academy.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-trading-flutter.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging-trading.deriv.com | https | 200 | - | - | no | alive | - |
| staging-tradingview.deriv.com | https | 200 | - | - | no | alive | - |
| staging-uk-hub.deriv.com | https | 200 | - | - | no | alive | - |
| staging-us-hub.deriv.com | https | 200 | - | - | no | alive | - |
| staging-webflow.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| staging.cf-pages-app.deriv.com | https | 200 | - | - | no | alive | - |
| staging.cf-pages-binary-bot.deriv.com | https | 200 | - | - | no | alive | - |
| staging.cf-pages-binary-static.deriv.com | https | 200 | - | - | no | alive | - |
| staging.cf-pages-deriv-app.deriv.com | https | 200 | - | - | no | alive | - |
| staging.cf-pages-deriv-binary-bot.deriv.com | https | 200 | - | - | no | alive | - |
| staging.cf-pages-deriv-binary-static.deriv.com | https | 200 | - | - | no | alive | - |
| staging.cf-pages-deriv-com.deriv.com | https | 200 | - | - | no | alive | - |
| staging.cf-pages-deriv-components.deriv.com | https | 200 | - | - | no | alive | - |
| staging.cf-pages-deriv-developers-portal.deriv.com | https | 200 | - | - | no | alive | - |
| staging.cf-pages-deriv-static-content.deriv.com | https | 200 | - | - | no | alive | - |
| staging.cf-pages-firstsource-io.deriv.com | https | 200 | - | - | no | alive | - |
| staging.cf-pages-sinbad.deriv.com | https | 200 | - | - | no | alive | - |
| staging.cf-pages-smart-charts.deriv.com | https | 200 | - | - | no | alive | - |
| staging.cf-pages-tradingview.deriv.com | https | 200 | - | - | no | alive | - |
| staging.cf-pages-webtrader.deriv.com | https | 200 | - | - | no | alive | - |
| staging.cf-pages.deriv.com | https | 200 | - | - | no | alive | - |
| staging.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| staging.derivatives-bot.deriv.com | https | 200 | - | - | no | alive | - |
| static-core-staging.deriv.com | https | 200 | - | - | no | alive | - |
| static.deriv.com | https | 301 | cloudflare | https://deriv.com/ | yes | alive | - |
| store.deriv.com | https | 403 | cloudflare | - | yes | blocked | - |
| stream.deriv.com | https | 200 | - | - | no | alive | - |
| support.deriv.com | https | 200 | - | - | no | alive | - |
| swipe.deriv.com | https | 200 | - | - | no | alive | - |
| t.deriv.com | https | 200 | - | - | no | alive | - |
| tech.deriv.com | https | 301 | cloudflare | https://derivai.substack.com/ | yes | alive | - |
| templates-preview-developers.deriv.com | https | 404 | cloudflare | - | yes | alive | - |
| test-api.deriv.com | https | 302 | cloudflare | https://derivcom.cloudflareaccess.com/cdn-cgi/access/login/test-api.deriv.com?kid=9fe8e1f291da834c832cf92c83f139f473c4d18cb1cee6d67b81d83540476c16&meta=eyJ0eXAi | yes | alive | - |
| test-app.deriv.com | https | 200 | - | - | no | alive | - |
| test-dalus.deriv.com | https | 200 | - | - | no | alive | - |
| test-developers.deriv.com | https | 200 | - | - | no | alive | - |
| test-home-agent.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| test-home-builder.deriv.com | https | 200 | - | - | no | alive | - |
| test-home.deriv.com | https | 200 | - | - | no | alive | - |
| test.cf-pages-binary-bot.deriv.com | https | 200 | - | - | no | alive | - |
| test.cf-pages-binary-static.deriv.com | https | 200 | - | - | no | alive | - |
| test.cf-pages-deriv-binary-bot.deriv.com | https | 200 | - | - | no | alive | - |
| test.cf-pages-deriv-binary-static.deriv.com | https | 200 | - | - | no | alive | - |
| track.deriv.com | https | 301 | cloudflare | https://api-core.deriv.com/v1/partners/partner-referral/legacy-redirect?provider=myaffiliate&legacy_token=/ | yes | alive | - |
| trade.deriv.com | https | 301 | cloudflare | https://deriv.com/ | yes | alive | - |
| trader.deriv.com | https | 200 | - | - | no | alive | - |
| traders-academy.deriv.com | https | 200 | cloudflare | - | yes | alive | - |
| traders-hub.deriv.com | https | 200 | - | - | no | alive | - |
| trading.deriv.com | https | 200 | - | - | no | alive | - |
| translations.deriv.com | https | 404 | cloudflare | - | yes | alive | - |
| uat-app.deriv.com | https | 200 | - | - | no | alive | - |
| uat2-app.deriv.com | https | 200 | - | - | no | alive | - |
| urls.deriv.com | https | 301 | cloudflare | https://urls.deriv.com/sitemap.xml | yes | alive | - |
| vtrack.deriv.com | https | 200 | - | - | no | alive | - |
| webflow-copy.deriv.com | https | 200 | - | - | no | alive | - |
| webflow.deriv.com | https | 301 | cloudflare | https://deriv.com/ | yes | alive | - |
| workaround.cf-pages-binary-bot.deriv.com | https | 200 | - | - | no | alive | - |
| workaround.cf-pages-binary-static.deriv.com | https | 200 | - | - | no | alive | - |
| www.cashier.deriv.com | https | 200 | - | - | no | alive | - |
| www.deriv.com | https | 301 | cloudflare | https://deriv.com/ | yes | alive | - |
| www.dx-mobile.deriv.com | https | 200 | - | - | no | alive | - |
| www.mt5-demo-web.deriv.com | https | 200 | - | - | no | alive | mt5 |
| x.deriv.com | https | 301 | - | https://www.deriv.com/ | yes | alive | - |
| backoffice-commissions.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| backoffice-feed-studio.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| backoffice-options.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| backoffice-synthetic-feed.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| backoffice.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| bridge-api-zuplo.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | - |
| bridge-api.deriv.cloud | https | 404 | cloudflare | - | yes | alive | - |
| client-migration-staging.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | - |
| client-migration.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | - |
| cms.deriv.cloud | https | 200 | - | - | no | alive | - |
| commissions.deriv.cloud | https | 200 | - | - | no | alive | - |
| crypto-backoffice.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| data-modeler.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | - |
| data.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | - |
| dealing-desk.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| deriv.cloud | https | 200 | - | - | no | alive | - |
| deriv.deriv.cloud | https | 200 | - | - | no | alive | - |
| derivedge.deriv.cloud | https | 200 | - | - | no | alive | - |
| derivpay-fe-poc.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | - |
| derivpay-poc.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | - |
| dev-mt5-demo-p01-ts01.deriv.cloud | https | 403 | - | - | no | blocked | mt5 |
| dev-mt5-demo-p01-ts03.deriv.cloud | https | 403 | - | - | no | blocked | mt5 |
| dev-mt5-real-p01-ts01.deriv.cloud | https | 403 | - | - | no | blocked | mt5 |
| dev-mt5-real-p02-ts01.deriv.cloud | https | 403 | - | - | no | blocked | mt5 |
| dev-mt5-real-p03-ts01.deriv.cloud | https | 403 | - | - | no | blocked | mt5 |
| dev.deriv.cloud | https | 200 | - | - | no | alive | - |
| dev.qadev01.deriv.cloud | https | 200 | - | - | no | alive | - |
| drona-dev.apigw.deriv.cloud | https | 200 | - | - | no | alive | - |
| drone-test.deriv.cloud | https | 200 | - | - | no | alive | - |
| dx-admin.deriv.cloud | https | 200 | - | - | no | alive | internal |
| dx-dealer.deriv.cloud | https | 200 | - | - | no | alive | internal |
| external-aws-deriv-ai.deriv.cloud | https | 200 | - | - | no | alive | - |
| external-gcp-ai-agents.deriv.cloud | https | 200 | - | - | no | alive | - |
| frontend.deriv.cloud | https | 200 | - | - | no | alive | - |
| gcp-ai-agents.deriv.cloud | https | 200 | - | - | no | alive | - |
| integration.deriv.cloud | https | 200 | - | - | no | alive | - |
| internal-aws-deriv-ai.deriv.cloud | https | 200 | - | - | no | alive | internal |
| internal-gcp-ai-agents.deriv.cloud | https | 200 | - | - | no | alive | internal |
| internaltools.deriv.cloud | https | 200 | - | - | no | alive | internal |
| kyc-backoffice.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| lens.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | - |
| microservices.deriv.cloud | https | 200 | - | - | no | alive | - |
| office-cup.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| p2p-backoffice.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| pa-backoffice.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| pages.deriv.cloud | https | 200 | - | - | no | alive | - |
| partners-events.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | - |
| portainer-test.deriv.cloud | https | 200 | - | - | no | alive | internal |
| preview-prod-backoffice-commissions.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| preview-staging-backoffice-commissions.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| prod-mt5-connection-manager.deriv.cloud | https | 200 | - | - | no | alive | mt5 |
| prod-mt5-demo-p01-ts03.deriv.cloud | https | 403 | - | - | no | blocked | mt5 |
| prod-mt5-real-p03-ts01.deriv.cloud | https | 403 | - | - | no | blocked | mt5 |
| product-universe.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | - |
| qa-openstack.deriv.cloud | https | 200 | - | - | no | alive | - |
| rancher.deriv.cloud | https | 200 | - | - | no | alive | internal |
| registry-test.deriv.cloud | https | 200 | - | - | no | alive | internal |
| smartcharts-champion.deriv.cloud | https | 200 | - | - | no | alive | - |
| smartcharts.deriv.cloud | https | 200 | - | - | no | alive | - |
| staging-auth.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | - |
| staging-backoffice-commissions.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| staging-backoffice-feed-studio.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| staging-backoffice-options.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| staging-backoffice-synthetic-feed.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| staging-backoffice.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| staging-bridge-api-zuplo.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | - |
| staging-bridge-api.deriv.cloud | https | 404 | cloudflare | - | yes | alive | - |
| staging-crypto-backoffice.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| staging-data.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | - |
| staging-dealfix.deriv.cloud | https | 200 | - | - | no | alive | - |
| staging-dealfix2.deriv.cloud | https | 200 | - | - | no | alive | - |
| staging-kyc-backoffice.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| staging-p2p-backoffice.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| staging-pa-backoffice.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| staging-partners-events.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | - |
| staging-smartcharts.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | - |
| staging-trading-game-backoffice.deriv.cloud | https | 200 | - | - | no | alive | internal |
| staging-workflow-automation.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | - |
| staging.backoffice.deriv.cloud | https | 200 | - | - | no | alive | internal |
| staging.deriv.cloud | https | 200 | - | - | no | alive | - |
| stream.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | - |
| team-metrics.deriv.cloud | https | 200 | - | - | no | alive | - |
| test-home.deriv.cloud | https | 200 | - | - | no | alive | - |
| training.deriv.cloud | https | 200 | - | - | no | alive | - |
| vault-loadtest.deriv.cloud | https | 200 | - | - | no | alive | internal |
| vault-openstack.deriv.cloud | https | 200 | - | - | no | alive | internal |
| vault-test.deriv.cloud | https | 200 | - | - | no | alive | internal |
| vault-test1.deriv.cloud | https | 200 | - | - | no | alive | internal |
| win-mgmt-dev.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| win-mgmt-lt.deriv.cloud | https | 200 | - | - | no | alive | internal |
| win-mgmt-octopus.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | internal |
| win-mgmt-wac.deriv.cloud | https | 200 | - | - | no | alive | internal |
| win-mgmt.deriv.cloud | https | 200 | - | - | no | alive | internal |
| workflow-automation.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | - |
| workplace-analytics.deriv.cloud | https | 200 | - | - | no | alive | - |
| ws.staging.deriv.cloud | https | 200 | - | - | no | alive | - |
| www.dx-dealer.deriv.cloud | https | 200 | - | - | no | alive | internal |
| www.xano.pl.deriv.cloud | https | 200 | - | - | no | alive | xano |
| xano-pii-uae.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xano-pii.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xano-pii.pl.deriv.cloud | https | 200 | - | - | no | alive | xano |
| xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xano-sandbox.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xano.pl.deriv.cloud | https | 200 | - | - | no | alive | xano |
| xanoproxytest.deriv.cloud | https | 200 | - | - | no | alive | xano |
| xd4b-d4ka-fjga-t11o-fm2z-4314.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-t4j6-dl0l-3154.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-t5af-i7tc-e789.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-t7fe-8qim-0805.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-t9ru-cayu-39e6.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-taus-sv3s-e893.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-tbfs-tjen-dbcb.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-thdx-jooc-be2d.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-thgv-gbj8-5ae9.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-thyu-gofa-4381.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-tlfe-l1vw-709f.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-tlhb-e5fh-c2f7.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-tm28-qq35-a21a.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-tmtl-q0go-9b90.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-tnk1-8yrr-cce6.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-tnll-hpwb-3586.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-tqbx-4p5d-7a86.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-tsqn-flfv-648c.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-ttgy-zaa4-def7.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-tu5y-h3s2-07c0.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-tuv1-bx50-2c0c.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-tx8i-qloj-4e03.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-tz7x-vhft-de07.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xd4b-d4ka-fjga-tzil-o2dh-f4fe.xano-prod.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xpex-zssa-kasm-t5jl-kp7h-ec68.xano-pii.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
| xpex-zssa-kasm-tmpi-ufqd-3bf9.xano-pii.deriv.cloud | https | 403 | cloudflare | - | yes | blocked | xano |
