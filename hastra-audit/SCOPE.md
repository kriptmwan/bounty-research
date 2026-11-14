# Hastra Bug Bounty — Scoping (2026-11-13)

STATUS: DECLINED by user 2026-11-13 15:29 WIB ("Lewati saja"). Do not pursue, do not re-offer. Scoping below kept for reference only.

Program: Hastra (RWA liquid staking; Figure/Provenance ecosystem). Bug bounty
live ~Nov 2026 (announced 9 Nov 2026). Up to $100,000 for Critical.
Submission: https://bugbounty.hastra.io/ — sign-in required; NON-REFUNDABLE
$10 USDC.SOL burn per submission (burn exactly $10 to incinerator
1nc1nerator11111111111111111111111111111111 from the payout wallet, paste
the burn tx signature to unlock the form). No published scope/rules/reward
table found on the public pages; scope presumably = the smart contracts.
First-report/KYC/disclosure terms unknown until sign-in.

## The protocol
- wYLDS (liquid yield token) → stake → PRIME (HELOC yield, ~6.32% APY,
  ~$530M TVL) / AUTO (auto loans, ~12.77% APY, ~$110M TVL) / SMB.
- Chains: Solana, Ethereum, Tempo. Admin: 4-of-7 multisigs both chains
  (Safe v1.4.1 ETH, Squads v4 SOL). Oracles: Chainlink NAV.
- Code: open source, provenance-io org on GitHub.

## Repos (provenance-io, checked 2026-11-13 via GitHub API)
- hastra-sol-vault (997KB, main, updated 2026-10-30): CURRENT Solana code.
  22 .rs files, 351,048 bytes. Two Anchor programs: vault-mint + vault-stake
  (each: account_structs/error/events/guard/lib/processor/state).
- hastra-eth-vault (15,897KB incl. deps, updated 2026-10-30): upgradeable
  vault system — YieldVault (USDC→wYLDS) + StakingVaults (PRIME/AUTO/SMB),
  Chainlink-verified NAV, async request-and-completion USDC redemptions.
  Exact .sol LOC NOT measured (GitHub API rate limit hit 2026-11-13 15:24
  WIB, shared egress IP, resets ~16:03 WIB).
- hastra-sol-vault-mint + hastra-sol-vault-stake (176KB/140KB, updated
  2025-10-31): STALE predecessors, superseded by hastra-sol-vault.

## Audit history = EXCLUSION LIST (check every candidate against these)
- Informal Systems, Solana vault-mint + vault-stake, 24 Sep–18 Nov 2025:
  9 issues incl. 1 Critical (reported remediated).
- Sherlock, Ethereum vault, Mar–Apr 2026: no Critical/High.
- OtterSec, BOTH hastra-eth-vault + hastra-sol-vault, 30 Jun–6 Aug 2026:
  16 findings. Audited commits: eth bba117c, sol b094b70; final commits
  15fc053 (eth), b169cb0 (sol). Report: hastra.io/Figure Hastra EVM and SOL
  Final.pdf. Named advisories: ADV-00 incorrect NAV application overstates
  vault value; ADV-01 missing staking cooldown around NAV updates (reward
  capture — most impactful); ADV-02 deposit allows vault token self-transfer;
  ADV-03 reusable reward proofs across epoch versions; ADV-04 empty admin
  lists disable gated operations; ADV-05 non-monotonic Chainlink price
  updates; ADV-06 partial redemption discards outstanding request; SUG-03
  price verification validation; SUG-04 reward ID canonical sequence +
  replay protection. REMEDIATION NOT CONFIRMED (per third-party reviews).
- Also thanked in Hastra comms: Halborn, Certora, ChainSecurity.

## Fresh angle
Both live repos were updated 2026-10-30 — AFTER the OtterSec audit (Aug 6).
Highest-value work: (1) verify whether the 16 OtterSec findings are actually
remediated at HEAD; (2) audit the post-audit delta (commits after 15fc053 /
b169cb0) — unaudited code.

## Options presented to user 2026-11-13
1. Audit vault Ethereum (RECOMMENDED): Solidity + Foundry already installed
   → buildable + POC-able. OtterSec remediation check + post-audit delta.
2. Audit vault Solana: Rust/Anchor, NO Rust toolchain on VM → static-only
   (read code, no compile/test/POC). Install would need a separate order.
3. Both (sequential; ETH first).

## Blockers
- SUBMISSION BLOCKED on funding: $10 USDC.SOL burn + SOL gas per submission,
  non-refundable; all three known Solana wallets hold 0 SOL / 0 USDC
  (checked 2026-11-13). Funding is the user's step; decide only if a solid
  finding survives. Audit itself needs no funds.
- Sign-in to the submission form is wallet-based → user's step.
- NO filing/submission/burn without a SEPARATE order after audit results.
