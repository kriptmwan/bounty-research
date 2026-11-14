# Phase 0C — Deployed-bytecode vs repo-HEAD correspondence: HopV2 + OFT mesh

**Date:** 2026-11-14 (probes 12:30–13:30 WIB approx.) · **Mode:** audit-only, read-only. No transactions, no contact with the Frax team, no gist, no submission. Zero GitHub API calls (git clones only, for dependency references).

**Question:** for each canonical live contract, does deployed code match repo HEAD source? The bounty requires findings against current live deployments; repo-source findings are filing-ready only where correspondence holds.

**Repo pins (read-only, verified clean at end of session):**

| Repo | HEAD |
|---|---|
| `fraxtal-lz-hop` | `cb3240bb3d644ee30267b20f2d8b82e5de559c55` |
| `frax-oft-upgradeable` | `6964529b29b367d976d62a6df1efbbacb31d3205` |
| `lz-fork-ref` (LZ fork reference) | `e1470197e0cffe0d89dd9c776762c8fdc1e160` |

**Universe:** 422 unique (chain, address) pairs — 299 canonical pairs from the Phase 0B JSON (27 of them mocks, excluded) plus 123 discovered EIP-1967 implementation pairs found by reading proxy slots. Correspondence is per (chain, address): the same address deploys different code on different chains (proven, see §7), so address-alone matching was never used.

## 1. Headline verdicts

| Verdict | Pairs | Meaning |
|---|---|---|
| **HEAD** — repo HEAD source IS the live code | **245** | Proven by verified-source diff, forge-build byte equality, byte-identical/immutable-only twin bytecode, or codehash identity with a proven pair. |
| **DIFFERS** — live code proven to DIFFER from repo HEAD | **70** | Proven by verified-source diff, build mismatch, or twin/codehash propagation from a proven pair. Source is known for 66 of these (V201 tree, old generations); unknown for 4 (2 new RemoteAdmins, 2 Fraxtal v1 contracts). |
| **UNKNOWN** — NO-RECORD | **79** | No verified source retrievable by any non-browser route and no build/twin proof. Includes 25 spoke proxies (third-repo proxy code, see §6) and the live hub implementation. |
| **EXCLUDED** | **28** | 27 mocks + 1 Tempo system address. |

**The five decisive findings:**

1. **The live v2.0.1 spoke source WAS retrieved without a browser.** `RemoteHopV201` is Sourcify-verified on Ink (57073) and Robinhood (4663) — Phase 0B had checked only Fraxtal/Ethereum. The 56-file tree was rebuilt with forge (solc 0.8.23, optimizer 200, evm shanghai, `viaIR: true`) and is **byte-identical** to the deployed spoke implementation on Ethereum, Robinhood, and Ink. The spoke implementation codehash is uniform on all 24 non-Tempo chains, so **all 24 live spokes run known V201 source that DIFFERS from repo HEAD** (new files `HopV201.sol` / `RemoteHopV201.sol` / `IHopV201.sol`, absent from HEAD). Spoke findings must be written against the retrieved V201 tree, not repo HEAD — but they ARE filing-ready against that tree.
2. **The live hub implementation source was NOT retrievable by any non-browser route: NO-RECORD.** Hub impl `0x00000000d25B8809150b59ce5dAE5699FfD26485` (15,418 B, Fraxtal) is Sourcify-unmatched; Fraxscan Blockscout/v1 APIs fail (see §8); Etherscan v2 API is credential-gated ("Missing/Invalid API Key"), not Cloudflare-blocked. It matches neither the repo-HEAD `FraxtalHopV2` build nor the `RemoteHopV201` build. It is presumably a `FraxtalHopV201` sibling — **that name is an unconfirmed hypothesis, not evidence.** Hub-logic findings cannot be filed from repo source. Browser explorer check flagged for the parent (§10).
3. **Tempo is the exception in the spoke mesh.** Its spoke proxy points to a different implementation (`0x00000000b2707226814D5792137fb0B482310A36`, 16,859 B, different admin) — Phase 0B had assumed uniformity without reading the slot. Sourcify-unmatched, build-mismatched vs V201: NO-RECORD.
4. **The new RemoteAdmins differ from repo HEAD and their source is unknown.** Fraxtal new RemoteAdmin (1,269 B) and Ethereum new RemoteAdmin (1,225 B) both mismatch the repo-HEAD `RemoteAdmin` build (1,169 B) at byte 4, differ from each other, and are Sourcify-unmatched. The OLD RemoteAdmins match repo HEAD (build + Sourcify).
5. **The OFT mesh mostly matches repo HEAD — except its oldest generation.** 89 OFT implementations are HEAD-proven (token OFTs, WFRAX, frxUSD/sfrxUSD, mintable adapters, Tempo variant). The exceptions: 3 Ethereum plain adapters (`FraxOFTAdapterUpgradeable`, ±10 lines, old generation), 5 Polygon zkEVM old-generation token OFTs (pre-EIP3009, `version()` tuple), 6 legacy pre-upgradeable adapters, and 16 UNKNOWN implementations (Fraxtal plain adapters, EraVM, zkEVM 13,670 B, Tempo variants).

## 2. Method

Five independent evidence layers, applied in priority order per pair. Full per-pair evidence (including the basis string for every verdict) is in `work/correspondence-phase0c.json`; the full table is Appendix A.

### 2.1 EIP-1967 slot confirmation + codehash capture (32/33 chains)

`work/slots-phase0c.cjs` read `eth_getCode` (size + keccak256) for every unique address, plus implementation/admin slots for every proxy-kind address, plus codehashes for every discovered implementation. **39/39 `implementation` fields in the 0B JSON were confirmed by slot reads, 0 disagreements, 0 empty slots. Zero-code addresses: 0.** Only Blast (81457) failed — `https://rpc.blast.io` TLS disconnect; Blast is deprecated and OFT-only. Blast implementation discovery was therefore impossible; its 6 canonical proxies were still Sourcify-checked.

### 2.2 Sourcify v2 sweep (423 checks, 181 matched)

`work/sourcify-phase0c.cjs` (323 checks, all canonical pairs + per-chain spoke-impl checks) and `work/sourcify-phase0c-pass2.cjs` (100 checks, discovered implementations). All 75 Phase 0B results were reproduced exactly. **181 (chain, address) pairs matched** (exact_match 34+ in pass 1; pass 2 mostly exact_match OFT impls). All verified sources + `metadata.json` saved under `sourcify-hopv2-oft/sources/<chainId>/<address>/` (181 trees, 38 MB). Somnia (5031) is **not supported by Sourcify** (HTTP 400 "Chain 5031 not found") — its 14 "none" results are coverage gaps, resolved where possible by bytecode methods. One anomaly: Somnia `0xB90035361706A8299F9EC505FFD26598aB2cbaF5` returned HTTP 400 while the same address matched exact_match on Robinhood.

### 2.3 Source diff vs repo HEAD (`work/diff-phase0c.py`, 181 contracts)

Every saved source file was compared against its repo-HEAD counterpart: `src/...` → hop repo, `contracts/...` → OFT repo, `@fraxfinance/...` → LZ fork, `@openzeppelin/...` → fresh OZ clones (5.4.0 and 4.8.1), `@layerzerolabs/...` → fork mirrors, bare filenames → basename search, flattened single-file verifications → `contracts/flat/*Flat.sol` candidates. Comparison: raw byte equality, else comment+whitespace-normalized equality (comment stripper handles string literals), else DIFF with hunks. Verdicts are driven by **Frax files only**; dependency-version drift is recorded separately as `depDrift` (see §2.6). Raw counts: MATCH 102 / PARTIAL 46 / MISMATCH 33 — re-presented per pair in the assembly step (PARTIAL with clean Frax files = HEAD; see §6 for proxy handling).

### 2.4 Forge builds + immutable-masked bytecode comparison

Three fresh build dirs outside the checkouts; dependency pinning established by byte comparison (all 5 `@fraxfinance` files in the old-hub tree are byte-identical to `lz-fork-ref` @ e1470197; OZ 5.4.0 clones byte-identical to the Sourcify OZ files used). Comparison masks immutable-reference byte ranges from the artifact on both sides and strips CBOR metadata tails if present (all compared deployments had 0 bytes stripped — no metadata tails). Compilation stayed well inside the ~45-minute time-box; all three builds assembled and ran.

| Build | Dir | Source | Settings | Result |
|---|---|---|---|---|
| 1 — repo HEAD | `work/build-hopv2/` | Hop repo HEAD files | solc 0.8.23, optimizer 200, evm shanghai, bytecode_hash none, cbor off | MATCH: `FraxtalHopV2` vs old hub impl (13,711 B, byte-identical — toolchain validated); `RemoteHopV2` vs Arbitrum/Base/**Ethereum** first-gen impls; `RemoteAdmin` vs old Fraxtal/Ethereum admins. MISMATCH: live hub impl, live spoke impl, both new RemoteAdmins, all v1 (see build 2). |
| 2 — v1 profile | `work/build-hopv2-v1/` | Hop repo HEAD files | solc 0.8.23, optimizer **OFF**, evm **paris** (per v1 Sourcify metadata) | MISMATCH for old generation (e.g. RemoteHop 13,734 vs 14,021 B, first diff byte 11) — source differs beyond settings. Build-1 settings MATCH new-gen `RemoteMintRedeemHop` on Robinhood/Celo/Somnia (6,563 B). |
| 3 — V201 tree | `work/build-v201/` | Sourcify-retrieved tree verbatim | Build-1 settings + **`viaIR: true`** (from V201 metadata; without via-IR the build was 15,290 B and mismatched) | `RemoteHopV201` 14,987 B, **byte-exact MATCH** vs deployed spoke impl on Ethereum, Robinhood, Ink (re-verified independently from the saved artifacts; the contract has no immutables, so this is a pure byte comparison). MISMATCH vs Tempo impl (16,859 B, first diff byte 12) and hub impl (15,418 B, first diff byte 89). |

### 2.5 Twin deployed-bytecode diffs + codehash propagation

OFT implementations and v1 contracts embed per-chain immutables (LayerZero endpoint, token addresses), so codehashes differ even for identical source — codehash-identity propagation alone would miss most of the mesh. `work/twin-diff-phase0c.cjs` (89 candidates) and `work/twin-diff-v1-phase0c.cjs` (21 candidates) byte-diffed each unmatched contract against Sourcify-verified twins of the same size class. **48 OFT implementations** resolved: 18 byte-identical, 30 differing only in ≤160 bytes across ≤16 regions of ≤20 bytes (address-sized immutable slots) or a 32-byte CBOR metadata hash. Spot-decoded: the Ink-vs-Optimism 160-byte diff is exactly the 20-byte endpoint address (`0xca29f3a6…` vs `0x1a440760…`) at 8 sites; the Worldchain-vs-Robinhood 32-byte diff is the metadata hash at the tail. **11 v1 contracts** resolved the same way (80–130 bytes, ≤11 regions, max 20 B) against old-generation twins. Separately, **90 pairs** inherited verdicts by exact codehash identity with a proven pair (zero anchor contradictions: no codehash maps to both HEAD and DIFFERS). Codehash identity is exact proof of identical deployed code and was applied across chains only where hashes are equal.

### 2.6 Dependency-drift caveat (applies to most HEAD verdicts)

Most Sourcify-verified trees use dependency versions different from the reference clones: old trees use OZ 5.0-era files, new-generation trees use OZ 5.4.0-era files, the V201 tree uses OZ 4.8.1 via the fork snapshot. The Frax files match HEAD, but the full compilation trees differ. **Hunter must use the saved Sourcify trees for exact reproduction, not a fresh HEAD + latest-deps build.** The exact OZ 5.0 patch version was deliberately not chased — Frax verdicts do not depend on it.

## 3. The v2.0.1 story

### 3.1 Spoke: source retrieved, rebuild-proven, DIFFERS from HEAD

`RemoteHopV201 @ src/contracts/hop/RemoteHopV201.sol`, solc 0.8.23, optimizer 200, evm shanghai, `viaIR: true`, metadata hash none. Verified on Ink (runtime-only partial, 2026-07-14) and Robinhood (creation+runtime partial, 2026-09-08, deployer `0x54F9b12743A7DeeC0ea48721683cbebedC6E17bC`). The two trees are byte-identical (56 files). Unmatched on the other 22 uniform-impl chains including Ethereum (Tempo runs a different implementation, §3.3) — but the implementation codehash `0x02d1a2f7e94f2d1b3f…` is identical on all 24 chains and the rebuild matches on 3 of them, so all 24 run this source.

**Delta vs repo HEAD** (`HopV201.sol` 533 lines vs `HopV2.sol` 467 lines, 98 changed lines; the contract's own docstring states it is "nearly identical to HopV2 except for the recover/recoverERC20()/recoverETH and feeMultipliers functions"):

- Contract renamed `HopV2`→`HopV201`, interface `IHopV2`→`IHopV201` (+ `FeeMultipliers` struct); interfaces moved from `src/contracts/hop/interfaces/` to `src/contracts/interfaces/` (the 5 moved non-Hop interfaces are byte-identical to HEAD).
- `PAUSER_ROLE` internal→public; new `RECOVER_ETH_ROLE` (`0xfedd0e52…`); `BPS=10_000`; storage adds `feeMultipliers` mapping (EID → FeeMultipliers); new events `RecoveredERC20`/`RecoveredETH`, errors `RecoverFailed`/`LengthMismatch`.
- `version()` returning `"2.0.1"` added (repo HEAD `HopV2.sol` has **no `version()` function at all** — the live `version()=2.0.1` alone proves divergence).
- `quoteHop` applies DVN/executor/treasury fee multipliers and changes the executor `getFee` message length from 36 to `360 + _data.length` (with derivation comment).
- New admin `setFeeMultipliers` + `setFeeMultipliersBatch`; new `feeMultipliers(eid)` view.
- **`recover(address _target, uint256 _value, bytes _data)` arbitrary-call REMOVED**, replaced by `recoverERC20` (DEFAULT_ADMIN_ROLE, to caller) + `recoverETH` (RECOVER_ETH_ROLE, to caller). **This is the highest-consequence delta for Hunter: the arbitrary-call recovery path in repo HEAD does not exist on live spokes.**
- `RemoteHopV201.sol` vs HEAD `RemoteHopV2.sol`: rename + `__init_HopV201` + 2 comment reflows only (14 changed lines). `IHopV201` vs `IHopV2`: adds `FeeMultipliers`, setters (`setNumDVNs`, `setHopFee`, `setFeeMultipliers`, `setFeeMultipliersBatch`, `setExecutorOptions`), the recover split, and views (`numDVNs`, `hopFee`, `feeMultipliers`, `executorOptions`, `EXECUTOR`, `DVN`, `TREASURY`) — 24 changed lines.

The V201 tree's `@fraxfinance` files import OZ 4.8.1 (a different/older fork snapshot than the old-hub tree's OZ 5.x).

### 3.2 Hub: NO-RECORD

Hub impl `0x00000000d25B8809150b59ce5dAE5699FfD26485`, 15,418 B. Sourcify 404 on Fraxtal; all alternate routes failed (§8); mismatches both the HEAD `FraxtalHopV2` build (13,711 B, first diff byte 9, deployed contains "2.0.1") and the `RemoteHopV201` build (first diff byte 89 — expected, different contract). **No source was guessed.** The hub proxy itself (1,700 B, codehash `0x22deb25f…`) is also unmatched and differs from the spoke-proxy build (1,686 B). Both are UNKNOWN.

### 3.3 Tempo spoke: NO-RECORD, different code

Tempo spoke impl `0x00000000b2707226814D5792137fb0B482310A36` (16,859 B), admin `0x000000dbfaA1Fb91ca46867cE6D41aB6da4f7428`. Sourcify 404; V201-build mismatch (first diff byte 12). UNKNOWN. (Abstract, by contrast, IS the uniform spoke impl — slot-confirmed this phase; its admin `0xE59Dcae52a4ffA39Be99588486C84Bc2dC1bA52f` matches ZkSync's.)

### 3.4 RemoteAdmins: old match HEAD, new differ, source unknown

| RemoteAdmin | Size | Verdict | Evidence |
|---|---|---|---|
| Old Fraxtal `0xDC3369C18Ff9C077B803C98b6260a186aDE9A426` | 1,169 B | HEAD | Sourcify MATCH + build MATCH (192 immutable bytes masked) |
| Old Ethereum `0xa2db46c06e0B643A926ef60d1fEB744A7385a593` | 1,169 B | HEAD | Build MATCH |
| Base `0xF333d66C7e47053b96bC153Bfdfaa05c8BEe7307`, Arbitrum `0x03047fA366900b4cBf5E8F9FEEce97553f20370e` | 1,169 B | HEAD | Sourcify MATCH (`RemoteAdmin`) |
| **New Fraxtal `0x34029e02821178B4387e12644896994f910D6E73`** | **1,269 B** | **DIFFERS, source unknown** | Build MISMATCH (first diff byte 4); Sourcify 404 |
| **New Ethereum `0x181EBC9deA868ED8e5EeeAef7f767D43BF390dFa`** | **1,225 B** | **DIFFERS, source unknown** | Build MISMATCH (first diff byte 4); Sourcify 404; differs from the Fraxtal one too (44 B) |

The new RemoteAdmins are plausibly a V201-era variant — unconfirmed; do not assume.

### 3.5 Decommissioned first-gen HopV2: matches HEAD

Old hub impl `0x6550284EA5dcb134a45a6F3c80afa2B30bc56fe9` (`FraxtalHopV2`, Sourcify MATCH, solc 0.8.23, verified 2026-07-17) and first-gen spoke impls on Arbitrum `0xB4523b73CD695827d663A67f955f9E87C164f85c`, Base `0x039c5144D6395CBC6ff0698E0A42d708eaE2E5F4` (both Sourcify-verified `RemoteHopV2`), and Ethereum `0xdFeDeC5Ce317245430C57AcE0Ce9Fb2a17AC0F6E` (Sourcify-unmatched, **build-proven**) are all HEAD. These contracts are paused/wound down; HEAD-proven but not live-surface.

## 4. v1 RemoteHop / MintRedeemHop: three proven generations + three unproven

All v1 contracts are `paused=true` (wound down) except MintRedeemHop v1, which 0B found still live (`paused=false`) on all 24 chains. Generations, by deployed size and verified source:

**Generation A — oldest (14,021 B RemoteHop / 11,774 B MintRedeemHop).** Verified source on 9 RemoteHop + 8 MintRedeemHop chains (Ethereum, Optimism, Arbitrum, Polygon, BSC, Avalanche, Linea, Sei, and others). Deltas vs repo HEAD (direction: HEAD → deployed):
- `RemoteHop.sol` **±19**: deployed has NO `version()` ("1.0.1"), NO `ArrayLengthMismatch` error; constructor takes NO `_owner` (`Ownable(msg.sender)`) and NO `_eids`/`_executorOptions` (no executor-options init loop); `recoverETH` uses `transfer()` where HEAD uses `call{value}("")`.
- `RemoteMintRedeemHop.sol` **±9**: same pattern minus executor-options (no `version()`, `Ownable(msg.sender)`, `transfer()` in `recoverETH`).
- `IExecutor.sol` **±2**: deployed lacks `endpoint()` + `localEidV2()` declarations.
- Twin-proven Gen-A members (immutable-only diffs, 80–125 B): Sonic, XLayer, Ink (v1 + MR) and Avalanche (MR) — 7 pairs.

**Generation B — Base set (14,055 B / 11,808 B).** Verified on Base only (`RemoteHop` ±17, `RemoteMintRedeemHop` ±7): identical to Gen A EXCEPT `recoverETH` already uses `call` like HEAD. Twin-proven members: Unichain, Worldchain (120–130 B immutable-only diffs) — 4 pairs. Newer than Gen A, older than HEAD.

**Generation C — repo HEAD (6,563 B MintRedeemHop only).** Robinhood, Celo (Sourcify MATCH), Somnia (build MATCH; Sourcify does not cover Somnia). HEAD-proven. No Gen-C RemoteHop exists (those chains have no v1 RemoteHop).

**Unproven generations (UNKNOWN, no verified source, no twin):** Plume (13,144 / 10,972 B), Katana + Hyperliquid (13,693 / 11,521 B), Monad + Stable (13,413 / 11,241 B), ZkSync EraVM (47,456 / 32,672 B) — 8 pairs. Distinct sizes prove distinct builds; their sources are NO-RECORD. Do not assume they match any proven generation.

**Fraxtal v1 hub-side contracts (DIFFERS, source unknown):** `FraxtalHop` `0x2A2019b30C157dB6c1C01306b8025167dBe1803B` (10,555 B) and `FraxtalMintRedeemHop` `0x3e6a2cBaFD864e09e6DAb9Cf035a0AbEa32bc0BC` (10,806 B) mismatch repo builds under BOTH profiles (opt-off first-diff bytes 323/357 — mid-code divergence, not an immutable artifact). Sourcify-unmatched. Exact source deltas NO-RECORD.

## 5. OFT mesh

### 5.1 HEAD-proven implementations (89 pairs)

| Family | Pairs | Chains |
|---|---|---|
| `FraxOFTUpgradeable` | 25 | 19 chains (Optimism…Katana; see Appendix) |
| `FrxUSDOFTUpgradeable` | 19 | 19 chains |
| `WFRAXTokenOFTUpgradeable` | 18 | 18 chains |
| `SFrxUSDOFTUpgradeable` | 17 | 17 chains |
| `FraxOFTMintableAdapterUpgradeable` | 6 | Ethereum, Fraxtal |
| `FraxOFTUpgradeableTempo` | 4 | Tempo (all 4 share one codehash incl. the verified one) |

Proven via Sourcify Frax-file MATCH (35+ direct), byte-identical twins (17), immutable-only twins (30), or codehash identity. Note the Fraxtal mintable adapters ARE verified and HEAD — the Fraxtal gap is only the *plain* adapters (§5.3). **FPI-on-Ethereum inference from 0B is NOT confirmed:** the FPI impl `0x2063961F26019B588F48007D1CC43770e8B7383C` has a distinct codehash from the verified mintable twins; its correspondence rests on its own evidence (see Appendix), not the inference.

### 5.2 DIFFERS, source known (old generations)

- **`FraxOFTAdapterUpgradeable` ±10 (3 pairs, all Ethereum):** frxETH `0x742109450E2466421b00A2Bf61D513D2616a74FC`, sfrxETH `0x9e951Dd846e748E6fCB58bFb76953c4900f819f4`, deprecated-FXS impl `0x7605c24F24e660708fc2E75997935501697A1780`. Deployed source is OLDER: constructor body empty (HEAD adds `_disableInitializers()`); `version()` returns `(uint256 major, minor, patch)` = (1,0,0) with `external` visibility (HEAD returns string `"1.0.1"`, `public`). **Findings referencing `version()` must use the deployed signature.**
- **Polygon zkEVM old-generation token OFTs (5 pairs, one codehash `0xbca98606…`):** 2 Sourcify-verified (flattened) + 3 codehash-identical. Deployed `FraxOFTUpgradeable` (15,057 B) predates HEAD substantially: NO `EIP3009Module`/`PermitModule`, NO `_disableInitializers()`, old `version()` (1,0,0) tuple, `initialize` uses `initializer` (not `reinitializer(3)`), NO `initializeV110`, NO EIP3009/EIP2612 `_transfer`/`_approve` overrides. Repo HEAD is v1.1.0 with those modules. (The diff script's ±2,588 figure against the repo flat file is NOT quoted as the delta: the repo's `FraxOFTUpgradeableFlat.sol` actually contains a different contract, `FRAXOFTUpgradeable` — the delta above comes from direct body comparison.)
- **Legacy pre-upgradeable adapters (6 pairs, Ethereum):** `FraxOFTAdapter`, `FraxEtherOFTAdapter`, `StakedFraxEtherOFTAdapter`, `FraxSharesOFTAdapter`, `FraxPriceIndexOFTAdapter`, `StakedFraxOFTAdapter`. Verified source retrieved, but the target files are absent from both in-scope repos (old layout, not in HEAD). DIFFERS with known source.

### 5.3 UNKNOWN implementations (16 pairs) — excluded pending source retrieval

| Group | Pairs | Notes |
|---|---|---|
| Live hub impl | 1 | §3.2 — the single most important gap |
| Fraxtal plain adapters, 10,431 B | 3 | `0x369f7135…`, `0x773a1660…`, `0xeB904DaD…` — all distinct codehashes (token immutable); 1,398 B smaller than the Ethereum 11,829 B adapters; reason for the size difference NOT established (no OFT flat-build comparison was attempted — out of the task's step-3 scope; do not assume they match either the Ethereum old-gen variant or HEAD) |
| ZkSync + Abstract EraVM | 8 | 85,536 / 92,640 / 105,312 B; Sourcify 404; EraVM bytecode, no EVM comparison possible |
| zkEVM 13,670 B | 1 | `0xEAf6C10a…` — distinct size from the 15,057 B old-gen group; likely a different old-gen variant; NO-RECORD |
| Tempo spoke impl | 1 | §3.3 |
| Tempo 16,881 B + 4,862 B | 2 | `0xB9003536…` (16,881 B on Tempo vs 22,753 B on Somnia/Robinhood — same address, different code per chain), `0xB7E34f51…` (4,862 B on Tempo vs 19,728 B elsewhere) |

### 5.4 OFT proxies

132 OFT proxy pairs are HEAD (plus the deprecated FXS lockbox proxy, also HEAD — 133 proxy-role HEAD pairs in total; standard `TransparentUpgradeableProxy`, target file byte-identical to the pinned fork; PARTIAL verdicts in the diff run are dep-drift-only). Proxy codehash groups: 1,945 B ×3 hashes (42/42/16), 1,985 B ×3 hashes (15/11/6), 11,744 B EraVM (12). The 2 zkEVM flattened proxies (±212 vs the repo flat file) are codehash-identical to modular-verified standard proxies — the ±212 is a flattening artifact, not a code difference. UNKNOWN proxies: 12 EraVM (11,744 B), 4 Fraxtal 1,766 B (a distinct smaller proxy build, unmatched, unique codehash group — proxy code NO-RECORD, low risk as standard-proxy-shaped), 4 dead HopV2 proxies (1,386 B), 25 spoke proxies (§6), 1 hub proxy (§3.2).

## 6. Proxies, admins, timelocks — scoping notes

- **Spoke proxies (25, all UNKNOWN-as-HEAD):** verified on 9 chains as `FraxUpgradeableProxy` from `frax-standard-solidity` — a THIRD repo, not in scope; the file has no counterpart in either in-scope repo. All 25 share one codehash (`0xf27c0a16…`, 1,686 B). The proxy code is retrieved, standard, and uniform; it is simply not repo-HEAD code. The logic verdict lives on the implementation rows. Do not cite the spoke proxies as HEAD-proven or as differing — cite them as third-repo standard proxy code.
- **ProxyAdmins:** 6 HEAD (`FraxProxyAdmin`: Ethereum `0x223a681f…` at 1,592 B, Base, Linea, and the shared `0x000000dbfa…` on Tempo/Robinhood/Somnia). 3 UNKNOWN: the same address `0x223a681f…` on Fraxtal is a different, unmatched 1,803 B deployment (address reuse — it is the live hub/spoke admin on Fraxtal); Monad `0xc2871eae…` (1,751 B); ZkSync `0xE59Dcae5…` (7,264 B EraVM).
- **Timelocks (2, UNKNOWN, out of scope):** `0x8412ebf45bAC1B340BbE8F318b928C466c4E39CA` (Compound-style, solc 0.6.11) and `0xb898Ad2976b4d8f2E21521C9db16b7497825E503` (solc 0.8.29). Verified sources saved; no counterpart in the two in-scope repos. Nearest same-named files in other repos differ — those cross-repo comparisons are NOT HEAD evidence and are not quoted as deltas. Timelocks are control infrastructure, not HopV2/OFT logic.
- **FraxUpgradeableProxy / flat-file hygiene:** the OFT repo's `contracts/flat/` files are stale in places (`FraxOFTUpgradeableFlat.sol` contains `FRAXOFTUpgradeable`). Flat-file comparisons were used only as candidates with best-verdict selection, and the zkEVM OFT delta was established by direct body comparison instead.

## 7. Cross-chain hazards established

- **Address reuse with different code:** e.g. `0x9e951Dd846e748E6fCB58bFb76953c4900f819f4` is 11,829 B on Ethereum but 18,825 B on Ink; `0x231788c09f3936cd343c4f1bded89f0fbe80719c` has 2 hashes across 3 chains; `0xB9003536…`/`0xB7E34f51…` differ between Tempo and other chains. Every verdict in this report is per (chain, address).
- **Immutables defeat naive codehash comparison** for OFT impls and v1 contracts (endpoint/token addresses embedded). All same-size OFT impl codehashes differ even within a size class; twin-diffing (§2.5) is the correct tool, codehash equality the sufficient-but-rare shortcut.
- **Size classes are generations, not proof:** same-size + verified-twin + immutable-only diff = proof; same-size alone = suggestion only. The Fraxtal 10,431 B class has no twin and stays UNKNOWN.

## 8. Alternate verified-source retrieval (v2.0.1 targets) — honest log

All attempts via `work/alt-retrieval-phase0c.cjs` / `work/alt-retrieval-apihost-phase0c.cjs`, with Sourcify-verified controls (old hub impl, old RemoteAdmin) in every batch. Controls failed identically, proving endpoint failures, not verification status. **No v2.0.1 source was retrieved via any Blockscout/Etherscan route; the spoke source came from Sourcify per-chain checks (§2.2).**

| Route | Result |
|---|---|
| `fraxscan.com/api/v2/smart-contracts/<addr>` | HTTP 302 → `../404` for all 10 Fraxtal targets incl. controls. `…/api/v2/stats` → 302 → `…/api/404`; homepage HTTP 200. |
| `fraxscan.com/api?module=contract&action=getsourcecode` | HTTP 200, `{"status":"0","message":"NOTOK","result":"Invalid API URL endpoint, use api.fraxscan.com"}` |
| `api.fraxscan.com/api/v2/smart-contracts/<addr>` | HTTP 404 HTML for all incl. controls (Etherscan clone, not Blockscout) |
| `api.fraxscan.com/api?...getsourcecode` | HTTP 200 NOTOK: "You are using a deprecated V1 endpoint, switch to Etherscan API V2" |
| `api.etherscan.io/v2/api?chainid=1` and `chainid=252`, `getsourcecode` | HTTP 200 NOTOK **"Missing/Invalid API Key"** (server nginx, no cf-ray) — a credential gate, NOT a Cloudflare block. No API key is in scope for this task. |
| `api.fraxscan.com/v2/api?...` | 404 HTML |

**Conclusion: NO-RECORD via these routes for the hub impl, new RemoteAdmins, Tempo spoke impl, Fraxtal plain adapters, and other Sourcify-unmatched implementations.** The browser-based explorer check remains a parent follow-up (§10). No source was guessed.

## 9. Auditable live surface

### 9.1 Filing-ready against repo HEAD (HEAD-proven, live)

These are the only contracts whose **repo-source** findings can be filing-ready without further source work. (Paused/wound-down HEAD contracts — old hub impl, first-gen impls, old RemoteAdmins — are proven but not live; they are listed separately below.)

**OFT mesh (live):** all 89 HEAD-proven OFT implementations (§5.1) + the 132 HEAD-proven OFT proxies behind/around them. Families: `FraxOFTUpgradeable` (25 pairs / 19 chains), `FrxUSDOFTUpgradeable` (19/19), `WFRAXTokenOFTUpgradeable` (18/18), `SFrxUSDOFTUpgradeable` (17/17), `FraxOFTMintableAdapterUpgradeable` (6, Ethereum+Fraxtal), `FraxOFTUpgradeableTempo` (4, Tempo). **Caveat:** use the saved Sourcify trees (§2.6), and note the deployed `version()` signatures where they differ by generation (§5.2 applies to the DIFFERS set, not this set — but verify per contract in the Appendix).

**v1 MintRedeemHop Gen-C (live, `paused=false`):** Robinhood `0xEfb78823eDCB57d78975a33576A7361dBD154d64`, Celo `0x3Fe759e54D619a655650ac64622aCE94BD6b6394`, Somnia `0xE9e53734D2b67Ae263089d7a5dE1F5d97ab8cBDD` — repo HEAD `RemoteMintRedeemHop`.

**Admins (live):** `FraxProxyAdmin` on Ethereum `0x223a681fc5c5522c85c96157c0efa18cd6c5405c`, Base `0xF59C41A57AB4565AF7424F64981523DfD7A453c5`, Linea `0x3cf371c128b092b085B7732069cEAF3Fd863F270`, and shared `0x000000dbfaA1Fb91ca46867cE6D41aB6da4f7428` (Tempo/Robinhood/Somnia).

**HEAD-proven but paused/wound down (not live surface):** old hub impl `0x6550284EA5dcb134a45a6F3c80afa2B30bc56fe9`, first-gen impls (Arbitrum/Base/Ethereum), old RemoteAdmins (Fraxtal/Ethereum/Base/Arbitrum). Findings against these are not live-deployment findings.

### 9.2 Filing-ready against retrieved NON-HEAD source (DIFFERS, source known)

**Live spokes (24 chains):** `RemoteHopV201` — findings must be written against the retrieved V201 tree (`sourcify-hopv2-oft/sources/4663/0x0000000f9a66622C8885E1071B78E37b2b3ecCCd/`, identical on Ink), proven by via-IR rebuild. The repo-HEAD `recover()` arbitrary-call path does not exist here (§3.1).

**v1 Gen-A/Gen-B (paused, except MintRedeemHop which is live):** 28 pairs run known old-generation source (verified trees + twin-proven). Live MintRedeemHop Gen-A/Gen-B deployments (14 pairs) ARE in the live surface against their retrieved old-generation source — with the `transfer()`-vs-`call` and no-`version()` deltas in §4. The 6 legacy adapters and 3 Ethereum old-gen plain adapters and 5 zkEVM old-gen OFTs are DIFFERS-with-known-source; liveness per 0B (legacy adapters are deprecated; zkEVM OFTs are live OFT deployments).

### 9.3 EXCLUDED pending source retrieval (UNKNOWN, live-relevant)

Findings against these MUST NOT be filed from repo source (or any assumed source) until verified source is retrieved or bytecode-level analysis is done:

1. **Live hub implementation** `0x00000000d25B8809150b59ce5dAE5699FfD26485` (Fraxtal, 15,418 B) + hub proxy (1,700 B).
2. **New RemoteAdmins** (Fraxtal 1,269 B, Ethereum 1,225 B).
3. **Tempo spoke implementation** (16,859 B) + Tempo 16,881 B / 4,862 B OFT impls.
4. **Fraxtal plain adapters** (3 × 10,431 B).
5. **EraVM implementations** (8, ZkSync + Abstract) + EraVM proxies/admins + EraVM v1/MR (2).
6. **zkEVM 13,670 B impl** + unproven v1 generations: Plume, Katana, Hyperliquid, Monad, Stable (6 pairs).
7. **Fraxtal v1 hub-side contracts** (DIFFERS-by-build, source unknown — §4).
8. **Fraxtal 1,766 B proxies** (4), **Fraxtal/Monad proxy-admins** (2), **dead HopV2 proxies** (4), **Blast implementations** (undiscoverable — no working RPC).
9. Spoke proxies (25): third-repo code, retrieved and standard — excluded from HEAD claims, not from review; review against the retrieved `FraxUpgradeableProxy` source.

## 10. Parent follow-up: browser-based explorer checks

A generic subagent cannot use the live browser. The following checks need a browser-capable agent (or an Etherscan API key, which would unblock the v2 API route that returned "Missing/Invalid API Key"):

1. **Fraxscan / Etherscan:** is the hub impl `0x00000000d25B8809150b59ce5dAE5699FfD26485` (Fraxtal) verified under any name (check for `FraxtalHopV201`)? Retrieve full source + compiler settings if so.
2. Same for new RemoteAdmins (`0x34029e02821178B4387e12644896994f910D6E73` Fraxtal, `0x181EBC9deA868ED8e5EeeAef7f767D43BF390dFa` Ethereum), Tempo spoke impl `0x00000000b2707226814D5792137fb0B482310A36`, Fraxtal plain adapters (3 × 10,431 B), zkEVM `0xEAf6C10a5660f3f73aC8340A1f726bcDaeE1b419`, Tempo `0xB90035361706A8299F9EC505FFD26598aB2cbaF5` / `0xB7E34f51eC7417e3E0Afb91bD5E33657d911A8d7`.
3. EraVM chains (ZkSync/Abstract explorers): any verification for the 8 EraVM OFT impls + EraVM v1/MR + EraVM proxies?
4. Unproven v1 generations (Plume/Katana/Hyperliquid/Monad/Stable explorers): any verification for the 6 pairs in §4?

If any source is retrieved, re-run the diff step (`work/diff-phase0c.py` + `work/assemble-phase0c.py`) with the new trees placed under `sourcify-hopv2-oft/sources/<chainId>/<address>/` to update verdicts.

## 11. Evidence index

| Artifact | Path |
|---|---|
| This report | `~/workspace/frax-audit/CORRESPONDENCE-HOPV2-OFT.md` |
| Per-pair correspondence records (verdict + basis + notes) | `~/workspace/frax-audit/work/correspondence-phase0c.json` |
| Saved Sourcify sources (181 trees + metadata.json each) | `~/workspace/frax-audit/sourcify-hopv2-oft/sources/<chainId>/<address>/` |
| Sourcify sweep results | `~/workspace/frax-audit/work/sourcify-phase0c.json` (323), `~/workspace/frax-audit/work/sourcify-phase0c-pass2.json` (100); raw responses `~/workspace/frax-audit/work/sourcify-phase0c-raw/` |
| Slot + codehash probe | `~/workspace/frax-audit/work/slots-phase0c.json` |
| Source-diff results | `~/workspace/frax-audit/work/diffs-phase0c.json` |
| Build comparisons | `~/workspace/frax-audit/work/bytecode-compare-phase0c.json`, `~/workspace/frax-audit/work/bytecode-compare-v1-phase0c.json`; V201 rebuild re-verified this session from `~/workspace/frax-audit/work/build-v201/out/` |
| Twin diffs | `~/workspace/frax-audit/work/twin-diff-phase0c.json`, `~/workspace/frax-audit/work/twin-diff-v1-phase0c.json` |
| Alternate-retrieval log | `~/workspace/frax-audit/work/alt-retrieval-phase0c.json`, `~/workspace/frax-audit/work/alt-retrieval-apihost-phase0c.json` |
| Scripts | `~/workspace/frax-audit/work/sourcify-phase0c.cjs`, `sourcify-phase0c-pass2.cjs`, `slots-phase0c.cjs`, `diff-phase0c.py`, `bytecode-compare-phase0c.cjs`, `bytecode-compare-v1-phase0c.cjs`, `twin-diff-phase0c.cjs`, `twin-diff-v1-phase0c.cjs`, `alt-retrieval-phase0c.cjs`, `alt-retrieval-apihost-phase0c.cjs`, `assemble-phase0c.py` |
| Build dirs (outside checkouts) | `~/workspace/frax-audit/work/build-hopv2/`, `build-hopv2-v1/`, `build-v201/`, `build-deps/` (OZ 5.4.0 + 4.8.1 clones) |
| Inputs | `~/workspace/frax-audit/ONCHAIN-GROUNDWORK-HOPV2-OFT.md`, `~/workspace/frax-audit/hopv2-oft-addresses.json`, `~/workspace/frax-audit/work/sourcify-phase0b.json` |

**Known gaps / unknowns (not filled by guessing):** hub impl source; new RemoteAdmin sources; Tempo spoke impl source; Fraxtal plain-adapter source + size-difference reason; Fraxtal v1 exact source deltas; exact OZ 5.0 patch version in old trees; Blast slot/code data (no working RPC); unproven v1 generation sources; EraVM sources.

## Appendix A — Full correspondence table (422 pairs)

`Sourcify`: `exact_match` / `match` / `none(404)` / `unsupported-chain` (Somnia) / `not-checked`. `Comparison`: `diff:` = source-diff result (Frax files; `±N` = changed lines, `ABSENT` = file absent from HEAD); `build:` = forge-build comparison; `twin:`/`twinV1:` = deployed-bytecode diff vs verified twin (diff bytes / regions). Verdicts: **HEAD** = repo HEAD source IS the live code; **DIFFERS** = live code proven to differ; **UNKNOWN** = NO-RECORD; **EXCLUDED** = mock/system address. Per-pair notes and evidence pointers: `work/correspondence-phase0c.json`.

| Chain | Address | Role | Sourcify | Comparison | Verdict | Basis |
|---|---|---|---|---|---|---|
| Ethereum (1) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | build:RemoteHopV201:MATCH | **DIFFERS** | v201-rebuild:MATCH |
| Ethereum (1) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | match | diff:MATCH | **UNKNOWN** | sourcify-diff:third-repo-no-counterpart |
| Ethereum (1) | `0x04ACaF8D2865c0714F79da09645C13FD2888977f` | proxy | exact_match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Ethereum (1) | `0x175e4B98075c81511E476c0c5446ddA95d9106c8` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Ethereum (1) | `0x181EBC9deA868ED8e5EeeAef7f767D43BF390dFa` | remote-admin | none(404) | build:RemoteAdmin:MISMATCH | **DIFFERS** | forge-build:MISMATCH:RemoteAdmin |
| Ethereum (1) | `0x1c1649A38f4A3c5A0c4a24070f688C525AB7D6E6` | proxy | exact_match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Ethereum (1) | `0x1f55a02A049033E3419a8E2975cF3F572F4e6E9A` | direct | match | diff:StakedFraxEtherOFTAdapter.sol ABSENT | **DIFFERS** | sourcify-diff:target-absent-from-HEAD |
| Ethereum (1) | `0x2063961F26019B588F48007D1CC43770e8B7383C` | implementation | none(404) | twin:100B/5r | **HEAD** | twin:immutable-only-diff |
| Ethereum (1) | `0x223a681fc5c5522c85c96157c0efa18cd6c5405c` | proxy-admin | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Ethereum (1) | `0x23432452B720C80553458496D4D9d7C5003280d0` | direct | match | diff:FraxSharesOFTAdapter.sol ABSENT | **DIFFERS** | sourcify-diff:target-absent-from-HEAD |
| Ethereum (1) | `0x3ad4dC2319394bB4BE99A0e4aE2AbF7bCEbD648E` | direct | match | diff:RemoteHop.sol ±19,IExecutor.sol ±2; build:RemoteHop:MISMATCH | **DIFFERS** | sourcify-diff:MISMATCH |
| Ethereum (1) | `0x566a6442A5A6e9895B9dCA97cC7879D632c6e4B0` | proxy | exact_match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Ethereum (1) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | exact_match | diff:PARTIAL(dep-only) | **EXCLUDED** | mock |
| Ethereum (1) | `0x6Eca253b102D41B6B69AC815B9CC6bD47eF1979d` | direct | match | diff:FraxPriceIndexOFTAdapter.sol ABSENT | **DIFFERS** | sourcify-diff:target-absent-from-HEAD |
| Ethereum (1) | `0x7311CEA93ccf5f4F7b789eE31eBA5D9B9290E126` | proxy | exact_match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Ethereum (1) | `0x742109450E2466421b00A2Bf61D513D2616a74FC` | implementation | exact_match | diff:FraxOFTAdapterUpgradeable.sol ±10 | **DIFFERS** | sourcify-diff:MISMATCH |
| Ethereum (1) | `0x7605c24F24e660708fc2E75997935501697A1780` | implementation | exact_match | diff:FraxOFTAdapterUpgradeable.sol ±10 | **DIFFERS** | sourcify-diff:MISMATCH |
| Ethereum (1) | `0x8412ebf45bAC1B340BbE8F318b928C466c4E39CA` | timelock | match | diff:PARTIAL(dep-only) | **UNKNOWN** | manual:out-of-scope-infra |
| Ethereum (1) | `0x8b71237C759052C29A97408CE4b3B7cFebc525e0` | implementation | none(404) | twin:0B/0r | **HEAD** | twin:byte-identical |
| Ethereum (1) | `0x9033BAD7aA130a2466060A2dA71fAe2219781B4b` | proxy | exact_match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Ethereum (1) | `0x909DBdE1eBE906Af95660033e478D59EFe831fED` | direct | match | diff:FraxOFTAdapter.sol ABSENT | **DIFFERS** | sourcify-diff:target-absent-from-HEAD |
| Ethereum (1) | `0x99B5587ab54A49e3F827D10175Caf69C0187bfA8` | direct | match | diff:RemoteMintRedeemHop.sol ±9,IExecutor.sol ±2; build:RemoteMintRedeemHop:MISMATCH | **DIFFERS** | sourcify-diff:MISMATCH |
| Ethereum (1) | `0x9e951Dd846e748E6fCB58bFb76953c4900f819f4` | implementation | exact_match | diff:FraxOFTAdapterUpgradeable.sol ±10 | **DIFFERS** | sourcify-diff:MISMATCH |
| Ethereum (1) | `0xa2db46c06e0B643A926ef60d1fEB744A7385a593` | remote-admin | none(404) | build:RemoteAdmin:MATCH | **HEAD** | forge-build:MATCH:RemoteAdmin |
| Ethereum (1) | `0xb898Ad2976b4d8f2E21521C9db16b7497825E503` | timelock | exact_match | diff:Timelock.sol ±115 | **UNKNOWN** | manual:out-of-scope-infra |
| Ethereum (1) | `0xbBc424e58ED38dd911309611ae2d7A23014Bd960` | proxy | exact_match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Ethereum (1) | `0xC6F59a4fD50cAc677B51558489E03138Ac1784EC` | proxy | exact_match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Ethereum (1) | `0xdFeDeC5Ce317245430C57AcE0Ce9Fb2a17AC0F6E` | implementation | none(404) | build:RemoteHopV2:MATCH; twin:0B/0r | **HEAD** | forge-build:MATCH:RemoteHopV2 |
| Ethereum (1) | `0xe4796cCB6bB5DE2290C417Ac337F2b66CA2E770E` | direct | match | diff:StakedFraxOFTAdapter.sol ABSENT | **DIFFERS** | sourcify-diff:target-absent-from-HEAD |
| Ethereum (1) | `0xF010a7c8877043681D59AD125EbF575633505942` | direct | match | diff:FraxEtherOFTAdapter.sol ABSENT | **DIFFERS** | sourcify-diff:target-absent-from-HEAD |
| Ethereum (1) | `0xF07571beDB8cbd98e6cA43B5Ee0fB178477d2219` | implementation | none(404) | twin:100B/5r | **HEAD** | twin:immutable-only-diff |
| Ethereum (1) | `0xFd3B410b82a00B2651b42A13837204c5e3D92e27` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Optimism (10) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| Optimism (10) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | match | diff:MATCH | **UNKNOWN** | sourcify-diff:third-repo-no-counterpart |
| Optimism (10) | `0x08F27a096CC262b9d100F169B5510FfdA6596a99` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Optimism (10) | `0x2581533557620Cf6d2CafEf9D64957a483e40288` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Optimism (10) | `0x31D982ebd82Ad900358984bd049207A4c2468640` | direct | match | diff:RemoteHop.sol ±19,IExecutor.sol ±2 | **DIFFERS** | sourcify-diff:MISMATCH |
| Optimism (10) | `0x3Ec3849C33291a9eF4c5dB86De593EB4A37fDe45` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Optimism (10) | `0x43eDD7f3831b08FE70B7555ddD373C8bF65a9050` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Optimism (10) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | exact_match | diff:PARTIAL(dep-only) | **EXCLUDED** | mock |
| Optimism (10) | `0x5Bff88cA1442c2496f7E475E9e7786383Bc070c0` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Optimism (10) | `0x64445f0aecC51E94aD52d8AC56b7190e764E561a` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Optimism (10) | `0x681975DdfebaeeEB7400B2407E4CBFe6C41573ad` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Optimism (10) | `0x7a07D606c87b7251c2953A30Fa445d8c5F856C7A` | direct | match | diff:RemoteMintRedeemHop.sol ±9,IExecutor.sol ±2 | **DIFFERS** | sourcify-diff:MISMATCH |
| Optimism (10) | `0x80Eede496655FB9047dd39d9f418d5483ED600df` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Optimism (10) | `0x90581eCa9469D8D7F5D3B60f4715027aDFCf7927` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Optimism (10) | `0xaA2D2f45D1F84F9597dD3d750C3Ba293CA6fc766` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| BSC (56) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| BSC (56) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | match | diff:MATCH | **UNKNOWN** | sourcify-diff:third-repo-no-counterpart |
| BSC (56) | `0x370DD74Dd32d8D47d3Cd0Abc5fcf2Cd1e9912a97` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| BSC (56) | `0x3Ec3849C33291a9eF4c5dB86De593EB4A37fDe45` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| BSC (56) | `0x43eDD7f3831b08FE70B7555ddD373C8bF65a9050` | proxy | match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| BSC (56) | `0x452420df4AC1e3db5429b5FD629f3047482C543C` | direct | match | diff:RemoteHop.sol ±19,IExecutor.sol ±2; build:RemoteHop:MISMATCH | **DIFFERS** | sourcify-diff:MISMATCH |
| BSC (56) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | exact_match | diff:PARTIAL(dep-only) | **EXCLUDED** | mock |
| BSC (56) | `0x5Bff88cA1442c2496f7E475E9e7786383Bc070c0` | proxy | match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| BSC (56) | `0x64445f0aecC51E94aD52d8AC56b7190e764E561a` | proxy | match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| BSC (56) | `0x80Eede496655FB9047dd39d9f418d5483ED600df` | proxy | match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| BSC (56) | `0x90581eCa9469D8D7F5D3B60f4715027aDFCf7927` | proxy | match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| BSC (56) | `0xdee45510b42Cb0678C8A61D043C698aF66b0d852` | direct | match | diff:RemoteMintRedeemHop.sol ±9,IExecutor.sol ±2 | **DIFFERS** | sourcify-diff:MISMATCH |
| BSC (56) | `0xEA12Ae50E998D2551eFABE01c569Be4274a6a684` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| BSC (56) | `0xec74a123fC45e5d8e36abD09B736010ba8fC0Eda` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| BSC (56) | `0xFb9bbE14d8a751725C9348AE72e8DFe68fa109F1` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Unichain (130) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| Unichain (130) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Unichain (130) | `0x231788c09F3936Cd343c4F1bDed89f0fbe80719c` | implementation | none(404) | twin:32B/1r | **HEAD** | twin:immutable-only-diff |
| Unichain (130) | `0x36c28Ef9A8116A64752Efd6B9efA3056F24A82AE` | implementation | none(404) | twin:152B/16r | **HEAD** | twin:immutable-only-diff |
| Unichain (130) | `0x3Ec3849C33291a9eF4c5dB86De593EB4A37fDe45` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Unichain (130) | `0x43eDD7f3831b08FE70B7555ddD373C8bF65a9050` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Unichain (130) | `0x4E7F19d86a81857C46e87182a14B4e894b8Ada1a` | implementation | none(404) | twin:152B/16r | **HEAD** | twin:immutable-only-diff |
| Unichain (130) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | none(404) | — | **EXCLUDED** | mock |
| Unichain (130) | `0x5Bff88cA1442c2496f7E475E9e7786383Bc070c0` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Unichain (130) | `0x64445f0aecC51E94aD52d8AC56b7190e764E561a` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Unichain (130) | `0x80Eede496655FB9047dd39d9f418d5483ED600df` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Unichain (130) | `0x90581eCa9469D8D7F5D3B60f4715027aDFCf7927` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Unichain (130) | `0x91A3f8a8d7a881fBDfcfEcd7A2Dc92a46DCfa14e` | implementation | none(404) | twin:32B/1r | **HEAD** | twin:immutable-only-diff |
| Unichain (130) | `0x983aF86c94Fe3963989c22CeeEb6eA8Eac32D263` | direct | none(404) | twinV1:130B/11r | **DIFFERS** | twin-v1:immutable-only-diff |
| Unichain (130) | `0xc71BF5Ee4740405030eF521F18A96eA14fec802D` | direct | none(404) | twinV1:120B/6r | **DIFFERS** | twin-v1:immutable-only-diff |
| Polygon (137) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| Polygon (137) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | match | diff:MATCH | **UNKNOWN** | sourcify-diff:third-repo-no-counterpart |
| Polygon (137) | `0x02A7A4bfF1edaC698BAc1A2380A208F2E6A56697` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Polygon (137) | `0x2e760c086fBCaC54437153999eedeF3a9f29013e` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Polygon (137) | `0x3Ec3849C33291a9eF4c5dB86De593EB4A37fDe45` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Polygon (137) | `0x43eDD7f3831b08FE70B7555ddD373C8bF65a9050` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Polygon (137) | `0x5658e82E330e094627D9b362ed0E137eA06673C4` | direct | match | diff:RemoteMintRedeemHop.sol ±9,IExecutor.sol ±2 | **DIFFERS** | sourcify-diff:MISMATCH |
| Polygon (137) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | exact_match | diff:PARTIAL(dep-only) | **EXCLUDED** | mock |
| Polygon (137) | `0x5Bff88cA1442c2496f7E475E9e7786383Bc070c0` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Polygon (137) | `0x64445f0aecC51E94aD52d8AC56b7190e764E561a` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Polygon (137) | `0x6D5791E23e026cA13E1CE74De2F7BEEa29D5AA7e` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Polygon (137) | `0x80Eede496655FB9047dd39d9f418d5483ED600df` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Polygon (137) | `0x8383EDf0B101249A632D1d5372BAf0D7709D65fE` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Polygon (137) | `0x90581eCa9469D8D7F5D3B60f4715027aDFCf7927` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Polygon (137) | `0xf74D38A26948E9DDa53eD85cF03C6b1188FbB30C` | direct | match | diff:RemoteHop.sol ±19,IExecutor.sol ±2; build:RemoteHop:MISMATCH | **DIFFERS** | sourcify-diff:MISMATCH |
| Monad (143) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| Monad (143) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Monad (143) | `0x40f66fff44dbbee88058185f2cfe287558d7e532` | direct | none(404) | — | **UNKNOWN** | no-record |
| Monad (143) | `0x92e6892706053ee85fc1178affcb3803118d2c4f` | direct | none(404) | — | **UNKNOWN** | no-record |
| Monad (143) | `0xc2871eae630640ce1a16b39a17c498f22d76c21a` | proxy-admin | none(404) | — | **UNKNOWN** | no-record |
| Sonic (146) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| Sonic (146) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Sonic (146) | `0x3A5cDA3Ac66Aa80573402610c94B74eD6cdb2F23` | direct | none(404) | twinV1:80B/4r | **DIFFERS** | twin-v1:immutable-only-diff |
| Sonic (146) | `0x3Ec3849C33291a9eF4c5dB86De593EB4A37fDe45` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:MATCH-target-clean |
| Sonic (146) | `0x43eDD7f3831b08FE70B7555ddD373C8bF65a9050` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Sonic (146) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | none(404) | — | **EXCLUDED** | mock |
| Sonic (146) | `0x5815491CCC92666da273bE16081C98Aba458823e` | implementation | none(404) | twin:32B/1r | **HEAD** | twin:immutable-only-diff |
| Sonic (146) | `0x592a48c0FB9c7f8BF1701cB0136b90DEa2A5B7B6` | implementation | none(404) | twin:152B/16r | **HEAD** | twin:immutable-only-diff |
| Sonic (146) | `0x5Bff88cA1442c2496f7E475E9e7786383Bc070c0` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:MATCH-target-clean |
| Sonic (146) | `0x64445f0aecC51E94aD52d8AC56b7190e764E561a` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:MATCH-target-clean |
| Sonic (146) | `0x80Eede496655FB9047dd39d9f418d5483ED600df` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:MATCH-target-clean |
| Sonic (146) | `0x90581eCa9469D8D7F5D3B60f4715027aDFCf7927` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:MATCH-target-clean |
| Sonic (146) | `0xC45ea5d262405932fE2CC8D01cD90685CA8292Ca` | implementation | none(404) | twin:152B/16r | **HEAD** | twin:immutable-only-diff |
| Sonic (146) | `0xCd223049c07c10bA31612D6fbCe1731E9Cc20Bbf` | implementation | none(404) | twin:32B/1r | **HEAD** | twin:immutable-only-diff |
| Sonic (146) | `0xf6115Bb9b6A4b3660dA409cB7afF1fb773efaD0b` | direct | none(404) | twinV1:85B/9r | **DIFFERS** | twin-v1:immutable-only-diff |
| XLayer (196) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| XLayer (196) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | none(404) | — | **UNKNOWN** | no-record |
| XLayer (196) | `0x1D21D1E79792C8ccd0064e209006697d2d9E8D4f` | implementation | none(404) | twin:0B/0r | **HEAD** | twin:byte-identical |
| XLayer (196) | `0x1ed5dDc7d623408A7d2E9236739B90D484Eb5f6f` | implementation | none(404) | twin:0B/0r | **HEAD** | twin:byte-identical |
| XLayer (196) | `0x3Ec3849C33291a9eF4c5dB86De593EB4A37fDe45` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| XLayer (196) | `0x43eDD7f3831b08FE70B7555ddD373C8bF65a9050` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| XLayer (196) | `0x45c6852A5188Ce1905567EA83454329bd4982007` | direct | none(404) | twinV1:125B/11r | **DIFFERS** | twin-v1:immutable-only-diff |
| XLayer (196) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | none(404) | — | **EXCLUDED** | mock |
| XLayer (196) | `0x5Bff88cA1442c2496f7E475E9e7786383Bc070c0` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| XLayer (196) | `0x64445f0aecC51E94aD52d8AC56b7190e764E561a` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| XLayer (196) | `0x79152c303AD5aE429eDefa4553CB1Ad2c6EE1396` | direct | none(404) | twinV1:118B/6r | **DIFFERS** | twin-v1:immutable-only-diff |
| XLayer (196) | `0x80Eede496655FB9047dd39d9f418d5483ED600df` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| XLayer (196) | `0x82187Dc7F09a6a289Ffba5Cd80a67eF85eAF1e89` | implementation | none(404) | twin:0B/0r | **HEAD** | twin:byte-identical |
| XLayer (196) | `0x90581eCa9469D8D7F5D3B60f4715027aDFCf7927` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| XLayer (196) | `0x98bF0cFAe290D0Dd02196e5B46d1a35Dbd875C22` | implementation | none(404) | twin:0B/0r | **HEAD** | twin:byte-identical |
| Fraxtal (252) | `0x00000000d25B8809150b59ce5dAE5699FfD26485` | implementation | none(404) | build:RemoteHopV201:MISMATCH | **UNKNOWN** | no-record |
| Fraxtal (252) | `0x00000000e18aFc20Afe54d4B2C8688bB60c06B36` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Fraxtal (252) | `0x17f173e0D487dfaD794B528dA2830095Ca302dc7` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Fraxtal (252) | `0x223a681fc5c5522c85c96157c0efa18cd6c5405c` | proxy-admin | none(404) | — | **UNKNOWN** | no-record |
| Fraxtal (252) | `0x2A2019b30C157dB6c1C01306b8025167dBe1803B` | direct | none(404) | build:FraxtalHop:MISMATCH | **DIFFERS** | forge-build:MISMATCH:FraxtalHop |
| Fraxtal (252) | `0x34029e02821178B4387e12644896994f910D6E73` | remote-admin | none(404) | build:RemoteAdmin:MISMATCH | **DIFFERS** | forge-build:MISMATCH:RemoteAdmin |
| Fraxtal (252) | `0x369f71356e0d0E102C2434DaC92603aFbF9ee82A` | implementation | none(404) | — | **UNKNOWN** | no-record |
| Fraxtal (252) | `0x3e6a2cBaFD864e09e6DAb9Cf035a0AbEa32bc0BC` | direct | none(404) | build:FraxtalMintRedeemHop:MISMATCH | **DIFFERS** | forge-build:MISMATCH:FraxtalMintRedeemHop |
| Fraxtal (252) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | none(404) | — | **EXCLUDED** | mock |
| Fraxtal (252) | `0x6550284EA5dcb134a45a6F3c80afa2B30bc56fe9` | implementation | match | diff:MATCH; build:FraxtalHopV2:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Fraxtal (252) | `0x75c38D46001b0F8108c4136216bd2694982C20FC` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Fraxtal (252) | `0x773a166030C08C72c42D0cb38f9e3A0dE5A112c6` | implementation | none(404) | — | **UNKNOWN** | no-record |
| Fraxtal (252) | `0x8861AB8683CfD1FCC84327415888B870aB144f51` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Fraxtal (252) | `0x88Aa7854D3b2dAA5e37E7Ce73A1F39669623a361` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Fraxtal (252) | `0x96A394058E2b84A89bac9667B19661Ed003cF5D4` | proxy | exact_match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Fraxtal (252) | `0x999dfAbe3b1cc2EF66eB032Eea42FeA329bBa168` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Fraxtal (252) | `0x9aBFE1F8a999B0011ecD6116649AEe8D575F5604` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Fraxtal (252) | `0xd86fBBd0c8715d2C1f40e451e5C3514e65E7576A` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Fraxtal (252) | `0xDC3369C18Ff9C077B803C98b6260a186aDE9A426` | remote-admin | match | diff:MATCH; build:RemoteAdmin:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Fraxtal (252) | `0xE0c5294bfb2355d7Ae36AD7a3387A2c902fb26a8` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Fraxtal (252) | `0xe8Cd13de17CeC6FCd9dD5E0a1465Da240f951536` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Fraxtal (252) | `0xeB904DaDce7493D23500e96115B4EFF038756Cfc` | implementation | none(404) | — | **UNKNOWN** | no-record |
| ZkSync (324) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| ZkSync (324) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | none(404) | — | **UNKNOWN** | no-record |
| ZkSync (324) | `0x2587068F36F0FDFe8f014DaB0F96104E6901cE49` | implementation | none(404) | — | **UNKNOWN** | no-record |
| ZkSync (324) | `0x30d789e5c962eF1F44D05E1d9A174a53E220A4C2` | implementation | none(404) | — | **UNKNOWN** | no-record |
| ZkSync (324) | `0x3Fc877008e396FdD7f9Ee3Deb2e8A54d54da705A` | direct | none(404) | — | **EXCLUDED** | mock |
| ZkSync (324) | `0x580F2ee1476eDF4B1760bd68f6AaBaD57dec420E` | proxy | none(404) | — | **UNKNOWN** | no-record |
| ZkSync (324) | `0x9F87fbb47C33Cd0614E43500b9511018116F79eE` | proxy | none(404) | — | **UNKNOWN** | no-record |
| ZkSync (324) | `0xa05e9f9b97c963b5651ed6a50fae46625a8c400b` | direct | none(404) | — | **UNKNOWN** | no-record |
| ZkSync (324) | `0xAf01aE13Fb67AD2bb2D76f29A83961069a5F245F` | proxy | none(404) | — | **UNKNOWN** | no-record |
| ZkSync (324) | `0xc5e4a0cfef8d801278927c25fb51c1db7b69ddfb` | direct | none(404) | — | **UNKNOWN** | no-record |
| ZkSync (324) | `0xc7Ab797019156b543B7a3fBF5A99ECDab9eb4440` | proxy | none(404) | — | **UNKNOWN** | no-record |
| ZkSync (324) | `0xe59dcae52a4ffa39be99588486c84bc2dc1ba52f` | proxy-admin | none(404) | — | **UNKNOWN** | no-record |
| ZkSync (324) | `0xEa77c590Bb36c43ef7139cE649cFBCFD6163170d` | proxy | none(404) | — | **UNKNOWN** | no-record |
| ZkSync (324) | `0xF559acAa7283C78a7eC244Fcf62C6B01F5676442` | implementation | none(404) | — | **UNKNOWN** | no-record |
| ZkSync (324) | `0xfD316f51F0FF2C6d4D170E3744B40f7b315EDa41` | implementation | none(404) | — | **UNKNOWN** | no-record |
| ZkSync (324) | `0xFD78FD3667DeF2F1097Ed221ec503AE477155394` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Worldchain (480) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| Worldchain (480) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Worldchain (480) | `0x111ddab65Af5fF96b674400246699ED40F550De1` | direct | none(404) | twinV1:130B/11r | **DIFFERS** | twin-v1:immutable-only-diff |
| Worldchain (480) | `0x3Ec3849C33291a9eF4c5dB86De593EB4A37fDe45` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Worldchain (480) | `0x43eDD7f3831b08FE70B7555ddD373C8bF65a9050` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Worldchain (480) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | none(404) | — | **EXCLUDED** | mock |
| Worldchain (480) | `0x5Bff88cA1442c2496f7E475E9e7786383Bc070c0` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Worldchain (480) | `0x64445f0aecC51E94aD52d8AC56b7190e764E561a` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Worldchain (480) | `0x6C7484758A2E972E06F01495050C795Bee7A997b` | implementation | none(404) | twin:32B/1r | **HEAD** | twin:immutable-only-diff |
| Worldchain (480) | `0x803dEdb83Fe86C20369b9Cb26CD8A293fd1C78e7` | implementation | none(404) | twin:152B/16r | **HEAD** | twin:immutable-only-diff |
| Worldchain (480) | `0x80Eede496655FB9047dd39d9f418d5483ED600df` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Worldchain (480) | `0x90581eCa9469D8D7F5D3B60f4715027aDFCf7927` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Worldchain (480) | `0x938d99A81814f66b01010d19DDce92A633441699` | direct | none(404) | twinV1:120B/6r | **DIFFERS** | twin-v1:immutable-only-diff |
| Worldchain (480) | `0xAb7d4C8FA387e57d99cbd976CeD90d480Fec4916` | implementation | none(404) | twin:32B/1r | **HEAD** | twin:immutable-only-diff |
| Worldchain (480) | `0xeFdF0Dea7048D9784D6289002f65d0f3E9764d6B` | implementation | none(404) | twin:152B/16r | **HEAD** | twin:immutable-only-diff |
| Stable (988) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| Stable (988) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | match | diff:MATCH | **UNKNOWN** | sourcify-diff:third-repo-no-counterpart |
| Stable (988) | `0x938Ca0dbaF2876011CD43598b14acA21a6c61b6e` | direct | none(404) | — | **UNKNOWN** | no-record |
| Stable (988) | `0xA27eCe4f3108655dCE7d8aD684B780a2163928A1` | direct | none(404) | — | **UNKNOWN** | no-record |
| Hyperliquid (999) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| Hyperliquid (999) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Hyperliquid (999) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | none(404) | — | **EXCLUDED** | mock |
| Hyperliquid (999) | `0x8EbB34b1880B2EA5e458082590B3A2c9Ea7C41A2` | direct | none(404) | — | **UNKNOWN** | no-record |
| Hyperliquid (999) | `0xb85A8FDa7F5e52E32fa5582847CFfFee9456a5Dc` | direct | none(404) | — | **UNKNOWN** | no-record |
| zkEVM (1101) | `0x1baB75610B42b2c6547019f23807a7DA61837779` | implementation | none(404) | — | **DIFFERS** | codehash-identity:manual:old-generation-body |
| zkEVM (1101) | `0x3Ec3849C33291a9eF4c5dB86De593EB4A37fDe45` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:MATCH-target-clean |
| zkEVM (1101) | `0x40B5984C1Ca72E26CbbE6221160883f5e3a76D5E` | implementation | none(404) | — | **DIFFERS** | codehash-identity:manual:old-generation-body |
| zkEVM (1101) | `0x43eDD7f3831b08FE70B7555ddD373C8bF65a9050` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:MATCH-target-clean |
| zkEVM (1101) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | exact_match | diff:PARTIAL(dep-only) | **EXCLUDED** | mock |
| zkEVM (1101) | `0x5Bff88cA1442c2496f7E475E9e7786383Bc070c0` | proxy | match | diff:TransparentUpgradeableProxy.sol ±212 | **HEAD** | manual:proxy-codehash-standard |
| zkEVM (1101) | `0x64445f0aecC51E94aD52d8AC56b7190e764E561a` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:MATCH-target-clean |
| zkEVM (1101) | `0x6A678cEfcA10d5bBe4638D27C671CE7d56865037` | implementation | match | diff:FraxOFTUpgradeable.sol ±2588 | **DIFFERS** | manual:old-generation-body |
| zkEVM (1101) | `0x7fEDa252881b9c6166B387d3d11d1BDFC076d5CB` | implementation | match | diff:FraxOFTUpgradeable.sol ±2588 | **DIFFERS** | manual:old-generation-body |
| zkEVM (1101) | `0x80Eede496655FB9047dd39d9f418d5483ED600df` | proxy | match | diff:TransparentUpgradeableProxy.sol ±212 | **HEAD** | manual:proxy-codehash-standard |
| zkEVM (1101) | `0x90581eCa9469D8D7F5D3B60f4715027aDFCf7927` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:MATCH-target-clean |
| zkEVM (1101) | `0xAdE2b968674724Ce009576b5C1E4A7d69f365D37` | implementation | none(404) | — | **DIFFERS** | codehash-identity:manual:old-generation-body |
| zkEVM (1101) | `0xEAf6C10a5660f3f73aC8340A1f726bcDaeE1b419` | implementation | none(404) | — | **UNKNOWN** | no-record |
| Sei (1329) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| Sei (1329) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Sei (1329) | `0x0255a172d0a060F2bEab3e7c12334dD73cCC26ba` | direct | match | diff:RemoteMintRedeemHop.sol ±9,IExecutor.sol ±2 | **DIFFERS** | sourcify-diff:MISMATCH |
| Sei (1329) | `0x3a6F28e8DDD232B02C72C491Bd1626F69D2fb329` | direct | match | diff:RemoteHop.sol ±19,IExecutor.sol ±2 | **DIFFERS** | sourcify-diff:MISMATCH |
| Sei (1329) | `0x3d9eC5191Af8447BbcB61ff460944056be350013` | implementation | none(404) | twin:0B/0r | **HEAD** | twin:byte-identical |
| Sei (1329) | `0x3Ec3849C33291a9eF4c5dB86De593EB4A37fDe45` | proxy | match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Sei (1329) | `0x43eDD7f3831b08FE70B7555ddD373C8bF65a9050` | proxy | match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Sei (1329) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | none(404) | — | **EXCLUDED** | mock |
| Sei (1329) | `0x5Bff88cA1442c2496f7E475E9e7786383Bc070c0` | proxy | match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Sei (1329) | `0x64445f0aecC51E94aD52d8AC56b7190e764E561a` | proxy | match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Sei (1329) | `0x80Eede496655FB9047dd39d9f418d5483ED600df` | proxy | match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Sei (1329) | `0x90581eCa9469D8D7F5D3B60f4715027aDFCf7927` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Sei (1329) | `0xA140Ac7d8EdA834933bbb94A575eC7037386079D` | implementation | none(404) | twin:0B/0r | **HEAD** | twin:byte-identical |
| Sei (1329) | `0xB5e839659BB9070cCE2bEc3Db8F038F0E7950Cd5` | implementation | none(404) | twin:0B/0r | **HEAD** | twin:byte-identical |
| Sei (1329) | `0xBC36Cb5A521458C41A9ce6199Bc9Cc62E4069c7F` | implementation | none(404) | twin:0B/0r | **HEAD** | twin:byte-identical |
| Abstract (2741) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| Abstract (2741) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Abstract (2741) | `0x2587068F36F0FDFe8f014DaB0F96104E6901cE49` | implementation | none(404) | — | **UNKNOWN** | no-record |
| Abstract (2741) | `0x30d789e5c962eF1F44D05E1d9A174a53E220A4C2` | implementation | none(404) | — | **UNKNOWN** | no-record |
| Abstract (2741) | `0x580F2ee1476eDF4B1760bd68f6AaBaD57dec420E` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Abstract (2741) | `0x9F87fbb47C33Cd0614E43500b9511018116F79eE` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Abstract (2741) | `0xAf01aE13Fb67AD2bb2D76f29A83961069a5F245F` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Abstract (2741) | `0xBd39033994F5324Fe8D50bB524396A78ff9dFe22` | direct | none(404) | — | **EXCLUDED** | mock |
| Abstract (2741) | `0xc7Ab797019156b543B7a3fBF5A99ECDab9eb4440` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Abstract (2741) | `0xEa77c590Bb36c43ef7139cE649cFBCFD6163170d` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Abstract (2741) | `0xF559acAa7283C78a7eC244Fcf62C6B01F5676442` | implementation | none(404) | — | **UNKNOWN** | no-record |
| Abstract (2741) | `0xfD316f51F0FF2C6d4D170E3744B40f7b315EDa41` | implementation | none(404) | — | **UNKNOWN** | no-record |
| Abstract (2741) | `0xFD78FD3667DeF2F1097Ed221ec503AE477155394` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Tempo (4217) | `0x00000000883279097A49dB1f2af954EAd0C77E3c` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Tempo (4217) | `0x000000008c3930dCA540bB9B3A5D0ee78FcA9A4c` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Tempo (4217) | `0x00000000b2707226814D5792137fb0B482310A36` | implementation | none(404) | build:RemoteHopV201:MISMATCH | **UNKNOWN** | no-record |
| Tempo (4217) | `0x00000000D61733e7A393A10A5B48c311AbE8f1E5` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Tempo (4217) | `0x00000000E9CE0f293D1Ce552768b187eBA8a56D4` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Tempo (4217) | `0x00000000fD8C4B8A413A06821456801295921a71` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Tempo (4217) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Tempo (4217) | `0x000000dbfaA1Fb91ca46867cE6D41aB6da4f7428` | proxy-admin | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:MATCH-target-clean |
| Tempo (4217) | `0x20C0000000000000000000003554d28269E0f3c2` | direct | none(404) | — | **EXCLUDED** | manual:system-address |
| Tempo (4217) | `0x3cF546bAb0cE157794834f8FA3d9170b36E55989` | implementation | none(404) | twin:0B/0r | **HEAD** | twin:byte-identical |
| Tempo (4217) | `0x5a2C5B3BB5f1865149bc090BD6CFe9BCdBC61F75` | implementation | none(404) | twin:0B/0r | **HEAD** | twin:byte-identical |
| Tempo (4217) | `0x766c2BD9C6dDc5BeE9ACd7D4C8ADD5b969952969` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Tempo (4217) | `0xB7E34f51eC7417e3E0Afb91bD5E33657d911A8d7` | implementation | none(404) | — | **UNKNOWN** | no-record |
| Tempo (4217) | `0xB90035361706A8299F9EC505FFD26598aB2cbaF5` | implementation | none(404) | — | **UNKNOWN** | no-record |
| Tempo (4217) | `0xCDB811527345F3BB76E8a9bd8D4b865624504337` | implementation | none(404) | twin:0B/0r | **HEAD** | twin:byte-identical |
| Tempo (4217) | `0xDb0fEac2227FB4cD887b0eCeb8DD074802552794` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Robinhood (4663) | `0x00000000883279097A49dB1f2af954EAd0C77E3c` | proxy | exact_match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Robinhood (4663) | `0x000000008c3930dCA540bB9B3A5D0ee78FcA9A4c` | proxy | exact_match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Robinhood (4663) | `0x00000000D61733e7A393A10A5B48c311AbE8f1E5` | proxy | exact_match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Robinhood (4663) | `0x00000000E9CE0f293D1Ce552768b187eBA8a56D4` | proxy | exact_match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Robinhood (4663) | `0x00000000fD8C4B8A413A06821456801295921a71` | proxy | exact_match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Robinhood (4663) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | match | diff:HopV201.sol ABSENT,RemoteHopV201.sol ABSENT,IHopV201.sol ABSENT; build:RemoteHopV201:MATCH | **DIFFERS** | sourcify-diff:target-absent-from-HEAD |
| Robinhood (4663) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | match | diff:MATCH | **UNKNOWN** | sourcify-diff:third-repo-no-counterpart |
| Robinhood (4663) | `0x000000dbfaA1Fb91ca46867cE6D41aB6da4f7428` | proxy-admin | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Robinhood (4663) | `0x3cF546bAb0cE157794834f8FA3d9170b36E55989` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Robinhood (4663) | `0x5a2C5B3BB5f1865149bc090BD6CFe9BCdBC61F75` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Robinhood (4663) | `0xB7E34f51eC7417e3E0Afb91bD5E33657d911A8d7` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Robinhood (4663) | `0xB90035361706A8299F9EC505FFD26598aB2cbaF5` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Robinhood (4663) | `0xCDB811527345F3BB76E8a9bd8D4b865624504337` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Robinhood (4663) | `0xEfb78823eDCB57d78975a33576A7361dBD154d64` | direct | match | diff:MATCH; build:RemoteMintRedeemHop:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Somnia (5031) | `0x00000000883279097A49dB1f2af954EAd0C77E3c` | proxy | unsupported-chain | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Somnia (5031) | `0x000000008c3930dCA540bB9B3A5D0ee78FcA9A4c` | proxy | unsupported-chain | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Somnia (5031) | `0x00000000D61733e7A393A10A5B48c311AbE8f1E5` | proxy | unsupported-chain | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Somnia (5031) | `0x00000000E9CE0f293D1Ce552768b187eBA8a56D4` | proxy | unsupported-chain | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Somnia (5031) | `0x00000000fD8C4B8A413A06821456801295921a71` | proxy | unsupported-chain | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Somnia (5031) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | unsupported-chain | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| Somnia (5031) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | unsupported-chain | — | **UNKNOWN** | no-record |
| Somnia (5031) | `0x000000dbfaA1Fb91ca46867cE6D41aB6da4f7428` | proxy-admin | unsupported-chain | — | **HEAD** | codehash-identity:sourcify-diff:MATCH-target-clean |
| Somnia (5031) | `0x3cF546bAb0cE157794834f8FA3d9170b36E55989` | implementation | unsupported-chain | twin:0B/0r | **HEAD** | twin:byte-identical |
| Somnia (5031) | `0x5a2C5B3BB5f1865149bc090BD6CFe9BCdBC61F75` | implementation | unsupported-chain | twin:0B/0r | **HEAD** | twin:byte-identical |
| Somnia (5031) | `0xB7E34f51eC7417e3E0Afb91bD5E33657d911A8d7` | implementation | unsupported-chain | twin:0B/0r | **HEAD** | twin:byte-identical |
| Somnia (5031) | `0xB90035361706A8299F9EC505FFD26598aB2cbaF5` | implementation | unsupported-chain | twin:0B/0r | **HEAD** | twin:byte-identical |
| Somnia (5031) | `0xCDB811527345F3BB76E8a9bd8D4b865624504337` | implementation | unsupported-chain | twin:0B/0r | **HEAD** | twin:byte-identical |
| Somnia (5031) | `0xE9e53734D2b67Ae263089d7a5dE1F5d97ab8cBDD` | direct | unsupported-chain | build:RemoteMintRedeemHop:MATCH | **HEAD** | forge-build:MATCH:RemoteMintRedeemHop |
| Base (8453) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| Base (8453) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | match | diff:MATCH | **UNKNOWN** | sourcify-diff:third-repo-no-counterpart |
| Base (8453) | `0x039c5144D6395CBC6ff0698E0A42d708eaE2E5F4` | implementation | match | diff:MATCH; build:RemoteHopV2:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Base (8453) | `0x0CEAC003B0d2479BebeC9f4b2EBAd0a803759bbf` | proxy | exact_match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Base (8453) | `0x15f6eFE4806F526B4E870596c36b4C56299f618B` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Base (8453) | `0x192e0C7Cc9B263D93fa6d472De47bBefe1Fb12bA` | proxy | exact_match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Base (8453) | `0x22beDD55A0D29Eb31e75C70F54fADa7Ca94339B9` | proxy | match | diff:MATCH | **UNKNOWN** | sourcify-diff:third-repo-no-counterpart |
| Base (8453) | `0x3Ec3849C33291a9eF4c5dB86De593EB4A37fDe45` | direct | match | diff:RemoteHop.sol ±17,IExecutor.sol ±2 | **DIFFERS** | sourcify-diff:MISMATCH |
| Base (8453) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | exact_match | diff:PARTIAL(dep-only) | **EXCLUDED** | mock |
| Base (8453) | `0x73382eb28F35d80Df8C3fe04A3EED71b1aFce5dE` | direct | match | diff:RemoteMintRedeemHop.sol ±7,IExecutor.sol ±2 | **DIFFERS** | sourcify-diff:MISMATCH |
| Base (8453) | `0x7eb8d1E4E2D0C8b9bEDA7a97b305cF49F3eeE8dA` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Base (8453) | `0x91A3f8a8d7a881fBDfcfEcd7A2Dc92a46DCfa14e` | proxy | exact_match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Base (8453) | `0xcB5C5c2F47d8986E92EDa5BeA98eD05a3318439F` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Base (8453) | `0xCcc012D6a3E68Ab69f8F5B1DfE5C2ddC92c9f6d7` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Base (8453) | `0xDC4944793b86c337a0498E31f6Bd0F2F814c0F42` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Base (8453) | `0xe5020A6d073a794B6E7f05678707dE47986Fb0b6` | proxy | exact_match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Base (8453) | `0xEEdd3A0DDDF977462A97C1F0eBb89C3fbe8D084B` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Base (8453) | `0xF333d66C7e47053b96bC153Bfdfaa05c8BEe7307` | remote-admin | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Base (8453) | `0xF59C41A57AB4565AF7424F64981523DfD7A453c5` | proxy-admin | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Plasma (9745) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | none(404) | — | **EXCLUDED** | mock |
| Mode (34443) | `0x3d9eC5191Af8447BbcB61ff460944056be350013` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Mode (34443) | `0x3Ec3849C33291a9eF4c5dB86De593EB4A37fDe45` | proxy | match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Mode (34443) | `0x43eDD7f3831b08FE70B7555ddD373C8bF65a9050` | proxy | match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Mode (34443) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | none(404) | — | **EXCLUDED** | mock |
| Mode (34443) | `0x5Bff88cA1442c2496f7E475E9e7786383Bc070c0` | proxy | match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Mode (34443) | `0x64445f0aecC51E94aD52d8AC56b7190e764E561a` | proxy | match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Mode (34443) | `0x80Eede496655FB9047dd39d9f418d5483ED600df` | proxy | match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Mode (34443) | `0x90581eCa9469D8D7F5D3B60f4715027aDFCf7927` | proxy | match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Mode (34443) | `0xA140Ac7d8EdA834933bbb94A575eC7037386079D` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Mode (34443) | `0xB5e839659BB9070cCE2bEc3Db8F038F0E7950Cd5` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Mode (34443) | `0xBC36Cb5A521458C41A9ce6199Bc9Cc62E4069c7F` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Arbitrum (42161) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| Arbitrum (42161) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | match | diff:MATCH | **UNKNOWN** | sourcify-diff:third-repo-no-counterpart |
| Arbitrum (42161) | `0x03047fA366900b4cBf5E8F9FEEce97553f20370e` | remote-admin | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Arbitrum (42161) | `0x29F5DBD0FE72d8f11271FCBE79Cb87E18a83C70A` | direct | match | diff:RemoteHop.sol ±19,IExecutor.sol ±2 | **DIFFERS** | sourcify-diff:MISMATCH |
| Arbitrum (42161) | `0x338ED3Ad7FbbC17c5C025530e54D8a83CeA5494d` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Arbitrum (42161) | `0x3cf371c128b092b085B7732069cEAF3Fd863F270` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Arbitrum (42161) | `0x3Ec3849C33291a9eF4c5dB86De593EB4A37fDe45` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Arbitrum (42161) | `0x43eDD7f3831b08FE70B7555ddD373C8bF65a9050` | proxy | match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Arbitrum (42161) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | exact_match | diff:PARTIAL(dep-only) | **EXCLUDED** | mock |
| Arbitrum (42161) | `0x5Bff88cA1442c2496f7E475E9e7786383Bc070c0` | proxy | match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Arbitrum (42161) | `0x64445f0aecC51E94aD52d8AC56b7190e764E561a` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Arbitrum (42161) | `0x80Eede496655FB9047dd39d9f418d5483ED600df` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Arbitrum (42161) | `0x90581eCa9469D8D7F5D3B60f4715027aDFCf7927` | proxy | match | diff:PARTIAL(dep-only) | **HEAD** | sourcify-diff:PARTIAL-target-clean |
| Arbitrum (42161) | `0xa46A266dCBf199a71532c76967e200994C5A0D6d` | direct | match | diff:RemoteMintRedeemHop.sol ±9,IExecutor.sol ±2 | **DIFFERS** | sourcify-diff:MISMATCH |
| Arbitrum (42161) | `0xB4523b73CD695827d663A67f955f9E87C164f85c` | implementation | match | diff:MATCH; build:RemoteHopV2:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Arbitrum (42161) | `0xc3C747e76A3700d611fB76cae9A8AB3411835CA0` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Arbitrum (42161) | `0xf307Ad241E1035062Ed11F444740f108B8D036a6` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Arbitrum (42161) | `0xfDAAaC78248BCF8eeb741FdFF54006447BB32D21` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Celo (42220) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| Celo (42220) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Celo (42220) | `0x3Fe759e54D619a655650ac64622aCE94BD6b6394` | direct | match | diff:MATCH; build:RemoteMintRedeemHop:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Avalanche (43114) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| Avalanche (43114) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Avalanche (43114) | `0x3Ec3849C33291a9eF4c5dB86De593EB4A37fDe45` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Avalanche (43114) | `0x43eDD7f3831b08FE70B7555ddD373C8bF65a9050` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Avalanche (43114) | `0x452420df4AC1e3db5429b5FD629f3047482C543C` | direct | none(404) | twinV1:125B/11r | **DIFFERS** | twin-v1:immutable-only-diff |
| Avalanche (43114) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | exact_match | diff:PARTIAL(dep-only) | **EXCLUDED** | mock |
| Avalanche (43114) | `0x5Bff88cA1442c2496f7E475E9e7786383Bc070c0` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Avalanche (43114) | `0x64445f0aecC51E94aD52d8AC56b7190e764E561a` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Avalanche (43114) | `0x686cABd9B4A41965184fbb95F2AE80c20BeF18Ab` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Avalanche (43114) | `0x7a07D606c87b7251c2953A30Fa445d8c5F856C7A` | direct | match | diff:RemoteHop.sol ±19,IExecutor.sol ±2 | **DIFFERS** | sourcify-diff:MISMATCH |
| Avalanche (43114) | `0x80Eede496655FB9047dd39d9f418d5483ED600df` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Avalanche (43114) | `0x8AA56ceB925f04156075e7b0cb71Bd6ecaB78830` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Avalanche (43114) | `0x90581eCa9469D8D7F5D3B60f4715027aDFCf7927` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Avalanche (43114) | `0x96A394058E2b84A89bac9667B19661Ed003cF5D4` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Avalanche (43114) | `0xb47CBaa686D0396cA863eca35ff2e9E85B550d43` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Ink (57073) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | match | diff:HopV201.sol ABSENT,RemoteHopV201.sol ABSENT,IHopV201.sol ABSENT; build:RemoteHopV201:MATCH | **DIFFERS** | sourcify-diff:target-absent-from-HEAD |
| Ink (57073) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Ink (57073) | `0x3Ec3849C33291a9eF4c5dB86De593EB4A37fDe45` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Ink (57073) | `0x43eDD7f3831b08FE70B7555ddD373C8bF65a9050` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Ink (57073) | `0x452420df4AC1e3db5429b5FD629f3047482C543C` | direct | none(404) | twinV1:125B/11r | **DIFFERS** | twin-v1:immutable-only-diff |
| Ink (57073) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | none(404) | — | **EXCLUDED** | mock |
| Ink (57073) | `0x5Bff88cA1442c2496f7E475E9e7786383Bc070c0` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Ink (57073) | `0x64445f0aecC51E94aD52d8AC56b7190e764E561a` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Ink (57073) | `0x7a07D606c87b7251c2953A30Fa445d8c5F856C7A` | direct | none(404) | twinV1:118B/8r | **DIFFERS** | twin-v1:immutable-only-diff |
| Ink (57073) | `0x80Eede496655FB9047dd39d9f418d5483ED600df` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Ink (57073) | `0x90581eCa9469D8D7F5D3B60f4715027aDFCf7927` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Ink (57073) | `0x9e951Dd846e748E6fCB58bFb76953c4900f819f4` | implementation | none(404) | twin:160B/8r | **HEAD** | twin:immutable-only-diff |
| Ink (57073) | `0xbBc424e58ED38dd911309611ae2d7A23014Bd960` | implementation | none(404) | twin:160B/8r | **HEAD** | twin:immutable-only-diff |
| Ink (57073) | `0xC7346783f5e645aa998B106Ef9E7f499528673D8` | implementation | none(404) | twin:160B/8r | **HEAD** | twin:immutable-only-diff |
| Ink (57073) | `0xF9B0dfD08C2506F871D4aCBfD4e909f6C8275A03` | implementation | none(404) | twin:160B/8r | **HEAD** | twin:immutable-only-diff |
| Linea (59144) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| Linea (59144) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | match | diff:MATCH | **UNKNOWN** | sourcify-diff:third-repo-no-counterpart |
| Linea (59144) | `0x383Eac7CcaA89684b8277cBabC25BCa8b13B7Aa2` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Linea (59144) | `0x3cf371c128b092b085B7732069cEAF3Fd863F270` | proxy-admin | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Linea (59144) | `0x5217Ab28ECE654Aab2C68efedb6A22739df6C3D5` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Linea (59144) | `0x592a48c0FB9c7f8BF1701cB0136b90DEa2A5B7B6` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Linea (59144) | `0x6185334f1542a9966CbaD694577fFbede3DD1f1F` | direct | none(404) | — | **EXCLUDED** | mock |
| Linea (59144) | `0x6cA98f43719231d38F6426DB64C7F3D5C7CE7876` | direct | match | diff:RemoteHop.sol ±19,IExecutor.sol ±2 | **DIFFERS** | sourcify-diff:MISMATCH |
| Linea (59144) | `0x8612a9fdf219Ab6C0E92bDD69E2266572c7D893B` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Linea (59144) | `0x96A7dd70799f8962Ea256a14DDaa120d19de7D8a` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Linea (59144) | `0xa71f2204EDDB8d84F411A0C712687FAe5002e7Fb` | direct | match | diff:RemoteMintRedeemHop.sol ±9,IExecutor.sol ±2 | **DIFFERS** | sourcify-diff:MISMATCH |
| Linea (59144) | `0xB1aFD04774c02AE84692619448B08BA79F19b1ff` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Linea (59144) | `0xC7346783f5e645aa998B106Ef9E7f499528673D8` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Linea (59144) | `0xC83a8D6d758f52f6226Da964CBe80E097b1E534E` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Linea (59144) | `0xDaF72Aa849d3C4FAA8A9c8c99f240Cf33dA02fc4` | proxy | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Linea (59144) | `0xEc4fC039412cD8c34408907533a478984adB2598` | implementation | exact_match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Berachain (80094) | `0x10694bDbB42E6fcF859185748282fB99540db9C2` | implementation | none(404) | twin:32B/1r | **HEAD** | twin:immutable-only-diff |
| Berachain (80094) | `0x15638D0EB6097601bA9F711f3F8eDDddEf3D1048` | implementation | none(404) | twin:152B/16r | **HEAD** | twin:immutable-only-diff |
| Berachain (80094) | `0x33cFa536D2fE47aB8F0feB0eaDc2Da443a8eF0AF` | implementation | none(404) | twin:32B/1r | **HEAD** | twin:immutable-only-diff |
| Berachain (80094) | `0x3Ec3849C33291a9eF4c5dB86De593EB4A37fDe45` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Berachain (80094) | `0x43eDD7f3831b08FE70B7555ddD373C8bF65a9050` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Berachain (80094) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | none(404) | — | **EXCLUDED** | mock |
| Berachain (80094) | `0x5Bff88cA1442c2496f7E475E9e7786383Bc070c0` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Berachain (80094) | `0x64445f0aecC51E94aD52d8AC56b7190e764E561a` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Berachain (80094) | `0x80Eede496655FB9047dd39d9f418d5483ED600df` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Berachain (80094) | `0x90581eCa9469D8D7F5D3B60f4715027aDFCf7927` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Berachain (80094) | `0xAe47A59BF1012D825135CcD6C2c708588e80B2F7` | implementation | none(404) | twin:152B/16r | **HEAD** | twin:immutable-only-diff |
| Blast (81457) | `0x3Ec3849C33291a9eF4c5dB86De593EB4A37fDe45` | direct | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Blast (81457) | `0x43eDD7f3831b08FE70B7555ddD373C8bF65a9050` | direct | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Blast (81457) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | match | diff:MATCH | **EXCLUDED** | mock |
| Blast (81457) | `0x5Bff88cA1442c2496f7E475E9e7786383Bc070c0` | direct | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Blast (81457) | `0x64445f0aecC51E94aD52d8AC56b7190e764E561a` | direct | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Blast (81457) | `0x80Eede496655FB9047dd39d9f418d5483ED600df` | direct | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Blast (81457) | `0x90581eCa9469D8D7F5D3B60f4715027aDFCf7927` | direct | match | diff:MATCH | **HEAD** | sourcify-diff:MATCH-target-clean |
| Plume (98866) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| Plume (98866) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Plume (98866) | `0x192e0C7Cc9B263D93fa6d472De47bBefe1Fb12bA` | implementation | none(404) | twin:160B/8r | **HEAD** | twin:immutable-only-diff |
| Plume (98866) | `0x231788c09F3936Cd343c4F1bDed89f0fbe80719c` | implementation | none(404) | twin:160B/8r | **HEAD** | twin:immutable-only-diff |
| Plume (98866) | `0x36c28Ef9A8116A64752Efd6B9efA3056F24A82AE` | implementation | none(404) | twin:160B/8r | **HEAD** | twin:immutable-only-diff |
| Plume (98866) | `0x3Ec3849C33291a9eF4c5dB86De593EB4A37fDe45` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Plume (98866) | `0x43eDD7f3831b08FE70B7555ddD373C8bF65a9050` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Plume (98866) | `0x4E7F19d86a81857C46e87182a14B4e894b8Ada1a` | implementation | none(404) | twin:160B/8r | **HEAD** | twin:immutable-only-diff |
| Plume (98866) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | none(404) | — | **EXCLUDED** | mock |
| Plume (98866) | `0x5Bff88cA1442c2496f7E475E9e7786383Bc070c0` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Plume (98866) | `0x64445f0aecC51E94aD52d8AC56b7190e764E561a` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Plume (98866) | `0x6cA98f43719231d38F6426DB64C7F3D5C7CE7876` | direct | none(404) | — | **UNKNOWN** | no-record |
| Plume (98866) | `0x80Eede496655FB9047dd39d9f418d5483ED600df` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Plume (98866) | `0x90581eCa9469D8D7F5D3B60f4715027aDFCf7927` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Plume (98866) | `0xa71f2204EDDB8d84F411A0C712687FAe5002e7Fb` | direct | none(404) | — | **UNKNOWN** | no-record |
| Scroll (534352) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | exact_match | diff:PARTIAL(dep-only) | **EXCLUDED** | mock |
| Katana (747474) | `0x0000000f9a66622C8885E1071B78E37b2b3ecCCd` | implementation | none(404) | — | **DIFFERS** | codehash-identity:v201-rebuild:MATCH |
| Katana (747474) | `0x0000006d38568b00b457580b734e0076c62de659` | proxy | none(404) | — | **UNKNOWN** | no-record |
| Katana (747474) | `0x231788c09F3936Cd343c4F1bDed89f0fbe80719c` | implementation | none(404) | twin:32B/1r | **HEAD** | twin:immutable-only-diff |
| Katana (747474) | `0x36c28Ef9A8116A64752Efd6B9efA3056F24A82AE` | implementation | none(404) | twin:152B/16r | **HEAD** | twin:immutable-only-diff |
| Katana (747474) | `0x3Ec3849C33291a9eF4c5dB86De593EB4A37fDe45` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Katana (747474) | `0x43eDD7f3831b08FE70B7555ddD373C8bF65a9050` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Katana (747474) | `0x4E7F19d86a81857C46e87182a14B4e894b8Ada1a` | implementation | none(404) | twin:152B/16r | **HEAD** | twin:immutable-only-diff |
| Katana (747474) | `0x57558Cb8d6005DE0BAe8a2789d5EfaaE52dba5a8` | direct | none(404) | — | **EXCLUDED** | mock |
| Katana (747474) | `0x5Bff88cA1442c2496f7E475E9e7786383Bc070c0` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Katana (747474) | `0x5d8EB59A12Bc98708702305A7b032f4b69Dd5b5c` | direct | none(404) | — | **UNKNOWN** | no-record |
| Katana (747474) | `0x64445f0aecC51E94aD52d8AC56b7190e764E561a` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Katana (747474) | `0x80Eede496655FB9047dd39d9f418d5483ED600df` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Katana (747474) | `0x90581eCa9469D8D7F5D3B60f4715027aDFCf7927` | proxy | none(404) | — | **HEAD** | codehash-identity:sourcify-diff:PARTIAL-target-clean |
| Katana (747474) | `0x91A3f8a8d7a881fBDfcfEcd7A2Dc92a46DCfa14e` | implementation | none(404) | twin:32B/1r | **HEAD** | twin:immutable-only-diff |
| Katana (747474) | `0xF6f45CCB5E85D1400067ee66F9e168f83e86124E` | direct | none(404) | — | **UNKNOWN** | no-record |
| Aurora (1313161554) | `0xA057D8D4Fc86a62801CE363C169b0A8d192F6cEE` | direct | none(404) | — | **EXCLUDED** | mock |
