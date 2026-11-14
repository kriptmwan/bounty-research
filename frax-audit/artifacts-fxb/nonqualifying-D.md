# Non-Qualifying Observations — Hunter Domain D (access control / privileged roles + FRAX/frxUSD boundary)

**Run:** adversarial code audit, Frax FXB / Frax Bonds, Ethereum mainnet. Hunter role per
`adversarial_code_audit` SKILL.md §4 (phases 1–6). Audit-only, read-only; no repo patched,
no browsing, zero GitHub API calls, no `cast` (not installed; no cast-based claim is made).
**Result: 0 qualifying findings** — `hunter-findings-D.json` is `[]`. Every observation below
was hunted, traced, and killed for a stated reason. Nothing was left as an unexamined suspicion
except the explicitly listed unresolved cross-references (§5).

**Scope-deciding facts applied (FRAX BAR):** only demonstrated theft-of-funds or
permanent-freezing paths against CURRENT LIVE mainnet deployments, each with a mainnet-fork PoC,
can qualify. "Admin can do X" = centralization → kill (triage Q4). Only privilege ESCALATION
(non-privileged caller reaching a privileged effect) or privilege BRICKING (loss of a needed
privileged function with fund impact) against live instances can qualify. Defects confined to
files with no live mainnet instance are sub-bar.

**Source baseline (hashes captured before dispatch, rechecked before concluding — unchanged):**

| File | sha256 |
|---|---|
| `work/v1-live/lib/frax-standard-solidity/src/access-control/v2/Timelock2Step.sol` | `a8dd24ba…099e10d9` |
| `repos/frax-bonds/src/contracts/OwnedV2.sol` @ `4ef235e68c8277ad3dbc676762fffe663c9896fc` | `5cb926b1…ca63d692` |
| `repos/frax-bonds/src/contracts/ERC20PermitPermissionedOptiMintable.sol` @ same HEAD | `ad90bab6…bbea26d` |

Repo left clean (`git status` empty). The assigned Timelock2Step file is byte-identical to the
Timelock2Step in the factory Sourcify bundle, and identical to the AMO-bundle and HEAD-lib copies
except a constructor parameter name (`_timelock` vs `_timelockAddress`) — no semantic drift.

**Live-state re-verification (read-only `eth_call`, block 26411601, publicnode RPC):**

| Check | Result |
|---|---|
| FXBFactory `timelockAddress` / `pendingTimelockAddress` | `0x83182266…7D40` (Safe) / `0x0` |
| FxbAMO `timelockAddress` / `pendingTimelockAddress` | Safe / `0x0` |
| FxbAMO `operatorAddress` / `pendingOperatorAddress` | **Safe** / `0x0` — operator == timelock == Safe; no separate operator holder exists live |
| Auction #4 `timelockAddress` / `pendingTimelockAddress` | `0x452420df…543C` (FxbAMO) / `0x0` |
| FxbAMO FXB_20261231 balance | exactly 1,999,230.0 |
| FxbAMO storage slot 3 (pending operator) | `0x0` — consistent with the getter |

No role transfer is in flight on any checked live contract. The Safe is the sole privileged
principal for every role in the live system (3-of-6 EOAs, threshold 3, nonce 68 per Phase 0).

---

## 1. Sub-bar observations (killed)

### NQ-D-1 — Timelock2Step: `transferTimelock` has no zero-address check
- **Location:** `Timelock2Step.sol:48-51` + `_transferTimelock` `:76-79`.
- **Observation:** the timelock can nominate `address(0)` as pending. `acceptTransferTimelock`
  (`:55-58`) then requires `msg.sender == address(0)`, which no transaction can satisfy, so the
  nomination can never be accepted.
- **Kill reason — recoverable, no bricking, no escalation:** the current timelock retains full
  power and can overwrite the dead nomination with a fresh `transferTimelock` call
  (`_transferTimelock` unconditionally overwrites `pendingTimelockAddress`). No privileged
  function is lost and no non-privileged caller gains anything. Live `pendingTimelockAddress`
  is `0x0` on factory, AMO, and auction #4 (verified above). Nominating a never-accepting
  address (EOA or contract) has the identical recoverable shape.

### NQ-D-2 — Timelock2Step: constructor does not reject a zero timelock
- **Location:** `Timelock2Step.sol:37-39`.
- **Observation:** deploying with `_timelock == address(0)` would permanently brick all
  timelock-gated functions (no caller can satisfy `msg.sender == address(0)`).
- **Kill reason — deploy-time choice, no live instance affected:** all live inheritors were
  deployed with nonzero timelocks (factory → Safe, auctions → FxbAMO, AMO → Safe; verified
  on-chain). An attacker cannot reach the constructor of a deployed contract. No escalation,
  no live bricking.

### NQ-D-3 — Timelock2Step: `renounceTimelock` permanently bricks privileged functions
- **Location:** `Timelock2Step.sol:62-67` (requires sender to be both timelock and pending
  timelock, i.e. a deliberate 2-step: `transferTimelock(self)` then `renounceTimelock`; sets
  both addresses to `0x0`, after which no caller can ever satisfy either check).
- **Kill reason — intended privileged self-bricking, Q4 centralization:** renouncement requires
  two deliberate transactions from the current timelock (for the factory/AMO, two 3-of-6 Safe
  executions). "Admin can brick its own powers" is not an escalation path for any non-privileged
  caller. Fund impact even if exercised is nil for existing holders: live v1 FXBs have no
  timelock role at all and redemption is purely timestamp-gated, so renouncing the factory
  timelock would only prevent *future* FXB creation. Consistent with EX-F12 (admin powers
  intended per the trust model). No live renouncement has occurred (timelocks nonzero, verified).

### NQ-D-4 — Timelock2Step: front-running / griefing of `acceptTransferTimelock`
- **Location:** `Timelock2Step.sol:55-58`, `:83-86`.
- **Observation considered:** a searcher observing a pending nomination might try to front-run
  acceptance, or the current timelock might overwrite the nomination before acceptance.
- **Kill reason — no theft possible:** acceptance requires `msg.sender == pendingTimelockAddress`
  (`_requireSenderIsPendingTimelock`), so no third party can impersonate the nominee; there is
  no value transferred by acceptance itself. Overwriting a nomination before acceptance is the
  timelock's intended revocation power (privileged caller, Q4). No non-privileged griefing
  vector exists: all three external role functions are gated, and no permissionless function in
  the file mutates role state. There are no external calls anywhere in the file, so no
  reentrancy surface.

### NQ-D-5 — Auction timelock transfer/renounce is unreachable through FxbAMO (timelock pinned)
- **Location:** evidence — `FxbAMO.sol` (evidence-only, out of scope) exposes no function that
  calls an auction's `transferTimelock` / `acceptTransferTimelock` / `renounceTimelock`; its
  `multicall` (`:526-531`) delegatecalls only to `address(this)`, never to an auction; no
  generic `execute`/call forwarding to auctions exists.
- **Observation:** each live auction's timelock (FxbAMO) can never be moved or renounced via any
  exposed path — including by the Safe — because only FxbAMO can call those functions and
  FxbAMO cannot call them.
- **Kill reason — no fund impact, no escalation; the pinning *prevents* hijack/bricking:** the
  Safe → FxbAMO → auction control chain is intact, auctions remain restartable by the Safe
  through FxbAMO `startAuction`/`stopAuction`, and no funds are frozen by the pinning (auctions
  hold 0 FRAX / 0 FXB; proceeds flow back to FxbAMO on `stopAuction`). Recorded as a
  robustness note, not a defect. (No finding is reported in FxbAMO itself, per scope.)

### NQ-D-6 — Role concentration: Safe holds every role; FxbAMO holds ~2M FXB_20261231
- **Location:** live state (verified above) + evidence `FxbAMO.sol`.
- **Observation:** the Safe is simultaneously factory timelock, AMO timelock, and AMO operator;
  FxbAMO (Safe-controlled) is auction timelock and holds 1,999,230 FXB_20261231 (~33% of that
  bond's supply, part of the 6.05M outstanding, not additional).
- **Kill reason — centralization, Q4:** concentration of intended team powers in the 3-of-6 Safe
  is the documented trust model (EX-F12), not an escalation. The operator==timelock identity
  *removes* the separate-operator risk surface live: there is no third-party operator who could
  abuse start/stop within caps. No non-privileged path reaches FxbAMO's holdings through
  in-scope contracts (see §3 privilege matrix): FXB `burn` burns only the caller's own FXB,
  auction withdrawals pay only the timelock caller (FxbAMO itself) inside timelock-gated
  `start`/`stop`, and FxbAMO withdrawals require the timelock.

### NQ-D-7 — OwnedV2: `nominateNewOwner` has no zero-address / acceptability check
- **Location:** `OwnedV2.sol:20-23` (`nominateNewOwner`, `onlyOwner`, no validation);
  `acceptOwnership` `:25-31` requires `msg.sender == nominatedOwner`.
- **Observation:** the owner can nominate `address(0)` or an address that can never call
  `acceptOwnership`, creating a dead nomination.
- **Kill reason — recoverable AND no live instance (either alone kills it):** the owner retains
  full power and can overwrite the nomination with a fresh `nominateNewOwner`; no function is
  lost and no third party can accept (front-running acceptance is impossible — `msg.sender`
  check). Independently, OwnedV2 has **no confirmed live mainnet instance in this system**
  (the only inheritor in the repo is `ERC20PermitPermissionedOptiMintable`, itself with no
  confirmed live mainnet instance; the live FRAX token is the separate `FRAXStablecoin`
  contract — see §4). Sub-bar per the brief. Note the constructor *does* reject a zero owner
  (`:15`), and there is no renounce function, so the owner cannot self-brick at all.

### NQ-D-8 — ERC20PermitPermissionedOptiMintable: `setTimelock` is single-step, callable by either owner or timelock
- **Location:** `ERC20PermitPermissionedOptiMintable.sol:70-74` (`onlyByOwnGov`: owner OR
  `timelock_address`), `:208-212` (`setTimelock`, zero-checked, no acceptance step).
- **Observation:** the timelock can unilaterally reassign its own role to any address in one
  transaction, with no 2-step acceptance as in Timelock2Step; the owner can likewise replace
  the timelock single-step.
- **Kill reason — privileged reassignment of an already-held power, Q4, plus no live instance:**
  `setTimelock` reassigns a power the caller already holds; it grants nothing to a
  non-privileged caller. The timelock cannot escalate to *owner*: `nominateNewOwner` is
  `onlyOwner` (OwnedV2) and acceptance requires nomination, so the owner/timelock separation
  holds in the one direction that matters. Independently sub-bar: no confirmed live mainnet
  instance (see NQ-D-7 / §4). (EX-F11's Optimism-code boundary is noted but not needed for
  this kill — this file is the Frax wrapper, and the kill rests on Q4 + no-live-instance.)

### NQ-D-9 — ERC20PermitPermissionedOptiMintable: minters can mint uncapped; owner/timelock can add any minter
- **Location:** `:167-170` (`minter_mint`, `onlyMinters`, arbitrary recipient/amount, no cap),
  `:174-182` (`addMinter`, `onlyByOwnGov`).
- **Observation:** a minter can mint unlimited tokens to any address; owner/timelock can grant
  minter status to anyone, including themselves.
- **Kill reason — trusted-role abuse, Q4, plus no live instance:** minters are a privileged,
  admin-granted role; "a minter can mint" is the role's intended function, not an escalation
  by a non-privileged caller. No path lets a non-privileged caller *become* a minter
  (`addMinter` is `onlyByOwnGov`). Independently sub-bar: no confirmed live mainnet instance.

### NQ-D-10 — ERC20PermitPermissionedOptiMintable: constructor does not validate timelock/bridge/remote addresses
- **Location:** `:55-66` (`_timelock_address`, `_bridge`, `_remoteToken` stored unchecked;
  only `_creator_address` is zero-checked, via `OwnedV2`).
- **Observation:** deploying with `timelock_address == 0` leaves owner-only governance;
  `BRIDGE == 0` permanently disables `mint`/`burn` (both `onlyBridge`, bridge immutable).
- **Kill reason — deploy-time configuration, fail-closed, no live instance:** misconfiguration
  at deploy time cannot be reached by an attacker post-deployment, creates no privilege for
  any non-privileged caller (zero address can never call), and the bridge-zero case fails
  closed (mint/burn unusable rather than open). Independently sub-bar: no confirmed live
  mainnet instance.

### NQ-D-11 — ERC20PermitPermissionedOptiMintable: `removeMinter` is O(n) and leaves zero-holes
- **Location:** `:186-202` (linear scan of `minters_array`, zeroing the slot, `break` on match).
- **Observation:** removal cost grows with the minter array; the array accumulates zero entries
  and re-adding a removed minter appends a duplicate entry.
- **Kill reason — no reachable harm, no live instance:** the array grows only via privileged
  `addMinter`, so no attacker can bloat it into a removal-DoS; the `minters` mapping (not the
  array) is the source of truth for `onlyMinters`, so holes/duplicates have no access-control
  effect; re-adding a removed minter works correctly (mapping check). Cosmetic at most.
  Independently sub-bar: no confirmed live mainnet instance.

### NQ-D-12 — ERC20PermitPermissionedOptiMintable: `minter_burn_from` burns another account's tokens
- **Location:** `:159-162` (`super.burnFrom(b_address, b_amount)`, `onlyMinters`).
- **Observation considered:** a minter burning from an arbitrary address would be theft if no
  allowance were required.
- **Kill reason — verified benign:** OpenZeppelin `ERC20Burnable.burnFrom` (pinned lib copy
  read) calls `_spendAllowance(account, _msgSender(), value)` before `_burn`, so a minter can
  burn only up to the victim's allowance granted to that minter. No arbitrary-burn path exists.
  (Also sub-bar independently: no live instance.)

### NQ-D-13 — Timelock2Step / OwnedV2: Safe-as-timelock and TimelockController-assumption hazards
- **Location:** `Timelock2Step.sol` (whole file), `OwnedV2.sol` (whole file).
- **Observation considered:** whether either primitive assumes the privileged address is an EOA
  (e.g. `extcodesize` checks, ETH transfers, callbacks) or an OZ `TimelockController`
  (schedule/execute, proposer/executor roles, delays).
- **Kill reason — verified no such assumption:** both files gate purely on `msg.sender`
  equality comparisons, make no external calls, transfer no ETH, and expect no callbacks. The
  live timelock is a Gnosis Safe 1.3.0 proxy whose `execTransaction` calls surface as
  `msg.sender == Safe`, which satisfies every check; no delay/schedule semantics are assumed
  anywhere ("timelock" is a label for the admin address, not a TimelockController). The pending
  party in a 2-step transfer must itself initiate acceptance — satisfiable by the Safe, an EOA,
  or any calling contract — and a non-accepting nominee is recoverable by re-nomination
  (NQ-D-1/NQ-D-7). No defect.

### NQ-D-14 — HEAD factory-owner early burn (EX-F12) does not apply to live v1 FXBs
- **Location:** HEAD `FXB.sol:104` (`isRedeemable` owner branch), HEAD `FXB_LFRAX.sol:313-316`
  (timelock branch) — evidence only, other domains' files.
- **Kill reason — excluded as intended (EX-F12) AND absent live:** the admin early-burn power
  is documented intended functionality. Live v1 FXBs have no early-burn path at all:
  v1 `FXB.isRedeemable()` is purely timestamp-gated (`work/v1-live/.../FXB.sol:91-93`), and
  Phase 0 observed `false` for the unmatured bond from all three simulated callers including
  the Safe, with no timelock/factory address or selector in FXB bytecode. No escalation: no
  non-privileged caller can redeem early on any live contract. The HEAD-only
  `timelockAddress`-vs-`owner` interface mismatch between the two HEAD branches is relayed
  separately (R-D-1) because it is a distinct mechanism in another domain's file.

### NQ-D-15 — Permissionless paths in evidence contracts (factory creation, auction creation, FXB mint/burn)
- **Location:** evidence — v1 `FXBFactory.createFxbContract` (timelock-gated, `:153-154`),
  `SlippageAuction.startAuction`/`stopAuction` (timelock-gated), `SlippageAuctionFactory`
  (permissionless by design), v1 `FXB.mint`/`burn` (permissionless, holder-self).
- **Kill reason — each path confirmed correctly open or correctly closed (§3); residual
  factory-registry question relayed (R-D-3):** creation of FXBs is Safe-only; auction
  start/stop is FxbAMO-only; FXB mint requires the caller's own FRAX 1:1 and burn destroys
  only the caller's own FXB, so permissionless mint/burn grants no privilege. No
  non-privileged caller reaches any privileged effect through in-scope code. The
  permissionless auction-factory registry itself lives in another domain's file and is
  relayed, not reported here.

---

## 2. Cross-domain relays (flawed code, if any, lives in another domain's file — NOT reported under D)

### R-D-1 — HEAD `FXB_LFRAX.isRedeemable` reads `Timelock2Step(factory).timelockAddress()`, but HEAD `FXBFactory` has no `timelockAddress`
- **Files:** `repos/frax-bonds/src/contracts/FXB_LFRAX.sol:313-316` calls
  `Timelock2Step(factory).timelockAddress()`; `repos/frax-bonds/src/contracts/FXBFactory.sol`
  inherits `Ownable2StepUpgradeable` and exposes `owner()`, with no `timelockAddress` anywhere
  in the file (verified by grep). HEAD `FXB.sol:104` instead uses `Ownable(factory).owner()` —
  the two HEAD bond implementations disagree on the factory's role interface.
- **Mechanism (one line):** if the live Fraxtal factory is the HEAD factory, the
  `timelockAddress()` call reverts, so `isRedeemable()` always reverts and `burn()` bricks for
  everyone including post-maturity holders.
- **Status — UNRESOLVED, needs the FXB_LFRAX-domain owner + Fraxtal inventory:** whether the
  live Fraxtal factory exposes `timelockAddress()` (e.g. a pre-upgrade v1-style factory) is
  unverified — the Sourcify bundle for the Fraxtal factory `0xaFa17050…71f6De4` contains no
  sources, and the Fraxtal inventory is an owed Phase 0 follow-up (#9, not done). No mainnet
  instance exists in any case (live mainnet FXBs are v1 timestamp-only), so this cannot
  qualify under the mainnet FRAX BAR regardless; do not file on mainnet grounds. Cited
  here so the coordinator can dedup/reassign, not as a D finding.

### R-D-2 — v1 `FXB.mint`/`burn` do not check FRAX `transferFrom`/`transfer` return values — VERIFIED BENIGN against live FRAX
- **Files:** `work/v1-live/src/contracts/FXB.sol:124` (`FRAX.transferFrom(...)`, return
  ignored), `:145` (`FRAX.transfer(...)`, return ignored).
- **Mechanism checked:** if FRAX returned `false` instead of reverting on failure, FXB would
  mint unbacked / burn without paying. **Checked against the live FRAX verified source**
  (Sourcify bundle `1_0x853d955a…`, contract `FRAXStablecoin`, Solidity 0.6.11): `_transfer`
  `require`s nonzero sender/recipient and reverts via SafeMath `.sub` on insufficient balance;
  `transfer`/`transferFrom` return `true` on success and can only otherwise revert. No
  fee-on-transfer, transfer pause, blocklist, or permit exists in the FRAX source/ABI (the
  only pause gates the collateral-ratio refresh, not transfers). The FXB's `FRAX` address is
  immutable, so this invariant cannot change for a deployed FXB.
- **Status:** checked-and-clear; relayed for the mint/burn domain's awareness so it is not
  re-hunted as a fresh candidate. Not a D finding (code lives in `FXB.sol`).

### R-D-3 — `SlippageAuctionFactory.createAuctionContract` is permissionless and registers arbitrary-timelock auctions in `isAuction`
- **File:** `work/v1-live/auction-factory-tree/src/contracts/SlippageAuctionFactory.sol:38-42`
  (no access control; natspec: "Permission-less factory").
- **Mechanism (one line):** anyone can deploy an auction with any timelock/tokens and have it
  listed in `auctions[]` / `isAuction`, so the registry is not a trust signal.
- **Status — checked, no in-scope on-chain effect:** no on-chain contract consumes
  `SlippageAuctionFactory.isAuction` (verified by grep across HEAD `src/` and all v1 trees;
  only a test assertion and FxbAMO's own unrelated `isAuction` view reference the name;
  FxbAMO gates on its own `auctionDetails`/`fxbToAuction`, and on `FXBFactory.isFxb`, never on
  the auction factory registry). Whether any *off-chain* consumer treats registry membership
  as endorsement is unknown (U-D-4). A created auction's timelock affects only that new
  auction; no privileged effect on the live system is reachable. Relayed to the factory
  domain; not a D finding (code lives in the factory file).

### Checked-and-clear, no relay needed
- **FxbAMO `multicall` (evidence-only file, `FxbAMO.sol:526-531`):** permissionless entry
  delegatecalling `address(this)` does NOT escalate — `delegatecall` preserves `msg.sender`,
  so every inner role check (`_requireSenderIsTimelock`, `_requireTimelockOrOperator`,
  pending-operator checks) re-executes against the original caller; no inner function keys
  off anything `delegatecall` changes, and no value is accepted. A non-privileged caller
  batching privileged calls through `multicall` reverts inside each call exactly as a direct
  call would. No finding in FxbAMO is reported, per scope.
- **Operator2Step / OperatorRole (frax-std, read via the AMO Sourcify bundle; not assigned
  files):** transfer/accept/renounce semantics mirror Timelock2Step correctly
  (pending-only acceptance, 2-step renounce, recoverable nomination). FxbAMO's
  `transferOperator` override moves initiation from operator to timelock, so the operator
  cannot self-transfer or unilaterally renounce (renounce additionally requires the timelock
  to have nominated the operator as pending). Live operator == timelock == Safe, so the
  operator role adds no distinct principal. No defect found; nothing to relay.

---

## 3. Privilege matrix — confirmed closed (evidence for the zero-finding result)

Every privileged effect in the live system was traced to its gate; no permissionless path
reaches any of them through in-scope code:

| Privileged effect | Gate (verified in source) | Live holder |
|---|---|---|
| Create FXB (`FXBFactory.createFxbContract`) | `_requireSenderIsTimelock` | Safe only |
| Transfer/accept/renounce factory timelock | Timelock2Step 2-step, gated as analyzed | Safe only; no transfer in flight |
| Start/stop auction (`SlippageAuction`) | `_requireSenderIsTimelock` | FxbAMO only |
| Transfer/accept/renounce auction timelock | Timelock2Step 2-step | FxbAMO only, unreachable via FxbAMO's exposed fns (NQ-D-5) |
| Direct FxbAMO (`createAuctionContract`, `mintBonds`, `redeemBonds`, `withdrawFrax`, `withdrawBonds`, setters, `transferOperator`) | `_requireSenderIsTimelock` | Safe only |
| FxbAMO `startAuction`/`stopAuction` | `_requireTimelockOrOperator` + bond-approved check | Safe only live (operator == Safe) |
| Accept operator transfer | pending-operator-only | nobody pending live |
| FXB mint | permissionless BY DESIGN — requires caller's own FRAX 1:1 via `transferFrom` | any caller, self-funded only |
| FXB burn/redeem | permissionless BY DESIGN — burns caller's own FXB, only at/after maturity (timestamp-only, no privileged bypass live) | any holder, self only |
| Upgrade any live FXB/auction/factory | none exists — all direct immutable deployments, no proxy slots | nobody |
| Mint/burn of live FRAX | FRAX `pool_mint`/`pool_burn_from`, pool-gated (FRAX contract, out of scope) | FRAX pools, not the FXB system |

No inheritor overrides `transferTimelock`/`acceptTransferTimelock`/`renounceTimelock`, and no
inheritor calls the internal `_transferTimelock`/`_setTimelock`/`_acceptTransferTimelock`
setters directly (verified by grep) — role mutation happens only through the three gated
externals. No storage collision between `Timelock2Step` (slots 0–1) and `OperatorRole2Step`
(slots 2–3) in FxbAMO (live slot reads consistent).

---

## 4. FRAX / frxUSD boundary — checked

- **Live FRAX is NOT an instance of any assigned file.** Verified source (Sourcify bundle
  `1_0x853d955a…`): contract `FRAXStablecoin`, Solidity 0.6.11, OZ-style ERC20, 18 decimals,
  `pool_mint`/`pool_burn_from` gated by `onlyPools`. No `permit`, no blocklist, no transfer
  pause, no `timelockAddress`/`owner`-gated transfer path. None of the three assigned files
  calls FRAX or depends on FRAX decimals, return values, permit behavior, or pausability:
  Timelock2Step and OwnedV2 are pure `msg.sender` role checks with no external calls, and
  `ERC20PermitPermissionedOptiMintable` is itself a token template, not a FRAX consumer.
- **frxUSD flows are Fraxtal-side.** No mainnet FXB/auction references frxUSD (Phase 0 §6.4;
  the Fraxtal frxUSD proxy `0xFc…0001` has no code on mainnet). The Fraxtal frxUSD address
  resolves in Sourcify to a `TransparentUpgradeableProxy` (implementation not identified in
  the available bundle); the LFRAX implementation/proxy and Fraxtal factory bundles contain
  no sources, so **no live instance of `ERC20PermitPermissionedOptiMintable` or `OwnedV2` is
  confirmed on any chain from the available evidence** — the upgrade scripts merely *cast*
  the LFRAX addresses to that type, which proves nothing about deployed bytecode. The
  sub-bar conclusion for both HEAD files therefore does not depend on resolving the Fraxtal
  question, but see U-D-2.
- **Permit note:** `ERC20PermitPermissionedOptiMintable` inherits OZ `ERC20Permit` with no
  custom permit logic; no role change is reachable via `permit` (it only sets allowances).
  Live FRAX has no `permit` at all, so no permit-based interaction with the live system
  exists. `FXB_LFRAX.initialize`'s one-shot frxUSD `burn(balanceOf(this))` calls the
  single-argument OZ `ERC20Burnable.burn` (self-burn), distinct from the bridge-only
  two-argument `burn(address,uint256)` — no selector/role confusion; the burn itself is
  EX-F14 intended behavior.

---

## 5. Unresolved cross-references

- **U-D-1 — Direct-deployed v1 contracts:** factory registries + nonce + storage prove exactly
  5 factory-created FXBs and 5 factory-created auctions, but cannot rule out contracts
  deployed directly via the v1 constructors bypassing the factories (Phase 0 residual
  limitation; `eth_getLogs` unavailable on both RPCs). If such a contract existed with a
  different timelock, the role graph would differ. No evidence of any was found; D cannot
  close this — it needs the owed creation-event / bytecode-similarity follow-ups.
- **U-D-2 — Fraxtal live state:** factory role interface (R-D-1), LFRAX implementation
  identity, and frxUSD implementation are unverified (Sourcify bundles lack sources; Fraxtal
  inventory owed). Blocks any Fraxtal-side conclusion; does not affect the mainnet result.
- **U-D-3 — Safe internals:** fallback-handler identity and pending Safe transactions (Phase 0
  owed follow-up #5) were not re-verified. Not needed for D's conclusions: assigned files
  interact with the Safe only through `msg.sender` equality.
- **U-D-4 — Off-chain consumers of `SlippageAuctionFactory.isAuction`:** no on-chain consumer
  exists (R-D-3); whether any frontend/indexer treats registry membership as endorsement is
  unknown and outside code-audit evidence.

---

## 6. Files scanned / skipped, exclusions applied

**Assigned files — all read in full (3/3, none skipped):**

1. `work/v1-live/lib/frax-standard-solidity/src/access-control/v2/Timelock2Step.sol` (163 lines)
2. `repos/frax-bonds/src/contracts/OwnedV2.sol` (41 lines)
3. `repos/frax-bonds/src/contracts/ERC20PermitPermissionedOptiMintable.sol` (249 lines)

**Evidence read (no findings reported in these):** v1 `FXB.sol`, v1 `FXBFactory.sol`,
v1 `SlippageAuction.sol` (both trees — identical except provenance header),
`SlippageAuctionFactory.sol`, `FxbAMO.sol` (evidence-only, full read),
`Operator2Step.sol` + `OperatorRole.sol` (via AMO Sourcify bundle),
`IERC20PermitPermissionedOptiMintable.sol`, HEAD `FXB.sol`/`FXBFactory.sol`/`FXB_LFRAX.sol`
(role-relevant excerpts + greps), live FRAX verified source (ERC20 transfer logic, ABI,
pause/blocklist/permit greps), `ONCHAIN-GROUNDWORK-FXB.md` + `fxb-addresses.json` (full),
`EXCLUSION_LIST_FXB.md` (full, 16 items).

**Tests (intended behavior only):** searched all of `repos/frax-bonds/src/test/` and
`src/script/` — **no test or script exercises** `transferTimelock`, `acceptTransfer*`,
`renounce*`, `nominateNewOwner`, `acceptOwnership`, `addMinter`/`removeMinter`, `setTimelock`,
or `transferOperator`; role-transfer intended behavior rests on natspec + code only.
`FXBFactoryTest` creation-gating lines read; no role test was skipped unknowingly.

**Skipped:** nothing assigned was skipped. HEAD-lib `Timelock2Step` copies were diffed, not
separately hunted (identical modulo a parameter name). Fraxtal contracts were not hunted
(out of mainnet scope; see U-D-2). FxbAMO was used as evidence only, per scope — no finding
in it is reported.

**Exclusions applied:** EX-F12 (admin upgrade/early-burn intended — NQ-D-3, NQ-D-6, NQ-D-14),
EX-F11 (OptimismMintable boundary — noted for NQ-D-8), EX-F13/EX-F14 (intended mint/burn
semantics — §4). No Hunter candidate matched any other EX-F item. Distinctions cited where
a relay touches an excluded mechanism (R-D-1 vs EX-F12: interface mismatch is a distinct
mechanism from intended admin power; R-D-2 vs EX-F01: return-value handling is distinct
from stuck-token recovery).

**Methods:** static source reads + targeted greps + Sourcify-bundle source extraction
(local files only) + read-only mainnet `eth_call`/storage reads. No Foundry/`cast`
verification was performed or claimed; no fork PoC was built because no qualifying
candidate survived triage (a PoC for a killed observation would demonstrate nothing).
Confidence in the zero-finding result is high for the assigned files' own logic (complete
reads, every external function traced, live role state re-verified); it is bounded by
U-D-1/U-D-2 for any claim about contracts outside the verified live set.
