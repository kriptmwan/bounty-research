# Recon — Relay periphery (Router 3.2 / ApprovalProxy 3.1 / Receiver)

Read-only enrichment pass. No findings, no suspicions. All statements are
verified context from the pinned source; intended behavior is reported as
stated in NatSpec, deploy notes, or the HEAD commit message.

- Target: `~/workspace/relay-audit/repos/relay-periphery`, HEAD
  `e221935f54df03f9f73f2645ff688370a87033d8` ("fix: sweep ERC20 residue …
  (DEC-2400) (#77)", 2026-11-09). Tree clean at read time.
- Scope: `src/` only, 10 files, 2,004 LOC, read in full in triage scan order.
- Triage: `artifacts/triage.json` was usable (riskMap + 10-file assigned list
  + scan order present). Its critical/high/medium arrays were copied
  unchanged into `recon.json`; its `contextOnly` directories were mapped to
  `contextOnly`.
- Context-only reads (not report scope): `README.md`,
  `deployments/v3/instructions.md`, `foundry.toml`, `remappings.txt`,
  `script/receiver/ReceiverDeployer.s.sol`, test file names plus
  `RouterAndApprovalTest.sol`, `SolverCallExecutedHashTest.sol`, and
  `ApprovalProxyResidueCleanupTest.sol` (skimmed), and the HEAD commit diff.
- Machine-readable companion: `artifacts/recon.json` (86 file:line notes).
  This document is derived from it.

## 1. Tech stack

- **Toolchain:** Foundry. Default profile: solc 0.8.28, EVM Cancun,
  `via_ir = true`, optimizer on, **1,000,000 runs** (first used for 3.2;
  3.0/3.1 used the 200-run default). `bytecode_hash = "none"`,
  `cbor_metadata = false`. Compiler settings are part of creationCode and
  hence of every CREATE2 address, so they are frozen per version.
- **Profiles:** `london` (EVM London, no transient storage) for the
  NonTstore build; `receiver` (200 runs) so `RelayReceiver` CREATE2
  addresses stay stable across chains.
- **Pragmas:** proxy `^0.8.23`; both routers `^0.8.25`; `Multicall3`
  `^0.8.12`; Permits / IERC3009 / IRelayRouter / RelayReceiver `^0.8.23`.
- **Libraries used in src/:** OpenZeppelin (IERC20, SafeERC20, IERC721,
  IERC1155); Solady (Ownable, EIP712, SignatureCheckerLib,
  SafeTransferLib); permit2-relay (IPermit2, ISignatureTransfer
  interfaces); trustlessPermit (TrustlessPermit). **0x-settler** is a
  declared dependency but is referenced only in tests, never in `src/`.
- **EVM features:** transient storage (EIP-1153, `tload`/`tstore`) is used
  only by the `ReentrancyGuardMsgSender` guard in the Cancun `RelayRouter`.
  The NFT recipient slot uses plain `sstore`/`sload` in **both** router
  variants.
- **Versions:** Router `VERSION = "3.2"` (both variants); ApprovalProxy
  `VERSION = "3.1"`. The proxy version string doubles as the EIP-712 domain
  version for multicall authorizations and moves only when the proxy itself
  changes.

## 2. Architecture

```text
                    ┌─────────────────────┐
  end user / relayer│  RelayApprovalProxy │  (Ownable + EIP712, v3.1)
  ─────────────────►│  4 entrypoints:     │
   (signatures,     │   transferAndMulticall (plain approval)
    approvals,      │   permitTransferAndMulticall (EIP-2612)
    native value)   │   permit2TransferAndMulticall (Permit2 + witness)
                    │   permit3009TransferAndMulticall (EIP-3009 + auth sig)
                    └──────────┬──────────┘
         pulls user ERC20s ────┘  (transferFrom / Permit2 / receiveWithAuthorization)
                               │  tokens land on the router
                               ▼
                    ┌─────────────────────┐
  anyone / solver ─►│  RelayRouter 3.2    │  (Multicall3 + msg.sender guard)
  ─────────────────►│  RelayRouter_NonTstore (same logic, sstore guard)
                    │  multicall + 4 cleanup* entrypoints, permissionless
                    └──────────┬──────────┘
                               │  arbitrary calls, router is msg.sender
                               ▼
              ┌────────────────────────────────────────┐
              │  caller-chosen targets: DEXes, depositories,
              │  NFT contracts, etc. (composed off-chain)
              └────────────────────────────────────────┘
                               │  SolverCallExecuted(to, dataHash, amount)
                               ▼
                    off-chain oracle (verifySolverCalls) — out of scope

  ┌────────────────────┐   native in   ┌──────────────────┐
  │ anyone (fallback / │──────────────►│  RelayReceiver   │──► SOLVER (immutable)
  │ forward)           │  FundsForwardedWithData         │  makeCalls: solver-only
  └────────────────────┘               └──────────────────┘  arbitrary calls
  Standalone contract: imports nothing, references neither router nor proxy.
```

- **Proxy → router call flow:** the proxy moves tokens to the router, then
  calls `IRelayRouter.multicall{calls, refundTo, nftRecipient, metadata}`
  with `msg.value`, then sweeps residue back (see §5). The interface
  exposes only `multicall`, `cleanupErc20s`, `cleanupNative` — the
  `*ViaCall` cleanup variants are not reachable through it.
- **Router → world:** `Multicall3._aggregate3Value` executes the
  caller-supplied `Call3Value[]` in order with the router as `msg.sender`.
  Call targets are entirely caller-chosen; nothing in `src/` names a
  depository, hub, oracle, allocator, or settlement contract. The
  periphery's connection to the settlement layer is off-chain: the oracle
  consumes `SolverCallExecuted` events, and `metadata` bytes plus
  `FundsMovement` events correlate flows off-chain.
- **Receiver model:** deployed via CREATE2 (fixed salt, `SOLVER` env
  address) by `script/receiver/ReceiverDeployer.s.sol`. It is a dumb
  forwarder: any native value sent to it is immediately forwarded to the
  immutable solver address, and only the solver can execute `makeCalls`.

## 3. Entry-point table

### RelayApprovalProxy (all `external payable` unless noted)

| Function | Expected caller | Signer vs caller vs recipient |
|---|---|---|
| `withdraw(token, recipient)` | Owner only (`onlyOwner`) | Rescue: full balance of `token` (or native) to explicit recipient; recipient must not be zero or the proxy itself |
| `transferAndMulticall` | End user (token owner) | Caller = token owner; pulls via `transferFrom(msg.sender → router)` under a plain ERC20 approval |
| `permitTransferAndMulticall` | End user | Requires `permit.owner == msg.sender`; EIP-2612 permit names the proxy as spender; `trustlessPermit` tolerates a frontrun permit |
| `permit2TransferAndMulticall` | Relayer (caller) on behalf of `user` | Signer = `user` (Permit2 signature); caller = relayer, bound by the witness (relayer, msgValue, refundTo, nftRecipient, metadata, calls); empty signature = multicall-only, no token movement |
| `permit3009TransferAndMulticall` | Relayer (caller) | Signer = `permit.from` per permit; each permit needs its own EIP-712 `MulticallAuthorization` signature binding from/relayer/msgValue/refundTo/nftRecipient/metadata/fundingIndex/calls/funding; the authorization digest is reused as the ERC3009 nonce |
| `receive()` | Anyone sending native | Emits `FundsMovement` for positive value |

All four multicall entrypoints require `refundTo != address(0)`.

### RelayRouter / RelayRouter_NonTstore (all `public`, `nonReentrant`, no caller restriction)

| Function | Expected caller | Notes |
|---|---|---|
| `multicall(calls, refundTo, nftRecipient, metadata)` (payable) | Anyone: end user, solver, relayer, or the proxy | Executes calls, then refunds full leftover native balance via `cleanupNative(0, refundTo, metadata)` |
| `cleanupErc20s` | Anyone (permissionless by design) | Amount 0 = full router balance per token; recipients caller-chosen |
| `cleanupErc20sViaCall` | Anyone (permissionless by design) | Approves each target, calls it, emits only the balance delta consumed; no metadata arg (empty metadata in event) |
| `cleanupNative` | Anyone (permissionless by design) | Amount 0 = full balance; recipient `address(0)` = `msg.sender` |
| `cleanupNativeViaCall` | Anyone (permissionless by design) | Forwards native value with the call; no `SolverNativeTransfer` event |
| `onERC721Received` / `onERC1155Received` / `onERC1155BatchReceived` | Token contracts (NFT callbacks) | No `nonReentrant` modifier; forward received NFTs to the recipient slot (see §6) |
| `receive()` | Anyone sending native | Emits `SolverNativeTransfer` |

The router has **no owner/admin role** and no other access control besides
the reentrancy guard.

### RelayReceiver

| Function | Expected caller | Notes |
|---|---|---|
| `fallback()` (payable) | Anyone | Forwards `msg.value` to `SOLVER`; emits `FundsForwardedWithData(msg.data)` |
| `forward(data)` (payable) | Anyone | Same, with caller-supplied `data` in the event |
| `makeCalls(calls)` (payable) | `SOLVER` only | Executes arbitrary calls in order; first failure reverts the whole batch |

## 4. Trust-boundary table

| Boundary | Statement (as documented in code / deploy notes) |
|---|---|
| Router statelessness | NatSpec: the router "holds no ETH or ERC20 balances at rest by design — every inflow is consumed and forwarded within the same transaction." |
| Permissionless cleanups | NatSpec threat model: "`cleanup*` functions are intentionally permissionless (they sweep stranded dust; there is nothing to steal in normal operation)" and "residual funds are out of scope." |
| Self-call bypass | NatSpec: "`msg.sender == address(this)` bypassing the reentrancy guard is intentional to support self-calls inside a multicall." |
| Hook-registry guard | `_revertIfHookRegistry` blocks calls to the ERC1820/ERC820 registries from `_aggregate3Value` and both `*ViaCall` cleanups, ignoring `allowFailure`. Rationale (NatSpec): the router is `msg.sender` for its calls, so a registry call would set the router's own ERC777 hooks, which would then run inside transfers while it holds in-flight funds, or hand entries to a new manager. The router needs no hook: ERC777 tokens move through it with `transfer`/`transferFrom`. |
| Zero-target guard | A zero-address call target reverts `InvalidTarget` regardless of `allowFailure`: a CALL to address(0) returns success and burns forwarded value, and the event would report the burn as success. |
| Solver-call attestation | `SolverCallExecuted(to, dataHash, amount)` is emitted once per **successful** call, in call order, after the call returns; nested multicalls emit before the enclosing call's event. `dataHash = keccak256(callData)` (Router 3.2 change; previously the calldata itself). The oracle's `verifySolverCalls` checks the hash against the calldata it holds from the signed order, and per the deploy notes must decode both event shapes before any 3.2 router takes fills. Failed calls emit nothing. |
| Permit2 witness | The relayer witness binds relayer address, `msg.value`, refundTo, nftRecipient, metadata, and the calls hash, so (per NatSpec) "the relayer cannot under-fund calls that carry a value and rely on `allowFailure` to swallow the shortfall." |
| 3009 authorization | The `MulticallAuthorization` digest is used as the ERC3009 nonce, "cryptographically binding the complete ordered funding batch to the displayed call targets, values, data, and other execution parameters" (NatSpec). |
| 2612 nonce | `Permit2612` has no nonce field by design: the nonce is derived on-chain from the token's `nonces(owner)`. |
| Owner powers | The proxy owner can only `withdraw` full balances to an explicit recipient. There is no pause, no fee setter, no router/permit2 rotation (immutables), and no other privileged function anywhere in `src/`. |
| Permit2 address | Constructor arg, immutable. Canonical default `0x000000000022d473030f116ddee9f6b43ac78ba3`; deploy notes say to use a different address where it is not deployed. Canonical proxy owner `0x463cB782c8dd0a1887b77336DfF74D60F006F56E` is pinned for CREATE2 address stability. |
| Fees | **No fee logic exists in `src/`** — no fee/bps/treasury accounting. The only fee references are fee-on-transfer token handling (balance-delta accounting in `_handlePermit3009`) and a treasury mention in `withdraw` NatSpec. |

## 5. State, residue, and error boundaries

- **Where funds/allowances are written:** the proxy pulls tokens to the
  router (never holding them except transiently in the 3009 path, where
  tokens land on the proxy and are immediately forwarded). The router
  holds funds only mid-transaction. Allowances are written only in
  `cleanupErc20sViaCall` (`safeApproveWithRetry`, USDT-tolerant) and via
  token permits/Permit2 approvals granted by users off-chain.
- **Residue / cleanup flows:**
  - `multicall` always ends with `cleanupNative(0, refundTo, metadata)` —
    full native refund.
  - The proxy's `_cleanupErc20s` calls router `cleanupErc20s` with all
    recipients = `refundTo` and all amounts = 0 (full balances), for
    **exactly the listed tokens**. Swap outputs or other unlisted ERC20s
    left on the router are not swept by the proxy; callers must include
    their own `cleanupErc20s` call (per NatSpec).
  - Sweep matrix: `transferAndMulticall` sweeps ERC20s only (native is
    already refunded by the router); the three permit entrypoints sweep
    ERC20s plus an explicit `cleanupNative`; the Permit2 path skips the
    ERC20 sweep when the signature is empty (nothing was transferred).
- **DEC-2400 HEAD fix (commit `e221935`):** the only `src/` code change is
  one added line — `_cleanupErc20s(tokens, refundTo, metadata)` at the end
  of `transferAndMulticall` — plus NatSpec clarifying that `refundTo`
  receives leftover tokens as well as native value and that only listed
  tokens are swept. The commit message states the prior behavior left
  residue on the router claimable via the permissionless cleanups, citing
  SEC-460 (USDT leftovers swept by outside addresses). Interim ideas in
  the same commit (a Permit2 empty-signature sweep branch, a redundant
  `cleanupNative`, a VERSION bump to 3.2) were all reverted before merge;
  VERSION stayed at 3.1. New fork-free tests in
  `ApprovalProxyResidueCleanupTest.sol` cover the sweep behavior.
- **Failure propagation:** in `_aggregate3Value`, a failed call with
  `allowFailure = false` bubbles the revert data and reverts everything;
  with `allowFailure = true` the failure is recorded in `Result` and
  execution continues. The zero-target and hook-registry reverts ignore
  `allowFailure`. Both `*ViaCall` cleanups revert `CallFailed` on target
  failure (no `allowFailure` parameter). `makeCalls` reverts `CallFailed`
  on the first failed call.
- **Events as the settlement interface:** `FundsMovement` (proxy + router)
  and `SolverNativeTransfer` (router) record explicit fund movements with
  `metadata` for off-chain correlation. `cleanupErc20sViaCall` documents
  that its event `to` is the approved spender, not necessarily the final
  recipient, which the router cannot observe.

## 6. Concurrency / reentrancy

- **Both guards key on `msg.sender`, not on a boolean.** The outermost
  caller is stored in the guard slot; while set, a *different* sender
  reverts with `InvalidMsgSender`, while the stored sender and
  `address(this)` may re-enter. Only the outermost frame acquires and
  clears the slot; nested allowed frames neither overwrite nor clear it.
- **Transient vs persistent:** `RelayRouter` uses the `tload`/`tstore`
  guard (Cancun); `RelayRouter_NonTstore` uses the identical logic with
  `sload`/`sstore` (London/pre-Cancun chains). The two guard files differ
  only in the load/store opcodes and the contract name. The two router
  files differ only in the guard import and contract name — verified by
  diff.
- **NFT recipient slot:** persistent `sstore` in both variants at
  `keccak256("RelayRouter.recipient") - 1`. `multicall` sets it only when
  `nftRecipient != 0`; only the frame that set it clears it; a nested
  frame requesting a *different* recipient reverts `RecipientAlreadySet`,
  while the same recipient is accepted. The three NFT callbacks read the
  slot, revert `NoRecipientSet` when unset, and forward the received
  tokens to the recipient through the calling token contract. Per NatSpec,
  direct `safeTransferFrom` transfers to the router therefore revert
  unless part of a multicall that set the recipient.
- **Receiver send cap:** `RelayReceiver.send` caps the forwarding call at
  100,000 gas. The proxy's `_send` (withdraw-only) forwards all gas, per
  its comment, so multisig/smart-wallet recipients are not stranded.

## 7. Cross-contract edges (summary)

- Proxy → router: `multicall`, `cleanupErc20s`, `cleanupNative` via
  `IRelayRouter`; proxy → Permit2: `permitWitnessTransferFrom`;
  proxy → tokens: `permit` (via trustlessPermit), `transferFrom`,
  `receiveWithAuthorization`.
- Router → arbitrary targets: `_aggregate3Value` calls, `*ViaCall`
  cleanups, NFT forwarding callbacks, `safeTransferETH`.
- Receiver → solver: native forwarding; solver → arbitrary targets via
  `makeCalls`. No code-level link between receiver and router/proxy.
- Off-chain edges (context only, out of scope): oracle `verifySolverCalls`
  consuming `SolverCallExecuted`; solver registry expecting the 3.2
  CREATE2 addresses; depository/settlement contracts reached only as
  caller-chosen multicall targets composed off-chain.

## 8. Unresolved boundaries

These could **not** be determined from the code and deploy notes in this
repo:

1. **Oracle expectations:** `verifySolverCalls` semantics beyond the
   event-shape note (order matching, call-order checks) — the oracle
   service lives in `relay-protocol-oracle`, out of scope.
2. **Metadata format:** the contents of the opaque `metadata` bytes and
   who composes multicall calldata (SDK / relayer / solver) are not
   specified in `src/` or the deploy notes.
3. **Deployed-bytecode equivalence:** whether on-chain bytecode matches
   this pinned source on each chain (200-run 3.0/3.1 vs 1M-run 3.2 builds,
   NonTstore variants) was not verified in this read-only pass; SCOPE.md
   §2 records it as unverified.
4. **vigil PRECON-012:** referenced in the router threat-model NatSpec but
   not present in this repo; its exact statement could not be read here.
5. **Deployment-specific config:** Permit2 addresses on chains lacking the
   canonical deployment, and key management behind the canonical proxy
   owner address, are not determinable from `src/`.
6. **Off-chain oracle/signer trust assumptions:** how the oracle attests
   fills and who operates solvers/relayers is outside this codebase.

## 9. Tests skimmed (context only)

- `RouterAndApprovalTest.sol` (fork tests): Permit2 witness binding
  (refundTo/nftRecipient tamper), EIP-2612 frontrun tolerance, 3009
  msgValue binding and fee-on-transfer forwarding, NFT recipient
  callbacks, USDT cleanup, phantom-`FundsMovement` checks.
- `SolverCallExecutedHashTest.sol`: hash emission per call in order, empty
  calldata, no event on failed calls, both router variants.
- `ApprovalProxyResidueCleanupTest.sol`: DEC-2400 sweep behavior for
  `transferAndMulticall` (unspent tokens/native to `refundTo`, only
  transferred tokens swept, no-op when fully consumed).
- Other suites present: `MulticallZeroTargetTest`,
  `ReentrancyGuardMsgSenderVIG084Test`, `RelayRouterRecipientSlotTest`,
  `RelayRouterResidualFundsTest`, `RelayRouterUsdtCleanupTest`,
  `RouterHookRegistryTest`, `RouterProxyHardeningTest`.
