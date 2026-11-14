#!/usr/bin/env bash
# Phase 1 alive check — ONE HEAD request per host via the h1curl wrapper
# (research header always on). GET fallback only on 405. HTTP fallback only
# on hard connection-refused (exit 7) on 443. No payloads, no auth, no
# retries on 429/block. Rate: ~1 host per ~0.3s+request time, sequential.
set -uo pipefail
DIR="$HOME/workspace/deriv-h1"
H1="$DIR/bin/h1curl"
LIST="$DIR/alive-targets-2026-11-13.txt"
OUT="$DIR/alive-check-2026-11-13.tsv"
TMPHDR="$(mktemp)"
TMPCODE="$(mktemp)"
trap 'rm -f "$TMPHDR" "$TMPCODE"' EXIT

printf 'host\tscheme\tstatus\tserver\tlocation\tcf_ray\tverdict\tcurl_rc\tflags\tsecs\n' > "$OUT"
n=0
while IFS= read -r host; do
  [ -z "$host" ] && continue
  n=$((n+1))
  scheme="https"; code=""; rc=0
  : > "$TMPHDR"; : > "$TMPCODE"
  "$H1" -s -I --max-time 10 -o "$TMPHDR" -w '%{http_code} %{time_total}\n' "https://$host/" > "$TMPCODE" 2>/dev/null; rc=$?
  read -r code secs < "$TMPCODE" 2>/dev/null || code=""
  if [ "$rc" -eq 7 ]; then
    scheme="http"
    : > "$TMPHDR"; : > "$TMPCODE"
    "$H1" -s -I --max-time 10 -o "$TMPHDR" -w '%{http_code} %{time_total}\n' "http://$host/" > "$TMPCODE" 2>/dev/null; rc=$?
    read -r code secs < "$TMPCODE" 2>/dev/null || code=""
  fi
  if [ "$code" = "405" ]; then
    : > "$TMPHDR"; : > "$TMPCODE"
    "$H1" -s --max-time 10 -o /dev/null -D "$TMPHDR" -w '%{http_code} %{time_total}\n' "$scheme://$host/" > "$TMPCODE" 2>/dev/null; rc=$?
    read -r code secs < "$TMPCODE" 2>/dev/null || code=""
  fi
  # Cross-check: parse the status line from the captured headers; if the
  # -w code is empty/000 but headers carry a real status, trust the headers.
  hdr_code=$(grep -a -m1 -i '^HTTP/' "$TMPHDR" 2>/dev/null | awk '{print $2}' | grep -E '^[1-5][0-9][0-9]$' || true)
  if [ -n "$hdr_code" ] && { [ -z "$code" ] || [ "$code" = "000" ]; }; then code="$hdr_code"; fi
  server=""; location=""; cfray="no"
  if [ -s "$TMPHDR" ]; then
    server=$(grep -i '^server:' "$TMPHDR" | head -1 | sed 's/^[^:]*:[[:space:]]*//;s/\r$//' | tr '\t' ' ' | head -c 80)
    location=$(grep -i '^location:' "$TMPHDR" | head -1 | sed 's/^[^:]*:[[:space:]]*//;s/\r$//' | tr '\t' ' ' | head -c 160)
    grep -qi '^cf-ray:' "$TMPHDR" && cfray="yes"
  fi
  verdict="dead"
  case "$code" in
    ''|000) verdict="dead" ;;
    403|429|503) verdict="blocked" ;;
    [1-5][0-9][0-9]) verdict="alive" ;;
  esac
  flags=""
  lc=$(printf '%s' "$host" | tr 'A-Z' 'a-z')
  case "$lc" in
    *backoffice*|*vault*|*rancher*|*portainer*|*win-mgmt*|*internal*|*dealing-desk*|*dx-admin*|*dx-dealer*|*registry-test*|*office-cup*|*kyc-backoffice*|*p2p-backoffice*|*pa-backoffice*) flags="internal" ;;
  esac
  case "$lc" in *xano*) flags="${flags:+$flags,}xano";; esac
  case "$lc" in *mt5*) flags="${flags:+$flags,}mt5";; esac
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$host" "$scheme" "${code:-000}" "$server" "$location" "$cfray" "$verdict" "$rc" "$flags" "${secs:-0}" >> "$OUT"
  echo "[$n] $host -> $verdict ${code:-rc$rc}" >&2
  sleep 0.3
done < "$LIST"
echo "DONE $n hosts" >&2
