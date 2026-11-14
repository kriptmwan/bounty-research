# Hunter C — non-qualifying leads (rate engine + oracles)

Hunter: domain C. Date: 2026-11-14 (WIB). Read-only; live state checked via
`cast` / ethers view calls against `https://ethereum-rpc.publicnode.com`.
Nothing below is in `hunter-findings-C.json` (which is `[]`). Each lead states
file:line and why it fails the bounty bar (theft-of-funds or permanent freezing
on a CURRENT LIVE deployment, attacker-triggerable, fork-PoC-quantifiable).
Reference pair: `0xaB3cb84c310186B2Fa4B4503624A5D90b5DcB22D`;
rate `0x987a96c6637cF7E7B369BA7C1110d5fB69fb2d17`;
oracle `0x4355903F610D0F94ee476df6e3227811ff7efeE1`.

NQ-C-1 — Rate-curve underflow when full-utilization rate < zero-util rate.
`repos/fraxlend/src/contracts/VariableInterestRate.sol:150-178` (`getNewRate`
computes `_newFullUtilizationInterest - ZERO_UTIL_RATE`; the same shape is in
`rate__src_VariableInterestRateSettable.sol:159-191` with `zeroUtilRate`).
Killed by live config: all five live V2/V3 rate deployments have
ZERO_UTIL_RATE < MIN_FULL_UTIL_RATE (0x1850/0x576E: 158,247,046 < 1,582,470,460;
0x0148: 316,494,092 < 2,373,705,690; 0x9599: 15,824,704 < 1,582,470,460; 0x987a:
1,065,449,010 < 7,912,352,300), and the stored full rate is clamped to
>= MIN on every accrual, so the subtraction cannot underflow on any live pair.
On the settable contract the setter cap (6% = 1,898,964,552) is itself below
MIN_FULL_UTIL_RATE, so even setter abuse cannot create the condition. Any other
instance needs privileged construction config. Fails the bar.

NQ-C-2 — Rate-math division-by-zero / overflow / uint64 truncation.
`VariableInterestRate.sol:115-140` (`getFullUtilizationInterest`: denominators
MIN_TARGET_UTIL, UTIL_PREC - MAX_TARGET_UTIL, RATE_HALF_LIFE * 1e36; `uint64()`
casts applied before the MIN/MAX clamp; `_decayGrowth` quadratic in
`_deltaUtilization`). Killed quantitatively: every live V2/V3 deployment uses
MIN_TARGET_UTIL=75000, MAX_TARGET_UTIL=85000, VERTEX_UTILIZATION=87500,
RATE_HALF_LIFE=172800, so all denominators are interior and nonzero; live
`getNewRate` calls at 0% / 100% / 100001 utilization and deltaTime up to 1 year
all succeed. Truncation of the pre-clamp `uint64()` cast needs a growth factor
of ~2.3e9, i.e. deltaTime ~4e14 seconds at the live half-life; `_decayGrowth`
overflow needs deltaTime ~1e41 seconds. Neither is reachable: `lastTimestamp`
updates on every pair interaction. The only remaining route (a pair constructed
with a near-uint64-max stored full rate) needs whitelisted-deployer config.
Fails the bar.

NQ-C-3 — Unbounded `setVertexRatePercent` can brick accrual.
`rate__src_VariableInterestRateSettable.sol:203-206` has no bounds check (unlike
`setZeroUtilRate` at :194-195, capped at 6%). A SETTER_ROLE holder setting
`vertexRatePercent > 1e18` makes `_vertexInterest > _newFullUtilizationInterest`,
so the high-utilization branch underflows and `getNewRate` reverts on all 9
pairs using 0x987a; an enormous value overflows the vertex computation instead.
Fails the bar: requires SETTER_ROLE. `DEFAULT_ADMIN_ROLE` (the role admin) is
held by timelock `0xB1748C79709f4Ba2Dd82834B8c82D4a505003f27` (verified
on-chain); no unprivileged grant path exists in the code, and no checked
address other than the timelock holds either role. Historical holder
enumeration was blocked (publicnode archive `eth_getLogs` returns 403), but
privilege obtainability is admin-gated regardless. Also admin-recoverable
(the setter can re-set a sane value), so not permanent freezing.

NQ-C-4 — Rate manipulation via flash borrow/deposit.
`VariableInterestRate.sol:150-178` with pair `_calculateInterest` (evidence
only: pair core short-circuits when `lastTimestamp == block.timestamp` and
accrues with pre-transaction utilization). Same-block borrow/deposit cannot
move the stored rate at all; sustained drift needs utilization held outside
the 75–85% band for ~half-life (2 days) while paying the very interest being
manipulated, and borrowing back raises utilization, drifting the rate back up.
No attacker-profitable theft path was demonstrated; the drift is the designed
mechanism. Fails the bar.

NQ-C-5 — Negative/zero Chainlink/Redstone answers revert the Triple Oracle
instead of warning. `oracle__src_contracts_abstracts_EthUsdChainlinkOracleWithMaxDelay.sol:87`,
`..._FraxUsdChainlinkOracleWithMaxDelay.sol:87`, and
`..._RedstoneOracleWithMaxDelay.sol:72` all do `uint256(_answer)` on a signed
answer while only flagging `_answer <= 0` as bad data; the Triple Oracle's
scaling (`oracle__src_contracts_SfrxEthUsdTripleOracle.sol:245-261,279-284`,
`1e18 * raw / precision`) then overflows on the wrapped huge value (negative
answer) or `calculatePrices` (:291-313) divides by zero (zero answer), so
`getPrices` reverts and borrow/liquidate paths on the 5 pairs using 0x4355...
brick — the `isBadData` warn-don't-revert design never surfaces. Fails the bar:
it requires a Chainlink/Redstone feed malfunction (answer <= 0), which an
attacker cannot cause; all three live feeds returned positive answers with
complete rounds at check time. Robustness issue, not attacker-triggerable
freezing.

NQ-C-6 — Stale oracle data is warned, not rejected, and still prices
liquidations. `SfrxEthUsdTripleOracle.sol:315` ORs the three staleness flags
into `isBadData`, which the pair only logs (evidence: pair core emits
`WarnOracleData` and stores the prices). A stale-high ETH/USD Chainlink feed
during a crash would leave the Curve and Redstone legs stale-low while the
TWAP leg stays live: borrows block via the deviation gate, but liquidations
use the stale low rate, delaying liquidations. Fails the bar: requires an
external Chainlink outage exceeding `maximumEthUsdOracleDelay` (3900s live);
an attacker cannot stall Chainlink. Dedup-adjacent: EX-011 (TOB-FXLEND-5,
oracle-outage risk, informational). Live feeds were fresh at check time
(ETH/USD age ~2466s, FRAX/USD fresh, Redstone age ~13819s vs 21900s limit).

NQ-C-7 — `answeredInRound` / round completeness unchecked.
All three Chainlink/Redstone abstracts (`_getEthUsdChainlinkPrice`,
`_getFraxUsdChainlinkPrice`, `_getRedstonePrice`) and
`DualOracleChainlinkUniV3.sol:111-127` discard `roundId`/`answeredInRound`
from `latestRoundData`. KILLED BY DEDUP: EX-010 (TOB-FXLEND-4, improper
Chainlink validation) reported this mechanism class; the v3 code partially
remediated it (`updatedAt` staleness is now checked). The residual
incomplete-round acceptance needs an aggregator anomaly, and live rounds are
complete (`answeredInRound == roundId` on both Chainlink feeds; the Redstone
feed uses constant roundId 1 by design). Fails the bar and is a duplicate.

NQ-C-8 — UniV3 TWAP manipulation (900s window).
`oracle__src_contracts_abstracts_UniswapV3SingleTwapOracle.sol:78-91` quotes
one pool via the Mean Finance Static Oracle; `calculatePrices`
(`SfrxEthUsdTripleOracle.sol:291-328`) takes extremes over three legs. The
borrow side is structurally protected: solvency uses the HIGH rate and
borrows block when the spread exceeds `maxOracleDeviation` (5000 = 5%), so
moving one leg cannot create undercollateralized borrows; only temporary
liquidation-delay via the low leg remains. The pool
(`0x36C060Cc4b088c830a561E959A679A58205D3F56`, frxETH/FRAX 1% fee) is deep
(liquidity ~1.66e22) with observation cardinality 180 (> 75 needed for 900s),
so sustained distortion costs far exceed any temporary benefit. No profitable
theft path demonstrated. Fails the bar.

NQ-C-9 — Curve EMA manipulation / staleness.
`oracle__src_contracts_abstracts_CurvePoolEmaPriceOracleWithMinMax.sol:80-84`
clamps the EMA to [minimum, maximum] with no staleness check. Live clamp is
[0.9e18, 1.0e18] and raw `price_oracle()` is 0.9976e18, so the maximum
favorable manipulation (pushing the EMA to its 1.0 cap) moves that leg by
~0.24% — negligible for both borrows (deviation gate) and liquidations.
Staleness requires pool inactivity, not attacker action. Fails the bar,
quantified.

NQ-C-10 — Redstone failure modes.
`oracle__src_contracts_abstracts_RedstoneOracleWithMaxDelay.sol:65-72` with
live `maximumOracleDelay` = 21900s (~6h): a stale Redstone ratio feeds one of
three legs for up to 6h before flagging bad data, and bad data does not block
the pair. The Redstone leg is a slow-moving sfrxETH/ETH ratio combined with
live Chainlink ETH/USD, and extremes + the deviation gate prevent a single
stale leg from yielding a manipulable borrow price. Fails the bar: external
precondition, no theft path.

NQ-C-11 — Unbounded trust in sfrxETH `pricePerShare`.
`SfrxEthUsdTripleOracle.sol:276-277` (`getFrxEthPerSfrxEthErc4626Vault`) feeds
the vault exchange rate into the Curve and TWAP legs. A donation inflating
`pricePerShare` lowers both legs, widening the spread (borrows block) and
deflating the liquidation low rate. Cost scales with vault TVL — the donation
is a permanent gift to all sfrxETH holders and the attacker recovers only
their pro-rata share — and no profitable theft was demonstrated. Fails the bar.

NQ-C-12 — DualOracleChainlinkUniV3 bad-data collapse to a single TWAP source.
`repos/fraxlend/src/contracts/oracles/dual-oracles/DualOracleChainlinkUniV3.sol:143-157`:
on bad Chainlink data both returned prices equal the TWAP price, collapsing
the deviation band to zero and re-allowing borrows on one source (also flagged
in DELTA-2023-2025.md §6.9); a TWAP revert propagates uncaught, and
`block.timestamp - _updatedAt` (:115/:127) panics if a feed ever reports a
future timestamp. Fails the bar on live deployment: a sweep of all 49 distinct
v3 pair oracles on 2026-11-14 found NO deployment of this exact contract —
the only oracle exposing its getter shape (`0xd2F0fa7f...`) returns
`oracleType = 2` while the file hardcodes `oracleType = 1` (:50) and its name
advertises a Curve EMA leg this file lacks. Zero live pairs, zero funds at risk.

NQ-C-13 — LinearInterestRate.
`repos/fraxlend/src/contracts/LinearInterestRate.sol:52-92` (v1 interface
`getNewRate(bytes,bytes)`). No live pair uses it: all 7 distinct registry rate
contracts were identified by `name()`/`version()` — five Variable Rate V2/V3
and two V1 "Variable Time-Weighted Interest Rate" — none is "Linear Interest
Rate". Its v1 selector is incompatible with v3 pairs, and installing it would
require the owner/timelock `setRateContract` path (admin-gated). Its own math
is bounded by `requireValidInitData` (vertex in (0, 1e5), ordered rates).
Fails the live-deployment bar. Dedup-uncertain note: this file is pre-v3 code
(cosmetic-only delta per DELTA-2023-2025.md) and the Jan 2023 ToB report PDF
could not be retrieved, so a Jan 2023 duplicate cannot be excluded — moot,
since there is no live deployment.

NQ-C-14 — Oracle admin setters.
`SfrxEthUsdTripleOracle.sol:160-200` (`setMinimum/MaximumCurvePoolEma`,
`setTwapDuration` with no lower bound — 0 would make the TWAP a spot quote,
`setMaximumEthUsd/FraxUsd/RedstoneOracleDelay` with no upper bound) and
`DualOracleChainlinkUniV3.sol:100-105` (`setMaxOracleDelay`) are all
timelock-gated (live oracle timelock `0x8412ebf45bAC1B340BbE8F318b928C466c4E39CA`).
Misconfiguration footguns exist (inverted EMA min/max pins the EMA leg;
huge delays accept stale data) but every path requires the timelock key.
Fails the bar: admin-key-required, no unprivileged obtainability.

NQ-C-15 — `addRoundData` truncation / permissionless call.
`SfrxEthUsdTripleOracle.sol:216-226` casts prices to `uint104` and is callable
by anyone with any receiver address. Live prices (~4.5e14) are far below 2^104,
authorization is enforced receiver-side, and the function has no effect on
pair pricing. Fails the bar.

NQ-C-16 — `getPricesNormalized` ignores decimal normalization.
`oracle__src_contracts_DualOracleBase.sol:67-83` computes NORMALIZATION_0/1
but `SfrxEthUsdTripleOracle.sol:357-366` returns raw `getPrices()` unchanged.
Live deployment is correctly configured: all four token decimals are 18,
NORMALIZATION_0 = NORMALIZATION_1 = 0, BASE_TOKEN_0/1 = `0x348` (USD
placeholder), QUOTE_TOKEN_0/1 = sfrxETH — no mispricing. Misconfiguration
class is dedup-adjacent to EX-020 (TOB-FBSRO-2, resolved deployment
misconfig). Fails the bar.

NQ-C-17 — DualOracleChainlinkUniV3 constructor normalization exponent.
`DualOracleChainlinkUniV3.sol:81-89`: `CHAINLINK_NORMALIZATION = 10 ** (18 +
multiplyDecimals - divideDecimals + baseDecimals - quoteDecimals)` can
underflow (uint arithmetic) for unusual feed/token decimal combinations,
reverting deployment. Deployment-time only, and per NQ-C-12 no live
deployment of this contract exists. Fails the bar.
