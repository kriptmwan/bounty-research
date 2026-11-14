# Phase 0B — On-Chain Groundwork: Frax FXB / Frax Bonds (Ethereum Mainnet)

**Audit-only, read-only.** No transactions, no signatures, no broadcasts, no state changes on any live chain. No block-explorer visits, no GitHub API calls, no `cast` (not installed). All state below comes from `eth_call` / `eth_getCode` / `eth_getStorageAt` / `eth_getBalance` / `eth_getTransactionCount` against public Ethereum RPCs, plus read-only inspection of the target repo.

| Item | Value |
|---|---|
| Target repo | `~/workspace/frax-audit/repos/frax-bonds` @ `4ef235e68c8277ad3dbc676762fffe663c9896fc` (verified clean: `git status` empty at end of probing) |
| Chain | Ethereum mainnet (chainId 1) ONLY. Fraxtal (chain 252) and Polygon addresses were checked *on mainnet* for the sweep and are otherwise out of scope — see §9 and owed follow-up #9. |
| Primary RPC | `https://ethereum-rpc.publicnode.com` — worked for all `eth_call`/`eth_getCode`/`eth_getStorageAt` probes. `eth_getLogs` FAILED on this endpoint (see §10). |
| Alternate RPC | `https://eth.llamarpc.com` — tried once for `eth_getLogs` only; unreachable (HTTP 525 / network-detection failure). No third endpoint was tried. |
| Probe window | Blocks 26411500–26411541, 2026-11-14 06:42–06:51 UTC (13:42–13:51 WIB). Reference block for the JSON inventory: **26411541**, timestamp **1794639059** (2026-11-14T06:50:59.000Z). |
| Machine-readable inventory | [`fxb-addresses.json`](sandbox://workspace/frax-audit/fxb-addresses.json) — every address with role, chain, code-present, proxy/impl, maturity, supply, full auction detail tuples, and all 171 sweep entries. |
| Probe tooling | Node v24 + ethers v6 (installed to `/tmp/fxb-probe`, outside the repo). Function selectors and EIP-1967 slots were computed with ethers, never hardcoded from memory. |

## 1. Executive summary

The canonical **live mainnet** FXB deployment is **small, old, immutable, and almost entirely dormant** — and it is **not** the code at repo HEAD:

- **5 FXB maturity contracts** in the factory registry. **4 are matured**; only **1 is unmatured** (FXB_20261231, matures 2027-01-01). 3 hold nonzero supply. All 5 are **v1.0.2 immutable contracts**, FRAX-denominated, with **no proxy, no upgrade path, no owner**.
- **5 SlippageAuction contracts** in the auction-factory registry, paired 1:1 with the 5 FXBs. **Zero live auctions**: all 33 historical runs are stopped and expired, and every auction holds **0 FRAX and 0 FXB**. All 5 are **v1.0.1 immutable contracts**, controlled by an operator contract that does not exist in the repo.
- **Missed-deployment sweep: 0 candidates.** All 171 unique addresses found in the repo were code-checked on mainnet; none is an FXB or auction outside the two factory registries. Three coded-but-unregistered addresses were separately flagged and cleared by interface fingerprinting (§8).
- **Headline discrepancy (read before auditing HEAD code):** the deployed mainnet system runs **v1 code** (Timelock2Step-gated factory, immutable FXBs). The repo HEAD contains **v2 code** (beacon proxies, `Ownable2Step`, `FXB_LFRAX`) that **targets Fraxtal**, not mainnet. The mainnet factories have no `owner()`, `beacon()`, `token()`, or `version()` views at all. Auditing HEAD logic as if it were live on mainnet would misstate roles, upgradeability, creation gating, and redemption gating. See §2.

### Counts

| Count | Value |
|---|---|
| Live FXB contracts (factory registry) | **5** |
| Unmatured / matured (as of probe block) | **1 / 4** |
| FXBs with nonzero totalSupply | **3** |
| Auction contracts (factory registry) | **5** |
| Live auctions (active AND unexpired) | **0** |
| Historical auction runs (detail records) | **33** (0 + 10 + 10 + 0 + 13) |
| Missed-deployment candidates | **0** |
| Repo addresses swept (code-checked on mainnet) | **171** |
| Total FXB outstanding / FRAX held by FXBs | **6,082,680.004302** / **6,082,680.004302** (exactly 1:1 per contract) |

## 2. HEAD source vs deployed bytecode — the v1/v2 split (critical context)

| Aspect | Repo HEAD (`4ef235e`) | Deployed on mainnet (observed) |
|---|---|---|
| FXBFactory | v2.0.0, `Ownable2StepUpgradeable`, beacon + `token()`, hardcodes 4 Fraxtal FXBs in `initialize()` | **v1**: `Timelock2Step`, `FRAX()` immutable, `timelockAddress()` = Safe. `owner()`, `beacon()`, `token()`, `version()` all **revert**. Direct deployment, EIP-1967 slots zero. |
| FXB | v2.0.0 upgradeable (`factory()`, `token()`, owner early-burn in `isRedeemable`) and `FXB_LFRAX` v1.2.0 (Fraxtal upgrade impl) | **v1.0.2 immutable**: `FRAX()` immutable, `MATURITY_TIMESTAMP` immutable. `factory()`, `token()`, `frxUSD()`, `owner()`, `timelockAddress()`, `getBeacon()` all **revert**. No proxy slots. `isRedeemable()` behaves **timestamp-only** (see §4). |
| SlippageAuctionFactory | v1.0.0 with `version()` | **v1**: no `version()`, no `owner()`. `auctionsLength()` / `getAuctions()` / `getAuction()` / `auctions(i)` / `isAuction()` match HEAD shapes. |
| SlippageAuction | v1.0.1 | **v1.0.1** — version matches HEAD; interface matches HEAD (`TOKEN_BUY/SELL`, `details`, `getDetailStruct`, `getLatestAuction`, `Timelock2Step`). Closest HEAD/live match in the system. |
| Deployment target of HEAD scripts | Fraxtal: `DeployFXBFactory.s.sol` hardcodes Fraxtal Safe `0xC4EB…1090E6`, LFRAX `0xff…01Fd`, Fraxtal ProxyAdmin `0xfc…000a`; LFRAX scripts run with `--chain-id 252` | Mainnet factories predate HEAD (README deploy commits `5879a32` / `384f562`, Jan 2024 activity). |

**Consequence for the audit:** the in-scope *live mainnet* code is v1, whose source is **not in this repo at HEAD**. Phase 1+ must obtain the v1 verified source via the owed explorer follow-ups (§10, items 1–2) and must not assume HEAD semantics (especially: no beacon upgrades, no `setToken`, no factory-owner early redemption, no `FXB_LFRAX` behavior) apply to any mainnet contract.

## 3. Factories

### 3.1 FXBFactory — `0x7a07D606c87b7251c2953A30Fa445d8c5F856C7A`

README address **confirmed**: code present (13,205 bytes, codehash `0x03faf65f…47d28`), account nonce **6**, 0 ETH. Direct deployment — EIP-1967 implementation/admin/beacon slots all zero. Not a proxy; **no upgrade authority exists**.

| View | On-chain result |
|---|---|
| `timelockAddress()` | `0x831822660572bd54ebaa065C2acef662a6277D40` (Gnosis Safe, §6) |
| `pendingTimelockAddress()` | `0x0000000000000000000000000000000000000000` (no transfer in flight) |
| `FRAX()` | `0x853d955aCEf822Db058eb8505911ED77F175b99e` |
| `fxbsLength()` | **5** |
| `fxbs(0..4)` | See §4 table (all return distinct addresses; `isFxb() == true` for each) |
| `fxbs(5)`, `fxbs(99)` | Revert (array bounds — registry end proven) |
| `isTimestampFxb(m)` | `true` for all 5 maturities; `false` for `1234567890`, `isFxb(0x0) == false`, `isFxb(FRAX) == false` |
| `owner()` / `beacon()` / `token()` / `version()` / `implementation()` / `admin()` / `getBeacon()` / `paused()` | All revert (no such functions on v1) |
| Storage slots 0/1/2 | `0x0` (pending timelock) / Safe address (timelock) / `0x5` (array length). Slots 3–6 zero — no second registry. |

**Registry-completeness evidence (4 independent checks agree on exactly 5):** `fxbsLength() == 5`; `fxbs(i)` succeeds for 0–4 and reverts at 5 and 99; storage array-length slot == 5; factory account nonce == 6, i.e. 1 + 5 `CREATE`s. Bytecode contains the FRAX address (immutable) and the FXB creation code (hence FXB selectors appear in factory bytecode) but no timelock address (timelock lives in storage) and no maturity constants.

**Who can create new FXBs:** only the Safe (`timelockAddress`), via the timelock-gated creation function (exact v1 function name/signature to be confirmed from verified source — owed follow-up #1; HEAD name is `createFxbContract(uint256)`).

### 3.2 SlippageAuctionFactory — `0x983aF86c94Fe3963989c22CeeEb6eA8Eac32D263`

README address **confirmed**: code present (18,458 bytes, codehash `0xdac17261…6745`), account nonce **6**, 0 ETH. Direct deployment, EIP-1967 slots zero. Not a proxy; **no upgrade authority, no owner**.

| View | On-chain result |
|---|---|
| `auctionsLength()` | **5** |
| `getAuctions()` | 5 addresses, identical (order + set) to `auctions(0..4)` and `getAuction(0..4)` |
| `auctions(5)` | Reverts (registry end proven) |
| `isAuction()` | `true` for all 5 |
| `version()` / `owner()` / `timelockAddress()` / `implementation()` / `admin()` | All revert |
| Storage slot 0 | `0x5` (array length). Slots 1–3 zero. |

**Registry-completeness evidence:** length == 5 by three getters; OOB revert; storage length == 5; nonce == 6 (1 + 5 `CREATE`s). **Creation is permissionless** (no owner/timelock views; HEAD source is permissionless) — anyone *could* call the factory, but no creation has occurred beyond the 5. **Caveat:** the factory registry cannot see `SlippageAuction` contracts deployed directly via the constructor, bypassing the factory. Ruling those out needs the bytecode-similarity / deployer search in owed follow-up #4. The same caveat applies to directly-deployed v1 FXBs vs the FXB registry.

## 4. FXB maturity contracts (all 5, from the factory registry)

All five are **direct, immutable, non-proxy** deployments of the same v1.0.2 template: identical 6,237-byte length; codehashes differ only by immutables (maturity PUSH values at 4 sites, name/symbol strings, EIP-712 cached domain-separator/name hashes — 98–103 differing bytes in 8–9 ranges). Each bytecode embeds the FRAX address at byte offset 821 and its **own** address at byte offset 2961 (consistent with an OZ non-upgradeable `EIP712` immutable `_cachedThis`; inference from bytecode layout, not source-verified). **No** factory or timelock address is embedded in any FXB bytecode, and the `timelockAddress()` / `owner()` selectors are absent — the FXB never calls back to the factory or any timelock. EIP-1967 impl/admin/beacon slots are zero on all five; account nonce is 1 on all five; ETH balance is 0 on all five. There is **no minter allowlist, no owner, no pause, no upgrade** observable in the v1 interface.

| # | Address | Name / Symbol | Maturity (UTC) | Matured? | totalSupply (FXB) | FRAX held | Ver. |
|---|---|---|---|---|---|---|---|
| 0 | `0xfb51435D48cB04dbE5f23b22f80aDe6D996473F5` | FXB_0_MAR312024 / `FXB_20240331` | 1711929600 (2024-04-01) | YES — matured | 0.000000 | 0.000000 | 1.0.2 |
| 1 | `0x0dE54CFdfeD8005176f8b7A9D5438B45c4F1df1e` | FXB_1_JUN302024 / `FXB_20240630` | 1719792000 (2024-07-01) | YES — matured | 365.977105 | 365.977105 | 1.0.2 |
| 2 | `0xF8FDe8A259A3698902C88bdB1E13Ff28Cd7f6F09` | FXB_2_DEC312024 / `FXB_20241231` | 1735689600 (2025-01-01) | YES — matured | 35,533.154031 | 35,533.154031 | 1.0.2 |
| 3 | `0x13f19441Fb473fE96F1928d4a90f79fDb59675F1` | FXB_3_DEC312025 / `FXB_20251231` | 1767225600 (2026-01-01) | YES — matured | 0.000000 | 0.000000 | 1.0.2 |
| 4 | `0x76237BCfDbe8e06FB774663add96216961df4ff3` | FXB_4_DEC312026 / `FXB_20261231` | 1798761600 (2027-01-01) | NO — live until 2027-01-01 | 6,046,780.873166 | 6,046,780.873166 | 1.0.2 |

Per-contract evidence (all values at probe block; full wei precision in JSON):

- **#0 — `0xfb51435D48cB04dbE5f23b22f80aDe6D996473F5`** — `FXB_0_MAR312024` / `FXB_20240331`, maturity 1711929600 (2024-04-01, Monday). Matured. totalSupply **0**, minted 0, redeemed 0, FRAX balance 0. **Never used.** `bondInfo()` = (symbol `FXB_20240331`, name `FXB_0_MAR312024`, 1711929600). `isRedeemable() == true` from every caller (matured). Codehash `0xe6f378db…51ae7`.
- **#1 — `0x0dE54CFdfeD8005176f8b7A9D5438B45c4F1df1e`** — `FXB_1_JUN302024` / `FXB_20240630`, maturity 1719792000 (2024-07-01, Monday). Matured. totalSupply **365.977104976327354023**, minted 4,260,002.452861961722380045, redeemed 4,259,636.475756985395026022 (minted − redeemed == supply, exact). FRAX balance **365.977104976327354023** — exactly 1:1 with outstanding supply. Codehash `0x4c47b563…072b6`.
- **#2 — `0xF8FDe8A259A3698902C88bdB1E13Ff28Cd7f6F09`** — `FXB_2_DEC312024` / `FXB_20241231`, maturity 1735689600 (2025-01-01, Wednesday). Matured. totalSupply **35,533.154030874480338554**, minted 4,662,748.640232400611499160, redeemed 4,627,215.486201526131160606 (difference == supply, exact). FRAX balance exactly 1:1. Codehash `0xfb1bc5f3…c5f7`.
- **#3 — `0x13f19441Fb473fE96F1928d4a90f79fDb59675F1`** — `FXB_3_DEC312025` / `FXB_20251231`, maturity 1767225600 (2026-01-01, Thursday). Matured. totalSupply **0**, minted 0, redeemed 0, FRAX balance 0. **Never used.** Codehash `0xe823dd47…8fa`.
- **#4 — `0x76237BCfDbe8e06FB774663add96216961df4ff3`** — `FXB_4_DEC312026` / `FXB_20261231`, maturity 1798761600 (2027-01-01, Friday). **NOT matured — the only live bond.** totalSupply **6,046,780.873165932571809639**, minted the same, redeemed 0. FRAX balance exactly 1:1. This is the contract cited as the Ethereum example in the repo docs. Codehash `0x685d9f25…5c1`.

Common to all five: `decimals() == 18`; `FRAX() == 0x853d955a…` (the **sole** denomination — legacy FRAX; **no** frxUSD/LFRAX variant exists on mainnet, and no `frxUSD()` view exists); `DOMAIN_SEPARATOR()` present with EIP-712 domain `(name=symbol, version="1", chainId=1, verifyingContract=self)`; `nonces(0x0) == 0`. Storage slots 0–12 inspected on each: slot 2 = totalSupply, slots 3/4 = name/symbol short strings, slots 8/9 = minted/redeemed — no addresses stored anywhere (all immutables live in bytecode). Naming quirk (matches HEAD factory logic): the name/symbol use the **day before** maturity (e.g. `FXB_20261231` matures 2027-01-01).

**Redemption gating — observed behavior.** `isRedeemable()` was called with three simulated callers (`from` = zero address, the Safe, the factory): on the four matured FXBs it returns `true` for all callers; on unmatured FXB #4 it returns **`false` for all three callers, including the Safe**. Combined with the bytecode evidence (no timelock/factory address or selector in FXB code), the v1 `isRedeemable()` behaves as **purely timestamp-gated** — there is no observable early-burn privilege for the timelock/factory on mainnet, unlike HEAD v2 (`Ownable(factory).owner()`) and HEAD `FXB_LFRAX` (`Timelock2Step(factory).timelockAddress()`). This is behavioral + bytecode evidence only; the v1 source confirmation is owed follow-up #1. Practical consequence: FXB #4 holders cannot redeem before 2027-01-01 through any observed path, and the 6.05M FRAX locked in FXB #4 is not early-withdrawable by the team through any observed FXB-level privilege.

**Doc discrepancy:** the README states each maturity "always expires on a Wednesday, UTC 00:00". Only 1 of 5 on-chain maturities is a Wednesday (2025-01-01); the others are Monday, Monday, Thursday, Friday. All are 00:00 UTC on the 1st of a month.

## 5. SlippageAuction contracts (all 5, from the factory registry)

All five are **direct, immutable, non-proxy** v1.0.1 deployments: identical 15,533-byte length, codehashes differing by immutables (`TOKEN_BUY`/`TOKEN_SELL`/name). EIP-1967 slots zero; nonce 1; 0 ETH. Every auction's buy token is FRAX and sell token is its paired FXB; pairing follows registry order exactly.

| # | Address | Name | Pair (buy → sell) | Timelock | Runs | State | Balances (FRAX / FXB) |
|---|---|---|---|---|---|---|---|
| 0 | `0xEC7CD06EA2fE3E2A9bFB4F75467617B35F0931D7` | SlippageAuction: FXB_20240331 | FRAX → `FXB_20240331` | `0x452420df…` (operator) | 0 | dormant (all stopped/expired) | 0 / 0 |
| 1 | `0xC92067D8DDb1970ecB93202DA31a3C45cC2c1F44` | SlippageAuction: FXB_20240630 | FRAX → `FXB_20240630` | `0x452420df…` (operator) | 10 | dormant (all stopped/expired) | 0 / 0 |
| 2 | `0xc9aa98788a675FF0846E8856cb83F19452f3b0c8` | SlippageAuction: FXB_20241231 | FRAX → `FXB_20241231` | `0x452420df…` (operator) | 10 | dormant (all stopped/expired) | 0 / 0 |
| 3 | `0x50c4b90bE25a2de0cd6Ad8dF5047B4C50C78FDE8` | SlippageAuction: FXB_20251231 | FRAX → `FXB_20251231` | `0x452420df…` (operator) | 0 | dormant (all stopped/expired) | 0 / 0 |
| 4 | `0x63981f5E690eaF7E8795c42832664e8848F532fB` | SlippageAuction: FXB_20261231 | FRAX → `FXB_20261231` | `0x452420df…` (operator) | 13 | dormant (all stopped/expired) | 0 / 0 |

- **#0 — `0xEC7CD06EA2fE3E2A9bFB4F75467617B35F0931D7`** — paired with FXB #0. `detailsLength == 0`: **never started**. `getLatestAuction()` returns the zero struct. `getAmountOut()` reverts with an overflow **panic** (empty `details` array, `length - 1` underflow — matches HEAD code shape). Codehash `0xc8a3f1b0…9466`.
- **#1 — `0xC92067D8DDb1970ecB93202DA31a3C45cC2c1F44`** — paired with FXB #1. 10 runs, all `active == false`, all expired (latest expiry 2024-05-10). Gross listed 17,501,000 FXB; FRAX received 1,300,412.414970. Codehash `0xe39fea2c…b573`.
- **#2 — `0xc9aa98788a675FF0846E8856cb83F19452f3b0c8`** — paired with FXB #2. 10 runs, all stopped/expired (latest expiry 2024-05-10). Gross listed 17,501,000 FXB; FRAX received 1,485,998.709302. Codehash `0x1f4cc6e3…b1c7`.
- **#3 — `0x50c4b90bE25a2de0cd6Ad8dF5047B4C50C78FDE8`** — paired with FXB #3. `detailsLength == 0`: **never started**. Codehash `0x0e9bbeef…102f`.
- **#4 — `0x63981f5E690eaF7E8795c42832664e8848F532fB`** — paired with FXB #4 (the live bond). 13 runs, all stopped/expired (latest expiry 2024-12-05). Gross listed 22,001,000 FXB; FRAX received 3,679,687.175706. `getAmountOut()` reverts with a custom error (inactive auction); `getPreSlippagePrice()` on the stopped latest run returns the price floor (0.91729) — the view has no active-check. Codehash `0x11e39973…18a7`.

Common to all five: `timelockAddress() == 0x452420df4AC1e3db5429b5FD629f3047482C543C` (the operator contract, §6 — **not** the Safe directly), `pendingTimelockAddress() == 0x0`, `PRECISION() == 1e18`, `version() == 1.0.1`, `token0 == TOKEN_BUY`, `token1 == TOKEN_SELL`. **No auction is pausable** (no pause view in the interface); liveness is solely `active && !expired`, and no run satisfies it. Auctions are **restartable** by the operator at any time (a new `startAuction` requires only operator + FXB allowance + a future expiry), so dormancy is a state fact, not a guarantee — but as of the probe block, **no auction holds any funds and no swap can execute**.

Historical-run quirks visible in the detail records (full tuples in JSON): several runs have `priceDecay == 0` and `priceSlippage == 0` (fixed-price sales, e.g. auction #1 run 1 at 0.976566, auction #4 run 1 at 0.8915); several runs were started and stopped with zero sales (`amountLeft == amountListed`, `tokenBuyReceived == 0`); auction #4 run 1 nearly sold out (4.75 FXB left of 250,000 listed); `amountExcessBuy`/`amountExcessSell` are 0 on all 33 runs (no stray-token bookkeeping ever triggered).

### 5.1 All 33 historical auction runs (amounts in whole tokens, 6dp; exact wei in JSON)

| Auction | Run | Listed | Left | FRAX received | priceLast | priceMin | Decay | Slippage | Expiry | Active |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 (FXB_20240630) | 0 | 1,000.000000 | 871.939628 | 124.256019 | 0.970240900774632618 | 0.97 | 29000000000 | 6200000000 | 2024-01-13 | false |
| 1 (FXB_20240630) | 1 | 250,000.000000 | 2,408.665531 | 241,789.279137 | 0.976566 | 0.976566 | 0 | 0 | 2024-01-20 | false |
| 1 (FXB_20240630) | 2 | 250,000.000000 | 0.000000 | 243,880.890933 | 0.970076009818075706 | 0.97 | 29000000000 | 6200000000 | 2024-01-25 | false |
| 1 (FXB_20240630) | 3 | 2,000,000.000000 | 2,000,000.000000 | 0.000000 | 0.98 | 0.977 | 29000000000 | 6200000000 | 2024-01-31 | false |
| 1 (FXB_20240630) | 4 | 3,000,000.000000 | 2,604,058.710355 | 386,807.501255 | 0.976918302470180908 | 0.97681 | 2900000000 | 620000000 | 2024-02-01 | false |
| 1 (FXB_20240630) | 5 | 3,000,000.000000 | 2,634,440.261591 | 357,957.183313 | 0.979147083695547986 | 0.9791 | 2900000000 | 620000000 | 2024-02-15 | false |
| 1 (FXB_20240630) | 6 | 3,000,000.000000 | 2,929,111.309790 | 69,853.304298 | 0.98533653889733012 | 0.9829 | 2900000000 | 620000000 | 2024-02-29 | false |
| 1 (FXB_20240630) | 7 | 2,000,000.000000 | 2,000,000.000000 | 0.000000 | 0.9873 | 0.98717 | 2900000000 | 620000000 | 2024-03-29 | false |
| 1 (FXB_20240630) | 8 | 2,000,000.000000 | 2,000,000.000000 | 0.000000 | 0.9873 | 0.9871 | 2900000000 | 620000000 | 2024-04-12 | false |
| 1 (FXB_20240630) | 9 | 2,000,000.000000 | 1,999,999.999985 | 0.000014 | 0.991680000000017874 | 0.99168 | 2900000000 | 620000000 | 2024-05-10 | false |
| 2 (FXB_20241231) | 0 | 1,000.000000 | 989.440339 | 10.000000 | 0.947000249999999998 | 0.947 | 60000000000 | 12500000000 | 2024-01-13 | false |
| 2 (FXB_20241231) | 1 | 250,000.000000 | 0.000000 | 239,250.000000 | 0.957 | 0.957 | 0 | 0 | 2024-01-20 | false |
| 2 (FXB_20241231) | 2 | 250,000.000000 | 0.000000 | 237,391.659006 | 0.948835752118820796 | 0.947 | 60000000000 | 12500000000 | 2024-01-25 | false |
| 2 (FXB_20241231) | 3 | 2,000,000.000000 | 1,817,508.304308 | 173,393.964441 | 0.948949089111014136 | 0.947 | 60000000000 | 12500000000 | 2024-01-31 | false |
| 2 (FXB_20241231) | 4 | 3,000,000.000000 | 2,366,854.355851 | 604,039.223694 | 0.954029498059234694 | 0.95004 | 6000000000 | 1250000000 | 2024-02-01 | false |
| 2 (FXB_20241231) | 5 | 3,000,000.000000 | 2,819,999.658976 | 171,913.862162 | 0.955278162155404138 | 0.95492 | 6000000000 | 1250000000 | 2024-02-15 | false |
| 2 (FXB_20241231) | 6 | 3,000,000.000000 | 2,937,614.765437 | 60,000.000000 | 0.961841039999999998 | 0.96069 | 6000000000 | 1250000000 | 2024-02-29 | false |
| 2 (FXB_20241231) | 7 | 2,000,000.000000 | 2,000,000.000000 | 0.000000 | 0.962 | 0.96046 | 6000000000 | 1250000000 | 2024-03-29 | false |
| 2 (FXB_20241231) | 8 | 2,000,000.000000 | 2,000,000.000000 | 0.000000 | 0.9639 | 0.96372 | 6000000000 | 1250000000 | 2024-04-12 | false |
| 2 (FXB_20241231) | 9 | 2,000,000.000000 | 2,000,000.000000 | 0.000000 | 0.9612 | 0.96115 | 6000000000 | 1250000000 | 2024-05-10 | false |
| 4 (FXB_20261231) | 0 | 1,000.000000 | 1,000.000000 | 0.000000 | 0.888 | 0.878 | 180000000000 | 37500000000 | 2024-01-13 | false |
| 4 (FXB_20261231) | 1 | 250,000.000000 | 4.750421 | 222,870.765000 | 0.8915 | 0.8915 | 0 | 0 | 2024-01-20 | false |
| 4 (FXB_20261231) | 2 | 250,000.000000 | 192,063.274999 | 51,362.494862 | 0.886378747114673304 | 0.878 | 180000000000 | 37500000000 | 2024-01-25 | false |
| 4 (FXB_20261231) | 3 | 2,000,000.000000 | 1,443,614.124453 | 495,082.535126 | 0.900103270134451156 | 0.878 | 180000000000 | 37500000000 | 2024-01-31 | false |
| 4 (FXB_20261231) | 4 | 3,000,000.000000 | 2,164,917.302220 | 743,211.720110 | 0.88844151190082362 | 0.88634 | 18000000000 | 3750000000 | 2024-02-01 | false |
| 4 (FXB_20261231) | 5 | 3,000,000.000000 | 1,819,844.998120 | 1,050,116.024339 | 0.88936249533096371 | 0.8888 | 18000000000 | 3750000000 | 2024-02-15 | false |
| 4 (FXB_20261231) | 6 | 3,000,000.000000 | 2,550,157.135576 | 400,201.431847 | 0.886907858036116252 | 0.88611 | 18000000000 | 3750000000 | 2024-02-29 | false |
| 4 (FXB_20261231) | 7 | 2,000,000.000000 | 1,193,309.501641 | 716,162.107659 | 0.887964999999999998 | 0.88669 | 18000000000 | 3750000000 | 2024-03-29 | false |
| 4 (FXB_20261231) | 8 | 2,000,000.000000 | 2,000,000.000000 | 0.000000 | 0.889 | 0.88669 | 18000000000 | 3750000000 | 2024-04-12 | false |
| 4 (FXB_20261231) | 9 | 2,000,000.000000 | 1,999,230.000000 | 680.096764 | 0.883245100725728344 | 0.88324 | 18000000000 | 3750000000 | 2024-05-10 | false |
| 4 (FXB_20261231) | 10 | 1,500,000.000000 | 1,500,000.000000 | 0.000000 | 0.925 | 0.92265 | 18000000000 | 3750000000 | 2024-10-03 | false |
| 4 (FXB_20261231) | 11 | 1,500,000.000000 | 1,500,000.000000 | 0.000000 | 0.925 | 0.92265 | 18000000000 | 3750000000 | 2024-11-07 | false |
| 4 (FXB_20261231) | 12 | 1,500,000.000000 | 1,500,000.000000 | 0.000000 | 0.919 | 0.91729 | 18000000000 | 3750000000 | 2024-12-05 | false |

**Independent completeness cross-check (exact):** the operator contract's cumulative storage counters equal the sums over these 33 records to the wei — Σ listed = 57,003,000 (slot 5), Σ FRAX received = 6,466,098.299978011627251476 (slot 7), Σ sold = 7,025,001.500778201803039313 (slot 10), Σ left = 49,977,998.499221798196960687 (slot 11). The detail enumeration is therefore arithmetically corroborated by a second contract's state.

## 6. Roles, control map, and upgrade authority

### 6.1 The Safe (FXB Timelock) — `0x831822660572bd54ebaa065C2acef662a6277D40`

Confirmed as a **Gnosis Safe 1.3.0 proxy**: 171-byte proxy code (codehash `0xb89c1b3b…b000`, identical to the canonical Safe proxy bytecode), `VERSION() == "1.3.0"`, singleton `0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552` (22,958 bytes) at storage slot 0, ETH balance 0.099, account nonce 1, Safe nonce **68**.

- **Owners (6), threshold 3:**
  - `0x8da4E997e051605878c9C0B793c496556EACC2C0` (EOA, code length 0)
  - `0xcbc616D595D38483e6AdC45C7E426f44bF230928` (EOA, code length 0)
  - `0x6933BCC3e96f1C4d2cb73Cb391d854b18Ab7A4F2` (EOA, code length 0)
  - `0x05FB8eC3C41da95b26fCb85503DaF8B89B89A935` (EOA, code length 0)
  - `0xc28339c70054bC22255A74E927a0B9e9A475F224` (EOA, code length 0)
  - `0x6e74053a3798e0fC9a9775F7995316b27f21c4D2` (EOA, code length 0)
- **Guard:** none (guard storage slot zero; `getGuard()` reverts on this singleton/proxy combination — guard status was established by direct storage read, not by the getter).
- **Fallback handler:** `0xf48f2b2d2a534e402487b3ee7c18c33aec0fe5e4` (5,492 bytes) set in the fallback-manager slot. Identity not verified without an explorer (owed follow-up #5 — expected to be the Safe compatibility handler; **not assumed**).
- **Modules:** none (`getModulesPaginated` returns empty).
- **Holdings:** 0 FRAX, 0 of every FXB, no FRAX allowances to any FXB. The Safe holds no FXB-system funds directly.
- **Powers:** sole `timelockAddress` of the FXBFactory (can create new FXBs; can transfer factory timelock via 2-step); sole `timelockAddress` of the operator contract (can direct all auction operations through it, and can transfer operator timelock via 2-step). No pending timelock transfer exists on either contract.

### 6.2 The auction operator contract — `0x452420df4AC1e3db5429b5FD629f3047482C543C` (NOT in the repo)

This is the most significant on-chain discovery of this phase: **every auction names this contract, not the Safe, as its timelock**, so only this contract's calls can `startAuction`/`stopAuction`. It appears **nowhere** in the repo (no grep hit in any file). Observed facts:

- Code present: 18,064 bytes, codehash `0xb0bcba4a…2a06`, nonce 1, 0 ETH. Direct deployment, EIP-1967 slots zero — **not a proxy, not upgradeable**.
- `version() == 1.0.2`; `timelockAddress() ==` the Safe; `pendingTimelockAddress() == 0x0`. Storage slot 1 = Safe, slot 2 = Safe again (second address field, uninterpreted without source).
- Bytecode embeds the FXBFactory, AuctionFactory, and FRAX addresses (immutables) and contains the selectors for `transferTimelock` / `acceptTransferTimelock` / `renounceTimelock` (Timelock2Step), `startAuction`, `stopAuction`, `mint`, `burn`, and `createAuctionContract`. 46 candidate selectors were extracted from the dispatcher (listed in `fxb-addresses.json` under `operatorContract.dispatcherSelectorCandidates`; heuristic PUSH4+EQ scan, may include false positives; full ABI identification is owed follow-up #2). No `execute(address,uint256,bytes)`, `createFxbContract`, `swap`, `owner`, `name`, or `FRAX()` selector/view was found — but absence of a generic `execute` selector does **not** prove the contract lacks other privileged paths; source is required.
- **Holdings:** **1,999,230 FXB_20261231** (exactly the unsold remainder of auction #4 run 9, returned to the timelock on `stopAuction`), 0 FRAX, 0 of the other FXBs. **No live allowances**: FRAX allowance to every FXB is 0, and every FXB allowance to its auction is 0 — the operator cannot mint or list again without fresh approvals (which only the Safe can direct it to set, through whatever functions it exposes).
- **Accounting:** storage slots 5/7/10/11 are cumulative auction counters that match the 33 detail records exactly (§5.1). Slot 9 (`9,172,397.763857741784162612`) does not match any computed total (not minted, redeemed, listed, or received) and is **uninterpreted** pending source.

**Control chain:** Safe owners (3-of-6 EOAs) → Safe → operator contract → auctions. FXB creation is Safe → factory (one hop). Nothing else can create FXBs, start/stop auctions, or (observably) redeem early.

### 6.3 Who can do what (summary)

| Action | Who | Evidence |
|---|---|---|
| Create a new FXB | Safe only | Factory `timelockAddress` = Safe; creation is timelock-gated |
| Create a new auction (via factory) | Anyone (permissionless) | Factory has no owner/timelock; HEAD source permissionless |
| Start/stop an auction | Operator contract only | Each auction's `timelockAddress` = operator |
| Direct the operator | Safe only | Operator `timelockAddress` = Safe |
| Mint FXB | Anyone (1:1 FRAX via `transferFrom`) | v1 mint is permissionless by interface; no minter role observed |
| Redeem/burn FXB | Any holder, **only after maturity** (observed) | `isRedeemable()` timestamp-only from all tested callers (§4) |
| Upgrade any FXB/auction/factory | **Nobody** | All direct, immutable deployments; no proxy slots, no admin |
| Change Safe owners/threshold/singleton | Safe owners (3-of-6) via Safe tx | Standard Safe mechanics; no modules/guard |

### 6.4 Underlying token

**FRAX** `0x853d955aCEf822Db058eb8505911ED77F175b99e` — name `Frax`, symbol `FRAX`, 18 decimals, totalSupply **219,173,039.721717401905920735**. This is legacy FRAX (LFRAX on Ethereum per the repo docs). It is the sole denomination of every mainnet FXB and the buy token of every auction. No frxUSD contract is referenced by any mainnet FXB/auction (the frxUSD address in the repo, `0xFc…0001`, is Fraxtal-only and has no code on mainnet).

## 7. Impact quantification (balances that matter)

| Position | Amount |
|---|---|
| FXB #4 outstanding (unmatured, redeemable 2027-01-01) | 6,046,780.873166 FXB, backed by exactly 6,046,780.873166 FRAX locked in the contract |
| FXB #1 + #2 outstanding (matured, redeemable now) | 35,899.131136 FXB, backed 1:1 by FRAX in-contract |
| FXB #0 + #3 outstanding | 0 (never minted) |
| **Total FXB outstanding / total FRAX in FXBs** | **6,082,680.004302 / 6,082,680.004302** |
| Operator holdings | 1,999,230 FXB #4 (~33% of FXB #4 supply), 0 FRAX |
| Safe holdings | 0 FRAX, 0 FXB |
| All auctions combined | 0 FRAX, 0 FXB |
| Historical auction volume (33 runs) | 57,003,000 FXB gross listed; 7,025,001.500778 FXB sold; 6,466,098.299978 FRAX received |
| Live allowances (Safe/operator → FXBs/auctions) | All 0 — no standing approvals |
| FRAX total supply (context) | 219,173,039.721717 |

The only material live exposure is the **6.05M FRAX inside unmatured FXB #4** plus the **1,999,230 FXB #4 held by the operator** (redeemable for the same FRAX after maturity; the operator's FXB are part of the 6.05M outstanding, not additional). Matured-but-unredeemed FXB (#1/#2, ~35,899) is fully collateralized and redeemable on demand. There is no live auction value at risk (zero balances, zero active runs).

## 8. Missed-deployment sweep (HopV2 lesson applied)

**Method.** (1) Attributed grep of every `0x[0-9a-fA-F]{40}` value in `src/`, `scripts/`, `specification/`, and repo `*.md` (excluding `lib/`, `flattened.sol`, lockfiles): **171 unique values**. (2) Manual decode of the 40-hex address words inside the LFRAX JSON calldata (Safe-tx `data` fields embed addresses without `0x` prefixes): no additional addresses beyond the `0x`-prefixed set — the calldata contains only the Fraxtal proxy, ProxyAdmins, impls, 4 Fraxtal FXBs, frxUSD, and the Fraxtal factory. (3) `eth_getCode` + nonce for **every** value on Ethereum mainnet. (4) Interface fingerprinting (`MATURITY_TIMESTAMP`, `TOKEN_BUY/SELL`, `fxbsLength`, `auctionsLength`, `timelockAddress`, `name`, `symbol`, `version`, `totalSupply`, `decimals`, EIP-1967 slots, plus Safe/ProxyAdmin probes where indicated) for every coded address outside the known mainnet-constant set. (5) No `broadcast/` artifacts exist in the repo (verified by find — nothing to sweep there). (6) Negative controls: no swept address has the FXB (6,237-byte) or auction (15,533-byte) code length or codehash other than the 10 registry members; `isFxb`/`isAuction` are false for every non-member tested.

**Results by group:**

| Group | Total | Code on mainnet | No code | Verdict |
|---|---|---|---|---|
| Mainnet FXB system (factories, Safe, FRAX, FXB #4) | 5 | 5 | 0 | All confirmed in §§3–6 |
| Mainnet constants (tokens, oracles, pools, whales, operators) | 82 | 77 | 5 (EOAs: operator/whale/test wallets, nonzero nonces) | Infrastructure only; none is an FXB/auction (length/hash negative control) |
| Fraxtal system (factory, 4 FXBs, auction factory, LFRAX/frxUSD, ProxyAdmins, L2 Safe, impls, bridge, fork-test addrs) | 20 | **2 (flagged below)** | 18 | Fraxtal-only deployments; no code on mainnet as expected. Fraxtal inventory is a separate owed task. |
| Polygon test outputs (`DeployPolygonTestSuite/*.yaml`, 4 suites × 12) | 47 | 0 | 47 | Other-chain test deployments; nothing on mainnet. (Yaml 3 lists `0xE091…` twice, as both FXB_4 and SlippageAuction_4 — a yaml artifact, not a mainnet fact.) |
| Test actors (fork-test placeholders/users) | 3 | **1 (flagged below)** | 2 | See below |
| Fragments — not addresses | 14 | 0 | 14 | 6 calldata selector+padding fragments (`0x9623609d…`, `0x99a88ec4…`), 5 tx-hash prefixes in docs, 1 permit-typehash prefix, 1 storage-slot prefix, 1 ETH sentinel (`0xEeee…`). Excluded as addresses; code-checked anyway (all empty). |
| **Total** | **171** | **85** | **86** | **0 missed FXB/auction deployments** |

**Separately-flagged items (code present but NOT in any factory registry — all cleared by fingerprinting):**

1. **`0xC4EB45d80DC1F079045E75D5d55de8eD1c1090E6`** — the Fraxtal L2 Safe address. On mainnet it *also* hosts a Gnosis Safe 1.3.0 proxy (same 171-byte proxy code as the FXB Safe) with a **different** owner set (5 owners, threshold 3, nonce 19, singleton `0xfb1bffC9d739B8D520DaF37dF666da4C687191EA`, owners: `0xcbc616D5…`, `0x17e06ce6…`, `0x6933BCC3…`, `0x6e74053a…`, `0x8da4E997…`). This is a cross-chain same-address Safe deployment. It controls nothing in the mainnet FXB system (not referenced by any factory/auction/operator) and has no FXB/auction interface. Its Fraxtal incarnation is the v2 factory owner — do not conflate the two chains' owner sets.
2. **`0xaCa39B187352D9805DECEd6E73A3d72ABf86E7A0`** — labeled a "whale" in a Fraxtal fork test. On mainnet it carries 23-byte **EIP-7702 delegation code** (`0xef0100` + delegate `0x63c0c19a282a1B52b07dD5a65b58948A07DAE32B`), nonce 1419. No FXB/auction interface. Unrelated to the FXB system on mainnet.
3. **`0x13Fe62cB24aEa5afd179F20D362c056c3881ABcA`** — labeled `proxyAdmin` in `BaseTest.t.sol` (test-only). On mainnet it is a 6,565-byte `Ownable` contract (owner `0xe0d7755252873c4eF5788f7f45764E0e17610508`); `getProxyImplementation`/`getProxyAdmin` revert (it is **not** a ProxyAdmin); no FXB/auction interface; EIP-1967 slots zero. Unrelated to the FXB system on mainnet; identity is a low-priority owed follow-up.

**Reverse gap (repo incompleteness):** 4 of the 5 mainnet FXBs (`0xfb51…`, `0x0dE5…`, `0xF8FD…`, `0x13f1…`) and **all 5** mainnet auctions never appear anywhere in the repo — they were found only through the on-chain registries. Any inventory built from docs/scripts alone would have missed 9 of 12 live-system contracts. The operator contract (§6.2) is likewise absent from the repo entirely.

**Residual limitation (stated plainly):** the factory registries + nonce + storage checks prove exactly 5 factory-created FXBs and 5 factory-created auctions. They cannot rule out contracts deployed **directly** via the v1 constructors, bypassing the factories. The event-log cross-check that would close this gap was unavailable (both RPCs failed `eth_getLogs`, §10). Direct-deployment exclusion therefore depends on owed follow-ups #3–#4 (creation-event enumeration + bytecode-similarity/deployer search). No evidence of direct deployments was found; absence of evidence here is explicitly **not** proof of absence.

## 9. Discrepancies: docs/scripts vs on-chain state

1. **HEAD v2 code ≠ deployed v1 code** (factories, FXBs; §2). The single most important discrepancy. The deployed system has no beacon, no `Ownable2Step`, no `setToken`, no proxy upgrades, and no `FXB_LFRAX` behavior.
2. **Auction control is two-hop, not one-hop.** Docs name the Safe as the FXB creator/owner; auctions are in fact controlled by the unlisted operator contract `0x4524…`, itself Safe-gated. The operator contract is absent from the repo.
3. **README "always Wednesday" maturities:** false for 4 of 5 on-chain maturities (§4).
4. **HEAD `FXBFactory.initialize()` hardcodes 4 Fraxtal FXBs** into `fxbs[]`. Those addresses have no code on mainnet and are not in the mainnet registry. The mainnet set (5) and Fraxtal set (4) are disjoint.
5. **`00_DeployImpls.json` is a placeholder** (11 empty transactions; no calldata). `01_`/`02_` JSONs carry `"chainId": 1` in the file while targeting Fraxtal ProxyAdmins and Fraxtal addresses (the scripts run with `--chain-id 252`). The JSON `chainId` field must not be read as "mainnet".
6. **`scripts/constants/mainnet.ts` / `Constants.sol` list `FXB_FACTORY` and `SLIPPAGE_AUCTION_FACTORY` as `0x0`** — stale placeholders; the real mainnet factories are in the README and confirmed on-chain. (The Fraxtal constants file lists the Fraxtal factory correctly.)
7. **Two different "timelock" addresses in the repo:** `TIMELOCK_ADDRESS`/`MAINNET_TIMELOCK_ADDRESS` (`0x8412…39CA`, the main Frax timelock — code present on mainnet, 6,862 bytes) vs `FXB_TIMELOCK` (`0x8318…7D40`, the Safe). Only the Safe governs the FXB system; `0x8412…` has no observed role here.
8. **Auction-factory `version()`:** HEAD declares 1.0.0; the deployed factory exposes no `version()` at all. (Deployed auctions *do* report 1.0.1, matching HEAD.)
9. **Polygon yaml artifact:** `DeployPolygonTestSuite/3.yaml` reuses `0xE091…` for both `FXB_4` and `SlippageAuction_4`. No mainnet implication (no code at that address on mainnet).

## 10. Owed block-explorer follow-ups (exact checks; NO browsing was done in this phase)

1. **v1 verified source/ABI** (Etherscan) for: FXBFactory `0x7a07…`, all 5 FXBs, auction factory `0x983a…`, all 5 auctions. Diff each against HEAD; confirm: factory creation gating + maturity rules; FXB `mint`/`burn`/`isRedeemable` exact logic (especially: confirm no early-redemption path exists for any caller); auction `startAuction`/`stopAuction`/`swap` gating and math vs HEAD v1.0.1.
2. **Operator contract `0x4524…` identification** (Etherscan): contract name, verified source/ABI, all functions, storage layout (meaning of slots 5/7/9/10/11 — slots 5/7/10/11 arithmetically identified in §5.1, slot 9 unknown), creation tx + deployer, and the complete list of Safe-callable functions (especially: how it sets allowances, mints FXB, and starts/stops auctions; whether any other privileged path exists).
3. **Creation-event enumeration** (Etherscan logs/API): `BondCreated` events from `0x7a07…` and `AuctionCreated` events from `0x983a…` over full chain history. Confirm exactly 5 + 5 events matching the registries; capture creation block/tx/deployer for each contract. (Attempted via RPC `eth_getLogs`: publicnode returns "could not coalesce error" even on a 100k-block chunk; LlamaRPC unreachable with HTTP 525. Both failures are recorded; no log data was obtained.)
4. **Direct-deployment search** (Etherscan): contracts matching the v1 FXB template (6,237 bytes, codehash family in §4) or the v1 auction template (15,533 bytes) that were NOT created by the two factories — via deployer-tx history and similar-contract search. Confirm none exist, or enumerate them.
5. **Safe verification** (Etherscan + Safe UI): owners/threshold/singleton/fallback-handler for `0x8318…` match §6.1; no pending Safe transactions; identify fallback handler `0xf48f…` (do not assume — verify).
6. **Cross-chain Safe `0xC4EB…`**: confirm its mainnet owner set/threshold (§8, item 1) and that it controls nothing in the mainnet FXB system; separately confirm its Fraxtal owner set (different chain, different task).
7. **Low priority:** identify `0x13Fe62cB…` (Ownable contract, owner `0xe0d7…`) and the EIP-7702 delegate `0x63c0c19a…` — both cleared as unrelated; identification is completeness only.
8. **Deployment history:** creation transactions + deployers for both factories (nonces corroborate 5 creations each; creation txs still owed).
9. **Fraxtal inventory (separate task, Fraxtal RPC required — NOT done here):** enumerate the Fraxtal factory `0xaFa1…`, its FXB registry (expect the 4 hardcoded FXBs + any created since), the Fraxtal auction factory `0xDfA7…` + auctions, LFRAX proxy `0xff…01Fd` + impl `0x17Fd…`, frxUSD `0xFc…0001`, ProxyAdmins `0xfc…0009/000a`, L2 Safe `0xC4EB…`, impls `0xA7c3…`/`0x63aD…`, and verify the executed state of the LFRAX upgrade (FXB impl = `0xA7c3…`, `token() == LFRAX`, frxUSD drained/burned). Nothing in this report asserts any Fraxtal state.
10. **frxUSD on mainnet (if relevant to later phases):** the mainnet frxUSD address does not appear in this repo and no mainnet FXB/auction references frxUSD. If a later phase needs it, resolve it from an authoritative Frax source — do not reuse the Fraxtal `0xFc…0001` address on mainnet.

## 11. Methods, evidence handling, and limitations

- **Read-only guarantee:** every probe was `eth_call`, `eth_getCode`, `eth_getStorageAt`, `eth_getBalance`, or `eth_getTransactionCount`. The only `from`-overridden calls were `isRedeemable()` simulations (read-only `eth_call` with a simulated sender; no transaction was constructed, signed, or broadcast). No state-changing function was called in any form.
- **"Reverts" language:** a view reported as "reverts" means the `eth_call` returned a revert with no data, consistent with a missing function selector (no fallback) on these contracts. It is evidence of interface absence, not of a business-logic failure. Empty-return cases (Safe proxy fallback) are reported as "empty" where they occurred.
- **`eth_getLogs` unavailable:** 8 chunked calls on publicnode (4.4M-block chunks, then a 100k-block chunk) all failed with "could not coalesce error"; the single alternate endpoint (LlamaRPC) was unreachable (HTTP 525). No event data was obtained from any source. Registry completeness therefore rests on the getter + OOB + storage + nonce agreement documented in §3, plus the operator-counter arithmetic in §5.1 — not on logs.
- **Bytecode inferences are labeled as such:** the EIP-712 `_cachedThis` interpretation (§4), the operator-contract function characterization (§6.2), and the Safe-proxy identification (codehash + `VERSION()` + singleton slot) are the strongest available RPC-only inferences; each has a corresponding owed source-verification follow-up.
- **Time reference:** "matured" is judged against the probe-block timestamp (1794639059, 2026-11-14T06:50:59.000Z). FXB #3 (maturity 2026-01-01) is matured as of this probe; FXB #4 (2027-01-01) is not.
- **Repo hygiene:** the target repo was only read (plus `git rev-parse`/`git status`). No file was modified, no patch applied, no build run. `git status` is empty and HEAD is unchanged at the end of this phase.
- **Scope boundary:** this phase covers Ethereum mainnet only, as tasked. Fraxtal state, Polygon state, off-chain components (app.frax.finance), and the v1 source audit itself are explicitly out of scope here.

## Appendix — address index (checksummed; detail in JSON)

| Role | Address |
|---|---|
| FXBFactory (v1) | `0x7a07D606c87b7251c2953A30Fa445d8c5F856C7A` |
| SlippageAuctionFactory (v1) | `0x983aF86c94Fe3963989c22CeeEb6eA8Eac32D263` |
| FXB #0 (20240331, matured, unused) | `0xfb51435D48cB04dbE5f23b22f80aDe6D996473F5` |
| FXB #1 (20240630, matured) | `0x0dE54CFdfeD8005176f8b7A9D5438B45c4F1df1e` |
| FXB #2 (20241231, matured) | `0xF8FDe8A259A3698902C88bdB1E13Ff28Cd7f6F09` |
| FXB #3 (20251231, matured, unused) | `0x13f19441Fb473fE96F1928d4a90f79fDb59675F1` |
| FXB #4 (20261231, LIVE) | `0x76237BCfDbe8e06FB774663add96216961df4ff3` |
| Auction #0 (FXB #0, never started) | `0xEC7CD06EA2fE3E2A9bFB4F75467617B35F0931D7` |
| Auction #1 (FXB #1, 10 runs) | `0xC92067D8DDb1970ecB93202DA31a3C45cC2c1F44` |
| Auction #2 (FXB #2, 10 runs) | `0xc9aa98788a675FF0846E8856cb83F19452f3b0c8` |
| Auction #3 (FXB #3, never started) | `0x50c4b90bE25a2de0cd6Ad8dF5047B4C50C78FDE8` |
| Auction #4 (FXB #4, 13 runs) | `0x63981f5E690eaF7E8795c42832664e8848F532fB` |
| Timelock Safe (3-of-6) | `0x831822660572bd54ebaa065C2acef662a6277D40` |
| Safe singleton (1.3.0) | `0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552` |
| Safe fallback handler | `0xf48f2b2d2a534e402487b3ee7c18c33aec0fe5e4` |
| Auction operator contract | `0x452420df4AC1e3db5429b5FD629f3047482C543C` |
| FRAX (underlying) | `0x853d955aCEf822Db058eb8505911ED77F175b99e` |
| Fraxtal L2 Safe (same addr, mainnet incarnation — flagged, §8) | `0xC4EB45d80DC1F079045E75D5d55de8eD1c1090E6` |

*End of Phase 0B groundwork. Next: owed explorer follow-ups (§10) to obtain v1 source + operator ABI, then Phase 1 code audit against the verified v1 code — not against HEAD v2 code — for mainnet, with Fraxtal handled as a separate chain-scoped workstream.*
