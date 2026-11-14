# Frax Finance Bug Bounty — Scoping Report

**Date:** 2026-11-14 (WIB)
**Method:** Read-only. Public docs (docs.frax.com), web search, and git-protocol clones (`--depth 1`) of public repos. No api.github.com use (rate-limited from this VM). No testing, no fork execution, no PoC, no contact with the Frax team, no submission.
**Clones:** `~/workspace/frax-audit/repos/` (12 repos, see §1).

## Bounty terms (verified from the program page, 2026-11-14)

Source: https://docs.frax.com/protocol/security/bugbounty

- **Free to submit.** Submission = one **secret** GitHub Gist + anonymous contact (X / Telegram / Discord / Signal). No fee, no platform, no credits.
- **Payout:** lower of **10% of total possible exploit** or **$10M**, paid in frxUSD+FRAX (split at team discretion), "no questions asked", delivered immediately or ≤5 days (timelock+mitigation).
- **Qualifies ONLY:** (1) theft of funds — direct, attacker-profitable extraction of user or protocol funds/collateral; or (2) permanent freezing of funds (bricking) — against a **current, live on-chain deployment**. Every submission **must include a working PoC** (e.g. runnable Foundry/Hardhat test on a current mainnet fork) reproducing the exploit and **quantifying funds at risk**.
- **Does NOT qualify / will generally not receive a response:** theoretical issues; scanner/AI output without a verified reproducible PoC; best-practice / gas / informational / **low / medium** findings; issues requiring privileged/admin keys, governance actions, or unrealistic preconditions; frontend / server-side code. **Smart contract code only.**
- **Submission must include an adversarial self-check:** run the finding + PoC through a current frontier AI model asking it to *disprove* the exploit; include the full prompt + complete response in the gist.
- **Scope:** smart contract code on any chain managing Frax Protocol value and/or user deposited value, **including Fraxswap AMM, Fraxlend, frxETH, FraxNet, Flox, FXB, and Hop.**

**Honest bar assessment:** this is one of the highest bars in the industry. A finding must be a demonstrated, attacker-profitable theft/bricking path on a live deployment, with a fork PoC and quantified value at risk. Anything less is not reviewed. Prior review is extensive (see §3) — the newest systems were audited weeks ago (Oct 2026).

---

## 1. Repo inventory

HEAD SHAs verified via `git ls-remote` + local clone, 2026-11-14. LOC = `wc -l` on `.sol` files, excluding `lib/` and `node_modules/`; "core LOC" excludes flattened copies, mocks, scripts, and tests where stated. Counts include comments/blank lines.

### Public repos (cloned)

| System | Repo | HEAD | Last commit | Size | What it is |
|---|---|---|---|---|---|
| Fraxlend | `FraxFinance/fraxlend` | `2bed49d4dcc6702d92dede825c3424893517d841` | 2025-11-12 | 5,074 LOC / 39 files; core pair logic 3,164 LOC | Isolated, permissionless ERC-4626 lending pairs (FraxlendPair/Core/Deployer/Registry/Whitelist, rate calculators, dual oracles) |
| frxETH V1 | `FraxFinance/frxETH-public` | `018eaf4daf0eb5ca94dfbb275d3fa59008ea829e` | 2023-10-12 | src 992 LOC / 9 files (+ flattened.sol) | frxETH minter, sfrxETH ERC-4626 vault, OperatorRegistry, deposit contract. Frozen since 2023. |
| Fraxswap + core | `FraxFinance/frax-solidity` | `2702e7e147212b85a28e198a7eba1c3bab9119db` | 2026-11-02 | 126,198 LOC / 840 files (whole monorepo); **Fraxswap subtree 5,592 LOC** | Legacy monorepo: FRAX/FPI stablecoins, AMOs, gauges, staking, oracles. Fraxswap = UniV2 + TWAMM (`FraxswapPair`, `LongTermOrders`, `FraxswapRouter`, `FraxswapRouterMultihop`) under `src/hardhat/contracts/Fraxswap/`. `src/audits/` holds 14 audit PDFs locally. |
| FXB | `FraxFinance/frax-bonds` | `4ef235e68c8277ad3dbc676762fffe663c9896fc` | 2025-07-09 | contracts 3,133 LOC; src total 8,998 | FXB zero-coupon bonds (Wednesday maturities), FXBFactory, SlippageAuction. Includes LFRAX/FXB upgrade walkthrough docs. |
| frxETH redemption | `FraxFinance/frax-ether-redemption-queue` | `17ebebcddf31b7780e92c23a6b440dc789e5ceac` | 2023-09-11 | 1,288 LOC / 8 files | frxETH→ETH redemption queue (NFT tickets). Frozen since 2023. |
| Oracles | `FraxFinance/frax-oracles` | `bd56532a3c33da95faed904a5810313deab5f13c` | 2023-09-11 | src 6,276 LOC / 54 files | Dual oracles (FrxEthEth, SfrxEthEth, etc.). HEAD is byte-identical to the version Trail of Bits audited Oct 2023 — frozen. |
| Fraxtal + Flox | `FraxFinance/fraxtal-contracts` | `7bfce185a306c96170e03fdbd65ae4a1a3e6cb1c` | 2025-07-07 | src/contracts 33,166 LOC (scripts+tests add 68,436); **VestedFXS-and-Flox subtree 14,220 LOC** | Fraxtal L1/L2 contracts, VestedFXS, **Flox** (FloxConverter, FloxCapacitor, FxtlPoints, FloxIncentivesDistributor, FraxStaker, FPISLocker), Miscellany. OP-Stack code lives in `lib/` submodules. |
| sFRAX / sfrxUSD | `FraxFinance/staked-frax-erc4626` | `9e42ee6b39fb1c08c6dc3607707b8b190f2de58c` | 2025-08-27 | contracts 4,759 LOC; src total 12,537 | ERC-4626 vaults (sFRAX, sfrxUSD/StakedFrxUSD2), FrxUSDCustodian, FraxtalERC4626MintRedeemer. Note: `savings-frax-erc4626` resolves to the same HEAD (duplicate/renamed repo). |
| Hop (Frax's own) | `FraxFinance/fraxtal-lz-hop` | `cb3240bb3d644ee30267b20f2d8b82e5de559c55` | 2026-11-03 | src 15,773 LOC / 114 files; **hop/ 2,760 LOC** | LayerZero bridge contracts: `RemoteHop`, `HopV2`/`RemoteHopV2`, `FraxtalHop`/`FraxtalHopV2`, `MintRedeemHop`, `RemoteVaultHop`, plus LZ Curve AMOs, composers, BatchSend. **This is the "Hop" in bounty scope** (see note below). |
| OFT mesh | `FraxFinance/frax-oft-upgradeable` | `6964529b29b367d976d62a6df1efbbacb31d3205` | 2026-10-29 | hand-written contracts 2,357 LOC (31,582 more in `flat/` flattened copies) + Move/Anchor code | LayerZero OFT adapters/tokens for the Frax mesh (FraxOFTUpgradeable, mintable adapters, WFRAX OFT, FraxDVN, Tempo/TIP-20 variants), deployments across ~25 chains. |
| Fraxtal chain | `FraxFinance/fraxtal` | `a9ea07cad072401b2732890af02584c278f30515` | 2025-07-15 | 114,442 .sol LOC / 536 files + Go code | OP Stack fork monorepo (mostly Optimism code). Chain infrastructure, not a Frax audit target per se. |

### "Hop" scope disambiguation (important)

The bounty scope's "Hop" is **Frax's own Hop system**, not Hop Protocol. Frax docs ("Crosschain Strategy", docs.frax.com/protocol/crosschain/overview) describe Frax-built "Hop" contracts that hide the Fraxtal-hub OFT routing: `HopV2` replaced first-gen `RemoteHop` (now paused); `MintRedeemHop` remains live. Code: `fraxtal-lz-hop` + `frax-oft-upgradeable`. The separate **Hop Protocol** (`hop-protocol/hop`, HEAD `3ae90bad`, a TypeScript monorepo with zero `.sol` files) is a different protocol with its own bounty program and is **not** treated as in scope here. Residual ambiguity is flagged in §5.

### Private / not publicly available (ls-remote fails: private or nonexistent)

Frax's own style guide (`frax-standard-solidity` README) states `-dev` repos are internal/private and public repos drop the suffix. The following audit-named repos have **no public mirror** found under any probed name:

| Repo (as named in audits) | Contents | Evidence |
|---|---|---|
| `FraxFinance/fraxnet-dev` | FraxNet: FraxNetDepositFactory, FraxNetDeposit, FraxNetDepositV2, FrxUSDCustodian, RWARedemptionCoordinator | Zellic Jul 2025 + Sep 2025 audit targets (versions `d0e4ef06…`, `4e10ffdb…`) |
| `FraxFinance/frxETH_V2` | frxETH V2: ValidatorPool, EtherRouter, redemption-queue-v2 | Frax Security Cartel Mar 2024 audit, commit `aeee22c3…` |
| `dev-fraxswap` (name per Code4rena 2025-01-iq-ai docs) | Current Fraxswap V2 + **FraxswapRouterMultihopV2** (audited by Codespect Oct 2026: `FraxswapRouterMultihopV2.sol` + `PancakeV3Plugin.sol`, 4 contracts) — **not present in public `frax-solidity` HEAD** | IQ AI audit docs reference `dev-fraxswap/src/contracts/…`; grep of public HEAD finds only the old `FraxswapRouterMultihop.sol` |
| `dev-staked-frax-erc4626`, `dev-fraxchain-contracts` | FrxUSD3/StakedFrxUSD3, FraxtalMinter, RemoteCustodians, upgrade scripts | Zellic Frax0 Mesh Sep 2025 audit targets |

Consequence: **FraxNet and frxETH V2 cannot be audited from public source.** Their deployed contracts are Etherscan/Fraxscan-verified, so source is retrievable per-address from explorers — but that is a different workflow (and Etherscan is Cloudflare-blocked from this VM; Sourcify is the fallback).

---

## 2. Deployed addresses (from public docs + repo READMEs)

All addresses below are copied from Frax docs or repo files. "Unverified" = not confirmed against live chain state in this scoping pass (read-only state checks belong to the audit phase).

### Tokens (Ethereum mainnet unless noted)

| Token | Ethereum | Fraxtal (252) | Source |
|---|---|---|---|
| frxETH | `0x5E8422345238F34275888049021821E8E08CAa1f` | `0xfc00000000000000000000000000000000000006` | docs.frax.com Frax tokens page |
| sfrxETH | `0xac3E018457B222d93114458476f3E3416Abbe38F` | `0xfc00000000000000000000000000000000000005` | docs + fraxlend interface comments |
| FRAX (ex-FXS, native gas on Fraxtal) | `0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0` | Native token | docs |
| wFRAX | `0x04ACaF8D2865c0714F79da09645C13FD2888977f` | `0xfc00000000000000000000000000000000000002` | docs |
| frxUSD | `0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29` | `0xfc00000000000000000000000000000000000001` | docs frxUSD addresses page; also Arbitrum/Avalanche/BSC/Polygon `0x80Eede496655FB9047dd39d9f418d5483ED600df`, Base `0xe5020A6d073a794B6E7f05678707dE47986Fb0b6` |
| sfrxUSD | `0xcf62F905562626CfcDD2261162a51fd02Fc9c5b6` | `0xfc00000000000000000000000000000000000008` | docs |
| frxBTC | `0x6CA2338a21B2fE9dD39040d2fE06AAD861f77F95` | `0xfc00000000000000000000000000000000000007` | docs |
| FPIS | `0xc2544A32872A91F4A553b404C6950e89De901fdb` | `0xfc00000000000000000000000000000000000004` | docs |

**Docs inconsistency (flagged, not resolved):** the docs "Frax tokens" page lists frxUSD on Ethereum as `0x853d955aCEf822Db058eb8505911ED77F175b99e` — but that address is the legacy FRAX stablecoin (`FRAXStablecoin`, per an EtherAuthority audit of Apr 2024). The frxUSD addresses page and FraxNet docs consistently use `0xCAcd…E29` for frxUSD. Treat `0x853d…` as the legacy FRAX token; verify on-chain before any audit use.

### frxETH system (Ethereum)

| Contract | Address | Source |
|---|---|---|
| frxETHMinter | `0x6421d1Ca6Cd35852362806a2Ded2A49b6fa8bEF5` | frxETH-public `script/AddValidators.s.sol` |
| FraxEtherRedemptionQueue | `0x82bA8da44Cd5261762e629dd5c605b17715727bd` | Frax docs (frxETH redemption page) |
| Timelock (owner) | `0x8412ebf45bAC1B340BbE8F318b928C466c4E39CA` | frxETH-public deploy script; fraxlend ITimelock comment |

### Fraxlend (Ethereum)

No canonical registry/deployer addresses in the repo README/docs. Found in-repo: liquidator bot constants `FRAXLEND_DEPLOYER_ADDRESS = 0x5d6e79Bcf90140585CE88c7119b7E43CAaA67044`, `FRAXLEND_PAIR_HELPER_ADDRESS = 0x26fa88b783cE712a2Fa10E91296Caf3daAE0AB37` (chain unstated in the file — **unverified**). A `FraxlendPairDeployer` at `0xF767A82a188305461b6f01a7706f7Bc0ba941ffF` appears on Etherscan (third-party listing, **unverified** as the canonical deployer; forks such as Peapods deploy their own). **Canonical Fraxlend factory/registry addresses must be established from on-chain state or Frax docs during the audit — do not assume.**

### Fraxswap (factories)

| Chain | Factory | Source / status |
|---|---|---|
| Ethereum V1 | `0xb076b06f669e682609fb4a8c6646d2619717be4b` | Flipside wiki (third-party) — **unverified from official docs** |
| Ethereum V2 | `0x43ec799eadd63848443e2347c49f5f52e8fe0f6f` | Flipside wiki (third-party) — **unverified from official docs** |
| Fraxtal | `0xE30521fe7f3bEB6Ad556887b50739d6C7CA667E6` | Code4rena IQ AI audit docs (third-party) — **unverified from official docs** |

Router addresses (incl. the new Multihop V2 router): **not found in public docs/repos — gap.**

### FXB (Ethereum)

| Contract | Address | Source |
|---|---|---|
| FXBFactory | `0x7a07D606c87b7251c2953A30Fa445d8c5F856C7A` | frax-bonds README |
| SlippageAuctionFactory | `0x983aF86c94Fe3963989c22CeeEb6eA8Eac32D263` | frax-bonds README |
| AMO Timelock (FXB creator) | `0x831822660572bd54ebaa065C2acef662a6277D40` | frax-bonds README |

### FraxNet / frxUSD mint-redeem (Ethereum)

| Contract | Address | Source |
|---|---|---|
| FraxNetDepositFactory | `0xA3D62f83C433e2A56Af392E08a705A52DEd63696` | Frax docs (multiple pages) |
| frxUSD-USDC Custodian Proxy | `0x4F95C5bA0C7c69FB2f9340E190cCeE890B3bd87c` | Frax docs custodians page |
| frxUSD-USTB Custodian Proxy | `0x5fbAa3A3B489199338fbD85F7E3D444dc0504F33` | Frax docs |
| frxUSD-BUIDL Custodian Proxy | `0xe827abf9f462ac4f147753d86bc5f91e186e4e9c` | Frax docs |
| frxUSD-WTGXX Custodian Proxy | `0x860Cc723935FC9A15fF8b1A94237a711DFeF7857` | Frax docs |
| frxUSD-USDB Custodian Proxy | `0xFE2Ea8dE262d956e852F12DE108fda57171a0a29` | Frax docs |
| ERC4626RedeemUSTB (proxy) | `0x00000000564ee6a571C5819057f27bb671E78Bd5` | Frax docs |

FraxNetDeposit implementation addresses (behind factory-created minimal proxies): **not published in docs — gap** (recoverable from on-chain deployments + explorer verification).

### HopV2 / RemoteHop (from fraxtal-lz-hop README, "Deployed Contracts")

HopV2 `Hop` / `RemoteAdmin` (selected chains): Ethereum `0xFd3B410b82a00B2651b42A13837204c5e3D92e27` / `0xa2db46c06e0B643A926ef60d1fEB744A7385a593`; Fraxtal `0xe8Cd13de17CeC6FCd9dD5E0a1465Da240f951536` / `0xDC3369C18Ff9C077B803C98b6260a186aDE9A426`; Arbitrum `0xf307Ad241E1035062Ed11F444740f108B8D036a6`; Base `0x22beDD55A0D29Eb31e75C70F54fADa7Ca94339B9`. Full multi-chain tables (incl. v1 `RemoteHop`/`MintRedeemHop`, now-paused v1) are in the repo README. FraxtalHopV2 on Fraxtal is also documented as `0x00000000e18aFc20Afe54d4B2C8688bB60c06B36` in the Tempo docs page — **note: this differs from the README's Fraxtal Hop address; the two may be different contracts (hub vs spoke) or a docs drift — verify on-chain.**

### Flox (Fraxtal)

No Flox contract addresses published in the repo README or found in docs during this pass. FloxConverter / FloxCapacitor / FxtlPoints / FraxStaker deployments exist on Fraxtal (chain 252) but their addresses are **unverified — gap** (recoverable from `broadcast/` deploy logs in the repo or Fraxscan).

---

## 3. Audit history

Source: official audits page https://docs.frax.com/protocol/security/audit (fetched 2026-11-14) + PDFs in `frax-solidity/src/audits/`.

| Date | Scope | Firm |
|---|---|---|
| Nov 2020 | Core (v1) | Certik |
| Jun 2021 | Core | Trail of Bits |
| Dec 2021 | Core | Trail of Bits |
| Apr 2022 | (Shipyard / Macro) | Shipyard / Macro |
| Aug 2022 | **Fraxswap & FPI** (+ Fraxlend in the same ToB engagement) | Trail of Bits |
| Sep 2022 | **frxETH** | Code4rena |
| Nov 2022 | **Fraxlend & Fraxferry** | Trail of Bits |
| Jan 2023 | **Fraxlend & veFPIS** | Trail of Bits |
| Jul 2023 | FrxGov | Trail of Bits |
| Oct 2023 | **FXB, sFRAX, frxETH Redemption Queue, Frax Oracles** | Trail of Bits |
| Jan 2024 | Fraxchain (Fraxtal) | Trail of Bits |
| Mar 2024 | **frxETH V2** (2 Criticals found, fixed+verified) | Frax Security Cartel |
| Apr 2024 | **Fraxtal, VestedFXS, Flox** | Frax Security Cartel |
| May 2024 | FPISLocker & FraxtalERC4626MintRedeemer; Curve AMO for frxETH V2 | Frax Security Cartel |
| Oct 2024 | BAMM | Certora |
| Mar 2025 | Fraxtal North Star | Frax Security Cartel |
| Jul 2025 | **frxUSD, frxUSDCustodian, FraxNetDeposit, RWARedemptionCoordinator** | Zellic |
| Jul 2025 | **FRAX, FXB, sfrxUSD update** | ChainSecurity |
| Sep 2025 | **Frax0 Mesh** (OFTs, RemoteCustodians, RemoteHop, FraxtalMinter) | Zellic |
| Oct 2026 | **Frax Router Multihop V2** (0 Critical/High, 1 Medium fixed) | Codespect |
| Oct 2026 | **Frax (USD Stablecoin)** | Zellic |
| Oct 2026 | **Frax (frxUSD Ecosystem)** | Zellic |

**Least recently reviewed (by system):**
- **Fraxlend — Jan 2023** (ToB), while the repo kept changing through **Nov 2025**. ~34 months of unaudited deltas. Least fresh review of any major live system.
- **Fraxswap core (TWAMM pairs) — Aug 2022** (ToB). Caveat: the live V2/router code moved to a private repo and the new Multihop V2 router was audited Oct 2026 — the *public* code's review age overstates staleness of the *live* system.
- **frxETH V1 + redemption queue + oracles — 2022/2023**, but these repos are **frozen** (no commits since 2023), so review age ≈ code age; low delta risk.
- **Flox — Apr 2024** (Security Cartel) + North Star Mar 2025 touched Fraxtal broadly. ~19 months since the dedicated review; repo HEAD Jul 2025.
- **Freshest:** frxUSD ecosystem / USD stablecoin / Multihop V2 router — all **Oct 2026** (Zellic ×2, Codespect). Frax0 Mesh Sep 2025. FraxNet Jul 2025. These are the worst audit targets on freshness grounds.

---

## 4. Audit options (ranked)

Ranking criteria: (a) value at risk, (b) freshness of prior review, (c) single-pass fit (code size + PoC feasibility on a mainnet fork from this VM).

**Fork RPC availability (verified read-only, 2026-11-14, `eth_chainId` only — no fork executed):**
- Ethereum mainnet: `https://ethereum-rpc.publicnode.com` → `0x1` ✓ works.
- Fraxtal (252): `https://rpc.frax.com` → `0xfc` ✓ works. (`https://rpc.fraxtal.io` did not respond.)
- Arbitrum One public RPCs returned HTTP 403 from this VM on 2026-11-13 (reported, not re-tested today) — **do not assume Arbitrum fork feasibility**; Fraxtal/L2 fork work should be validated with a live fork test before committing to an L2-heavy scope. Note Fraxtal fork feasibility looks plausible via rpc.frax.com but is **not proven** (a fork test was out of scope for this read-only pass).

### Option 1 — Fraxlend (RECOMMENDED)

- **Repo + HEAD:** `FraxFinance/fraxlend` @ `2bed49d4` (2025-11-12), 5,074 LOC / 39 files.
- **Why first:** smallest major system; stalest dedicated review (Jan 2023) against a HEAD nearly 3 years newer; lending markets are the classic theft-of-funds surface (oracle manipulation, liquidation logic, interest-rate math, ERC-4626 share-price inflation, deployer/registry access control). Every live pair holds user deposits; a pair-level bug is directly quantifiable.
- **PoC needs:** Ethereum mainnet fork via publicnode (verified reachable). Needs: canonical FraxlendPairDeployer/Registry addresses + one live high-TVL pair (unresolved in §2 — first audit step), oracle feeds for the chosen pair, and a funded-attacker setup (flash loans / whale impersonation via `deal`/`prank`). Single-chain fork only — the simplest PoC shape of the three options.
- **Caveats:** the newest code (2024–2025 commits) must be diffed against the Jan 2023 audited version first; any finding must be shown live on a *current* pair deployment, not just on repo HEAD. Peapods-style forks are out of scope (only Frax's own deployments count).

### Option 2 — HopV2 + OFT mesh (highest value at risk, hardest PoC)

- **Repos + HEADs:** `FraxFinance/fraxtal-lz-hop` @ `cb3240bb` (2026-11-03), hop/ 2,760 LOC; `FraxFinance/frax-oft-upgradeable` @ `6964529b` (2026-10-29), hand-written contracts 2,357 LOC.
- **Why second:** bridge code guards cross-chain value; HopV2 is the *newest* generation (replaced paused v1 RemoteHop) and postdates the Zellic Frax0 Mesh audit (Sep 2025), which covered the previous generation. Small hand-written surface, very fresh commits (days old) — the classic "new code, thin review" profile.
- **PoC needs:** the hard part. A theft PoC here is inherently cross-chain: LayerZero message flow (OFT send → `lzCompose` on Fraxtal → second leg), endpoint/DVN mocking, and either a two-chain fork (Ethereum + Fraxtal) or a mocked-LZ single-fork harness. Fraxtal RPC works for reads; fork-mode + impersonation on Fraxtal is unproven from this VM. Budget significant harness time; a purely local (non-fork) deployment of both sides with mocked endpoints may be the pragmatic PoC shape, but the bounty demands a *mainnet fork* reproduction — confirm harness viability before committing.
- **Caveats:** must establish which HopV2 addresses are live per chain (§2 discrepancy on the Fraxtal hub address); v1 contracts are paused and out of scope for live impact.

### Option 3 — FXB / Frax Bonds (small, simple, lower value at risk)

- **Repo + HEAD:** `FraxFinance/frax-bonds` @ `4ef235e6` (2025-07-09), contracts 3,133 LOC.
- **Why third:** tiny, self-contained, Ethereum-only; bond mint/redeem + SlippageAuction mechanics are easy to fork-test. But: reviewed Oct 2023 (ToB) *and* Jul 2025 (ChainSecurity, FXB + sfrxUSD upgrade), and the 2025 LFRAX upgrade walkthrough suggests recent attention; per-maturity value at risk is smaller than lending/bridge TVL; bond mechanics (deposit FRAX → mint FXB → redeem at maturity) have a narrow attack surface.
- **PoC needs:** Ethereum mainnet fork via publicnode; FXBFactory + one live maturity + SlippageAuction addresses from the README (§2, verified present). Simplest PoC of the three after Fraxlend.

### Considered and NOT recommended

- **Fraxswap core (public code):** TWAMM pair code last audited Aug 2022, but live development moved to private `dev-fraxswap`; the public subtree may not match live deployments, and the new Multihop V2 router was audited Oct 2026 (0 Critical/High). Deployment-correspondence risk too high without the private repo.
- **Flox (fraxtal-contracts):** 14,220 LOC, Fraxtal-only, last dedicated review Apr 2024. Viable as a 4th option, but FXTL points/conversion mechanics have lower direct theft surface than lending/bridge, and Fraxtal-fork PoC feasibility is unproven. Reconsider if Options 1–3 come back clean.
- **frxETH V1 / redemption queue / oracles:** frozen since 2023, multiply audited, tiny. Low delta risk; not worth a pass.
- **frxETH V2:** source private (`frxETH_V2`); audited Mar 2024 with 2 Criticals fixed. Cannot scope from public source.
- **FraxNet:** source private (`fraxnet-dev`); audited Jul 2025 (Zellic) + Oct 2026 (Zellic, frxUSD ecosystem). Cannot scope from public source; freshest review in the program.
- **sFRAX / sfrxUSD (staked-frax-erc4626):** public and small (4,759 LOC contracts), but audited Jul 2025 (ChainSecurity) and Oct 2026 (Zellic ×2). Freshness kills it as a target.
- **Fraxtal chain (fraxtal repo):** OP Stack fork; auditing Optimism's code is out of the spirit of this bounty (and 114k LOC).

---

## 5. Gaps — cannot be established from public sources

1. **Private repos:** FraxNet (`fraxnet-dev`), frxETH V2 (`frxETH_V2`), current Fraxswap V2 + Multihop V2 router (`dev-fraxswap`), `dev-staked-frax-erc4626`, `dev-fraxchain-contracts`. No public mirrors found. Audit of these systems would require per-address explorer-verified source retrieval.
2. **Canonical Fraxlend factory/registry addresses** on Ethereum (and per-chain pair inventories + per-pair TVL). Not in repo docs; must be established on-chain.
3. **Fraxswap router addresses** (incl. Multihop V2 deployment) and confirmation of which factory version is live per chain. Factory addresses in §2 are third-party-sourced, unverified.
4. **Flox deployment addresses** on Fraxtal (FloxConverter, FloxCapacitor, FxtlPoints, FraxStaker). Not published in docs/README found.
5. **FraxNetDeposit implementation addresses** behind factory-created proxies; the Fraxtal HopV2 hub-address discrepancy (§2).
6. **Current TVL / funds-at-risk per system.** No TVL figures are asserted in this report; DeFiLlama was not consulted and third-party TVL claims were not relied on. Quantifying value at risk per candidate system is a first step of any audit pass (on-chain balance reads on a fork).
7. **"Hop" scope reading.** This report treats "Hop" as Frax's own HopV2 contracts per Frax docs. If the team instead meant Hop Protocol contracts holding Frax value, that is a different (and likely out-of-reach) target — confirm only if a HopV2 finding is ever filed; do not contact the team pre-submission without an order.
8. **Fork-mode feasibility on Fraxtal** (impersonation, `deal`, cheatcodes against `rpc.frax.com`) and on Arbitrum (403s in Nov 2026) is unverified. A 5-minute fork smoke test is required before committing to any L2-heavy PoC.
9. **Deployment-vs-repo correspondence:** for every option, the audit must verify that the deployed bytecode matches the audited repo HEAD (Sourcify/Etherscan). Frax deploys from private `-dev` repos and publishes later; HEAD drift is a known pattern (e.g. Fraxswap V2 router absent from public HEAD).

---

## 6. Standing notes for the audit phase (if ordered)

- Single-pass adversarial audit per the `adversarial_code_audit` skill; Foundry PoCs on a mainnet fork; parent re-verifies decisive claims before any report.
- The bounty requires the adversarial self-check (frontier model asked to disprove) embedded in the gist — budget that step into any filing.
- No submission without a separate explicit order. No contact with the Frax team during audit.
- Exclusion lists: every finding in the §3 audit reports is a known issue — the audit must dedup against the 14 local PDFs in `frax-solidity/src/audits/` and the Zellic/Codespect/ChainSecurity reports before claiming novelty.
