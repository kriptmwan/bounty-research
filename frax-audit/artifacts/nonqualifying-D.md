# Hunter D — non-qualifying items (deployer / registry / whitelist / timelock)

No finding survived the impact gate, so `hunter-findings-D.json` is `[]`. Each item
below is suspicious-but-not-qualifying: one paragraph, file:line, and why it fails the
bounty bar (theft of funds or permanent freezing on a CURRENT LIVE deployment, via an
unprivileged caller, with a fork PoC quantifying funds at risk). Dedup gap note: the
Jan 2023 ToB report could not be retrieved, so any item touching pre-v3 code paths
(CREATE2/salt handling, ownership transfer) is dedup-uncertain against that report even
where it matches a retrieved exclusion; kills below cite retrieved EX-IDs where they
apply. Live-state facts were verified with read-only `cast` calls on 2026-11-14 WIB.

## NQ-D-1 — deploy() forwards unvalidated pair config; registry trusts the deployer blindly

`FraxlendPairDeployer.sol:304-326` (`deploy`) decodes only asset/collateral from
`_configData` and forwards the rest (oracle, rate contract, maxLTV, liquidation fees)
unvalidated into the pair constructor, then `FraxlendPairRegistry.addPair` (deployed
registry, `registry__src_contracts_FraxlendPairRegistry.sol:95-106`) registers whatever
address the authorized deployer passes after only a name-uniqueness check — no code,
oracle, or parameter validation anywhere. A malicious pair (rigged oracle, >100% LTV)
registered as canonical could trap future depositors who trust the registry list. It
fails the bar three ways: (a) `deploy()` is gated by the deployer whitelist
(`FraxlendPairDeployer.sol:308-310`), and whitelist membership is owner-only
(`FraxlendWhitelist.sol:44-48`, live owner `0xa4EC124e09D6D1A092c6BD16aFac9CD83f73E3c3`),
so the path requires a privileged caller; (b) no live pair reads the registry (grep:
only the deployer references it), so registry state cannot endanger funds already in
live pairs such as `0xaB3cb84c310186B2Fa4B4503624A5D90b5DcB22D`; (c) a hypothetical
future fake pair has $0 at risk today and no fork PoC can quantify funds at risk.

## NQ-D-2 — Non-empty defaultSwappers bricks deploy()

`FraxlendPairDeployer.sol:268-275` (`_deploy`) calls `setSwapper` on the fresh pair for
each entry in `defaultSwappers`, but `FraxlendPair.setSwapper` is `onlyOwner`
(`FraxlendPair.sol:492`) and the pair owner is the comptroller, not the deployer
(`FraxlendPairAccessControl.sol:58-66` sets owner to `_comptrollerAddress`), so any
non-empty `defaultSwappers` makes every `deploy()` revert. Live state confirms the
trigger is latent: `defaultSwappers(0)` reverts (array empty). It fails the bar because
the trigger is owner-only (`setDefaultSwappers`, `FraxlendPairDeployer.sol:172-174`),
reversible by the same owner, and blocks only NEW pair creation — no funds in live
pairs are frozen or stolen.

## NQ-D-3 — Any whitelisted deployer can brick or over-seed new deployments via setAmountToSeed

`FraxlendPairDeployer.sol:238-249` lets any whitelisted address (not just the owner)
set the global `amountToSeed`; setting it to 0 makes `deploy()` revert with
`MustSeedPair()` (`:327-329`), and setting it above the deployer's asset balance makes
the seed deposit revert — both brick all new pair creation until another whitelisted
deployer resets it. It fails the bar because it requires whitelisted (privileged)
status, is reversible by any whitelisted address, and affects only future deployments,
not funds in live pairs.

## NQ-D-4 — Deployer seed shares are unrecoverable (no redeem/withdraw/recover function)

`deploy()` seeds each new pair with `deposit(amountToSeed, address(this))`
(`FraxlendPairDeployer.sol:327-330`), but the deployer exposes no redeem, withdraw, or
token-recovery function, so the deployer's fToken shares (and hence the seed funds) are
locked in each pair permanently. It fails the bar because the locked funds are the
protocol's own seed capital, not user funds — this reads as deliberate first-share /
inflation protection — and observed seed amounts on live pairs are small (5–10 asset
units). No user theft or user-funds freezing is demonstrated.

## NQ-D-5 — Deployed registry addSalt is dead and broken (no array push, no event)

Deployed registry `addSalt` (`registry__src_contracts_FraxlendPairRegistry.sol:121-126`)
writes only `deployedPairsBySalt[_salt]` — it never pushes to `deployedSaltsArray` and
never emits the declared `AddSalt` event, and no code anywhere reads
`deployedPairsBySalt` (the current deployer never calls `addSalt`; neither does the
legacy deployer). Live state confirms it: `deployedSaltsLength()` returns 0 and
`getAllPairSalts()` returns `[]`. Salt tracking is purely informational dead state with
no on-chain consumer, so its brokenness endangers no funds; the mapping is also
unreachable for poisoning since only the authorized deployer contract may call
`addSalt` and it contains no such call.

## NQ-D-6 — Deployed registry is single-step Ownable and append-only (no removePair)

The deployed registry uses OZ single-step `Ownable` (not HEAD's `Ownable2Step`) and has
no pair-removal function, so a mistyped `transferOwnership` could strand registry
administration and an erroneously registered pair can never be delisted. It fails the
bar because ownership transfer requires the registry owner (live: timelock
`0xB1748C79709f4Ba2Dd82834B8c82D4a505003f27`, i.e. governance) — an admin-key path —
losing registry admin would strand only deployer rotation, while the currently
authorized deployer keeps working and live pairs (which never read the registry) are
unaffected. The single-step-ownership pattern is a retrieved known issue: dedup
EX-007 (TOB-FXLEND-1). Divergence from HEAD (Ownable2Step, no salt tracking) is noted,
not a finding: the deployed version is what was audited.

## NQ-D-7 — CREATE2 salt / name race between whitelisted deployers

`getNextNameSymbol` derives the pair name from `deployedPairsLength() + 1`
(`FraxlendPairDeployer.sol:127-148`), the name feeds the CREATE2 salt
(`:280-286`), and the registry enforces name uniqueness, so two whitelisted deployers
deploying concurrently with the same registry length cause the second transaction to
revert entirely. It fails the bar because the unauthenticated-blocking mechanism of
EX-006 (TOB-FRAXLEND-6) no longer exists — `deploy()` is whitelist-gated, an
unprivileged caller cannot deploy at all, cannot CREATE2 to the deployer's predicted
addresses (the deployer address is part of the CREATE2 address formula), and the
residual race is between privileged operators with no funds impact. Dedup: EX-006.

## NQ-D-8 — setCreationCode reverts on creation code under 13,000 bytes

`FraxlendPairDeployer.sol:161-162` calls `BytesLib.slice(_creationCode, 0, 13_000)`
unconditionally, reverting for shorter code; the 2025 fix zeroed `contractAddress2` for
short code (`:168-172`, addressing EX-014) and `_deploy` only reads the second SSTORE2
blob when non-zero (`:265-267`, addressing EX-013's second half), but the first-half
slice assumption remains. It fails the bar because it is owner-only, the live creation
code is ~29,157 bytes (well above the threshold), and it is a retrieved known issue:
dedup EX-013 (TOB-FXLEND-7) / EX-014 (TOB-FXLEND-8).

## NQ-D-9 — Deployer owner can redirect all future deployments (creation code, registry, whitelist, timelock, comptroller, circuit breaker)

`setCreationCode`, `setRegistry`, `setWhitelist`, `setTimelock`, `setComptroller`, and
`setCircuitBreaker` (`FraxlendPairDeployer.sol:161-233`) are all `onlyOwner` with no
validation, and the deployer itself is single-step `Ownable`, so the live owner
`0xa4EC124e09D6D1A092c6BD16aFac9CD83f73E3c3` could point future deployments at arbitrary
pair bytecode, a fake registry, or a permissive whitelist. It fails the bar outright:
every path requires the deployer-owner admin key, which the bounty explicitly excludes,
and none of these setters touches already-deployed live pairs. The single-step transfer
aspect is the EX-007 pattern (dedup).

## NQ-D-10 — Timelock2Step: renounce / zero-nomination can brick timelock-only pair setters, but only by the timelock's own deliberate act

`Timelock2Step.sol:100-123`: `transferTimelock` accepts `address(0)` with no check, and
`renounceTimelock` (requiring the timelock to first nominate itself as pending, then
setting timelock to `address(0)`) would permanently disable timelock-only pair setters
such as `setOracle`, `setMaxLTV`, and `setRateContract` (`FraxlendPair.sol:299-393`,
`_requireTimelock` only) for that pair. It fails the bar because both paths require the
current timelock itself (live pairs: timelock `0xB1748C79709f4Ba2Dd82834B8c82D4a505003f27`)
acting deliberately in two steps; there is no unprivileged path (`acceptTransferTimelock`
requires nomination, and a zero nomination is recoverable because the current timelock
can overwrite `pendingTimelockAddress`). There is also no delay to bypass: despite the
name, `Timelock2Step` implements no time delay — the delay, if any, lives in the
timelock contract at the role address. Constructor initialization is safe: both live
inheritors overwrite the `msg.sender` default (`FraxlendPairAccessControl.sol:64`,
`DualOracleChainlinkUniV3.sol:69`).

## NQ-D-11 — Whitelist gates WHO can deploy, not WHAT; oracle/rate whitelists were removed in v3

`FraxlendWhitelist.sol:32-48` retains only `fraxlendDeployerWhitelist`; the v3 rewrite
removed the oracle and rate-contract whitelists and all deploy-time oracle/rate
validation, so a whitelisted deployer may deploy a pair with any oracle or rate
contract, including a malicious one. It fails the bar as a standalone item because
exploiting it requires whitelisted status, which is granted only by the whitelist owner
(live owner `0xa4EC…`, `pendingOwner()` zero, Sourcify exact match for the deployed
whitelist contract) — a privileged path. Residual uncertainty, recorded honestly: the
full whitelist membership was NOT enumerated (a mapping plus historical events; no
enumeration was attempted), so the verdict assumes members are trusted Frax operators —
consistent with the 13 pairs deployed by the canonical deployer all having plausible
Frax configurations. Next check if this is ever revisited: scan `SetFraxlendDeployerWhitelist`
events on `0xDc1cf6863b6100468479fE7dd3D2D1cDe7775265` and confirm no member is a
permissionless forwarder contract; no evidence of one was found in this pass.

## NQ-D-12 — Killed leads: CREATE2 prediction/donation, metadata reentrancy, constructor-time reentrancy

Three hypothesized unprivileged angles were traced and killed. (1) Pre-funding a
predicted CREATE2 pair address cannot manipulate share pricing: pair accounting uses
`totalAsset.amount`, not token balance (`FraxlendPair.sol:233-235`), the seed deposit
is atomic with deployment in one transaction, and only the deployer contract can
CREATE2 to the predicted address. (2) Malicious asset/collateral metadata cannot
reenter the deployer: `safeSymbol`/`safeName`/`safeDecimals` use `staticcall` with
fallbacks (`libraries/SafeERC20.sol:44-60`). (3) A malicious oracle or asset token
invoked during pair construction or the seed deposit cannot reenter any state-changing
deployer function: `deploy`/`setAmountToSeed` require whitelisted `msg.sender`,
setters require the owner, and `globalPause` requires the circuit breaker, so a
callback from the token/oracle address reverts on every path; the registry likewise
requires `deployers[msg.sender]`. No unprivileged trigger exists for any of the three.

## Legacy deployer (evidence only, no findings)

Legacy deployer `0x5d6e79Bcf90140585CE88c7119b7E43CAaA67044`
(`deployerA__src_contracts_FraxlendPairDeployer.sol`): pre-registry generation, contains
no `addPair`/`addSalt`/registry interaction, and `deployers(legacy)` is `false` on the
live registry (ONCHAIN-GROUNDWORK §2.2), so it cannot add pairs to the registry and its
8 V1 pairs cannot pollute registry state relied on by v3 pairs — which, as noted, do
not read the registry at all. No finding is reported in it.
