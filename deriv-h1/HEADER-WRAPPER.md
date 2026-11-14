# Header wrapper — `bin/h1curl`

`bin/h1curl` is a drop-in `curl` replacement for all Deriv/HackerOne work: it
always sends `X-HackerOne-Research: mosul` (the program-mandated research
header, username confirmed 2026-11-13), strips any caller-supplied copy of
that header so a stale or wrong value can never override it, and appends one
line per invocation (UTC timestamp + first http(s) URL, no headers or bodies)
to `logs/h1curl-requests.log` unless `H1CURL_NOLOG=1` is set. Use it exactly
like curl (`h1curl -I https://app.deriv.com`); every request to any Deriv
asset must go through it, with no exceptions, and scanners get the same
header via their own `-H`/`--header` flags when the wrapper cannot be used.

Verified 2026-11-13 15:33 WIB against https://httpbin.org/headers (non-Deriv
echo target): the header arrived as `X-Hackerone-Research: mosul`, and a
deliberately wrong caller-supplied value (`evil`) was replaced with `mosul`.
