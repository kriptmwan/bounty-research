"""Verbatim copy of desk/auth.py safe_next (lines ~232-245) + fake settings.
Tests whether a tab-containing 'next' passes. No repo imports, stdlib only."""
from urllib.parse import urlsplit

class S:
    scheme = "https"
    hosts = {"bounty": "bounty.xe.network", "support": "support.xe.network"}

def safe_next(settings, nxt, default="/my"):
    if not nxt or any(c in nxt for c in "\\\r\n\x00") or nxt != nxt.strip():
        return default
    if nxt.startswith("/") and not nxt.startswith("//"):
        return nxt
    u = urlsplit(nxt)
    if u.scheme == settings.scheme and u.hostname in settings.hosts.values() and not u.username:
        return nxt
    return default

s = S()
# As the server sees it after FastAPI percent-decodes ?next=/%09/evil.com
cases = [
    "/\t/evil.com/phish",
    "/my",
    "//evil.com",
    "/\\/evil.com",
    "https://evil.com",
    "https://bounty.xe.network/my",
    "/\n/evil.com",
]
for c in cases:
    print(repr(c), "->", repr(safe_next(s, c)))
