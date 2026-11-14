#!/usr/bin/env bash
# phase2-probe.sh — Deriv Phase 2 fingerprint probe (read-only, header on).
# One request per host: GET / (body capped 200KB) or HEAD-only for flagged hosts.
# Every request goes through bin/h1curl (injects X-HackerOne-Research: mosul).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
EV="evidence/phase2"
mkdir -p "$EV/bodies" "$EV/headers" "$EV/verbose"
H1="./bin/h1curl"
i=0
while IFS='|' read -r host tier mode; do
  [ -z "$host" ] && continue
  case "$host" in \#*) continue;; esac
  i=$((i+1))
  safe="${host//./_}"
  if [ "$mode" = "head" ]; then
    $H1 -s -I -m 15 -D "$EV/headers/$safe.txt" -o /dev/null -w "%{http_code} %{time_total}\n" --stderr "$EV/verbose/$safe.txt" -v "https://$host/" > "$EV/headers/$safe.status" 2>/dev/null || echo "ERR" > "$EV/headers/$safe.status"
  else
    $H1 -s -D "$EV/headers/$safe.txt" -o "$EV/bodies/$safe.html" -m 20 --max-filesize 200000 -w "%{http_code} %{time_total}\n" --stderr "$EV/verbose/$safe.txt" -v "https://$host/" > "$EV/headers/$safe.status" 2>/dev/null || echo "ERR" > "$EV/headers/$safe.status"
  fi
  echo "$host|$tier|$mode|$(cat "$EV/headers/$safe.status" 2>/dev/null)" >> "$EV/probe-log.tsv"
  sleep 0.4
done < "$1"
echo "probed $i hosts"
