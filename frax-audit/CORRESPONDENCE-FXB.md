# Phase 0C — Deployed-Bytecode Correspondence: Frax FXB / Frax Bonds

- **Repo (read-only):** `~/workspace/frax-audit/repos/frax-bonds` @ `4ef235e68c8277ad3dbc676762fffe663c9896fc` (verified clean, `git status` empty at end of phase).
- **Chains:** Ethereum mainnet (chain 1) **and** Fraxtal (chain 252). The task named chain 1, but the repo's script/Constants addresses are a second, disjoint Fraxtal deployment; both are classified here, chain-labelled throughout. Mainnet and Fraxtal registries share no contract addresses.
- **Inputs:** task-known addresses + `src/script/LFRAX_FXB_Upgrade/JSONs/*.json` + `src/Constants.sol` + `LFRAXUpgradeSharedState.sol` + Phase 0B inventory (`fxb-addresses.json`, `ONCHAIN-GROUNDWORK-FXB.md`, which appeared mid-phase and were fully incorporated — see §8).
- **Methods (read-only only):** Sourcify v2 HTTP API via curl (`?fields=deployment,sources,abi,metadata`, comma-separated — the pipe form in the brief is rejected by Sourcify with `invalid_parameter`); `eth_call` / `eth_getCode` / `eth_getStorageAt` / `eth_getLogs` / `eth_getBlockByNumber` via `https://ethereum-rpc.publicnode.com` (mainnet, tip ~block 26,411,5xx) and `https://fraxtal-rpc.publicnode.com` (Fraxtal, tip 43,914,297). Selectors computed locally with keccak-256 (pycryptodome). **No web browsing, zero GitHub API calls, `cast` not installed and not used, no repo writes.**
- **Sourcify match semantics:** `exact_match` = creation + runtime bytecode fully match the submitted sources+settings. `match` = partial match (runtime code matches, metadata differs — e.g. different compilation metadata). `404` / null matches = no Sourcify record.
- **Verdict definitions used here:** **HEAD** = every file in the verified source tree is byte-identical to the pinned HEAD tree. **DIFFERS** = verified (or, for Fraxtal, behaviourally probed) but source differs from HEAD; severity split into *material* / *minor* / *cosmetic-only* in the notes. **UNKNOWN/NO-RECORD** = unverified on Sourcify (behavioural evidence, where available, is recorded but cannot prove source correspondence). **EXCLUDED** = not part of the pinned repo's system (external token, Safe/Gnosis infra, OP-stack infra, OZ proxy bytecode, other-repo contract, test/other-chain address).

## 1. Verdict counts (36 individually classified addresses)

| Verdict | Count | Detail |
|---|---|---|
| HEAD (byte-identical full tree) | **0** | No deployed contract's full verified tree is byte-identical to HEAD. |
| DIFFERS | **12** | 6 material (mainnet FXBFactory + 5 FXBs: v1 generation vs HEAD v2) · 1 minor (mainnet SlippageAuctionFactory: HEAD minus `version()` only) · 5 cosmetic-only (mainnet SlippageAuctions: main file byte-identical to HEAD, sole tree diff is a parameter-name rename in a dependency — **semantically HEAD code**). |
| UNKNOWN / NO-RECORD | **5** | All Fraxtal, all Sourcify-404: FXBFactory, SlippageAuctionFactory, FXB_LFRAX impl, LFRAX impl, StorageSetterLFRAX. Behavioural evidence: 2 HEAD-consistent (FXB_LFRAX impl, StorageSetter — strong fingerprints), 1 HEAD-consistent on version only (auction factory), 2 behaviourally DIFFERING (factory v1.1.0; LFRAX impl v1.3.0 vs HEAD v1.0.0). |
| EXCLUDED | **19** | 8 mainnet (Safe proxy/singleton/fallback handler, FxbAMO operator, FRAX token, cross-chain Safe, EIP-7702 account, OP ProxyAdmin) · 11 Fraxtal (5 OZ transparent proxies whose implementations are classified separately, frxUSD proxy+impl, 2 ProxyAdmin contracts, L2 Safe+singleton). |

Bulk classes from the 0B sweep, excluded by class (see §8): 82 mainnet-constants externals, 47 Polygon test-output addresses (no mainnet code), 14 calldata fragments (not addresses), 6 Safe-owner EOAs + 3 test-actor labels. 0B's missed-deployment count is 0: no FXB/auction exists outside the two factory registries.

**Headline:** the live mainnet system is the **v1 generation** (Timelock2Step, immutable, non-upgradeable, 2023–24 deployments). HEAD's v2 code (beacon proxies, `Ownable2StepUpgradeable`, `FXB_LFRAX`) does **not** run anywhere on mainnet. On Fraxtal, the FXB proxies **were** upgraded to the HEAD-consistent `FXB_LFRAX` implementation (unverified, but version + constructor fingerprints match), while the Fraxtal factory is still v1-generation and the LFRAX implementation reports a **newer** version (1.3.0) than the HEAD file (1.0.0). The contract that actually operates all 5 mainnet auctions, `FxbAMO`, is **not in this repo at all**.

**Compiler-settings caveat (applies to every row):** all 12 core mainnet contracts were compiled with solc 0.8.23, optimizer enabled, **100,000 runs**, EVM Paris. The repo's `foundry.toml` default profile uses 200 runs and its `deploy` profile uses 1,000,000 runs + `via_ir`. Deployed bytecode therefore matches **neither** repo profile; correspondence in this phase is established at the **source** level (Sourcify exact/partial match + file diffs), not by rebuilding bytecode. A rebuild-equality check would need a custom 100k-run profile and is listed as an owed follow-up.

## 2. Per-address table

Compiler column: solc version + optimizer. Deployer column: Sourcify `deployment.deployer` (the creation-transaction sender as reported by Sourcify — for factory-created children this is the batch-tx EOA, not the immediate creator contract; see §6). Code hash = keccak-256 of deployed runtime code, computed locally (immutables make same-source deployments differ).

### 2a. Ethereum mainnet (chain 1)

| Address | Role | Sourcify | Verdict | Compiler | Deployer (Sourcify) | Notes |
|---|---|---|---|---|---|---|
| `0x7a07D606c87b7251c2953A30Fa445d8c5F856C7A` | FXBFactory | exact_match (creation+runtime), verified 2025-09-22 | **DIFFERS — material** | 0.8.23, opt 100k | `0xb0E1650A9760e0f383174af042091fc544b8356f` (tx `0xc4d0b396…`, block 18829289) | v1: `Timelock2Step`, immutable `FRAX`, direct `new FXB()` deploys, no `version()/beacon()/token()/owner()`. No proxy slots. Code 13,205 B. See D1. |
| `0x983aF86c94Fe3963989c22CeeEb6eA8Eac32D263` | SlippageAuctionFactory | exact_match, verified 2025-09-22 | **DIFFERS — minor** | 0.8.23, opt 100k | `0xb0E1650A…8356f` (tx `0x99363015…`, block 18816029) | Identical to HEAD except the whole `version()` function is absent (8 lines). All auction logic identical. See D3. Code 18,458 B. |
| `0xfb51435D48cB04dbE5f23b22f80aDe6D996473F5` | FXB_20240331 (idx 0) | exact_match, verified 2024-08-08 | **DIFFERS — material** | 0.8.23, opt 100k | `0xf4E1d185666a624099298FcC42C50ba662DC7e52` (batch tx `0x585919b7…`, block 18830374) | v1.0.2, immutable `FRAX`/maturity, non-upgradeable, `isRedeemable()` timestamp-only. Supply 0 (matured). See D2. Code 6,237 B. |
| `0x0dE54CFdfeD8005176f8b7A9D5438B45c4F1df1e` | FXB_20240630 (idx 1) | exact_match, verified 2024-08-08 | **DIFFERS — material** | 0.8.23, opt 100k | `0xf4E1d185…7e52` (same batch tx) | v1.0.2, same source tree as idx 0 (identical Sourcify tree hash). Nonzero supply, matured. See D2. |
| `0xF8FDe8A259A3698902C88bdB1E13Ff28Cd7f6F09` | FXB_20241231 (idx 2) | exact_match, verified 2026-01-26 | **DIFFERS — material** | 0.8.23, opt 100k | `0xf4E1d185…7e52` (same batch tx) | v1.0.2, same source tree. Nonzero supply, matured. See D2. |
| `0x13f19441Fb473fE96F1928d4a90f79fDb59675F1` | FXB_20251231 (idx 3) | exact_match, verified 2024-08-08 | **DIFFERS — material** | 0.8.23, opt 100k | `0xf4E1d185…7e52` (same batch tx) | v1.0.2, same source tree. Supply 0, matured 2026-01-01. See D2. |
| `0x76237BCfDbe8e06FB774663add96216961df4ff3` | FXB_20261231 (idx 4) | exact_match, verified 2024-08-08 | **DIFFERS — material** | 0.8.23, opt 100k | `0xf4E1d185…7e52` (same batch tx) | v1.0.2, same source tree. **Only unmatured mainnet FXB** (matures 2027-01-01), nonzero supply. See D2. |
| `0xEC7CD06EA2fE3E2A9bFB4F75467617B35F0931D7` | SlippageAuction → FXB_20240331 | exact_match, verified 2026-01-26 | **DIFFERS — cosmetic-only** | 0.8.23, opt 100k | `0xf4E1d185…7e52` (batch tx `0xa42e64f5…`, block 18842933) | `SlippageAuction.sol` byte-identical to HEAD; only tree diff is a parameter rename in `Timelock2Step.sol`. v1.0.1. 0 auction runs. See D4. Code 15,533 B. |
| `0xC92067D8DDb1970ecB93202DA31a3C45cC2c1F44` | SlippageAuction → FXB_20240630 | exact_match, verified 2024-08-08 | **DIFFERS — cosmetic-only** | 0.8.23, opt 100k | `0xf4E1d185…7e52` (same batch tx) | Same source tree as above. 10 runs. See D4. |
| `0xc9aa98788a675FF0846E8856cb83F19452f3b0c8` | SlippageAuction → FXB_20241231 | exact_match, verified 2024-08-08 | **DIFFERS — cosmetic-only** | 0.8.23, opt 100k | `0xf4E1d185…7e52` (same batch tx) | Same source tree. 10 runs. See D4. |
| `0x50c4b90bE25a2de0cd6Ad8dF5047B4C50C78FDE8` | SlippageAuction → FXB_20251231 | exact_match, verified 2026-02-02 | **DIFFERS — cosmetic-only** | 0.8.23, opt 100k | `0xf4E1d185…7e52` (same batch tx) | Same source tree. 0 runs. See D4. |
| `0x63981f5E690eaF7E8795c42832664e8848F532fB` | SlippageAuction → FXB_20261231 | exact_match, verified 2024-08-08 | **DIFFERS — cosmetic-only** | 0.8.23, opt 100k | `0xf4E1d185…7e52` (same batch tx) | Same source tree. 13 runs. See D4. |
| `0x831822660572bd54ebaa065C2acef662a6277D40` | "AMO Timelock" = Gnosis Safe proxy | `match` (partial), `GnosisSafeProxy.sol`, verified 2025-02-16 | **EXCLUDED** | 0.7.6, optimizer off | `0xf4E1d185…7e52` (tx `0xc6028f22…`, block 18271852) | Safe 1.3.0 proxy, 171 B. Slot 0 → singleton `0xd9Db270c…`. 6 owners, threshold 3 (per 0B). Factory `timelockAddress` + FxbAMO timelock. Not repo code. |
| `0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552` | Gnosis Safe singleton (slot 0 of above) | exact_match, `GnosisSafe.sol`, 0.7.6 | **EXCLUDED** | 0.7.6 | `0xD7Df5bf3B8d2bd159664dF54A30101d7FAF6cA26` (block 12504268) | Canonical Safe v1.3.0 singleton. Safe infra. |
| `0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4` | Safe fallback handler | exact_match, `CompatibilityFallbackHandler.sol` | **EXCLUDED** | 0.7.6, optimizer off | `0xD7Df5bf3…6cA26` (block 12504256) | Safe infra (found via 0B roles section). |
| `0x452420df4AC1e3db5429b5FD629f3047482C543C` | Auction operator = `FxbAMO` | `match` (partial), `src/contracts/FxbAMO.sol`, verified 2024-08-08 | **EXCLUDED** (out-of-repo, operationally critical) | 0.8.23, optimizer **off** | `0xb0E1650A…8356f` (tx `0xeb920b42…`, block 18829384) | Separate repo (`frax-bonds-amo` per source `@dev`). `timelockAddress` of **all 5** auctions; only it can start/stop auctions. v1.0.2. 735-line file, 30 sources. See §7. Code 18,064 B. |
| `0x853d955aCEf822Db058eb8505911ED77F175b99e` | FRAX (legacy FRAX) token | `match` (partial), `FRAXStablecoin`, verified 2024-08-08 | **EXCLUDED** | 0.6.11, opt 100k | `0xa448833bEcE66fD8803ac0c390936C79b5FD6eDf` (block 11465581) | External underlying of all mainnet FXBs/auctions. Not repo code. |
| `0xC4EB45d80DC1F079045E75D5d55de8eD1c1090E6` | Same address on mainnet: Safe proxy | **404 / no record** (chain 1) | **EXCLUDED** | — | — | 0B: Gnosis Safe 1.3.0 proxy on mainnet (5 owners, threshold 3, singleton `0xfb1bffC9…`), cross-chain same-address Safe. No FXB interface. (Its Fraxtal incarnation is verified — see §2b.) |
| `0xaCa39B187352D9805DECEd6E73A3d72ABf86E7A0` | EIP-7702 delegated account | **404 / no record** | **EXCLUDED** | — | — | 23-byte `0xef0100` delegation to `0x63c0c19a…` (per 0B). Test-label address only. |
| `0x13Fe62cB24aEa5afd179F20D362c056c3881ABcA` | Optimism `ProxyAdmin` | exact_match, `ProxyAdmin.sol` (op-bedrock) | **EXCLUDED** | 0.8.15, opt 50k | `0xE7c147CD1A7c05a6e73217645547582024E87a9B` (block 19135323) | OP-stack infra; test-only `proxyAdmin` label in repo. No FXB interface (per 0B). |

### 2b. Fraxtal (chain 252)

All implementation resolutions below are live `eth_getStorageAt` reads of the EIP-1967 slots at tip 43,914,297, cross-checked against the `02_UpgradeFXBs.json` / `01_HandleNewLFRAX.json` calldata (selector `0x9623609d` = `upgradeAndCall(address,address,bytes)`, `0x99a88ec4` = `upgrade(address,address)` — both confirmed by local keccak computation).

| Address | Role | Sourcify (252) | Verdict | Compiler | Deployer | Notes |
|---|---|---|---|---|---|---|
| `0xaFa1705021f65418e746D8664f4B8A58271f6De4` | FXBFactory (Fraxtal) | **404 / no record** | **UNKNOWN** (behaviourally DIFFERS) | — | — | Direct deployment, no proxy slots. `version()`=(1,1,0), `FRAX()`=frxUSD proxy, `timelockAddress()`=L2 Safe, `fxbsLength()`=4; `beacon()/token()/owner()` revert → v1-generation `Timelock2Step` factory, **not** HEAD v2. Registry order: 20251231, 20291231, 20551231, 20271231. Code 9,656 B. See D5. |
| `0xDfA77cE8B723C5e13e20E8938A18648022b7Fe18` | SlippageAuctionFactory (Fraxtal) | **404 / no record** | **UNKNOWN** (behaviourally HEAD-consistent) | — | — | Direct deployment. `version()`=(1,0,0) = HEAD's version; `auctionsLength()`=0 — **no auction ever created on Fraxtal**. Code 14,853 B (differs in size from mainnet factory's 18,458 B; settings/code unproven). See D6. |
| `0xacA9A33698cF96413A40A4eB9E87906ff40fC6CA` | FXB20251231 proxy | **404 / no record** | **EXCLUDED** (proxy code; impl classified separately) | — (proxy bytecode identified by code-hash equality, see note) | — | OZ `TransparentUpgradeableProxy` bytecode (3,959 B, keccak `0x7e4526c9…`, identical to the two Sourcify-verified TUP instances below). Impl slot → `0xA7c3…`, admin slot → `0xfc…000a`. Through-proxy: name=symbol=`FXB20251231`, maturity 1,767,225,600, `token()`=LFRAX, `frxUSD()`=frxUSD, `factory()`=Fraxtal factory, `version()`=(1,2,0). |
| `0x6c9f4E6089c8890AfEE2bcBA364C2712f88fA818` | FXB20271231 proxy | **404 / no record** | **EXCLUDED** (proxy code) | — | — | Same proxy bytecode. Impl → `0xA7c3…`, admin → `0xfc…000a`. Maturity 1,830,297,600, `version()`=(1,2,0). |
| `0xF1e2b576aF4C6a7eE966b14C810b772391e92153` | FXB20291231 proxy | **404 / no record** | **EXCLUDED** (proxy code) | — | — | Same proxy bytecode. Impl → `0xA7c3…`, admin → `0xfc…000a`. Maturity 1,893,456,000, `version()`=(1,2,0). |
| `0xc38173D34afaEA88Bc482813B3CD267bc8A1EA83` | FXB20551231 proxy | **404 / no record** | **EXCLUDED** (proxy code) | — | — | Same proxy bytecode. Impl → `0xA7c3…`, admin → `0xfc…000a`. Maturity 2,713,910,400, `version()`=(1,2,0). |
| `0xA7c3C04D0c762F7f3B8fdeeE195dB66160bdf2eB` | Shared FXB implementation (`LFRAXFXB_IMPL`) | **404 / no record** | **UNKNOWN** (behaviourally HEAD-consistent, strong) | — | — | Serves **all 4** FXB proxies (single shared implementation). Direct calls: `version()`=(1,2,0) = HEAD `FXB_LFRAX` version; `name()`=`"JUNK"` = HEAD constructor `ERC20("JUNK","JUNK")`. Proxy storage (token/frxUSD/factory/maturities) matches the `02_UpgradeFXBs.json` initialize args exactly. Source unproven — needs Fraxscan verification. Code 8,292 B. See D6. |
| `0x17FdBAdAc06C76C73Ea73b834341b02779C36AA0` | LFRAX implementation (`LFRAX_IMPL`) | **404 / no record** | **UNKNOWN** (behaviourally DIFFERS) | — | — | `version()`=`"1.3.0"` via proxy and direct, but HEAD `ERC20PermitPermissionedOptiMintable.sol` declares `version = "1.0.0"`. Name/symbol (`Legacy Frax Dollar`/`LFRAX`) match the repo's deployment params, but the implementation is a **newer revision than the HEAD file** (or a different contract). Source unproven. Code 9,235 B. See D5. |
| `0x63aDb8B9C786D426a73800E40F1f67355aC36Bb7` | `StorageSetterLFRAX` (transient upgrade helper) | **404 / no record** | **UNKNOWN** (behaviourally HEAD-consistent, very strong) | — | — | All 6 runtime selectors match HEAD exactly (`setNameAndSymbol 0x3dd6dcb3`, `getBytes32 0xa6ed563e`, `getUint 0xbd02d0f5`, `getAddress 0x21f8a721`, `getBool 0x7ae1cfca`, `version 0x54fd4d50`); `version()`=`"1.2.1-beta.2"` = HEAD constant; bytecode embeds `"Legacy Frax Dollar"`/`"LFRAX"`. No longer an implementation of any proxy (intermediate step only). Code 507 B. See D6. |
| `0xff000000000000000000000000000000000001Fd` | LFRAX proxy | **404 / no record** | **EXCLUDED** (proxy code) | — | — | Same OZ TUP bytecode (3,959 B). Impl slot → `0x17Fd…`, admin slot → `0xfc…0009`. The `01_HandleNewLFRAX.json` upgrade executed (impl is the new impl, not the StorageSetter). |
| `0xFc00000000000000000000000000000000000001` | frxUSD proxy | `match` (partial, runtime only), OZ `TransparentUpgradeableProxy`, verified 2026-01-09 | **EXCLUDED** | 0.8.23, optimizer off | none reported | External token proxy. Impl slot → `0x0000000083bd…` (below), admin → `0xfc…000a`. `version()`=`"3.0.0"`. No deployment info (predeploy-style). |
| `0x0000000083bdf23788585d499eab0d92a8befb1d` | frxUSD implementation | **404 / no record** | **EXCLUDED** | — | — | frxUSD token logic (v3.0.0); not claimed by any repo file. Code 11,836 B. External dependency of `FXB_LFRAX`. |
| `0xfc00000000000000000000000000000000000009` | ProxyAdmin logic (LFRAX admin) | **404 / no record** | **EXCLUDED** | — | — | OZ `ProxyAdmin` logic contract, 3,213 B, no EIP-1967 slots. Slot 0 / `owner()` = L2 Safe `0xC4EB…`. Admin of the LFRAX proxy. |
| `0xfc0000000000000000000000000000000000000a` | ProxyAdmin proxy (FXB admin) | `match` (partial, runtime only), OZ `TransparentUpgradeableProxy`, verified 2025-02-09 | **EXCLUDED** | 0.8.23, optimizer off | none reported | A **proxy fronting the ProxyAdmin**: impl slot → `0xfc…0009`, admin slot → `0xfc…0009`, slot 0 owner = L2 Safe. It (not `0x…09` directly) is the registered admin of all 4 FXB proxies + frxUSD. `getProxyAdmin()` works via this proxy but reverts when called on `0x…09` directly — expected: the proxies only answer `admin()` to their registered admin (`0x…0a`). `getProxyImplementation(FXB20251231)` via this proxy confirms `0xA7c3…`. |
| `0xC4EB45d80DC1F079045E75D5d55de8eD1c1090E6` | L2 Comptroller Safe (Fraxtal) | `match` (partial), `GnosisSafeProxy.sol`, verified 2026-07-07 | **EXCLUDED** | 0.7.6, optimizer off | `0xE7c147CD1A7c05a6e73217645547582024E87a9B` (tx `0xc155736d…`, block 108832) | Safe proxy, 171 B. Slot 0 → `0xfb1bffC9…` (below). Owner of both ProxyAdmins + Fraxtal factory timelock. |
| `0xfb1bffc9d739b8d520daf37df666da4c687191ea` | Gnosis Safe L2 singleton | exact_match (**runtime only**, no creation match), `GnosisSafeL2.sol` | **EXCLUDED** | 0.7.6 | none reported | Safe infra. Same address is the singleton of the mainnet `0xC4EB…` Safe too (per 0B). Code 23,800 B. |

Proxy-bytecode identification note: the six 3,959-byte Fraxtal proxies (4 FXB + LFRAX + frxUSD + `0xfc…000a` = seven, counting `0x…0a`) all share runtime-code keccak `0x7e4526c92b11a85a3811ccbededda626daa7cfbe543c53f82b7b8c5f99b271f5`. Two of them (`0xfc…0001`, `0xfc…000a`) are Sourcify-verified as OZ `TransparentUpgradeableProxy`. The other five are therefore identified as the same proxy bytecode by hash equality even though Sourcify has no record for them individually.

## 3. DIFFERS detail (semantic differences, from unified diffs of verified sources vs HEAD)

Only **4 files** differ across the three mainnet verified source trees; every OpenZeppelin dependency file is byte-identical to the HEAD submodule, and `BokkyPooBahsDateTimeLibrary.sol` is identical. The three trees are: Tree A = FXBFactory + all 5 FXBs (21 files, one shared tree hash), Tree B = all 5 SlippageAuctions (12 files), Tree C = SlippageAuctionFactory (13 files = Tree B + factory file).

### D1. FXBFactory — deployed v1 vs HEAD v2.0.0 (MATERIAL)

Deployed `FXBFactory.sol` (222 lines) vs HEAD (223 lines). The deployed contract is a different architectural generation:

- **Access control:** deployed inherits `Timelock2Step` (constructor `_timelock`/`_frax`, immutable `FRAX`, `createFxbContract` gated by `_requireSenderIsTimelock()`). HEAD inherits `Ownable2StepUpgradeable`, uses `initialize(_owner,_token)` + `onlyOwner`, mutable `token`, and a `setToken()` the deployed contract lacks.
- **No upgradeability, no beacon:** deployed has no `beacon`, no `FraxBeacon`/`FraxBeaconProxy` imports, no `initialize`, no `_disableInitializers`, no `version()`. It deploys each FXB with `new FXB(...)` (full deployment). HEAD deploys `FraxBeaconProxy` instances and creates a beacon + implementation inside `initialize()`.
- **No Fraxtal registry:** HEAD `initialize()` hardcodes the 4 Fraxtal FXB addresses into `fxbs[]`/`isFxb`/`isTimestampFxb`. The deployed contract has no such pre-registration (its registry holds exactly the 5 mainnet FXBs it created).
- **Metadata scheme:** deployed generates symbol `FXB_YYYYMMDD` (with underscore) via `_generateSymbol` and name `FXB_<id>_<MON><DD><YYYY>` (e.g. `FXB_0_MAR312024`) via `_generateName` + `_monthNames` helper (with `InvalidMonthNumber` error). HEAD generates one identical string `FXBYYYYMMDD` for both name and symbol via `_generateFxbMetadata`. On-chain names/symbols confirm the deployed scheme.
- **Event shape:** deployed `BondCreated(address fxb, uint256 id, string symbol, string name, uint256 maturityTimestamp)` — **no indexed params, no `token` field**. HEAD's event indexes `fxb`/`id` and carries `metadata` + `token`. Off-chain indexers written against HEAD's event will not match deployed logs (different topic structure).
- **Maturity rounding/validation identical:** day-floor coercion, expired-maturity and duplicate-maturity reverts, and day-before naming are the same in both.

### D2. FXB — deployed v1.0.2 vs HEAD v2.0.0 (MATERIAL)

Deployed `FXB.sol` (155 lines) vs HEAD (169 lines):

- **Non-upgradeable vs upgradeable:** deployed is `ERC20 + ERC20Permit` with a constructor `(name_, symbol_, _frax, _maturityTimestamp)`; `FRAX` and `MATURITY_TIMESTAMP` are **immutable**. HEAD is `ERC20Upgradeable + ERC20PermitUpgradeable` with `initialize(_metadata, _token, _maturityTimestamp)`, mutable `factory`/`token` storage, and a `_disableInitializers` constructor. Deployed FXBs have **no proxy, no `factory()`, no `token()`** (both revert on-chain, confirmed); HEAD's `FRAX()` is a legacy-compat view over `token`, while deployed `FRAX` is the immutable itself.
- **`isRedeemable()` semantics differ (audit-relevant):** deployed = `block.timestamp >= MATURITY_TIMESTAMP` **only**. HEAD adds an early-burn bypass: `msg.sender == Ownable(factory).owner() || matured`. The deployed bonds cannot be redeemed early by anyone, including the team multisig; HEAD code permits factory-owner early redemption. Any finding premised on the HEAD bypass does **not** apply to deployed mainnet bonds.
- **Separate name/symbol** (constructor args) vs HEAD's single metadata string for both; deployed names are `FXB_<id>_<MON><DD><YYYY>`, symbols `FXB_YYYYMMDD`.
- **`mint`/`burn` economics identical** apart from the `token`→`FRAX` variable rename: permissionless 1:1 mint against FRAX deposit (`transferFrom`), burn 1:1 after maturity, same `totalFxbMinted`/`totalFxbRedeemed` accounting, same `ZeroAmount`/`BondNotRedeemable` errors, same "allow minting after expiry" note. No access control on either in either version.
- **Version:** deployed `(1,0,2)`; HEAD `(2,0,0)`. Deployed file carries an `SPDX-License-Identifier: ISC` header the HEAD file lacks (cosmetic).

### D3. SlippageAuctionFactory — deployed vs HEAD (MINOR)

Single difference: the deployed file (102 lines) **lacks the entire `version()` function** (HEAD lines: `version()` returning `(1,0,0)`). `createAuctionContract` (18-decimals checks, `new SlippageAuction`, `AuctionCreated` event), `auctions`/`isAuction`, `getAuctions`/`getAuction`/`auctionsLength`, errors — all byte-identical. On-chain `version()` reverts, consistent with the deployed source. No behavioural difference except the missing view.

### D4. SlippageAuction — deployed vs HEAD (COSMETIC-ONLY; semantically HEAD)

`SlippageAuction.sol` itself is **byte-identical** to HEAD (776 lines, `version()` = `(1,0,1)` in both, confirmed on-chain). The only difference in the whole 12-file tree is in the dependency `lib/frax-standard-solidity/src/access-control/v2/Timelock2Step.sol`: the constructor parameter is named `_timelock` in the deployed tree vs `_timelockAddress` in HEAD (161 lines both, one 2-line hunk). Parameter names do not affect bytecode (only metadata). The 5 deployed auctions are therefore **the HEAD auction code** as far as source correspondence can establish; the strict DIFFERS verdict is solely due to that rename. (Bytecode equality additionally depends on optimizer settings — deployed 100k runs vs repo profiles — see §1 caveat.)

### D5. Fraxtal behaviourally-DIFFERING contracts (source UNKNOWN; behaviour proves non-HEAD)

- **Fraxtal FXBFactory (`0xaFa1…`):** `version()`=(1,1,0) (HEAD: (2,0,0)); `Timelock2Step` interface (`timelockAddress()` = L2 Safe, immutable-style `FRAX()` = frxUSD); `beacon()/token()/owner()` revert. This is a v1-generation factory (newer patch than mainnet's version-less one), **not** the HEAD v2 factory. Its 4 FXBs are TransparentUpgradeableProxy deployments, not beacon proxies — so even the factory's deployment pattern differs from HEAD's `createFxbContract`.
- **LFRAX implementation (`0x17Fd…`):** `version()`=`"1.3.0"` (string constant, read both through the proxy and directly). HEAD `ERC20PermitPermissionedOptiMintable.sol` declares `version = "1.0.0"`. The deployed implementation postdates the HEAD file. Name/symbol and the `01_HandleNewLFRAX.json` upgrade path are consistent with the repo's *deployment plan*, but the *code* is not the HEAD file. Whether 1.3.0 differs semantically from 1.0.0 cannot be determined without the verified source (owed follow-up).

### D6. Fraxtal behaviourally HEAD-consistent contracts (source UNKNOWN; fingerprints match, proof absent)

- **FXB_LFRAX implementation (`0xA7c3…`, shared by all 4 FXB proxies):** `version()`=(1,2,0) = HEAD `FXB_LFRAX.version()`; direct `name()`=`"JUNK"` = HEAD constructor `ERC20("JUNK","JUNK")`; through-proxy storage matches the `02_UpgradeFXBs.json` `initialize(name, LFRAX, frxUSD, maturity, factory)` args for all 4 maturities (maturities 1,767,225,600 / 1,830,297,600 / 1,893,456,000 / 2,713,910,400). The `02` upgrade demonstrably executed. **Not proven:** source equality — no Sourcify record; a same-version rebuild or Fraxscan verification is still required before treating HEAD `FXB_LFRAX.sol` as the deployed code.
- **StorageSetterLFRAX (`0x63aD…`):** all 6 selectors + `version()`=`"1.2.1-beta.2"` + embedded name/symbol strings match HEAD exactly (see table). Strongest Fraxtal fingerprint in this phase. Same caveat: unverified source.
- **Fraxtal SlippageAuctionFactory (`0xDfA7…`):** `version()`=(1,0,0) matches HEAD; zero auctions exist, so no auction code is live on Fraxtal to compare. Code size differs from the mainnet factory (14,853 vs 18,458 B), which is consistent with different optimizer settings but unproven.

### Files in HEAD with no deployed verified counterpart

`FraxBeacon.sol`, `FraxBeaconProxy.sol`, `FraxUpgradeableProxy.sol`, `FXB_LFRAX.sol` (Fraxtal impl unverified), `ERC20PermitPermissionedOptiMintable.sol` (Fraxtal impl unverified + version differs), `OwnedV2.sol`, all `interfaces/*` except `IUniswapV2Callee.sol`, `EIP712StoragePad.sol`, `Storage.sol` (used by the unverified StorageSetter). The beacon/proxy-upgrade machinery in HEAD has **no verified deployment on either chain** in this inventory: mainnet uses no proxies at all, and Fraxtal uses OZ `TransparentUpgradeableProxy`, not `FraxUpgradeableProxy`/`FraxBeaconProxy`.

## 4. Proxy / implementation map

**Mainnet: no proxies anywhere in the FXB system.** EIP-1967 implementation/admin/beacon slots are all zero at both factories, all 5 FXBs, and all 5 auctions (read directly; 0B independently confirms). The only mainnet proxy in scope is the Gnosis Safe (`0x8318…`, slot-0 singleton pattern, not EIP-1967).

**Fraxtal proxy graph (all slots read live):**

```
L2 Safe 0xC4EB… (owner)
 ├── ProxyAdmin logic 0xfc…0009 ──(fronted by)──► ProxyAdmin proxy 0xfc…000a
 │       │                                      │  (impl→0x…09, admin→0x…09)
 │       └── admin of: LFRAX proxy 0xff…01Fd ──► impl 0x17Fd… (LFRAX v1.3.0)
 │       └── admin of: FXB proxies ──► shared impl 0xA7c3… (FXB_LFRAX, v1.2.0 fingerprints)
 │       └── admin of: frxUSD proxy 0xfc…0001 ──► impl 0x0000000083bd… (frxUSD v3.0.0)
 └── timelock of: FXBFactory 0xaFa1… (direct, v1.1.0)
```

- **Shared implementation:** `0xA7c3…` serves all 4 FXB proxies — one implementation upgrade moves all four bonds. No other implementation is shared.
- **Historical implementations: NOT recoverable from available RPC.** `eth_getStorageAt` at old blocks fails with "state pruned"; `eth_getLogs` returns empty for June 2025 (0 frxUSD transfers in a 50k-block window vs 18,468 in a recent window — logs are pruned, not merely absent). The pre-upgrade FXB implementation(s) and the original LFRAX implementation (before the StorageSetter intermediate step) are therefore **unclassified** — see owed check F1. The current implementations above are confirmed live.

## 5. Deployment facts

- **Deployers (Sourcify-reported creation-tx senders):**
  - `0xb0E1650A9760e0f383174af042091fc544b8356f` (= `Constants.POLYGON_DEPLOYER_ADDRESS`) deployed both mainnet factories and `FxbAMO` (blocks 18816029–18829384, Dec 2023). This EOA matches **neither** the Safe timelock **nor** any factory — it is the human/ops deployer.
  - `0xf4E1d185666a624099298FcC42C50ba662DC7e52` is the reported sender of the two batch transactions that created all 5 FXBs (tx `0x585919b7…`, block 18830374) and all 5 auctions (tx `0xa42e64f5…`, block 18842933), and of the Safe proxy creation. **Caveat:** Sourcify's `deployer` is the transaction sender; the immediate creator of each FXB/auction was the factory contract (called within those batch txs). The batch-tx structure (5 creations sharing one tx hash + index) needs trace confirmation — owed check E2. `0xf4E1…` is neither the timelock nor a factory.
  - Safe singleton/fallback handler: canonical deployer `0xD7Df5bf3…` (Safe's `0xD7Df…` deployment account). FRAX token: `0xa448833b…` (2020). OP ProxyAdmin: `0xE7c147CD…` (also the L2 Safe deployer on Fraxtal).
  - **Fraxtal:** no deployer information is available from Sourcify for any unverified contract, and the verified Fraxtal records report no deployment data. No Fraxtal deployer could be established in this phase — owed check F3.
- **No implementation appears on multiple proxies except** `0xA7c3…` (all 4 Fraxtal FXB proxies), as stated in §4.
- **No deployer matches the timelock or a factory** in any verified record. Factory/operator ownership (timelock = Safe) is a runtime role assignment, not a deployment relationship.

## 6. FxbAMO — the out-of-repo operator (finding for the parent)

`0x452420df…` (`FxbAMO`, 735 lines, `frax-bonds-amo` repo) is the `timelockAddress` of all 5 mainnet auctions and the only caller that can `startAuction`/`stopAuction`, `mintBonds`/`redeemBonds`/`withdrawBonds`/`withdrawFrax`, and set price floors. It is `Timelock2Step + OperatorRole2Step`, gated by the Safe. It does **not** exist in the pinned repo (no `FxbAMO` file; the repo's only AMO references are unrelated Curve-AMO constants). **Audit implication:** findings about auction operation, pricing floors, or fund flows that only consider `SlippageAuction.sol` + factories will miss the live control plane. Its Sourcify record is a partial `match` (optimizer disabled — unlike the 100k-run factory builds).

Corroboration value: FxbAMO's tree bundles `lib/dev-frax-bonds` copies of the v1 sources. Compared against the deployed mainnet trees, they are an **earlier snapshot**: its `SlippageAuction.sol` reports `(1,0,0)` (deployed/HEAD: `(1,0,1)`) and contains a `PriceSlippageTooHigh` 50%-cap check in `startAuction` that is **absent** from the deployed/HEAD `SlippageAuction.sol` at that location; its `FXB.sol` has a different constructor argument order; its `Timelock2Step.sol` uses HEAD's `_timelockAddress` spelling (deployed trees use `_timelock`). Its `SlippageAuctionFactory.sol` and `BokkyPooBahsDateTimeLibrary.sol` are identical to the deployed trees. This confirms the deployed generation sits between the FxbAMO snapshot and HEAD, and that the slippage-cap difference is a real code-evolution datum the hunters should be aware of (whether the cap moved elsewhere in 1.0.1 is a hunter question, not a correspondence verdict).

## 7. Bulk exclusions (0B sweep classes — no per-address Sourcify queries)

Per the 0B sweep (`fxb-addresses.json:sweep`, 171 unique repo addresses, `eth_getCode` on mainnet for each):

- **82 `mainnet-constant` addresses** (Curve pools, Chainlink oracles, Uniswap pools/routers, Convex wrappers, other Frax system contracts named in `Constants.sol`): EXCLUDED — external dependencies, not FXB system contracts. 0B established none is an FXB or auction.
- **47 `polygon-test-output` addresses** (`src/script/output/DeployPolygonTestSuite/*.yaml`): EXCLUDED — Polygon test deployments; all have no code on mainnet. Chain-137 verification was out of scope for this phase; if the parent wants Polygon correspondence, it needs a separate chain-137 pass (owed check P1).
- **14 fragments** (40-hex substrings of calldata/hashes that are not addresses): not addresses; ignored.
- **3 `test-actor` labels + 6 Safe-owner EOAs** (0B roles section): EOAs/test labels; no contract code to classify.
- **18 of 20 Fraxtal-system addresses** have no code on mainnet (expected — different chain); all 20 are covered in §2b on chain 252 instead. The 2 exceptions are the cross-chain Safes (`0xC4EB…`, covered in both tables).

## 8. Owed block-explorer follow-ups (exact checks for the parent)

No browsing was done in this phase. Each check below needs a block explorer (Etherscan for chain 1, Fraxscan for chain 252) or an archive node:

- **F1 (Fraxtal, high value):** On Fraxscan, open each proxy (`0xacA9…`, `0x6c9f…`, `0xF1e2…`, `0xc381…`, `0xff…01Fd`) → read the full `Upgraded` event history / proxy implementation history. Record every **prior implementation address** (pre-`0xA7c3…` FXB impl; pre-`0x17Fd…` LFRAX impl, including the transient `0x63aD…` StorageSetter step) with its upgrade tx hash and block. Then classify each prior impl (Fraxscan "Contract" tab: verified? which source? which `version()`?).
- **F2 (Fraxtal, high value):** On Fraxscan, check verification status + verified source for: `0xaFa1…` (factory), `0xDfA7…` (auction factory), `0xA7c3…` (FXB_LFRAX impl), `0x17Fd…` (LFRAX impl — confirm the 1.3.0 source and diff vs HEAD `ERC20PermitPermissionedOptiMintable.sol`), `0x63aD…` (StorageSetter), `0xfc…0009` (ProxyAdmin logic), `0x0000000083bd…` (frxUSD impl). If Fraxscan-verified, diff each against HEAD the same way §3 does and update the UNKNOWN verdicts.
- **F3 (Fraxtal):** For each Fraxtal contract in §2b, record creator address + creation tx from Fraxscan (Sourcify reports none). Confirm whether the deployer was the L2 Safe, `0xE7c147CD…`, or another EOA, and whether the 4 FXB proxies were created by the factory or directly.
- **E1 (mainnet):** Confirm the two "batch" creation transactions `0x585919b7…` (5 FXBs) and `0xa42e64f5…` (5 auctions) on Etherscan: internal-trace the immediate creator of each child (expected: the respective factory) and confirm the single-tx batching. Confirm `0xf4E1d185…`'s role (EOA sender vs contract).
- **E2 (mainnet):** Etherscan "Contract" tab for `0x452420df…` (FxbAMO): confirm Sourcify's partial-match source is the same as Etherscan's verification, and check whether Etherscan links it to the `frax-bonds-amo` repo (any newer `FxbAMO` version deployed elsewhere that supersedes it).
- **E3 (mainnet):** Etherscan for `0xC4EB…` on chain 1: it is Sourcify-404 but 0B found Safe-proxy code — check whether Etherscan verifies it as a Safe proxy and record its singleton/owners (expected singleton `0xfb1bffC9…`).
- **P1 (Polygon, only if in scope):** If Polygon correspondence is wanted, query Sourcify chain 137 for the 47 `DeployPolygonTestSuite` output addresses and classify against HEAD the same way. No Polygon RPC was used in this phase.
- **B1 (build check, needs a toolchain):** Rebuild HEAD's `SlippageAuction.sol` tree with solc 0.8.23 / optimizer 100k runs / EVM Paris and compare runtime bytecode (modulo immutables/metadata) against the 5 deployed auctions; repeat for the v1 `FXB`/`FXBFactory` trees from the extracted verified sources. This would upgrade the §3 source-level verdicts to bytecode-level ones. `forge`/`solc` were not available in this phase.

## 9. Evidence index

- Raw Sourcify v2 records (with `deployment` + `sources` + `abi` + `metadata`): `~/workspace/frax-audit/sourcify-fxb/` — 36 JSON files (`1_<address>.json` chain 1, `252_<address>.json` chain 252), including 404 bodies for unverified addresses.
- Extracted verified source trees used for the §3 diffs: `/tmp/fxb0c/verified/tree{A,B,C,D}_*` (ephemeral; re-extractable from the JSONs above).
- Runtime-code keccak-256 values (computed locally, cross-checked against 0B's `codeHash` fields where 0B reported them — all matched):

| Address (chain) | Code len (B) | Runtime keccak-256 |
|---|---|---|
| `0x7a07…` (1) | 13,205 | `0x03faf65fc69243032d0fea780f721be045997d5724664e4fe98e1f5324e47d28` |
| `0x983a…` (1) | 18,458 | `0xdac17261fa76c6ba5d6ac660731a24b449164fb32d06cdb1378a67ab3f7d6745` |
| `0xfb51…` (1) | 6,237 | `0xe6f378db5ec4ce686c33ed79e458756ae0bf1a21e32fe172ba9a7c4b9f551ae7` |
| `0x0de5…` (1) | 6,237 | `0x4c47b5636139a506b2095703375d2c45d07e3a9c421ce0202c340993be9072b6` |
| `0xf8fd…` (1) | 6,237 | `0xfb1bc5f3dad74a04fc96ae80aad478877ef14870b8182381dbbf31fc7bc2c5f7` |
| `0x13f1…` (1) | 6,237 | `0xe823dd475ad0b49d2a9df8fb7769a51c545863cc921be76268d2a873ca11f8fa` |
| `0x7623…` (1) | 6,237 | `0x685d9f25bdbcfd71d0211875213ebd84b9fc482cce6ae52bc753c0aed148d5c1` |
| `0xec7c…` (1) | 15,533 | `0xc8a3f1b0daaad9a8b4587f346e56e268c98b564343a1bd6cee9eb0dffa8f9466` |
| `0xc920…` (1) | 15,533 | `0xe39fea2cdd79ae2210362a9f95a23f95b7f5bce2e121e65bc82cb2e098c5b573` |
| `0xc9aa…` (1) | 15,533 | `0x1f4cc6e3baf971536a457d1a25fa8e5a46cf2935927d06944f8818b786bbb1c7` |
| `0x50c4…` (1) | 15,533 | `0x0e9bbeef3ba873c917f75ffa5127e4a397f069a703e441682934f960c7c3102f` |
| `0x6398…` (1) | 15,533 | `0x11e39973d30f0f05c3612970f36c93fae4c5dfafb88388cb1a353f78190118a7` |
| `0xaFa1…` (252) | 9,656 | `0xa795465f6e5266bb5fa2b05f6357688e445c35c3b9df6fba2eb00a33052816ea` |
| `0xDfA7…` (252) | 14,853 | `0xc85eb36f30429ecddc43e4f3758a366e3a0dfda27e3c3ca02bd3e5d2aa9bdd90` |
| 4 FXB proxies + LFRAX + frxUSD + `0xfc…000a` (252) | 3,959 each | `0x7e4526c92b11a85a3811ccbededda626daa7cfbe543c53f82b7b8c5f99b271f5` (all identical) |
| `0xA7c3…` (252) | 8,292 | `0xb8b83b5ca3a4892fa00caa275fce67a4a2bad5f06e32ba8e32c0aec474774d8d` |
| `0x17Fd…` (252) | 9,235 | `0xa7e8e5f2dded440894191352b518d00a07a6019fb18e1a54e4fa7f2df980a817` |
| `0x63aD…` (252) | 507 | `0xd4a8eca28870eb10f9a9fbe66f6364c16f6c4f908ab0300639abb49ce5a50c2a` |
| `0xfc…0009` (252) | 3,213 | `0xdfcfd4adc25aa4ff7af37ed97e47c34b051b6d50af4528eb99e3170d3ea96c99` |
| `0x0000000083bd…` (252) | 11,836 | `0x6f71a211feeccbb06f5cea435c8d298bcc237a58c429e6f071c2fa8c0b1cb8fc` |

(Mainnet FXBs/auctions differ in code hash despite identical source trees because constructor immutables — names, symbols, maturities, token addresses — are embedded in runtime code.)

## 10. Limitations

- Sourcify has no record for 11 of 16 Fraxtal addresses queried; Fraxtal verdicts rest on behaviour + slot reads, not source. Fraxscan may hold verifications Sourcify lacks (owed checks F1–F3).
- One RPC anomaly, discarded: a historical `eth_getStorageAt` via `https://fraxtal.drpc.org` returned a malformed-looking slot value (bytes resembling the queried proxy address itself); no conclusion was drawn from it, and all slot reads in this report come from publicnode at `latest`.
- `cast`/`forge`/`solc` unavailable: no local rebuild/bytecode-equality check was possible (§1 caveat, owed check B1).
- The 0B inventory was incorporated in full (it appeared during this phase). No address in the 0B structured sections (`factories`, `fxbs`, `auctions`, `roles`, `operatorContract`, `underlying`) is missing from §2; sweep classes are handled in §7.
