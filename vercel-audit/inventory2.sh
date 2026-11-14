#!/bin/bash
# Fixed LOC recount (sum all wc batches, skip 'total' lines) + targeted notes.
cd ~/workspace/vercel-audit/repos || exit 1
count_loc() { # $1 = newline-separated file list (via stdin)
  xargs wc -l 2>/dev/null | awk '$NF != "total" {s+=$1} END {print s+0}'
}
for d in */; do
  d="${d%/}"
  [ -d "$d/.git" ] || continue
  ( cd "$d" || exit 1
    SRC=$(git ls-files | grep -Ev 'node_modules/|\.git/|/dist/|/build/|pnpm-lock|package-lock|yarn\.lock' | grep -Ei '\.(ts|tsx|js|jsx|mjs|cjs|mts|cts|rs|go|py|svelte|vue|css|scss)$')
    CORE=$(echo "$SRC" | grep -Ev '\.(test|spec)\.|__tests__/|\.test\.|/examples/|/docs/|/fixtures/|/benchmarks/|e2e|/test/|/tests/|playground')
    echo "$d ALL_SRC_LOC=$(echo "$SRC" | count_loc) CORE_LOC=$(echo "$CORE" | count_loc) CORE_FILES=$(echo "$CORE" | wc -l)"
  )
done
echo "=== SECURITY files anywhere (depth<=3) ==="
for d in */; do
  d="${d%/}"
  [ -d "$d/.git" ] || continue
  ( cd "$d" && find . -maxdepth 3 -iname 'security*' -not -path './.git/*' 2>/dev/null | head -5 | sed "s|^|$d: |" )
done
echo "=== CVE mentions in changelogs ==="
for d in */; do
  d="${d%/}"
  [ -d "$d/.git" ] || continue
  ( cd "$d" && grep -rIl --include='CHANGELOG.md' -iE 'CVE-[0-9]{4}-[0-9]+' . 2>/dev/null | grep -v node_modules | head -3 | sed "s|^|$d CVE-CHANGELOG: |"; grep -rIhoE 'CVE-[0-9]{4}-[0-9]+' --include='CHANGELOG.md' . 2>/dev/null | sort -u | head -10 | sed "s|^|$d CVE: |" )
done
echo "=== better-auth core package ==="
( cd better-auth && echo "packages/better-auth/src: $(git ls-files 'packages/better-auth/src' | grep -E '\.(ts|tsx)$' | count_loc) lines, $(git ls-files 'packages/better-auth/src' | wc -l) files" && echo "packages/core/src: $(git ls-files 'packages/core/src' 2>/dev/null | grep -E '\.(ts|tsx)$' | count_loc) lines" && echo "packages/better-auth top: $(ls packages/better-auth)" && ls packages )
