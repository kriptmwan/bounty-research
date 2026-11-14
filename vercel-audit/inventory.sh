#!/bin/bash
# Per-repo inventory: pin, last commit, languages, LOC, security-policy/audit notes.
# LOC method: lines in tracked source files (ts/tsx/js/jsx/mjs/cjs/mts/cts/rs/go/py/svelte/vue/css/scss)
# excluding node_modules, dist, build, .git. Two counts: ALL tracked source, and
# IN-SCOPE-ISH = excluding test/spec files and examples/ + docs/ dirs.
cd ~/workspace/vercel-audit/repos || exit 1
for d in */; do
  d="${d%/}"
  echo "===== $d ====="
  if [ ! -d "$d/.git" ]; then echo "NOT CLONED"; continue; fi
  ( cd "$d" || exit 1
    echo "HEAD: $(git rev-parse HEAD 2>/dev/null)"
    echo "LAST_COMMIT: $(git log -1 --format='%ci %s' 2>/dev/null | head -c 200)"
    echo "BRANCH: $(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    echo "SECURITY_MD: $(ls SECURITY.md .github/SECURITY.md docs/SECURITY.md 2>/dev/null | tr '\n' ' ')"
    # language mix by tracked file count
    echo "EXT_COUNTS: $(git ls-files | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -8 | tr '\n' ';' )"
    # LOC counts
    ALL_FILES=$(git ls-files | grep -Ev 'node_modules/|\.git/|/dist/|/build/|pnpm-lock|package-lock|yarn\.lock' | grep -Ei '\.(ts|tsx|js|jsx|mjs|cjs|mts|cts|rs|go|py|svelte|vue|css|scss|md)$')
    ALL_LOC=$(echo "$ALL_FILES" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
    CORE_FILES=$(echo "$ALL_FILES" | grep -Ev '\.(test|spec)\.|__tests__/|\.test\.|/examples/|/docs/|/fixtures/|/benchmarks/|e2e' | grep -Ev '\.md$')
    CORE_LOC=$(echo "$CORE_FILES" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
    echo "LOC_ALL_SRC_MD: $ALL_LOC"
    echo "LOC_CORE_NO_TEST_NO_EXAMPLES: $CORE_LOC"
    echo "FILE_COUNT_CORE: $(echo "$CORE_FILES" | wc -l)"
    # top-level layout
    echo "TOPLEVEL: $(ls -1 | tr '\n' ' ' | head -c 400)"
    # changelog security mentions
    for cl in CHANGELOG.md packages/*/CHANGELOG.md; do
      [ -f "$cl" ] && grep -qi 'security' "$cl" && echo "CHANGELOG_SECURITY_HIT: $cl"
    done
    # advisories dir / audit docs
    find . -maxdepth 2 -iname '*audit*' -o -maxdepth 2 -iname '*advisories*' 2>/dev/null | grep -v node_modules | head -5 | sed 's/^/AUDIT_PATH: /'
  )
  echo
done
