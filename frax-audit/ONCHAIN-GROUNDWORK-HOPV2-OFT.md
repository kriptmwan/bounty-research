# Frax HopV2 + OFT mesh — On-chain groundwork (Phase 0B)

**Audit only. Read-only** (`eth_call` / `eth_getCode` / `eth_getBalance` / `eth_getStorageAt`,
Sourcify v2 API). No transactions, no signatures, no contact with the Frax team, no submission,
zero GitHub API calls. Etherscan was not used (Cloudflare-blocked).

| Item | Value |
|---|---|
| Repos (read-only) | `fraxtal-lz-hop` @ `cb3240bb3d644ee30267b20f2d8b82e5de559c55`; `frax-oft-upgradeable` @ `6964529b29b367d976d62a6df1efbbacb31d3205` |
| Probes | 2026-11-14, 11:38–12:20 WIB approx. |
| Balance snapshot | Ethereum block **26,410,898** (11:41:59 WIB); Fraxtal block **43,910,307** (11:42:05 WIB) |
| RPCs | Ethereum `https://ethereum-rpc.publicnode.com`; Fraxtal `https://rpc.frax.com`; other chains via the RPCs in `frax-oft-upgradeable/scripts/L0Config.json` plus publicnode/drpc fallbacks (all read-only, chain-id verified before use) |
| Machine-readable companion | `hopv2-oft-addresses.json` (301 entries) |

## Headline findings

1. **The README is stale: the live HopV2 mesh is a newer v2.0.1 rollout the repo does not
   describe.** The Fraxtal hub is `0x00000000e18aFc20Afe54d4B2C8688bB60c06B36` (the Tempo-docs
   address), **not** the README's `0xe8Cd13de17CeC6FCd9dD5E0a1465Da240f951536`, which is a
   decommissioned first-gen hub. Every spoke chain runs the **same** new spoke proxy
   `0x0000006d38568b00b457580b734e0076c62de659` (25 chains, all `paused=false`,
   `version()=2.0.1`, same implementation). The string `2.0.1` appears **nowhere** in
   `fraxtal-lz-hop` @ `cb3240bb`; its deploy scripts still point at the old hub.
2. **First-gen HopV2 and v1 RemoteHop are dead everywhere.** All 4 README HopV2 addresses and
   all 21 v1 RemoteHop/FraxtalHop addresses read `paused=true` with approvals revoked and
   routing config cleared (v1 matches the repo's `WinddownLegacyHop` signature exactly).
   Findings demonstrated only on these deployments do **not** meet the bounty bar
   (current live deployments only).
3. **MintRedeemHop (v1) is still live everywhere.** All 24 README MintRedeemHop addresses read
   `paused=false`. The winddown script explicitly excludes them. The Fraxtal one holds
   **599.22 frxETH** in native balance.
4. **Largest live escrows (on-chain reads only, §4):** Fraxtal WFRAX adapter
   **18,093,470.108182 WFRAX**; live hub native balance **637.17 frxETH**; Fraxtal
   MintRedeemHop native **599.22 frxETH**; Ethereum sfrxETH adapter 230.33 sfrxETH;
   Fraxtal frxETH adapter 213.18 frxETH. Mintable adapters (frxUSD/sfrxUSD) hold **0** —
   their risk is mint authority, not escrow.
5. **No fork risk found.** Every canonical address traces to Frax Safes / the Frax ProxyAdmin /
   Compound timelocks, with deployers matching the repos' known deployer EOAs (§5).
   `MockFraxOFT` is the only EOA-controlled deployment found; it is a test mock, excluded.
6. **Source gap (Hunter blocker):** the live v2.0.1 hub implementation
   (`0x00000000d25B8809150b59ce5dAE5699FfD26485`) and spoke implementation
   (`0x0000000f9a66622C8885E1071B78E37b2b3ecCCd`) are **unverified on Sourcify**.
   The repo source matches only the OLD hub (Sourcify-verified `FraxtalHopV2`). The Hunter
   phase must obtain v2.0.1 source (e.g. Fraxscan/Etherscan via browser) or audit from
   bytecode, and must not assume repo source == live code.

## 1. Hub discrepancy — RESOLVED

**Question:** README lists the Fraxtal Hop at
`0xe8Cd13de17CeC6FCd9dD5E0a1465Da240f951536`; Frax Tempo docs list FraxtalHopV2 on Fraxtal at
`0x00000000e18aFc20Afe54d4B2C8688bB60c06B36`. Same contract, hub-vs-spoke, or docs drift?

**Answer: neither — two successive hub deployments. The Tempo-docs address is the current live
hub; the README address is its decommissioned predecessor.** Both are Fraxtal-chain hub
contracts (both `localEid()=30255`, both proxies with admin = Frax ProxyAdmin). Evidence:

| Check (Fraxtal, read-only) | `0xe8Cd…1536` (README) | `0x00000000e18a…6B36` (Tempo docs) |
|---|---|---|
| Code present | Yes, 1,386 B proxy | Yes, 1,700 B proxy |
| EIP-1967 implementation | `0x6550284EA5dcb134a45a6F3c80afa2B30bc56fe9` (13,711 B) | `0x00000000d25B8809150b59ce5dAE5699FfD26485` (15,418 B) — different code |
| EIP-1967 admin | `0x223a…405c` (Frax ProxyAdmin) | `0x223a…405c` (Frax ProxyAdmin) |
| `paused()` | **true** | **false** |
| `version()` | (no such selector — reverts) | **`2.0.1`** |
| `localEid()` / `endpoint()` | 30255 / `0x1a44…728c` (LZ endpoint) | 30255 / `0x1a44…728c` |
| `numDVNs()` / `hopFee()` | 0 / 0 (cleared) | 5 / 0 |
| `approvedOft()` (6 Fraxtal OFTs) | all **false** | 5 **true**, FPI **false** |
| `remoteHop(eid)` sweep (31 EIDs) | **empty** (all zero) | **25 entries**, all = spoke `0x0000006d38568b00b457580b734e0076c62de659` |
| Native balance | 0 (+ 2.999088 frxUSD dust) | **637.172962645817391511 frxETH** |
| `DEFAULT_ADMIN_ROLE` members | old RemoteAdmin `0xDC33…`, Fraxtal msig `0x5f25…` | new RemoteAdmin `0x3402…`, Fraxtal msig `0x5f25…`, Safe `0xC4EB…` |
| `PAUSER_ROLE` members | 7 (incl. `0x13Fe…` carter) | 6 (same set minus carter) |
| Sourcify | impl **MATCH**: `FraxtalHopV2`, solc 0.8.23, verified 2026-07-17, deployer `0xb0E1650A9760e0f383174af042091fc544b8356f` | proxy + impl **no match** |
| Repo @ cb3240bb | `FRAXTAL_HOP` constant + README table point here | not referenced anywhere in the repo |

Corroboration: the live hub's `remoteHop(30101)` points at the Ethereum spoke
`0x0000006d38568b00b457580b734e0076c62de659`, whose `remoteHop(30255)` points back at the
Tempo-docs hub — a closed, live two-way link. The old hub has no live links at all. The same
pattern repeats on spokes: README HopV2 addresses on Ethereum/Arbitrum/Base are all
`paused=true` with approvals revoked, while the uniform new spoke is live on all 25 chains.

**Consequence for the Hunter phase:** target the Tempo-docs hub + uniform spoke (v2.0.1).
Treat all repo source as describing the OLD deployment until v2.0.1 source is obtained and
diffed. Do not cite README addresses as canonical without the "decommissioned" qualifier.

## 2. Live mesh map (v2.0.1)

One hub (Fraxtal) + one spoke address deployed identically on 25 chains. Spoke proxy code is
1,686 B everywhere; implementation `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` (slot-verified
on 23 chains; Tempo/Abstract verified by code + `paused=false` + `version()=2.0.1` only).
All spokes: `paused=false`, `version()=2.0.1`, `numDVNs=5` (read on Ethereum), `hopFee=0`
(read on Ethereum/Fraxtal), `remoteHop(30255)` = live hub (read on Ethereum; hub-side
`remoteHop` entries confirm the rest).

| Chain | ChainId | LZ EID | Spoke proxy admin (EIP-1967 slot) | RPC-verified |
|---|---|---|---|---|
| Ethereum | 1 | 30101 | `0x223a…405c` | full (roles/approvals/balances) |
| BSC | 56 | 30102 | `0x223a…405c` | code/paused/version/slots |
| Avalanche | 43114 | 30106 | `0x223a…405c` | code/paused/version/slots |
| Polygon | 137 | 30109 | `0x223a…405c` | code/paused/version/slots |
| Arbitrum | 42161 | 30110 | `0x223a…405c` | code/paused/version/slots |
| Optimism | 10 | 30111 | `0x223a…405c` | code/paused/version/slots |
| Celo | 42220 | 30125 | `0x000000dbfa…7428` | code/paused/version/slots |
| ZkSync | 324 | 30165 | `0xe59d…52f` | code/paused/version/slots (EraVM) |
| Linea | 59144 | 30183 | `0x3cf3…270` | code/paused/version/slots |
| Base | 8453 | 30184 | `0xF59C…53c5` | code/paused/version/slots |
| X-Layer | 196 | 30274 | `0x223a…405c` | code/paused/version/slots |
| Sei | 1329 | 30280 | `0x223a…405c` | code/paused/version/slots |
| Worldchain | 480 | 30319 | `0x223a…405c` | code/paused/version/slots |
| Unichain | 130 | 30320 | `0x223a…405c` | code/paused/version/slots |
| Abstract | 2741 | 30324 | (slot not read) | code/paused/version only |
| Sonic | 146 | 30332 | `0x223a…405c` | code/paused/version/slots |
| Ink | 57073 | 30339 | `0x223a…405c` | code/paused/version/slots |
| Hyperliquid | 999 | 30367 | `0x223a…405c` | code/paused/version/slots |
| Plume | 98866 | 30370 | `0x223a…405c` | code/paused/version/slots |
| Katana | 747474 | 30375 | `0x223a…405c` | code/paused/version/slots |
| Somnia | 5031 | 30380 | `0x000000dbfa…7428` | code/paused/version/slots |
| Monad | 143 | 30390 | `0xc287…21a` | code/paused/version/slots |
| Stable | 988 | 30396 | `0x223a…405c` | code/paused/version/slots |
| Tempo | 4217 | 30410 | (slot not read) | code/paused/version only |
| Robinhood | 4663 | 30416 | `0x000000dbfa…7428` | code/paused/version/slots |

Proxy admins match the `frax-oft-upgradeable` README ProxyAdmin table exactly (standard
`0x223a…405c` plus the Base/Linea/ZkSync/Monad/Tempo-group variants). Spoke proxy Sourcify:
MATCH `FraxUpgradeableProxy`, deployer `0x54F9b12743A7DeeC0ea48721683cbebedC6E17bC`
(checked on Ethereum, Polygon, Stable).

**Not in the live mesh:** Aurora (EID 30211) and Blast (30243) have no `remoteHop` entry on
the hub — Blast OFTs were deprecated at repo HEAD; Aurora holds only a mock deployment.
Non-EVM EIDs (Solana 30168, Aptos 30108, Movement 30362) also have no hub `remoteHop` entry.
Mode, Berachain, Polygon zkEVM, Scroll, Plasma hold OFT deployment files but no hub entry and
no spoke — legacy footprints, not live mesh members. **FPI is not hop-approved**: `approvedOft`
for the FPI adapter is `false` on both the live hub and the Ethereum spoke (the other five
OFTs are `true`). FPI bridging via Hop is disabled; direct OFT-level FPI sends were not
assessed.

**New RemoteAdmins** (discovered via `DEFAULT_ADMIN_ROLE` enumeration, confirmed by
`frxUsdOft()`/`hopV2()`/`fraxtalMsig()` reads): Fraxtal `0x34029e02821178B4387e12644896994f910D6E73`
(1,269 B), Ethereum `0x181EBC9deA868ED8e5EeeAef7f767D43BF390dFa` (1,225 B). Both point at
their chain's frxUSD adapter + live hop contract + the Fraxtal msig. New RemoteAdmins on the
other 23 spoke chains were not enumerated (spoke role members were read on Ethereum only).

## 3. Per-chain address tables

Verification levels: **FULL** = code + proxy slots + `paused`/`owner`/roles + `token()` +
balances read on-chain. **PARTIAL** = code + `paused` (+ slots/owner where noted). **FILE** =
extracted from repo files / README, README-consistent, not RPC-verified in this phase.
Sourcify values are from the v2 API (`match` / `exact_match` / `none` = checked, no match).

### 3a. Ethereum (chain 1) — FULL, block 26,410,898

| Address | Contract | Sourcify | Paused? | Owner / admin | Escrow / balances |
|---|---|---|---|---|---|
| `0x0000006d38568b00b457580b734e0076c62de659` | RemoteHopV2 spoke proxy (v2.0.1) | proxy match (`FraxUpgradeableProxy`); impl none | **false** | ProxyAdmin `0x223a…405c`; DEFAULT_ADMIN: Hop Admin Safe, OFT Admin Safe, new RemoteAdmin `0x181E…` | 0.037829148344050684 ETH; 0 of all 6 Frax tokens |
| `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | RemoteHopV2 impl (v2.0.1) | none | n/a | — | — |
| `0x181EBC9deA868ED8e5EeeAef7f767D43BF390dFa` | RemoteAdmin (new) | none | n/a | immutable pointers (§2) | 0 |
| `0xFd3B410b82a00B2651b42A13837204c5e3D92e27` | HopV2 first-gen proxy — DEAD | proxy none; impl none | **true** | ProxyAdmin; DEFAULT_ADMIN: old RemoteAdmin + Hop Admin Safe | 0 |
| `0xdFeDeC5Ce317245430C57AcE0Ce9Fb2a17AC0F6E` | HopV2 first-gen impl | none | n/a | — | — |
| `0xa2db46c06e0B643A926ef60d1fEB744A7385a593` | RemoteAdmin (old) | none | n/a | points at frxUSD adapter + dead hop | 0 |
| `0x3ad4dC2319394bB4BE99A0e4aE2AbF7bCEbD648E` | RemoteHop v1 — WOUND DOWN | match (`RemoteHop`) | **true** | OFT Admin Safe `0xB174…` | 0; config zeroed |
| `0x99B5587ab54A49e3F827D10175Caf69C0187bfA8` | RemoteMintRedeemHop v1 — LIVE | match (`RemoteMintRedeemHop`) | **false** | Hop Admin Safe `0x6cCF…` | 0.184930387685998716 ETH |
| `0x566a6442A5A6e9895B9dCA97cC7879D632c6e4B0` | frxUSD MintableAdapter proxy | proxy exact_match; impl exact_match (`FraxOFTMintableAdapterUpgradeable`) | n/a | frxUSD Upgrade Admin Safe `0xffffff4f…`; ProxyAdmin | 0 frxUSD (mint/burn) |
| `0x7311CEA93ccf5f4F7b789eE31eBA5D9B9290E126` | sfrxUSD MintableAdapter proxy | proxy exact_match; impl none | n/a | OFT Admin Safe; ProxyAdmin | 0 sfrxUSD (mint/burn) |
| `0x1c1649A38f4A3c5A0c4a24070f688C525AB7D6E6` | frxETH Adapter proxy (lockbox) | proxy exact_match; impl exact_match (`FraxOFTAdapterUpgradeable`) | n/a | OFT Admin Safe; ProxyAdmin | **141.48788 frxETH** |
| `0xbBc424e58ED38dd911309611ae2d7A23014Bd960` | sfrxETH Adapter proxy (lockbox) | proxy exact_match; impl exact_match (`FraxOFTAdapterUpgradeable`) | n/a | OFT Admin Safe; ProxyAdmin | **230.334628 sfrxETH** |
| `0x04ACaF8D2865c0714F79da09645C13FD2888977f` | WFRAX OFT proxy (token itself) | proxy exact_match; impl none | n/a | OFT Admin Safe; ProxyAdmin | supply 16,720,768.272642 WFRAX; holds 0 |
| `0x9033BAD7aA130a2466060A2dA71fAe2219781B4b` | FPI MintableAdapter proxy (inferred, §4) | proxy exact_match; impl none | n/a | OFT Admin Safe; ProxyAdmin | 0.305356 FPI (dust) |
| `0x223a681fc5c5522c85c96157c0efa18cd6c5405c` | FraxProxyAdmin | match (`FraxProxyAdmin`) | n/a | Timelock `0xb898…` | 0 |
| `0xb898Ad2976b4d8f2E21521C9db16b7497825E503` | Timelock (Compound-style) | exact_match (`Timelock`) | n/a | admin = frxUSD Upgrade Admin Safe; delay 24h | 0 |
| `0x8412ebf45bAC1B340BbE8F318b928C466c4E39CA` | Timelock (Compound-style) | match (`Timelock`) | n/a | admin = OFT Admin Safe; delay 48h | 0 |
| `0x909DBdE1eBE906Af95660033e478D59EFe831fED` | Legacy LFRAX lockbox | match (`FraxOFTAdapter`) | n/a | OFT Admin Safe | 73.93235 FRAX |
| `0xe4796cCB6bB5DE2290C417Ac337F2b66CA2E770E` | Legacy sFRAX lockbox | match (`StakedFraxOFTAdapter`) | n/a | OFT Admin Safe | **16,464.094405 sFRAX** |
| `0xF010a7c8877043681D59AD125EbF575633505942` | Legacy frxETH lockbox | match (`FraxEtherOFTAdapter`) | n/a | OFT Admin Safe | 0.21186 frxETH |
| `0x1f55a02A049033E3419a8E2975cF3F572F4e6E9A` | Legacy sfrxETH lockbox | match (`StakedFraxEtherOFTAdapter`) | n/a | OFT Admin Safe | 5.226813 sfrxETH |
| `0x23432452B720C80553458496D4D9d7C5003280d0` | Legacy FXS lockbox (README: "FRAX") | match (`FraxSharesOFTAdapter`) | n/a | OFT Admin Safe | **14,220.839929 FXS** |
| `0x6Eca253b102D41B6B69AC815B9CC6bD47eF1979d` | Legacy FPI lockbox | match (`FraxPriceIndexOFTAdapter`) | n/a | OFT Admin Safe | 0.8897 FPI |
| `0xC6F59a4fD50cAc677B51558489E03138Ac1784EC` | Deprecated FXS lockbox (proxy) | proxy exact_match | n/a | OFT Admin Safe | 0 FXS |
| `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | MockFraxOFT — EXCLUDED | proxy exact_match | n/a | EOA `0x45DC…` / admin EOA `0x8d82…` | mFRAX test token; not canonical |

OFT implementation addresses (EIP-1967 slot): frxUSD `0x175e4B98075c81511E476c0c5446ddA95d9106c8`;
sfrxUSD `0xF07571beDB8cbd98e6cA43B5Ee0fB178477d2219`; frxETH `0x742109450E2466421b00A2Bf61D513D2616a74FC`;
sfrxETH `0x9e951Dd846e748E6fCB58bFb76953c4900f819f4`; WFRAX `0x8b71237C759052C29A97408CE4b3B7cFebc525e0`;
FPI `0x2063961F26019B588F48007D1CC43770e8B7383C`; mock `0x7130176a1f87E29d2C4543f3bd3eDC245eA6b70D`.
All OFT proxies: `endpoint()` = LZ endpoint `0x1a44…728c`, `sharedDecimals()` = 6,
`approvalRequired()` = true except WFRAX OFT (false). Underlying tokens (§4): frxUSD
`0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29`, sfrxUSD `0xcf62F905562626CfcDD2261162a51fd02Fc9c5b6`,
frxETH `0x5E8422345238F34275888049021821E8E08CAa1f`, sfrxETH `0xac3E018457B222d93114458476f3E3416Abbe38F`,
FPI `0x5Ca135cB8527d76e932f34B5145575F9d8cbE08E`.

### 3b. Fraxtal (chain 252) — FULL, block 43,910,307

| Address | Contract | Sourcify | Paused? | Owner / admin | Escrow / balances |
|---|---|---|---|---|---|
| `0x00000000e18aFc20Afe54d4B2C8688bB60c06B36` | FraxtalHopV2 hub proxy (v2.0.1) — LIVE | proxy none; impl none | **false** | ProxyAdmin; DEFAULT_ADMIN: new RemoteAdmin, Fraxtal msig, Safe `0xC4EB…` | **637.172962645817391511 frxETH** native |
| `0x00000000d25B8809150b59ce5dAE5699FfD26485` | Hub impl (v2.0.1) | none | n/a | — | — |
| `0x34029e02821178B4387e12644896994f910D6E73` | RemoteAdmin (new) | none | n/a | immutable pointers (§2) | 0 |
| `0xe8Cd13de17CeC6FCd9dD5E0a1465Da240f951536` | FraxtalHopV2 first-gen proxy — DEAD | proxy none; impl match (`FraxtalHopV2`) | **true** | ProxyAdmin; DEFAULT_ADMIN: old RemoteAdmin + Fraxtal msig | 0 native; 2.999088 frxUSD dust |
| `0x6550284EA5dcb134a45a6F3c80afa2B30bc56fe9` | First-gen hub impl | match (`FraxtalHopV2`) | n/a | — | — |
| `0xDC3369C18Ff9C077B803C98b6260a186aDE9A426` | RemoteAdmin (old) | match (`RemoteAdmin`) | n/a | points at frxUSD adapter + dead hub | 0 |
| `0x2A2019b30C157dB6c1C01306b8025167dBe1803B` | FraxtalHop v1 — WOUND DOWN | none | **true** | Fraxtal msig Safe `0x5f25…` | 0 native; 0.01 sfrxUSD dust |
| `0x3e6a2cBaFD864e09e6DAb9Cf035a0AbEa32bc0BC` | FraxtalMintRedeemHop v1 — LIVE | none | **false** | Fraxtal msig Safe `0x5f25…` | **599.22086056610333038 frxETH** native + dust |
| `0x96A394058E2b84A89bac9667B19661Ed003cF5D4` | frxUSD MintableAdapter proxy | proxy exact_match; impl exact_match (`FraxOFTMintableAdapterUpgradeable`) | n/a | Fraxtal msig; ProxyAdmin | 0 frxUSD (mint/burn) |
| `0x88Aa7854D3b2dAA5e37E7Ce73A1F39669623a361` | sfrxUSD MintableAdapter proxy | proxy none; impl exact_match (`FraxOFTMintableAdapterUpgradeable`) | n/a | Fraxtal msig; ProxyAdmin | 0 sfrxUSD (mint/burn) |
| `0x9aBFE1F8a999B0011ecD6116649AEe8D575F5604` | frxETH Adapter proxy (lockbox) | proxy none; impl none | n/a | Fraxtal msig; ProxyAdmin | **213.182015 frxETH** |
| `0x999dfAbe3b1cc2EF66eB032Eea42FeA329bBa168` | sfrxETH Adapter proxy (lockbox) | proxy none; impl none | n/a | Fraxtal msig; ProxyAdmin | **165.126385 sfrxETH** |
| `0xd86fBBd0c8715d2C1f40e451e5C3514e65E7576A` | WFRAX Adapter proxy (lockbox) | proxy none; impl none | n/a | Fraxtal msig; ProxyAdmin | **18,093,470.108182 WFRAX** |
| `0x75c38D46001b0F8108c4136216bd2694982C20FC` | FPI MintableAdapter proxy | proxy none; impl exact_match (`FraxOFTMintableAdapterUpgradeable`) | n/a | Fraxtal msig; ProxyAdmin | 1.333073 FPI (dust) |
| `0x223a681fc5c5522c85c96157c0efa18cd6c5405c` | FraxProxyAdmin | none | n/a | Safe `0xC4EB45d80DC1F079045E75D5d55de8eD1c1090E6` (3-of-5) | 0 |
| `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | MockFraxMintableOFT — EXCLUDED | none | n/a | EOA `0x45DC…` / admin EOA `0x8d82…` | mFRAX test token; not canonical |

OFT implementation addresses: frxUSD `0x8861AB8683CfD1FCC84327415888B870aB144f51`;
sfrxUSD `0xE0c5294bfb2355d7Ae36AD7a3387A2c902fb26a8`; frxETH `0xeB904DaDce7493D23500e96115B4EFF038756Cfc`;
sfrxETH `0x773a166030C08C72c42D0cb38f9e3A0dE5A112c6`; WFRAX `0x369f71356e0d0E102C2434DaC92603aFbF9ee82A`;
FPI `0x17f173e0D487dfaD794B528dA2830095Ca302dc7`. Underlying tokens are the Fraxtal system
addresses: frxUSD `0xFc00000000000000000000000000000000000001`, WFRAX `…02`, FPI `…03`,
sfrxETH `…05`, frxETH `…06`, sfrxUSD `…08` (all 18 decimals, `token()`-confirmed).

### 3c. Other chains — hop status (PARTIAL, all RPC-verified)

Spoke = `0x0000006d38568b00b457580b734e0076c62de659` on every chain (see §2). v1 = README
RemoteHop, MR = README MintRedeemHop. Code sizes are proxy/contract runtime bytes as read;
ZkSync sizes are EraVM bytecode and not comparable.

| Chain | v1 RemoteHop paused? (code) | MintRedeemHop paused? (code) | Old HopV2 paused? |
|---|---|---|---|
| Sei | true (14,021 B) | false (11,774 B) | — |
| X-Layer | true (14,021 B) | false (11,774 B) | — |
| Sonic | true (14,021 B) | false (11,774 B) | — |
| Ink | true (14,021 B) | false (11,774 B) | — |
| Arbitrum | true (14,021 B) | false (11,774 B) | true (1,386 B) |
| Optimism | true (14,021 B) | false (11,774 B) | — |
| Polygon | true (14,021 B) | false (11,774 B) | — |
| Avalanche | true (14,021 B) | false (11,774 B) | — |
| BSC | true (14,021 B) | false (11,774 B) | — |
| Base | true (14,055 B) | false (11,808 B) | true (1,386 B) |
| Linea | true (14,021 B) | false (11,774 B) | — |
| Worldchain | true (14,055 B) | false (11,808 B) | — |
| Unichain | true (14,055 B) | false (11,808 B) | — |
| Plume | true (13,144 B) | false (10,972 B) | — |
| Katana | true (13,693 B) | false (11,521 B) | — |
| Hyperliquid | true (13,693 B) | false (11,521 B) | — |
| Monad | true (13,413 B) | false (11,241 B) | — |
| Stable | true (13,413 B) | false (11,241 B) | — |
| Somnia | n/a (no v1 entry) | false (6,563 B) | — |
| Robinhood | n/a (no v1 entry) | false (6,563 B) | — |
| Celo | n/a (no v1 entry) | false (6,563 B) | — |
| ZkSync | true (47,456 B EraVM) | false (32,672 B EraVM) | — |
| Tempo | (no README v1 entry) | (no README entry) | — |
| Abstract | (no README v1 entry) | (no README entry) | — |

Pattern is uniform without exception: **v1 paused, MintRedeemHop live, new spoke live.**
v1 `owner()` was read on 8 chains (Sei, Arbitrum, BSC, Base, Unichain, Hyperliquid + Ethereum
+ Fraxtal) and matched the README msig list in every case. The 6,563 B MintRedeemHops on
Somnia/Robinhood/Celo are a smaller bytecode variant (different deployment generation);
their `paused=false` and code presence are confirmed, internals not compared.

### 3d. OFT deployments on other chains (FILE + samples)

`deployments/` holds **193 files**: 140 EVM non-mock files (138 distinct deployments + 2
duplicate `FraxOFTUpgradeable` files) collapsing to **36 unique addresses** (CREATE2 reuse),
27 EVM mock files, 18 Aptos/Movement entries (32-byte account ids, non-EVM) and 8 Solana
files (`address: null`, PDAs in README). Deployment JSONs contain **only `address` + `abi`** — no proxy/implementation
distinction in the files. The deploy scripts prove every OFT address is a
`TransparentUpgradeableProxy` behind `FraxProxyAdmin`; implementations were read from the
EIP-1967 slot on Ethereum/Fraxtal only.

Address sets (all six tokens per chain; full per-chain table in Appendix A):

- **Standard set** (17 chains: Optimism, BSC, Unichain, Polygon, Sonic, X-Layer, Worldchain,
  Polygon zkEVM, Sei, Mode, Arbitrum, Avalanche, Ink, Berachain, Blast, Plume, Katana): frxUSD `0x80Eede496655FB9047dd39d9f418d5483ED600df`,
  sfrxUSD `0x5Bff88cA1442c2496f7E475E9e7786383Bc070c0`, frxETH `0x43eDD7f3831b08FE70B7555ddD373C8bF65a9050`,
  sfrxETH `0x3Ec3849C33291a9eF4c5dB86De593EB4A37fDe45`, WFRAX `0x64445f0aecC51E94aD52d8AC56b7190e764E561a`,
  FPI `0x90581eCa9469D8D7F5D3B60f4715027aDFCf7927`.
- **ZkSync/Abstract set**: frxUSD `0xEa77c590Bb36c43ef7139cE649cFBCFD6163170d`, sfrxUSD
  `0x9F87fbb47C33Cd0614E43500b9511018116F79eE`, frxETH `0xc7Ab797019156b543B7a3fBF5A99ECDab9eb4440`,
  sfrxETH `0xFD78FD3667DeF2F1097Ed221ec503AE477155394`, WFRAX `0xAf01aE13Fb67AD2bb2D76f29A83961069a5F245F`,
  FPI `0x580F2ee1476eDF4B1760bd68f6AaBaD57dec420E`.
- **Base set**: frxUSD `0xe5020A6d073a794B6E7f05678707dE47986Fb0b6`, sfrxUSD
  `0x91A3f8a8d7a881fBDfcfEcd7A2Dc92a46DCfa14e`, frxETH `0x7eb8d1E4E2D0C8b9bEDA7a97b305cF49F3eeE8dA`,
  sfrxETH `0x192e0C7Cc9B263D93fa6d472De47bBefe1Fb12bA`, WFRAX `0x0CEAC003B0d2479BebeC9f4b2EBAd0a803759bbf`,
  FPI `0xEEdd3A0DDDF977462A97C1F0eBb89C3fbe8D084B`.
- **Linea set**: frxUSD `0xC7346783f5e645aa998B106Ef9E7f499528673D8`, sfrxUSD
  `0x592a48c0FB9c7f8BF1701cB0136b90DEa2A5B7B6`, frxETH `0xB1aFD04774c02AE84692619448B08BA79F19b1ff`,
  sfrxETH `0x383Eac7CcaA89684b8277cBabC25BCa8b13B7Aa2`, WFRAX `0x5217Ab28ECE654Aab2C68efedb6A22739df6C3D5`,
  FPI `0xDaF72Aa849d3C4FAA8A9c8c99f240Cf33dA02fc4`.
- **Tempo/Somnia/Robinhood set** (README-only, no `deployments/` files, not RPC-verified):
  frxUSD `0x00000000D61733e7A393A10A5B48c311AbE8f1E5`, sfrxUSD `0x00000000fD8C4B8A413A06821456801295921a71`,
  frxETH `0x000000008c3930dCA540bB9B3A5D0ee78FcA9A4c`, sfrxETH `0x00000000883279097A49dB1f2af954EAd0C77E3c`,
  WFRAX `0x00000000E9CE0f293D1Ce552768b187eBA8a56D4`; plus Tempo `FrxUSDPolicyAdminTempo`
  `0x766c2BD9C6dDc5BeE9ACd7D4C8ADD5b969952969` and frxUSD TIP20 `0x20C0000000000000000000003554d28269E0f3c2`.

Sourcify samples on spoke chains: Arbitrum frxUSD + WFRAX proxies MATCH
(`TransparentUpgradeableProxy`, deployer `0x9C9d…`); Base frxUSD proxy exact_match; Linea
frxUSD proxy MATCH; ZkSync + Sonic frxUSD proxies no match (coverage gap, not evidence of
absence). **Gaps:** `deployments/` has mock-only dirs for Hyperliquid, Aurora, Scroll and
Plasma (no production OFT files) although Hyperliquid is a live-mesh chain — the README
standard set is the operative record there. OFT impl slots, owners and token supplies on
spoke chains were NOT read in this phase.

## 4. OFT model classification + escrow quantification

Three models (README design, confirmed on-chain via `token()`, `approvalRequired()`,
implementation names/sizes, and balances):

| Model | Behavior | Holds escrow? | Instances (verified) |
|---|---|---|---|
| **OFT** (`FraxOFTUpgradeable` / `WFRAXTokenOFTUpgradeable`) | The proxy IS the ERC20; mint on receive, burn on send. `token()` returns self, `approvalRequired()` false | No | WFRAX on Ethereum; all six tokens on spoke chains (per README design; spoke-chain balances not read) |
| **Adapter / lockbox** (`FraxOFTAdapterUpgradeable`) | Holds the underlying token; releases on receive, collects on send | **Yes — escrow at risk** | frxETH + sfrxETH on Ethereum; frxETH + sfrxETH + WFRAX on Fraxtal |
| **MintableAdapter** (`FraxOFTMintableAdapterUpgradeable`) | Mints/burns the underlying via `minter_mint` / `minter_burn_from`; holds ~0 | No — risk is **mint authority** | frxUSD + sfrxUSD on Ethereum and Fraxtal; FPI on Fraxtal (impl name verified); FPI on Ethereum **inferred** (13,245 B impl size class = mintable; plain adapters are 11,829 B on Ethereum; 0.305 FPI dust balance; Fraxtal twin verified mintable) |

### Exact on-chain balances (no third-party figures)

Ethereum, block 26,410,898 (11:41:59 WIB). All tokens 18 decimals.

| Holder | Token | Balance (exact wei) | Balance (tokens) |
|---|---|---|---|
| frxETH Adapter `0x1c16…D6E6` | frxETH | 141487880000000000000 | 141.48788 |
| sfrxETH Adapter `0xbBc4…960` | sfrxETH | 230334628000000000000 | 230.334628 |
| FPI Adapter `0x9033…B4b` | FPI | 305356000000000000 | 0.305356 |
| frxUSD MintableAdapter | frxUSD | 0 | 0 |
| sfrxUSD MintableAdapter | sfrxUSD | 0 | 0 |
| WFRAX OFT (self) | WFRAX | 0 (supply 16720768272642000000000000) | 0 (supply 16,720,768.272642) |
| Legacy LFRAX lockbox | FRAX | 73932350000000000000 | 73.93235 |
| Legacy sFRAX lockbox | sFRAX | 16464094405000000000000 | 16,464.094405 |
| Legacy frxETH lockbox | frxETH | 211860000000000000 | 0.21186 |
| Legacy sfrxETH lockbox | sfrxETH | 5226813000000000000 | 5.226813 |
| Legacy FXS lockbox | FXS | 14220839929000000000000 | 14,220.839929 |
| Legacy FPI lockbox | FPI | 889700000000000000 | 0.8897 |
| Deprecated FXS lockbox | FXS | 0 | 0 |
| RemoteMintRedeemHop v1 | ETH (native) | 184930387685998716 | 0.184930387685998716 |
| New spoke | ETH (native) | 37829148344050684 | 0.037829148344050684 |
| All other probed Eth holders | (all 9 tokens + native) | 0 | 0 |

Fraxtal, block 43,910,307 (11:42:05 WIB). Native balance unit is frxETH (18 decimals).

| Holder | Token | Balance (exact wei) | Balance (tokens) |
|---|---|---|---|
| WFRAX Adapter `0xd86f…576A` | WFRAX | 18093470108182000000000000 | **18,093,470.108182** |
| frxETH Adapter `0x9aBF…5604` | frxETH | 213182015000000000000 | 213.182015 |
| sfrxETH Adapter `0x999d…168` | sfrxETH | 165126385000000000000 | 165.126385 |
| FPI Adapter `0x75c3…20FC` | FPI | 1333073000000000000 | 1.333073 |
| frxUSD / sfrxUSD MintableAdapters | frxUSD / sfrxUSD | 0 / 0 | 0 / 0 |
| Live hub `0x00000000e18a…` | frxETH (native) | 637172962645817391511 | **637.172962645817391511** |
| FraxtalMintRedeemHop v1 | frxETH (native) | 599220860566103330380 | **599.22086056610333038** |
| Old hub (dead) | frxUSD | 2999088000000000000 | 2.999088 (dust) |
| FraxtalHop v1 (dead) | sfrxUSD | 10000000000000000 | 0.01 (dust) |
| FraxtalMintRedeemHop v1 | frxUSD / sfrxUSD | 626607547429906 / 588900663854127 | 0.000627 / 0.000589 (dust) |
| All adapters | frxETH (native) | 0 | 0 |

**Top escrows, ranked within their own units** (no USD conversion — no price source was
consulted, per task): (1) Fraxtal WFRAX adapter, 18.09M WFRAX (~48% of the 37,535,851.09
Fraxtal WFRAX supply); (2) live hub native, 637.17 frxETH; (3) Fraxtal MintRedeemHop native,
599.22 frxETH; (4) legacy sFRAX lockbox, 16,464.09 sFRAX; (5) legacy FXS lockbox, 14,220.84
FXS. The two ~600-frXETH native balances are the largest single-contract native holdings in
the mesh; both contracts expose owner-only recovery (`recover` / `recoverETH`), so the
bounty-relevant question for the Hunter phase is whether a non-admin path can move them or
brick the contracts holding them — not the admin path itself.

Underlying token supplies (context, same blocks): Ethereum frxUSD 84,879,455.45; sfrxUSD
32,299,570.01; frxETH 59,977.58; sfrxETH 37,082.54; FPI 5,889,909.18; FRAX (0x853d…) 219,173,039.72;
sFRAX 56,154,306.55; FXS (0x3432…) 99,681,495.59. Fraxtal frxUSD 8,935,631.80; WFRAX
37,535,851.09; FPI 5,190,426.40; sfrxETH 1,677.78; frxETH 3,223.71; sfrxUSD 18,484,296.58.

## 5. Admin / control tracing + fork-risk verdict

**Verdict: no unverified-fork risk among canonical addresses.** Every live or dead canonical
contract traces to Frax-controlled Safes, the Frax ProxyAdmin, or Compound timelocks whose
admins are those Safes. No Peapods-style fork deployments were encountered in either repo's
deployment records, and no probed address had an owner/admin outside the Frax set below —
except the mock (excluded).

| Control point | Address | Evidence |
|---|---|---|
| OFT Admin Safe (Ethereum) | `0xB1748C79709f4Ba2Dd82834B8c82D4a505003f27` | Safe 1.3.0, 3-of-5; owns 5/6 Eth OFT adapters + all legacy lockboxes + v1 RemoteHop; admin of timelock `0x8412…`; DEFAULT_ADMIN member of Eth spoke |
| Hop Admin Safe (Ethereum) | `0x6cCF3F2Ca29591F90ADB403D67E4dcB49cEcC634` | Safe 1.4.1, 3-of-6; owns Eth MintRedeemHop; DEFAULT_ADMIN member of old + new Eth hops |
| frxUSD Upgrade Admin Safe | `0xffffff4f3bac444b2c0ecf2a1840d018be783937` | Owns Eth frxUSD MintableAdapter; admin of timelock `0xb898…` |
| Fraxtal msig Safe | `0x5f25218ed9474b721d6a38c115107428E832fA2E` | Safe 1.3.0, 3-of-6; owns all 6 Fraxtal OFT adapters + v1 hops; DEFAULT_ADMIN member of both Fraxtal hubs |
| Fraxtal upgrade Safe | `0xC4EB45d80DC1F079045E75D5d55de8eD1c1090E6` | Safe 1.3.0, 3-of-5 (team owners); owns Fraxtal ProxyAdmin; DEFAULT_ADMIN member of live hub |
| ProxyAdmin (most chains) | `0x223a681fc5c5522c85c96157c0efa18cd6c5405c` | `FraxProxyAdmin`, deployer `0x9C9dD956b413cdBD81690c9394a6B4D22afe6745` (= README `PK_OFT_DEPLOYER`); owner = timelock `0xb898…` (Eth) / Safe `0xC4EB…` (Fraxtal) |
| Timelock `0x8412…` (task-supplied) | `0x8412ebf45bAC1B340BbE8F318b928C466c4E39CA` | Compound `Timelock`, admin = OFT Admin Safe, delay 48h. **No Hop/OFT proxy traces directly to it** in this phase; it anchors Frax control via the OFT Admin Safe, not via direct proxy ownership |
| Timelock `0xb898…` | `0xb898Ad2976b4d8f2E21521C9db16b7497825E503` | Compound `Timelock`, admin = frxUSD Upgrade Admin Safe, delay 24h; owns Ethereum ProxyAdmin |
| Pausers (7 old / 6 new) | `0x13Fe…`, `0x17e0…`, `0x8d82…`, `0xcbc6…`, `0x381e…`, `0x6e74…`, `0xC6EF…` | Team EOAs named in deploy scripts (carter/sam/dhruvin/travis/thomas/nader/dennis); carter holds PAUSER only on the old deployments |
| Deployers (Sourcify) | `0xb0E1650A…`, `0x0990be6d…`, `0x9C9dD956…`, `0x54F9b127…`, `0xDed88443…`, `0x1D3bE58f…` | First three = README deployer EOAs; `0x54F9…` deployed the v2.0.1 spoke proxies (new rollout deployer); last two = legacy lockbox deployers |

Safe owner sets overlap heavily (same team EOAs across all Safes). Chain msigs on spoke chains
match the README msig list wherever `owner()` was read. **Excluded:** `MockFraxOFT`
(`0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8`, owner EOA `0x45DCE8e4F2Dc005A5F28206A46cb034697eEDA8e`,
proxy admin EOA `0x8d8290d49e88D16d81C6aDf6C8774eD88762274A`) — a test deployment, not a fork,
not canonical, never to be presented as a target.

## 6. Reference targets — Hunter shortlist

Prioritized by: live + unpaused + funds at rest or mesh-wide blast radius + bounty bar
(demonstrated theft/bricking on current live deployments).

1. **Live Fraxtal hub** — proxy `0x00000000e18aFc20Afe54d4B2C8688bB60c06B36`, impl
   `0x00000000d25B8809150b59ce5dAE5699FfD26485` (Fraxtal). *Why:* single routing hub for all
   25 spokes; unpaused; 637.17 frxETH at rest; `recover()` + role admin + `lzCompose`
   handling all live. *Blocker:* v2.0.1 source unverified — obtain before/while hunting.
2. **Uniform spoke** — proxy `0x0000006d38568b00b457580b734e0076c62de659`, impl
   `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` (all 25 chains; hunt on Ethereum/Fraxtal
   fork + one cheap spoke chain). *Why:* one implementation everywhere — a single bug is
   mesh-wide; 5 OFTs approved; compose path (`lzCompose` → `hopCompose` → RemoteAdmin
   arbitrary call) is the highest-leverage surface. *Blocker:* same v2.0.1 source gap.
3. **Fraxtal WFRAX Adapter (lockbox)** — proxy `0xd86fBBd0c8715d2C1f40e451e5C3514e65E7576A`,
   impl `0x369f71356e0d0E102C2434DaC92603aFbF9ee82A` (Fraxtal). *Why:* largest escrow in the
   mesh (18.09M WFRAX); plain lockbox — theft = drain; impl source unverified but behavior
   matches verified `FraxOFTAdapterUpgradeable` twins on Ethereum. Include the Fraxtal
   frxETH/sfrxETH adapters (213.18 / 165.13) and Ethereum frxETH/sfrxETH adapters
   (141.49 / 230.33) as the same lockbox family.
4. **FraxtalMintRedeemHop v1 + remote MintRedeemHops** — Fraxtal
   `0x3e6a2cBaFD864e09e6DAb9Cf035a0AbEa32bc0BC`, Ethereum
   `0x99B5587ab54A49e3F827D10175Caf69C0187bfA8`, + 22 more (all live). *Why:* live v1 code
   path excluded from winddown; 599.22 frxETH at rest on Fraxtal; frxUSD↔sfrxUSD mint/redeem
   via lockboxes; deployed bytecode **predates repo source** (winddown header: deployed
   `recoverETH` is `transfer()`, repo has `call`) and is Sourcify-unmatched on Fraxtal —
   source drift is itself a hunting consideration. Bricking here strands in-flight
   mint/redeem composes (repo notes v1 `setMessageProcessed` is broken: `abi.encodePacked`
   vs `abi.encode`).

**Second tier:** MintableAdapters (frxUSD/sfrxUSD both chains + FPI) — hunt the mint/burn
authority path (`minter_mint`/`minter_burn_from`, peer/config trust), not escrow; legacy
lockboxes (16,464 sFRAX + 14,221 FXS escrows, Sourcify-verified old adapter code, Stargate
unlock path) — real funds, legacy surface, lower priority.

**Do NOT target:** first-gen HopV2 (4), v1 RemoteHop/FraxtalHop (21), MockFraxOFT, or any
address outside §§2–3. A finding that only reproduces on a paused/decommissioned deployment
does not meet the live-deployment bar. Note the repo's own warning: pausing/clearing the v1
hub bricks in-flight composes irrecoverably — the Hunter phase must not propose state
changes to live contracts; all demonstration stays in forks.

## 7. Gaps, caveats, and Hunter prerequisites

- **v2.0.1 source unavailable via Sourcify** (hub impl, spoke impl, new RemoteAdmins, several
  OFT impls). Fraxscan's Blockscout API returned a redirect/404 from this VM; Etherscan is
  Cloudflare-blocked. Parent should arrange a browser check of Fraxscan/Etherscan verified
  source for `0x00000000d25B8809150b59ce5dAE5699FfD26485` and
  `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` before the Hunter phase leans on repo source.
- **OFT spoke chains:** impl slots, owners, supplies and balances were read on Ethereum +
  Fraxtal only. Spoke-chain OFT entries in the JSON are file-extracted (README-consistent)
  with 6 Sourcify proxy samples. Hunter must read impl slots per target chain.
- **Tempo/Abstract spokes:** code + `paused` + `version` only; impl/admin slots and roles not
  read. New RemoteAdmins on non-Ethereum/Fraxtal spokes not enumerated.
- **No log/tx-history tracing** was done (no event scans, no deploy-tx analysis beyond
  Sourcify `deployment` fields). Decommissioning transactions for first-gen HopV2 were not
  traced; "decommissioned" is the observed on-chain state (paused + cleared + zeroed), not a
  traced admin history.
- **FPI-on-Ethereum model is inferred** (impl size class + dust + verified Fraxtal twin),
  not Sourcify-confirmed. Confirm by impl codehash comparison in the Hunter phase.
- **Provenance note:** a VM restart during this phase wiped `/tmp`, including raw probe JSONs
  for the Ethereum/Fraxtal deep probes and the first multi-chain passes. All values in this
  report were transcribed from the captured probe outputs (preserved in the task transcript);
  the C3 retry, probe-D slot fills, Sourcify sweep outputs and probe scripts survive under
  `work/`. Re-verification of any single value is one read-only call; the balance snapshot
  blocks above pin the figures.
- **Fraxtal fork-mode is unproven** (per task brief) — no fork was attempted; all reads are
  direct RPC. The Hunter phase owns fork/POC decisions.
- **ZkSync** reads succeeded via drpc; EraVM bytecode sizes are not comparable with EVM sizes.
- **No prices, no TVL:** all figures are raw on-chain token amounts. Any USD framing in later
  phases needs its own sourcing and must not be attributed to this phase.

## Appendix A — OFT deployments by chain (from `deployments/`, non-mock EVM files)

Columns: frxUSD | sfrxUSD | frxETH | sfrxETH | WFRAX | FPI. `—` = no file. Standard set =
`0x80Ee…`, `0x5Bff…`, `0x43eD…`, `0x3Ec3…`, `0x6444…`, `0x9058…` (full addresses in §3d);
ZkSync set = `0xEa77…`, `0x9F87…`, `0xc7Ab…`, `0xFD78…`, `0xAf01…`, `0x580F…`.

| Chain (id) | Set |
|---|---|
| Ethereum (1) | per-chain adapters + WFRAX OFT — see §3a |
| Optimism (10) | standard |
| BSC (56) | standard |
| Unichain (130) | standard |
| Polygon (137) | standard |
| Sonic (146) | standard |
| X-Layer (196) | standard |
| Fraxtal (252) | per-chain adapters — see §3b |
| ZkSync (324) | ZkSync set |
| Worldchain (480) | standard |
| Polygon zkEVM (1101) | standard |
| Sei (1329) | standard |
| Abstract (2741) | ZkSync set |
| Base (8453) | Base set — see §3d |
| Mode (34443) | standard |
| Arbitrum (42161) | standard |
| Avalanche (43114) | standard (+ duplicate `FraxOFTUpgradeable` file = sfrxUSD proxy) |
| Ink (57073) | standard |
| Linea (59144) | Linea set — see §3d |
| Berachain (80094) | standard |
| Blast (81457) | standard (deprecated) |
| Plume (98866) | standard |
| Katana (747474) | standard |
| Hyperliquid (999) | — (mock-only dir; README: standard set) |
| Aurora (1313161554) | — (mock-only dir) |
| Scroll (534352) | — (mock-only dir) |
| Plasma (9745) | — (mock-only dir) |
| Tempo (4217) / Somnia (5031) / Robinhood (4663) | Tempo set, README-only — see §3d |

Duplicate-file note: `deployments/ethereum-mainnet/FraxOFTUpgradeable.json` = WFRAX proxy
`0x04AC…`; `deployments/avalanche-mainnet/FraxOFTUpgradeable.json` = sfrxUSD proxy `0x5Bff…`.
Neither is a distinct deployment. Non-EVM: Aptos + Movement hold 9 account ids each (same
set, 32-byte hex); Solana files carry `address: null` with OFT store PDAs documented in the
README (§Solana) — out of scope for EVM groundwork.

## Appendix B — Probe inventory

- Probe scripts (surviving): `work/probe-phase0b-C3.cjs`, `work/probe-phase0b-D.cjs`,
  `work/sourcify-sweep.cjs`, `work/gen-addresses-json.py`. Earlier probe scripts/outputs were
  lost with `/tmp` in a VM restart; their outputs are transcribed into this report and
  `work/probe-evidence-consolidated.json`.
- Sourcify sweep: 75 checks (`work/sourcify-phase0b.json` + `.log`).
- OFT inventory: `work/oft-deployments.txt` (193 files).
- RPC verification totals: **33 addresses FULL** on Ethereum/Fraxtal (code/slots/views/
  balances incl. impls, timelocks, legacy); **25/25 spokes + 21/21 v1 hops + 24/24
  MintRedeemHops + 4/4 old HopV2** code-and-paused verified across 26 chains (Fraxtal hub +
  25 spoke chains); **75 Sourcify checks (37 matched)**. No chain in the live mesh is unverified: every
  spoke chain had at least code + `paused()` + `version()` read from a chain-id-verified RPC.
