#!/bin/bash
# Shallow-clone Vercel HackerOne in-scope OSS repos. Git protocol only, no API.
cd ~/workspace/vercel-audit/repos || exit 1
LOG=~/workspace/vercel-audit/clone-log.txt
: > "$LOG"
clone() {
  local name="$1" url="$2"
  echo "=== $name ===" | tee -a "$LOG"
  if [ -d "$name/.git" ]; then echo "already present, skipping" | tee -a "$LOG"; return; fi
  if timeout 600 git clone --depth 1 --single-branch "$url" "$name" >>"$LOG" 2>&1; then
    echo "OK $name" | tee -a "$LOG"
  else
    echo "FAIL $name (rc=$?)" | tee -a "$LOG"
  fi
}
clone vercel-workflow https://github.com/vercel/workflow.git
clone vercel-vercel https://github.com/vercel/vercel.git
clone vercel-turborepo https://github.com/vercel/turborepo.git
clone vercel-swr https://github.com/vercel/swr.git
clone vercel-nextjs https://github.com/vercel/next.js.git
clone vercel-flags https://github.com/vercel/flags.git
clone vercel-chat https://github.com/vercel/chat.git
clone vercel-async-sema https://github.com/vercel/async-sema.git
clone vercel-ai https://github.com/vercel/ai.git
clone vercel-labs-skills https://github.com/vercel-labs/skills.git
clone vercel-labs-agent-skills https://github.com/vercel-labs/agent-skills.git
clone sveltejs-svelte https://github.com/sveltejs/svelte.git
clone nuxt-nuxt https://github.com/nuxt/nuxt.git
clone nitrojs-nitro https://github.com/nitrojs/nitro.git
clone better-auth https://github.com/better-auth/better-auth.git
clone vercel-ms https://github.com/vercel/ms.git
clone vercel-eve https://github.com/vercel/eve.git
clone sveltejs-kit https://github.com/sveltejs/kit.git
echo "ALL DONE" | tee -a "$LOG"
