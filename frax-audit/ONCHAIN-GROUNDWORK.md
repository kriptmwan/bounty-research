# Fraxlend — On-Chain Groundwork (Phase 0B)

**Date:** 2026-11-14 (WIB). **Method:** read-only. `cast` view calls + Sourcify v2 API +
one Node/ethers enumeration script + one Foundry fork test. **No transactions sent, nothing
signed, no contact with the Frax team, zero GitHub API calls** (git protocol only, for the
forge-std clone used by the smoke test). Etherscan was not used (Cloudflare-blocked from
this VM); one web search corroborated the deployer name/compiler only — every address below
rests on on-chain evidence (code + Sourcify name match + view-call behavior).

- **Chain:** Ethereum mainnet (chain 1). **RPC:** `https://ethereum-rpc.publicnode.com`
  (no rate limits or errors observed in any call this pass).
- **Repo:** `~/workspace/frax-audit/repos/fraxlend` @ `2bed49d4dcc6702d92dede825c3424893517d841`
  (HEAD verified after all work; `git status` clean — the clone was never modified, no build
  was run inside it).
- **Tools:** cast/forge 1.5.1 (`~/.foundry/bin`), node v24 + ethers v6.17.0
  (from `~/workspace/nonce-mint/node_modules`).
- **Companion files:** full 71-pair enumeration JSON:
  `~/workspace/frax-audit/pairs-enumeration-block26410499.json`; enumeration script:
  `~/workspace/frax-audit/enumerate-pairs.mjs`; Sourcify-verified deployed sources (exact
  match) extracted to `~/workspace/frax-audit/sourcify/`; fork smoke-test project:
  `~/workspace/frax-audit/poc-smoke/`.

## 1. Deployer / registry interface (learned from repo source first)

**`FraxlendPairDeployer`** (`src/contracts/FraxlendPairDeployer.sol`, `version()` = 5.0.0):
constructor takes a single `ConstructorParams` struct
`(circuitBreaker, comptroller, timelock, fraxlendWhitelist, fraxlendPairRegistry)`.
Pair creation code is stored via SSTORE2 in `contractAddress1()` / `contractAddress2()`
(split at 13,000 bytes); pairs deploy via CREATE2 in `_deploy()` and are registered via
`IFraxlendPairRegistry.addPair()`. View functions used in this pass:

- `owner()`, `version() returns (uint256,uint256,uint256)`
- `deployedPairsLength()`, `getAllPairAddresses()`, `deployedPairsArray(uint256)`
- `circuitBreakerAddress()`, `comptrollerAddress()`, `timelockAddress()`,
  `fraxlendWhitelistAddress()`, `fraxlendPairRegistryAddress()`
- `contractAddress1()`, `contractAddress2()`

**`FraxlendPairRegistry`** (`src/contracts/FraxlendPairRegistry.sol`, HEAD version uses
`Ownable2Step`): constructor `(address _ownerAddress, address[] _initialDeployers)`.
View functions used:

- `owner()`, `pendingOwner()` (HEAD only — see §4, deployed registry lacks it)
- `deployers(address)`, `deployedPairsLength()`, `getAllPairAddresses()`,
  `deployedPairsArray(uint256)`, `deployedPairsByName(string)`

**Pair interface — trap found:** `src/contracts/interfaces/IFraxlendPair.sol` in the repo
declares `paused()`, `oracleMultiply()`, `oracleDivide()` — **none of these exist on the
deployed v3 pairs** (all three selectors revert with empty data). The deployed pairs match
`IFraxlendV3.sol` instead: a **single dual-oracle** held in the `ExchangeRateInfo` struct,
and **four separate pause flags**. Correct pair getters (verified on-chain, §3):

- `exchangeRateInfo() returns (address oracle, uint32 maxOracleDeviation, uint184 lastTimestamp, uint256 lowExchangeRate, uint256 highExchangeRate)`
- `isRepayPaused()`, `isWithdrawPaused()`, `isLiquidatePaused()`, `isInterestPaused()`
- `totalAsset() returns (uint128 amount, uint128 shares)`,
  `totalBorrow() returns (uint128 amount, uint128 shares)`, `totalAssets()`,
  `totalSupply()` (= totalAsset shares), `totalCollateral()`
- `asset()`, `collateralContract()`, `rateContract()`, `maxLTV()`,
  `cleanLiquidationFee()`, `dirtyLiquidationFee()`, `protocolLiquidationFee()`
- `getPairAccounting()`, `currentRateInfo()`, `version()`, `owner()`,
  `timelockAddress()`, `circuitBreakerAddress()`, `DEPLOYER_ADDRESS()`,
  `borrowLimit()`, `depositLimit()`, `name()`, `symbol()`, `decimals()`

## 2. Deployer / registry verification

### 2.1 Canonical deployer: VERIFIED — `0xF767A82a188305461b6f01a7706f7Bc0ba941ffF`

| Evidence | Result |
|---|---|
| `eth_getCode` | Non-empty (19,217 hex chars incl. `0x` prefix/newline) |
| Sourcify v2 (chain 1) | **Exact match** (`creationMatch` + `runtimeMatch` = `match`, matchId 6371379, verified 2025-05-20). Contract name `FraxlendPairDeployer`, file `src/FraxlendPairDeployer.sol`, solc 0.8.19+commit.7dd6d404 |
| `version()` | `(5, 0, 0)` — identical to repo HEAD deployer |
| `owner()` | `0xa4EC124e09D6D1A092c6BD16aFac9CD83f73E3c3` |
| `fraxlendPairRegistryAddress()` | `0xD6E9D27C75Afd88ad24Cd5EdccdC76fd2fc3A751` (the verified registry, §2.3) |
| `timelockAddress()` / `comptrollerAddress()` | `0xB1748C79709f4Ba2Dd82834B8c82D4a505003f27` (both; = registry owner, = reference-pair owner/timelock) |
| `circuitBreakerAddress()` | `0xfd3065C629ee890Fd74F43b802c2fea4B7279B8c` |
| `fraxlendWhitelistAddress()` | `0xDc1cf6863b6100468479fE7dd3D2D1cDe7775265` |
| `deployedPairsLength()` / `getAllPairAddresses()` | 13 pairs, **all 13 present in the registry** |
| Registry `deployers(address)` | `true` — currently authorized to add pairs |
| Reference pair `DEPLOYER_ADDRESS()` | Returns this address (§3) |
| SSTORE2 creation-code halves | `contractAddress1` `0x4b61011f2eACB1683b7E1f72B9DFBe7D0fF28881` (~13,001 bytes), `contractAddress2` `0x243d2614fE26098c64277e1c8D875ccF2a0776A0` (~16,156 bytes); total ≈ 29,157 bytes of pair creation code |

Corroboration (not relied on): a web search returns Etherscan listing this address as
`FraxlendPairDeployer`, compiler v0.8.19+commit.7dd6d404. The on-chain evidence above is
sufficient on its own. **This is the canonical current Fraxlend deployer. No docs search
was needed — the candidate verified directly.**

### 2.2 Legacy deployer: genuine Frax, SUPERSEDED — `0x5d6e79Bcf90140585CE88c7119b7E43CAaA67044`

**Not discarded as "wrong" — it is a real, older Frax deployer — but it is NOT the current
canonical deployer and must not be used as the audit's deployer.** Evidence:

| Evidence | Result |
|---|---|
| `eth_getCode` | Non-empty (20,847 hex chars) |
| Sourcify v2 (chain 1) | **Exact match** (matchId 6568264, verified 2025-06-22). Contract name `FraxlendPairDeployer`, file `src/contracts/FraxlendPairDeployer.sol`, **solc 0.8.16** |
| Interface | Pre-registry generation: constructor `(circuitBreaker, comptroller, timelock, fraxlendWhitelist)` (4 args, no registry); has `deployCustom`, `deployedPairsBySalt`, `TIME_LOCK_ADDRESS()` etc. `version()`, `fraxlendPairRegistryAddress()`, `timelockAddress()`, `contractAddress1/2()` selectors all **revert** (do not exist) |
| `owner()` | `0x168200cF227D4543302686124ac28aE0eaf2cA0B` (= its `COMPTROLLER_ADDRESS()`) |
| `TIME_LOCK_ADDRESS()` | `0x8412ebf45bAC1B340BbE8F318b928C466c4E39CA` (the OLD timelock; current is `0xB174…`) |
| `CIRCUIT_BREAKER_ADDRESS()` | `0xfd3065C629ee890Fd74F43b802c2fea4B7279B8c` (same circuit breaker as current deployer) |
| `FRAXLEND_WHITELIST_ADDRESS()` | `0x118C1462AA28bF2ea304f78f49C3388cfd93234e` (different whitelist from current) |
| `deployedPairsLength()` | 8 pairs (`FraxlendV1 - …/FRAX` pairs + `fFRAX(FPI)`); 7 of 8 are in the registry |
| Registry `deployers(address)` | **`false` — deauthorized** |

The one non-registered pair, `0xF1b3Cbc51a7483C656af9Aa09F319a3b66aD5e04`
(`fFRAX(ezETH)`, totalAsset 90 FRAX), has code and state but was never added to the
registry (the registry has no removal function, so it was never added — it predates the
registry). It is excluded from the §3 enumeration, which is registry-based.

Source: this address is the `FRAXLEND_DEPLOYER_ADDRESS` constant in the repo's
`src/liquidatorBot/bot.mjs` — consistent with a legacy bot pointing at the old deployer.

### 2.3 Registry: VERIFIED — `0xD6E9D27C75Afd88ad24Cd5EdccdC76fd2fc3A751`

| Evidence | Result |
|---|---|
| `eth_getCode` | Non-empty (7,323 hex chars) |
| Sourcify v2 (chain 1) | **Exact match** (matchId 6751721, verified 2025-07-04). Contract name `FraxlendPairRegistry`, solc 0.8.17 |
| `owner()` | `0xB1748C79709f4Ba2Dd82834B8c82D4a505003f27` (= current timelock) |
| `pendingOwner()` | **Reverts** — deployed registry is NOT the `Ownable2Step` HEAD version (see §4) |
| `deployedPairsLength()` | **71** |
| `deployers(0xF767…)` / `deployers(0x5d6e…)` | `true` / `false` |

**Inventory caveat:** the registry's 71 pairs ≠ deployer lists. Only 13 came from the
current deployer and 7 (of 8) from the legacy deployer; **51 pairs were registered by
other (earlier/superseded) deployer contracts** that are no longer authorized. The
registry is the complete inventory; per-deployer lists are not.

No candidate was discarded as non-Frax, and no third deployer needed to be found: both
SCOPE.md candidates verified as genuine Frax deployers of different generations.

## 3. Pair enumeration & reference pair

Enumeration block: **26,410,499** (single `getAllPairAddresses()` + per-pair view calls,
chunked; full data in the companion JSON). All 71 registry pairs returned `totalAsset`,
`totalBorrow`, `totalSupply`, `totalCollateral`, `asset`, `collateralContract`,
`rateContract`, `maxLTV`, `name`, `symbol`, `decimals`, `version`. Pause status could NOT
be read uniformly: the `paused()` selector exists only on V1/v2-era pairs (all returned
`false`); on v3 pairs it reverts, and the four `is*Paused` flags were read only for the
reference pair (§3.1). Do not treat "paused = revert" rows as paused — see appendix note.

**Top pairs by `totalAsset` (human units of the pair's asset token):**

| # | Pair | Symbol | Ver. | Asset | Total supplied | Total borrowed |
|---|---|---|---|---|---|---|
| 1 | `0xaB3cb84c310186B2Fa4B4503624A5D90b5DcB22D` | ffrxUSD(sfrxETH)-58 | 3.1.0 | frxUSD | 4,592,962.53 | 3,424,868.50 |
| 2 | `0x32467a5fc2d72D21E8DCe990906547A2b012f382` | FraxlendV1 - WBTC/FRAX | n/a (V1) | FRAX | 1,284,021.14 | 699,453.11 |
| 3 | `0x78bB3aEC3d855431bd9289fD98dA13F9ebB7ef15` | fFRAX(sfrxETH)-16 | 3.0.0 | FRAX | 894,945.68 | 708,719.22 |
| 4 | `0xC045A53936D793839BFCA146058976ef4285161E` | ffrxUSD(sfrxUSD)-69 | 3.2.0 | frxUSD | 625,554.10 | 120,253.15 |
| 5 | `0x470c677AF6CCE089ac38245332BfA03b22b4caeD` | ffrxUSD(WFRAX)-68 | 3.2.0 | frxUSD | 453,638.75 | 153,809.77 |
| 6 | `0x1c0C222989a37247D974937782cebc8bF4f25733` | fFRAX(FXB_20261231)-24 | 3.0.0 | FRAX | 357,248.70 | 357,248.53 |
| 7 | `0x28Cdf6Ce79702AAeFbF217cF98cbD11f5639B9f1` | ffrxUSD(sUSDe)-59 | 3.1.0 | frxUSD | 199,670.80 | 118,053.35 |
| 8 | `0x8E5f09de0cD7841239410F929A905E214443d9E0` | ffrxUSD(WBTC)-62 | 3.2.0 | frxUSD | 137,693.15 | 66,771.42 |

Version distribution across the 71: v3.0.0 (majority), v3.1.0, v3.2.0, v2.0.0 (5 pairs),
and V1 pairs with no `version()` function (their `version()` selector decodes garbage —
do not read it). 20+ pairs hold only dust/seed amounts (5–10 asset units, zero borrows).
The full 71-row table is in the appendix.

### 3.1 Reference pair (audit's reference): `0xaB3cb84c310186B2Fa4B4503624A5D90b5DcB22D`

Chosen as the live high-TVL pair: largest `totalAsset` in the registry by a 3.6× margin,
deployed by the current canonical deployer, unpaused, with active borrows.

- **Name / symbol:** `Fraxlend Interest Bearing frxUSD (Staked Frax Ether) - 58` /
  `ffrxUSD(sfrxETH)-58`. **Pair `version()`:** 3.1.0. **Decimals:** 18.
- **Asset token:** frxUSD `0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29` (18 decimals).
- **Collateral token:** sfrxETH `0xac3E018457B222d93114458476f3E3416Abbe38F` (18 decimals).
- **State — stored values** (`totalAsset()` / `totalBorrow()` public getters; identical
  at enumeration blocks 26,410,458 and 26,410,499 — no state-changing transaction touched
  the pair between those blocks):
  - `totalAsset`: **4,592,962.532789343590656850 frxUSD** (raw amount
    `4592962532789343590656850`, shares `4319466505069158671044958`).
  - `totalBorrow`: **3,424,868.497084372747584150 frxUSD** (raw amount
    `3424868497084372747584150`, shares `3112873561840053919643043`).
  - `totalSupply` (fToken): `4319466505069158671044958` (= totalAsset shares).
- **State — interest-previewed values** (`getPairAccounting()` / `totalAssets()` at block
  26,410,464; both call `previewAddInterest()`, so they include ≈305,772.63 frxUSD of
  accrued-but-not-yet-added interest — do NOT mix with the stored values above):
  - Previewed totalAsset: 4,593,268.305424231890780593 frxUSD (raw
    `4593268305424231890780593`, shares `4319495259832851157469267`).
  - Previewed totalBorrow: 3,425,174.269719261047707893 frxUSD (raw
    `3425174269719261047707893`, shares unchanged).
  - `totalCollateral`: **4,329.777905726386172461 sfrxETH** (raw `4329777905726386172461`).
  - Pair's own frxUSD balance: **1,168,094.035704970843072700 frxUSD**
    (raw `1168094035704970843072700`) — the unborrowed float; used as the whale
    balance in the fork smoke test (§5).
- **Pauses (all false):** `isRepayPaused=false`, `isWithdrawPaused=false`,
  `isLiquidatePaused=false`, `isInterestPaused=false`. `borrowLimit` and `depositLimit`
  both = `type(uint256).max` (unlimited).
- **Risk params:** `maxLTV=75000` (75%, 1e5 precision), `cleanLiquidationFee=10000`,
  `dirtyLiquidationFee=9000`, `protocolLiquidationFee=2000`.
- **Rate state:** `currentRateInfo` = lastBlock 26405961, feeToProtocolRate 10000,
  lastTimestamp 1794571943, ratePerSec 1649540723, fullUtilizationRate 7912352300.
- **Admin:** `owner` = timelock `0xB1748C79709f4Ba2Dd82834B8c82D4a505003f27`,
  `circuitBreakerAddress` = `0xfd3065C629ee890Fd74F43b802c2fea4B7279B8c`,
  `DEPLOYER_ADDRESS` = `0xF767A82a188305461b6f01a7706f7Bc0ba941ffF` (canonical deployer).
- **Oracle (single dual-oracle, via `exchangeRateInfo()`):**
  `0x4355903F610D0F94ee476df6e3227811ff7efeE1`, `SfrxEthUsdTripleOracle` v3.0.0
  ("V3 sfrxEth/USD Triple Oracle (Curve EMA|Uniswap V3 TWAP|SfrxEth Redstone|Frax and
  ETH Chainlink)"), `maxOracleDeviation=5000`, stored low/high exchange rates
  `405643808170850` / `406167407367761` at block 26,410,464 (lastTimestamp 1794222863).
  Live `getPrices()` during the oracle check: badData=false, low `448149836206114`,
  high `449030945765079` (block not pinned for that single call).
  Underlying feeds (all read on-chain): Chainlink ETH/USD
  `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419`, Chainlink FRAX/USD
  `0xB9E1E3A9feFf48998E45Fa90847ed4D467E8BcfD`, Redstone feed
  `0xdd60c54115C19e0c6360AD4762B88BB8076D50a8`, Curve pool EMA oracle
  `0x9c3B46C0Ceb5B9e304FCd6D88Fc50f7DD24B31Bc`, UniV3 pool
  `0x36C060Cc4b088c830a561E959A679A58205D3F56`, `SFRXETH_ERC4626` = sfrxETH,
  `twapDuration=900`, oracle timelock `0x8412ebf45bAC1B340BbE8F318b928C466c4E39CA`
  (old timelock).
- **Rate calculator:** `0x987a96c6637cF7E7B369BA7C1110d5fB69fb2d17`,
  `VariableInterestRateSettable` v3.0.0 (see §4 — not in the repo).
- **Runtime code size:** 47,560 hex chars (23,779 bytes).

## 4. Deployment-vs-repo correspondence

Method: Sourcify v2 exact/partial match status + diff of Sourcify-returned source against
the repo clone at HEAD (`2bed49d4`), file by file. **Every address below has an exact
Sourcify match** (creation + runtime), so no bytecode-length/prefix fallback against a
local forge build was needed, and none was run; the clone was left untouched. Sourcify
exact match already proves deployed bytecode == recompiled verified source; the diffs
below are therefore the operative correspondence evidence. Deployed sources are preserved
under `~/workspace/frax-audit/sourcify/`.

| Contract | Address | Sourcify | vs repo HEAD | Verdict |
|---|---|---|---|---|
| FraxlendPairDeployer (current) | `0xF767A82a188305461b6f01a7706f7Bc0ba941ffF` | exact match, solc 0.8.19, runs 832* | Main file **byte-identical** to `FraxlendPairDeployer.sol`; Frax `SafeERC20.sol` identical | **MATCH** |
| FraxlendPairDeployer (legacy) | `0x5d6e79Bcf90140585CE88c7119b7E43CAaA67044` | exact match, solc 0.8.16 | Older generation: different constructor/interface (no registry, `deployCustom`, `TIME_LOCK_ADDRESS` constants); not diffed file-by-file — interface-level mismatch is conclusive | **MISMATCH (older version)** |
| FraxlendPairRegistry | `0xD6E9D27C75Afd88ad24Cd5EdccdC76fd2fc3A751` | exact match, solc 0.8.17 | **Differs:** `Ownable` (not `Ownable2Step`), `pragma ^0.8.17`, no-arg constructor (no initial-deployers/owner params), extra salt tracking (`deployedSaltsArray`, `deployedPairsBySalt`, `getAllPairSalts`, `AddSalt`), error `DeployersOnly` (not `AddressIsNotDeployer`). Confirmed behaviorally: `pendingOwner()` reverts | **MISMATCH (older version)** |
| FraxlendPair (reference pair) | `0xaB3cb84c310186B2Fa4B4503624A5D90b5DcB22D` | exact match, solc 0.8.19, runs 832* | `FraxlendPair.sol`, `FraxlendPairAccessControl.sol`, `…Errors.sol`, `…Constants.sol`, `Timelock2Step.sol`, `VaultAccount.sol`, Frax `SafeERC20.sol`: all **identical**. `FraxlendPairCore.sol`: **3 substantive deltas** (below) | **PARTIAL — near-HEAD, 3 deltas** |
| VariableInterestRateSettable (rate calc) | `0x987a96c6637cF7E7B369BA7C1110d5fB69fb2d17` | exact match, solc 0.8.19 | **No corresponding file in repo HEAD.** Nearest file `VariableInterestRate.sol` is v2.0.0 without setter roles; deployed contract is v3.0.0 with `AccessControl` + `SETTER_ROLE` (`setZeroUtilRate`, `setVertexRatePercent`) | **NO-RECORD in repo** |
| SfrxEthUsdTripleOracle | `0x4355903F610D0F94ee476df6e3227811ff7efeE1` | exact match, solc 0.8.20 | Main file `SfrxEthUsdTripleOracle.sol` + `RedstoneOracleWithMaxDelay.sol` **absent** from `fraxlend` and `frax-oracles` public clones. `DualOracleBase.sol` matches the `frax-oracles` clone except pragma (0.8.20 vs 0.8.19); 4 abstracts match except pragma/import paths + one doc comment | **PARTIAL — main file not in any public repo** |

\* Deployed pair/deployer metadata records optimizer runs 832; the repo `foundry.toml`
sets runs 200. Compiler-settings difference only; Sourcify exact match is unaffected.

**The 3 `FraxlendPairCore.sol` deltas (deployed v3.1.0 vs repo HEAD v3.0.0)** — the audit
must use the DEPLOYED source for these code paths; a finding resting on the HEAD text of
any of them is not filing-ready:

1. `version()`: `_minor = 1` (deployed) vs `0` (HEAD).
2. Constructor default: `currentRateInfo.feeToProtocolRate = 10_000` (deployed) vs `0`
   (HEAD) — deployed pairs take a 10% protocol fee by default (1e5 precision).
3. `_isSolvent()` LTV formula reordered to avoid intermediate truncation:
   deployed `((_borrowerAmount * _exchangeRate) * LTV_PRECISION) / (_collateralAmount * EXCHANGE_PRECISION)`;
   HEAD `(((_borrowerAmount * _exchangeRate) / EXCHANGE_PRECISION) * LTV_PRECISION) / _collateralAmount`.
   (Plus 2 removed `@dev` comment lines on `liquidate` — cosmetic.)

**Implication for the audit:** the pair logic is auditable from repo HEAD *except* the
three deltas above; the rate calculator and the oracle must be audited from the
Sourcify-verified sources preserved under `~/workspace/frax-audit/sourcify/`, not from
any public repo. The registry must be audited as the deployed older version, not HEAD.
v3.2.0 pairs (e.g. #4, #5, #8 above) were not source-compared — if the audit later uses a
v3.2.0 pair, its Sourcify source must be diffed the same way before relying on it.

## 5. Fork smoke test: PASS

- **Project:** `~/workspace/frax-audit/poc-smoke/` (scratch Foundry project, NOT inside
  the repo clone). One test file `test/ForkSmoke.t.sol`, one test:
  `test_forkWhaleTransfer` — forks mainnet, `deal`s 10 ETH to the reference pair,
  `prank`s as the pair (frxUSD whale, ~1.17M frxUSD), transfers 100 frxUSD to
  `0xBEEF`, asserts recipient +100 and pair −100.
- **Pinned block:** **26,410,483**. **RPC:** `https://ethereum-rpc.publicnode.com`.
  **Command:** `forge test --fork-url <rpc> --fork-block-number 26410483 -vvv`
  (from `~/workspace/frax-audit/poc-smoke/`, foundry 1.5.1).
- **Result: PASS** — `[PASS] test_forkWhaleTransfer() (gas: 56269)`, 1 passed / 0 failed.
  Wall time 13s (compile ~4s + run 6.3s). No RPC rate limits or errors.
- **First attempt FAILED (diagnosed, not blind-retried):** every frxUSD call reverted
  `EvmError: NotActivated` inside the frxUSD implementation
  (`0x5c19D7C2838769ED3c5a1E506600940e62fF901F`, reached via delegatecall from the
  frxUSD proxy). Root cause: the implementation bytecode uses `PUSH0` (`0x5f`, visible
  at the start of the deployed bytecode) and the fork defaulted to a pre-Shanghai EVM
  spec. **Fix:** `evm_version = "cancun"` in `foundry.toml` — the retry with the same
  pinned block passed. **Standing requirement for all Fraxlend fork PoCs on this
  toolchain: set `evm_version = "cancun"` (or newer) or any frxUSD interaction reverts
  with `NotActivated`.** (A prior run failed earlier on a `foundry.toml` config error —
  `optimizer` as a table — fixed before any fork execution; 2 fork runs total.)
- forge-std was obtained via `git clone --depth 1` (git protocol, no GitHub API) into
  `poc-smoke/lib/forge-std`.

## 6. Notes / traps for the audit phase

1. Do not use `IFraxlendPair.sol` getters (`paused`, `oracleMultiply`, `oracleDivide`)
   against live pairs — they do not exist on deployed code. Use the Sourcify ABI /
   `IFraxlendV3.sol` shapes in §1.
2. Do not assume the registry list equals any one deployer's list (§2.3), and do not
   assume all pairs share one code version — v1/v2/v3.0/v3.1/v3.2 coexist.
3. Do not audit the rate calculator or oracle from repo HEAD — neither deployed contract
   is in the public repos (§4). Use `~/workspace/frax-audit/sourcify/`.
4. Do not audit the registry from HEAD — the deployed registry is the older `Ownable`
   version with salt tracking (§4).
5. Fork PoCs must set `evm_version = "cancun"` or newer (§5).
6. `FRAX` in pair symbols (e.g. `fFRAX(…)`) is the legacy FRAX stablecoin
   `0x853d955aCEf822Db058eb8505911ED77F175b99e`, distinct from frxUSD
   `0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29` — see the SCOPE.md docs-inconsistency
   flag. Asset addresses in the appendix are authoritative, not symbols.
7. V1 pairs (notably `0x32467a5f…` WBTC/FRAX, 1.28M FRAX supplied) run substantially
   older code and are outside the v3 reference-pair scope unless separately ordered.

## Appendix — all 71 registry pairs (block 26,410,499)

Columns: pair address, symbol, `version()`, asset (symbol + address in JSON), total
supplied / total borrowed in asset units, total collateral (raw, collateral-token units),
rate contract. "paused" column is intentionally omitted: `paused()` reverts on v3 pairs
and was not replaced by the four `is*Paused` reads except for the reference pair. V1
rows show `version() = n/a` (no such function; the selector decodes garbage). Rows sorted
by total supplied descending. Full raw values (amounts + shares, token addresses,
decimals, oracle/rate addresses, exchange-rate info) are in
`pairs-enumeration-block26410499.json`.

| Pair | Symbol | Ver. | Asset | Total supplied | Total borrowed | Total collateral (raw) | Rate contract |
|---|---|---|---|---|---|---|---|
| `0xaB3cb84c310186B2Fa4B4503624A5D90b5DcB22D` | ffrxUSD(sfrxETH)-58 | 3.1.0 | frxUSD | 4,592,962.532789343590656850 | 3,424,868.497084372747584150 | 4329777905726386172461 | `0x987a96c663…` |
| `0x32467a5fc2d72D21E8DCe990906547A2b012f382` | FraxlendV1 - WBTC/FRAX | n/a (V1) | FRAX | 1,284,021.144500520336583156 | 699,453.108949807414290391 | 2973893780 | `0x3da1bf0Be1…` |
| `0x78bB3aEC3d855431bd9289fD98dA13F9ebB7ef15` | fFRAX(sfrxETH)-16 | 3.0.0 | FRAX | 894,945.683894415472376019 | 708,719.216212454730039631 | 960891382490901179074 | `0x18500cB1f2…` |
| `0xC045A53936D793839BFCA146058976ef4285161E` | ffrxUSD(sfrxUSD)-69 | 3.2.0 | frxUSD | 625,554.102030166096158563 | 120,253.154779384203629142 | 124886010524394899383934 | `0x987a96c663…` |
| `0x470c677AF6CCE089ac38245332BfA03b22b4caeD` | ffrxUSD(WFRAX)-68 | 3.2.0 | frxUSD | 453,638.747617997533271494 | 153,809.769850500906734881 | 1015832231262204341675220 | `0x987a96c663…` |
| `0x1c0C222989a37247D974937782cebc8bF4f25733` | fFRAX(FXB_20261231)-24 | 3.0.0 | FRAX | 357,248.695361327796090991 | 357,248.532085399916227343 | 685610361695308091473462 | `0x01480a0C13…` |
| `0x28Cdf6Ce79702AAeFbF217cF98cbD11f5639B9f1` | ffrxUSD(sUSDe)-59 | 3.1.0 | frxUSD | 199,670.797915820661688111 | 118,053.354824228734731659 | 111473797037351326844215 | `0x987a96c663…` |
| `0x8E5f09de0cD7841239410F929A905E214443d9E0` | ffrxUSD(WBTC)-62 | 3.2.0 | frxUSD | 137,693.151291757756780881 | 66,771.421320700738925027 | 204720741 | `0x987a96c663…` |
| `0x8087346b8865e5B0bF9F8A49742c2D83f6a50a6c` | ffrxUSD(scrvUSD)-61 | 3.1.0 | frxUSD | 51,493.295701495965088071 | 22,226.726208128647683772 | 21716316271052017563793 | `0x987a96c663…` |
| `0xb5a46f712F03808aE5c4B885C6F598fA06442684` | fFRAX(wstETH)-28 | 3.0.0 | FRAX | 40,068.340687919791082308 | 34,529.379471957833299151 | 28561871704863561772 | `0x18500cB1f2…` |
| `0x3835a58CA93Cdb5f912519ad366826aC9a752510` | FraxlendV1 - CRV/FRAX | n/a (V1) | FRAX | 37,745.555224292353393638 | 12,622.569853502013737457 | 117436292076696160728914 | `0xFf7846bAcB…` |
| `0xa1D100a5bf6BFd2736837c97248853D989a9ED84` | FraxlendV1 - CVX/FRAX | n/a (V1) | FRAX | 36,802.861673061373436610 | 21,624.989441892761224051 | 25020651189446201849755 | `0xFf7846bAcB…` |
| `0xeE847a804b67f4887c9E8fe559A2dA4278deFB52` | fUSDC(sfrxETH)-26 | 3.0.0 | USDC | 23,715.560093 | 16,846.804283 | 27550275411339014699 | `0x18500cB1f2…` |
| `0xc6CadA314389430d396C7b0C70c6281e99ca7fe8` | fFRAX(UNI)-19 | 3.0.0 | FRAX | 20,903.582881074988013871 | 210.606806582937790322 | 1401612405148089129485 | `0x18500cB1f2…` |
| `0xb5Ae5b75C0DF5632c572A657109375646Ce66f90` | fFRAX(sUSDe)-31 | 3.0.0 | FRAX | 13,637.731364118458805564 | 6,602.657785113207991210 | 6178403583296232041647 | `0x576E23b6E2…` |
| `0x7093F6141293F7C4F67E5efD922aC934402E452d` | fFRAX(LINK)-27 | 3.0.0 | FRAX | 7,519.901813426354668909 | 0.043481920310623159 | 45034491659728593559 | `0x18500cB1f2…` |
| `0x66bf36dBa79d4606039f04b32946A260BCd3FF52` | fFRAX(gOHM)-11 | 2.0.0 | FRAX | 6,248.634417460149091920 | 39.996626147750037997 | 1783134945723794527 | `0x18500cB1f2…` |
| `0x794F6B13FBd7EB7ef10d1ED205c9a416910207Ff` | FraxlendV1 - WETH/FRAX | n/a (V1) | FRAX | 3,420.966390666499865871 | 2,383.523159885245119663 | 3221568674617562353 | `0x3da1bf0Be1…` |
| `0xDbe88DBAc39263c47629ebbA02b3eF4cf0752A72` | FraxlendV1 - FXS/FRAX | n/a (V1) | FRAX | 3,190.803671218821843744 | 169.116966773427234949 | 31424513037256909282996 | `0xFf7846bAcB…` |
| `0xeca60a11c49486088Ad7c5e4aD7Dae2C061DBb1c` | fFRAX(USDe)-32 | 3.0.0 | FRAX | 1,199.353293179096115972 | 126.146007770963370010 | 278220142493515015577 | `0x576E23b6E2…` |
| `0xa4Ddd4770588EF97A3a03E4B7E3885d824159bAA` | fFRAX(rETH)-30 | 3.0.0 | FRAX | 1,078.147252502539800069 | 1.041823342550097725 | 1101351176387805 | `0x18500cB1f2…` |
| `0xc779fEE076EB04b9F8EA424ec19DE27Efd17A68d` | fFRAX(AAVE)-20 | 3.0.0 | FRAX | 906.029881382827255995 | 104.142676376059104850 | 5204645775105633927 | `0x18500cB1f2…` |
| `0x48f32B7c960fD0280297F6F0182E2607a3398Db5` | fFRAX(sDOLA)-38 | 3.0.0 | FRAX | 816.861036535756524282 | 0.549427945300342973 | 571840925571184316 | `0x576E23b6E2…` |
| `0x0601B72bEF2b3F09E9f48B7d60a8d7D2D3800C6e` | fFRAX(LDO)-29 | 3.0.0 | FRAX | 580.713453654126776226 | 0.761333095756966964 | 1134561101496434410 | `0x18500cB1f2…` |
| `0x3a25B9aB8c07FfEFEe614531C75905E810d8A239` | fFRAX(APE)-17 | 3.0.0 | FRAX | 500.473986398438180007 | 192.925898516053034151 | 13394975779207977713 | `0x18500cB1f2…` |
| `0x281E6CB341a552E4faCCc6b4eEF1A6fCC523682d` | fFRAX(frxETHCRV)-21 | 3.0.0 | FRAX | 305.305255775659770423 | 0.001513279096149030 | 38761808451335616 | `0x18500cB1f2…` |
| `0x50E627a1DF8D665524942aD7eC6392b6BA60293a` | fFRAX(FPI) | n/a (V1) | FRAX | 257.177099349081653860 | 15.689357116444998205 | 37793265365384061970 | `0x3da1bf0Be1…` |
| `0x82Ec28636B77661a95f021090F6bE0C8d379DD5D` | fFRAX(MKR)-18 | 3.0.0 | FRAX | 212.241085509040985451 | 148.066312581260138236 | 2815734040989953204 | `0x18500cB1f2…` |
| `0x1Fff4a418471a7b44EFa023320e02DCDB486ED77` | fFRAX(crvFRAX)-22 | 3.0.0 | FRAX | 200.361328680064263983 | 140.511025825609170376 | 197000000000000000000 | `0x18500cB1f2…` |
| `0xd1887398f3bbdC9d10D0d5616AD83506DdF5057a` | fFRAX(FXB_20241231)-25 | 3.0.0 | FRAX | 103.034513785289712201 | 52.371133527676982040 | 105246350456983697834 | `0x01480a0C13…` |
| `0x74F82Bd9D0390A4180DaaEc92D64cf0708751759` | fFRAX(FPI)-12 | 2.0.0 | FRAX | 101.376485858307089559 | 46.230605056837463064 | 177783870711147747925 | `0x9599033315…` |
| `0x35E08B28d5b01D058cbB1c39dA9188CC521a79aF` | fFRAX(FXB_20240630)-23 | 3.0.0 | FRAX | 101.104570927303473671 | 40.727806743379950833 | 50000004868541754559 | `0x01480a0C13…` |
| `0x76FF120FF669591b7cb5452995C0269437beA414` | fFRAX(WETH)-42 | 3.0.0 | FRAX | 57.934133426393829277 | 0.000000000000000000 | 4025641974223 | `0x18500cB1f2…` |
| `0xc4d57603D47FB842EC11A5332748f9F96d44cbEB` | FraxlendV1 - CRV/FRAX | n/a (V1) | FRAX | 46.113295481143891228 | 0.000000000000000000 | 0 | `0x3da1bf0Be1…` |
| `0xb49B5cF2efB64d97825c70706a49059E93625865` | fDOLA(sFRAX)-50 | 3.0.0 | DOLA | 42.977940777716841606 | 0.209563719843138721 | 213485406142451387 | `0x576E23b6E2…` |
| `0x809d2fBffA273334b73A5d1F070eE421a0A4f3c1` | ffrxUSD(CVX)-64 | 3.2.0 | frxUSD | 35.767960491355250688 | 0.000000000000000000 | 0 | `0x18500cB1f2…` |
| `0x21E354Da5D929A4da55428F6bfd71eD9Ffd5001F` | fFRAX(sfrxETH)-9 | 2.0.0 | FRAX | 30.101667067284567362 | 17.159334766355542147 | 1468591172820820128 | `0x18500cB1f2…` |
| `0xC653f61BA422F97Beb141b34580906184f3765a2` | ffrxUSD(reusdscrv)-67 | 3.0.0 | frxUSD | 23.312910759585835913 | 0.000000000000000000 | 2094854762203740745 | `0x987a96c663…` |
| `0xbE08194b3F4ae9CD80Bd7f553A9a782c0ed65d17` | fFRAX(cbETH)-39 | 3.0.0 | FRAX | 15.519564131178543105 | 0.000000000000000000 | 970578088322 | `0x576E23b6E2…` |
| `0x37110563E3856D413B821f07C7E3991c4493673D` | ffrxUSD(WBTC)-60 | 3.1.0 | frxUSD | 12.000000000000000000 | 0.000000000000000000 | 710 | `0x18500cB1f2…` |
| `0x54e20B542EEd95e6c7d8F29aD46A3cf5661C3048` | ffrxETH(WOETH)-45 | 3.0.0 | frxETH | 10.001235524534702883 | 0.000000000000000000 | 416640679852 | `0x576E23b6E2…` |
| `0x7640Aeed096982aDaD9c8BA668eBE35c1f6551DE` | ffrxUSD(CRV)-63 | 3.2.0 | frxUSD | 10.000000000000000000 | 0.000000000000000000 | 0 | `0x18500cB1f2…` |
| `0xEdBa32045Bb3d69e42E6BcB6Ef6f1337c89c76c8` | ffrxUSD(sDOLA)-65 | 3.2.0 | frxUSD | 10.000000000000000000 | 0.000000000000000000 | 0 | `0x576E23b6E2…` |
| `0xdB856AfaE2A71eb20Bd47D5dc37deF1D83d29fD7` | ffrxUSD(sfrxUSD)-66 | 3.2.0 | frxUSD | 10.000000000000000000 | 0.000000000000000000 | 0 | `0x576E23b6E2…` |
| `0xA201E7bBb7Ca60ab88514d12dD91fC6748E6D050` | ffrxUSD(srRoyUSDC)-70 | 3.2.0 | frxUSD | 10.000000000000000000 | 0.000000000000000000 | 0 | `0x987a96c663…` |
| `0x00C242cA3Ef5c2CB909ed3eD972B6f24624B4337` | ffrxUSD(KRWQ)-71 | 3.2.0 | frxUSD | 10.000000000000000000 | 0.000000000000000000 | 0 | `0x987a96c663…` |
| `0x8C9dB7a9329f221eD1fFE56BF4Bd073aA320eed9` | fFRAX(weETH)-41 | 3.0.0 | FRAX | 5.010388452002849858 | 0.000000000000000000 | 190609337427427450 | `0x18500cB1f2…` |
| `0x6A80bE9Df5F46eB11d0C6ed706607F72c0d1C337` | fcrvUSD(sfrxETH)-47 | 3.0.0 | crvUSD | 5.000000337429263918 | 0.000000000000000000 | 0 | `0x18500cB1f2…` |
| `0x5Ee658b7f46FD9DeE4608aE9c8E7d78AAD7509C2` | fFRAX(ezETH)-33 | 3.0.0 | FRAX | 5.000000000000000000 | 0.000000000000000000 | 0 | `0x18500cB1f2…` |
| `0x1D95C12d7A8d525F8d8Cb0C44814B12cd13Dfa01` | fUSDC(wstETH)-40 | 3.0.0 | USDC | 5.000000 | 0.000000 | 0 | `0x18500cB1f2…` |
| `0x5EA719aA26C158B7B0F5b6363c6beBCF4aE3cdB6` | fDOLA(sfrxETH)-48 | 3.0.0 | DOLA | 5.000000000000000000 | 0.000000000000000000 | 0 | `0x18500cB1f2…` |
| `0xBb95286B7973f8B217cE903CA15c75528CBd8E69` | fUSDC(sFRAX)-51 | 3.0.0 | USDC | 5.000000 | 0.000000 | 248279987763 | `0x576E23b6E2…` |
| `0x672500520A4734Af8401915DBDDa42F6E01BFBA9` | fAUSD(sFRAX)-52 | 3.0.0 | AUSD | 5.000000 | 0.000000 | 0 | `0x576E23b6E2…` |
| `0x5F9deea62fDd79EfDd22Fd714670e53dE33463A5` | fFRAX(WBTC)-53 | 3.0.0 | FRAX | 5.000000000000000000 | 0.000000000000000000 | 108 | `0x18500cB1f2…` |
| `0x81268A140AE319C744388d1e4203B21Bf8879129` | fFRAX(ENS)-54 | 3.0.0 | FRAX | 5.000000000000000000 | 0.000000000000000000 | 0 | `0x18500cB1f2…` |
| `0xB5FbAB8eBD088c512AdD09A0Cf3ffa9F9CA437bf` | fFRAX(GRT)-55 | 3.0.0 | FRAX | 5.000000000000000000 | 0.000000000000000000 | 0 | `0x18500cB1f2…` |
| `0x427d3b3b645Ec5CbaA321cdCab1af1D9CE4C0805` | fFRAX(ETH+)-56 | 3.0.0 | FRAX | 5.000000000000000000 | 0.000000000000000000 | 0 | `0x18500cB1f2…` |
| `0xA042F783B33f78E7580608D1698fA35b2dEc245A` | fDAI(sfrxETH)-49 | 3.0.0 | DAI | 2.000000000000000000 | 0.000000000000000000 | 100000000000000 | `0x18500cB1f2…` |
| `0xc16B81e004288C465EaAdf080028994044a3C69F` | fFRAX(PEPE)-46 | 3.0.0 | FRAX | 0.129198625907265111 | 0.000000446213206361 | 30942339283152957 | `0x576E23b6E2…` |
| `0xCe2C6D5DD135D1190822CE0e21EDD4ADF41350C9` | ffrxETH(ETH+)-57 | 3.0.0 | frxETH | 0.010000000000000000 | 0.000000000000000000 | 0 | `0x18500cB1f2…` |
| `0x501256B1DC7bb99CdE57AF188a69307BCC7E00E8` | fsfrxETH(sFRAX)-35 | 3.0.0 | sfrxETH | 0.000060271361980248 | 0.000000000000000000 | 245835139107783693517 | `0x18500cB1f2…` |
| `0x918Ac498470d073C6518b55F3f74C203D6Df38fd` | fFRAX(FPI)-10 | 2.0.0 | FRAX | 0.000000000000000002 | 0.000000000000000001 | 11 | `0x18500cB1f2…` |
| `0x62e3FcDFcbef3fd7eD344aEa26939e8980c83CEC` | fFRAX(sfrxETH)-8 | 2.0.0 | FRAX | 0.000000000000000000 | 0.000000000000000000 | 0 | `0x18500cB1f2…` |
| `0x9234EA70C2360576C3C9E706e7F3F3219e6d885C` | fFRAX(sfrxETH)-13 | 3.0.0 | FRAX | 0.000000000000000000 | 0.000000000000000000 | 0 | `0x18500cB1f2…` |
| `0xA96eB85D1AfB297Bb67EB4856ad5A469Ec921D00` | fFRAX(sfrxETH)-14 | 3.0.0 | FRAX | 0.000000000000000000 | 0.000000000000000000 | 0 | `0x18500cB1f2…` |
| `0xe1B6A8C4A044b38FCd862ba509844C54393cc737` | fFRAX(sfrxETH)-15 | 3.0.0 | FRAX | 0.000000000000000000 | 0.000000000000000000 | 0 | `0x18500cB1f2…` |
| `0xb67Bd04f74BD79a505c5167675E8812355270eD5` | fWBTC(sFRAX)-34 | 3.0.0 | WBTC | 0.00000000 | 0.00000000 | 0 | `0x18500cB1f2…` |
| `0x1eE17BE9B788bcf3EB86C08D0E2b049e036F6eb1` | ffrxETH(ezETH)-36 | 3.0.0 | frxETH | 0.000000000000000000 | 0.000000000000000000 | 0 | `0x576E23b6E2…` |
| `0xCfE3550206ea801c3F7Dc7997376F09E0b7e4B81` | ffrxETH(rsETH)-37 | 3.0.0 | frxETH | 0.000000000000000000 | 0.000000000000000000 | 0 | `0x576E23b6E2…` |
| `0x138E6B890d14a07C11F69b51dCa9270968B01B8B` | fFRAX(MATIC)-43 | 3.0.0 | FRAX | 0.000000000000000000 | 0.000000000000000000 | 0 | `0x576E23b6E2…` |
| `0x254fbc9dBB12C446ea5c9a4439C816d34b875920` | fFRAX(WOETH)-44 | 3.0.0 | FRAX | 0.000000000000000000 | 0.000000000000000000 | 0 | `0x18500cB1f2…` |
