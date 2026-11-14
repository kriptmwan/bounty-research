# PRECHECK — Cronos Smart Contracts (HackenProof)

**Program:** https://hackenproof.com/programs/cronos-smart-contracts
**Checked:** 2026-11-14 ~20:16–20:30 WIB (live page fetched 2026-11-14 12:54 UTC; re-verified against the sweep's 19:54 WIB fetch — text identical).
**Auditor:** subagent, audit + runnable proofs ONLY. No account created, no filing, no submission, no live-mainnet testing. All on-chain reads were read-only `eth_call` / `eth_getCode` via `https://evm.cronos.org` (chain ID 25, confirmed).

## Verdict

**PRECHECK: PASS with workflow gates.** Scope pins to 6 named VVS targets (see below); submission is free; KYC is post-validity only. Two gates materially constrain any future filing and are flagged prominently in REPORT.md:

1. **Automation-suspicion exclusion** — reports "suspected to be generated using automated or generative tools" are out of scope. This audit is NOT filing-ready; any filing would need a HAND-WRITTEN report by the user.
2. **Reputation gate: UNVERIFIED** — no reputation minimum is stated on the public program page; HackenProof reputation gates are dashboard-gated and were NOT checked (checking would require creating/logging into an account, which this task forbids). Must be re-verified at the live submit form before any filing decision.

No discrepancy was found between the task's program facts and the live page. One material addition from the live page, not in the task brief: **the only accepted impacts are (a) cryptographic flaws and (b) unintentional withdrawal/draining/loss of user funds, both rated Critical** — there is no Medium/Low lane in this program. Everything else is out of scope even if it affects an in-scope asset.

## Scope pin (live page, verbatim target table)

| Target (page wording) | Type | Severity |
|---|---|---|
| Smart Contract - VVS - WCRO | Smart Contract | Critical |
| Smart Contract - VVS - Factory | Smart Contract | Critical |
| Smart Contract - VVS - Router | Smart Contract | Critical |
| Smart Contract - VVS - Token | Smart Contract | Critical |
| Smart Contract - VVS - Workbench | Smart Contract | Critical |
| Smart Contract - VVS - Craftsman | Smart Contract | Critical |

Intro text names "VVS Finance, Tectonic, and other DeFi projects" but the target table contains **VVS only** — Tectonic has no target row and was NOT audited. "Only the latest release version deployed to mainnet is considered as in-scope." Mock/Test folders and files are out of scope. "Vulnerabilities found within developmental code on GitHub which is not currently in production" are out of scope — this is why deployed-bytecode pinning (below) mattered.

### Deployed addresses (pinned on-chain, read-only, 2026-11-14)

| Target | Address | How pinned |
|---|---|---|
| Router | `0x145863Eb42Cf62847A6Ca784e6416C1682b1b2Ae` | Cronoscan label "VVS Finance: Router" (multiple tx pages); `factory()`/`WETH()` calls below |
| Factory | `0x3B44B2a187a7b3824131F8db5a74194D0a42Fc15` | Returned by `Router.factory()`; `allPairsLength()` = 23775; `feeToSetter()` set |
| WCRO | `0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23` | Returned by `Router.WETH()`; `name()`="Wrapped CRO", `symbol()`="WCRO"; `totalSupply()` == native balance exactly |
| Token (VVS) | `0x2D03BeCe6747ADC00E1a131bBA1469C15fD11e03` | `name()`="VVSToken", `symbol()`="VVS"; `owner()` = Craftsman address |
| Workbench (BENCH) | `0x6a2d178585806De5A2e5E7F9acFCE44680637284` | `name()`="Workbench Token"; `owner()` = Craftsman address; returned by `Craftsman.bench()` |
| Craftsman | `0xDccd6455AE04b03d785F12196B492b18129564bc` | `owner()` of both VVS and BENCH tokens; `vvs()`/`bench()` match; `poolLength()` = 172 |

### Source pinning (decisive)

- **Craftsman / Workbench / VVSToken: PINNED EXACTLY.** Repo `vvs-finance/vvs-farm` @ `acd79b99d88157b9d520eeac92e8c6424ae9d8de` (master HEAD, 3 commits total), compiled with solc 0.6.12 + optimizer runs 200 (settings from the repo's own `hardhat.config.js`), produces runtime bytecode **byte-identical to deployed code modulo the metadata trailer** for all three contracts (Craftsman 9,426 B; Workbench 4,798 B; VVSToken 5,004 B). The audited source IS the deployed code. Repro: `/tmp/poc-opt` build + strip-metadata comparison (commands in REPORT.md §7).
- **WCRO: NOT pinned to repo source.** Deployed WCRO (1,920 B) differs from `vvs-farm/contracts/libs/WCRO.sol` compiled the same way (1,786 B; first diff at byte 11). The repo file is evidently a stale/unused lib copy. Deployed WCRO was audited via its interface (exact WETH9 selector set, verified by probe) + behavior (`totalSupply()` == native balance, 684,107,409.71 CRO). No anomaly found. Residual risk: negligible; canonical-WETH9 behavior is in any case a previously-known Ethereum artifact (excluded, see below).
- **Factory / Router / Pair: source NOT obtainable from this VM; audited by bytecode forensics + behavioral probes, NOT line-read.** Failures, all recorded: Sourcify chain 25 → 404 for all targets; `api.cronoscan.com` → empty reply (Cloudflare/deprecated — Cronoscan was deprecated 2026-10-06); Etherscan v2 API → chain ID 25 unsupported; `explorer.cronos.org`/`explorer.cronos.com` Blockscout-style APIs → 404/301; no separate VVS core/periphery GitHub repo exists under any probed name (only `vvs-finance/vvs-farm` and `vvs-finance/swap-sdk` resolve). Forensic results (all read-only): Factory embeds pair creation code whose hash is its own `INIT_CODE_PAIR_HASH()` getter (`0xa77ee1cc…`), verified by exact CREATE2 reproduction of pair `0xbf62c67e…`; Pair `DOMAIN_SEPARATOR` recomputed exactly (name "VVS Finance LPs", version "1", chainId 25); `MINIMUM_LIQUIDITY` = 1000; `PERMIT_TYPEHASH` = canonical EIP-2612 value; Router `getAmountOut` confirms 997/1000 fee math; revert strings are VVS-renamed UniswapV2 strings (`VVS: IDENTICAL_ADDRESSES`, `VVSRouter: EXPIRED`, `VVS: INVALID_SIGNATURE`, `VVS: FORBIDDEN`, `VVS: INSUFFICIENT_OUTPUT_AMOUNT`). Conclusion: a renamed UniswapV2 fork with a PancakeSwap-style `INIT_CODE_PAIR_HASH` getter. No VVS-specific deviation was found in the probed surface. A source-level Factory/Router pass would need the verified source via a browser agent on the current Cronos explorer — flagged as the one open follow-up in REPORT.md.

### Live state that kills impact (read-only, 2026-11-14)

- `Craftsman.BONUS_MULTIPLIER()` = **0** → `updatePool` currently mints 0 rewards. Farm emissions are off.
- `Craftsman.migrator()` = `address(0)` → `migrate()` reverts for everyone.
- `Craftsman.devaddr()` = `address(0)`; dev-mint line is commented out in source.
- `Craftsman.owner()` = `0x7ed52ED16D4f4365046B9127c4a1081669682dB5`, an **EOA** (no code). All owner powers are single-EOA powers — and all owner-power attacks are excluded (see below).

## Gates (verbatim rules from the live page)

### Free submission: PROVEN (grade P)
No fee, credit, purchase, or token requirement appears anywhere in the full fetched program-page text (rules, eligibility, disclosure, rewards). No account was created to verify further; the submit form itself is login-gated and was not opened.

### KYC: payout-only, explicit
> "Cronos team requires KYC to be done for all bug bounty hunters submitting a report and wanting a reward. Once the report is deemed valid, you will need to fill up the KYC form here. The collection of this information will be done by the Cronos team."

KYC is post-validity, not upfront. Flagged per the user's standing order; no KYC was performed.

### Payout
- "Extreme: Up to $250,000"; discretionary bonus "an additional $50,000" for novel attacks (sole discretion of the team).
- "Critical smart contract vulnerabilities are capped at 10% of economic damage, primarily focused on the funds at risk."
- "Payouts are handled by Cronos team and are denominated in USD. Payouts are done in USDC and USDT only."

### Disclosure rule (STRICT — no public disclosure at all)
- "Any vulnerability found must be reported no later than 24 hours after discovery and exclusively through hackenproof.com."
- "Do not discuss this program or any vulnerabilities (even resolved ones) outside of the program without express consent from the organization."
- "No vulnerability disclosure, including partial is allowed for the moment."
- "Please do NOT publish/discuss bugs."
- "Public disclosure of an unpatched vulnerability in an embargoed bounty is prohibited."
- First reporter only; must not be a current/former employee or contractor; must use the registered HackenProof account email.

### Automation-suspicion exclusion (WORKFLOW GATE — read before any filing)
Out-of-scope list includes verbatim:
> "Reports that are suspected to be generated using automated or generative tools."

This audit was agent-assisted. A report derived from it risks rejection under this rule; the boundary is undefined on the page. **If a finding ever survives here, filing would require a HAND-WRITTEN report by the user, with the user re-verifying every claim independently.** This audit must not be presented as filing-ready. (Same caveat as the 1inch program's "AI-generated reports will not be considered.")

### Critical PoC rules (STRICT — every Critical claim must meet all of these)
- PoC mandatory: "All bug reports must come with a Proof-of-Concept (PoC) in order to be considered for a reward."
- "The maximum monetary value, unrelated to flash-loans, involved in the PoC should not exceed $300."
- "The impersonation of wallets or contracts having considerable funds in the PoC is strictly forbidden."
- "The exact block number utilized in the PoC must be explicitly specified."
- "The actual exploit must occur within one transaction" (staging, e.g. deploying an attack contract, is permissible).
- "Hypotheses that can't be unequivocally executed… are exempt from consideration."
- Damage = net positive value post-attack, after deducting initial capital/flash loans; non-quantifiable consequences (price drops, rewards dilution) do NOT count.
- Testing: "Any testing with mainnet or public testnet contracts is prohibited… all testing should be done on private testnets." (This audit used local Foundry tests only; no mainnet/testnet transactions were sent.)

### Other out-of-scope rules that decided this audit
- "Previously known vulnerabilities (resolved or not) on the Ethereum network (and any other fork of these)" — kills every canonical UniswapV2 / MasterChef / WETH9 behavior.
- "Previously known attack vectors or vulnerabilities (resolved or not) for which a bounty has already been awarded, including those that are similar but not identical."
- "Attacks requiring access to privileged addresses" — kills all owner/dev/migrator paths.
- "Potential vulnerabilities that require intervention from a third party (e.g., adding a malicious liquidity pool)."
- "Vulnerabilities that rely on pools or vaults with zero shares (empty)."
- "Devaluing/dilutions of protocol incentive rewards but do not result in the loss of user funds."
- "Denial of service… Gas draining… Best practice critiques… Design issues that are not necessarily a security risk."
- "VVS-Bench is Out of Scope" (ambiguous vs the in-scope "VVS - Workbench" row; treated conservatively: BENCH-token-only effects are not filed — see REPORT.md BUG-1).
- "Incorrect data supplied by third party oracles" (oracle manipulation/flash-loan attacks explicitly NOT excluded — but no oracle exists in the 6 targets).
- Rolling program, no deadline published.

### Reputation gate: UNVERIFIED
No reputation minimum is stated on the public program page. Per the sweep caveat, a gate may exist behind login. **Not checked — no account was created.** Re-verify at the live submit form before any filing decision. Do not assume a fresh account can submit.

## Early dedup (run BEFORE deep audit, per precheck skill)

- **SlowMist audit 2021** (report 0X002111050001, 2021-09-24–2021-11-05; pre-deployment code incl. core + farm): 11 findings N1–N11, full text read. N1/N10 excessive authority (Medium, confirmed/ignored); N2 emergency-withdraw/vault interaction (Low, confirmed); N3 dev address (suggestion, ignored); N4 permit DOMAIN_SEPARATOR replay (suggestion, ignored); N5 permit malleability (suggestion, fixed); N6 fee-on-transfer accounting (suggestion, ignored); N7/N11 missing events (fixed); N8 vault accounting (fixed); N9 CEI/reentrancy in emergencyWithdraw (suggestion, ignored — "will not use ERC777 token"). Every Hunter candidate below was deduped against N1–N11; four are direct duplicates.
- **Prior-audit duplicate risk is extreme**: the targets are a 2021 UniswapV2 + Sushi MasterChef + WETH9 fork set, live 5 years with no core-contract exploit on record (per public summaries checked). Any candidate matching canonical-fork behavior is excluded by the "previously known on Ethereum/forks" rule.
- **Tectonic gist** (fatherGoose1, reentrancy in TectonicStakingPoolV3 via VVS Router path): Tectonic is out of scope (no target row); the VVS Router was used as a swap path, not as the vulnerable contract. Not a VVS finding. Not pursued.
- User's already-filed findings: none relate to Cronos/VVS (memory checked via standing context; no Cronos filing exists).

## Precheck conclusion

Scope is pinned, submission is free, KYC is post-validity, and the rules are fully captured above. The audit proceeded on the pinned scope only. Gates that would apply to any future filing: hand-written report required (automation-suspicion exclusion), 24-hour reporting clock, reputation gate unverified, strict Critical PoC constraints ($300 / single-tx / exact block / no impersonation).
