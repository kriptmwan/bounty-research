# XE node audit — `xeprotocol/xe` (Go node) — 2026-11-12

**Auditor role:** subagent, AUDIT ONLY (find, verify, dedup, draft). Nothing was filed,
no login was performed, no live testnet interaction occurred beyond public read-only
reads (GitHub repo + the desk's public `/v1/tickets` API at normal rate).

## Verdict

**Surviving novel candidates: NONE.**

Five code-confirmed flaws were found across two passes. Every one of them is already
filed on the public desk, verified by reading the matching tickets' full texts via the
live desk API. Under the coordinator's filing bar (surviving list = only code-confirmed,
dedup-checked, MEDIUM-or-higher confidence findings), the surviving list is empty.
Nothing in this report is filing-ready, and no draft bounty text is included, because
filing any of these would be a re-report.

There are no Critical/Severe flags to raise: the two remote-crash flaws found (which
would otherwise have been Severe, PRIVATE-FORM-ONLY) are already public tickets
(XE-0096, XE-2634 and others).

## Commit audited

- Repo: `https://github.com/xeprotocol/xe`
- Checkout: shallow clone (`--depth 1`) at `~/workspace/xe-desk-audit/xe/`
- **HEAD: `89a542ea51d38375299aee54c6c99102e9bfa666`**
- Date: 2026-11-10 11:29:08 +0200, branch master
- Message: "release: testnet-0005 quorum withhold fix"
- Size: 99 Go files, ~29,513 lines. Module `github.com/xeprotocol/xe`, Go 1.25.0,
  libp2p + BadgerDB.

## Repo overview

Lattice ledger: per-account signed chains, send+receive pairs, no mempool, no miners,
zero fees. Finality via representative voting: converge, commit-lock, irrevocable final
vote at ≥67% of delegated weight. Two assets, 6 decimals, micro-units: XE (native, vote
weight, lease emission) and XUSD (permissioned mint by `sys.minter`, none deployed).
Network `testnet-0005`; ledger genesis hash
`3ff640410d7879821b544d09545dcfb8e96fe4fc717634e8bff4e53cacd1e150`, statechain genesis
hash `d01aabc1a29dc64bc6bbc30031a716cd2e0ceb867e5479953cd5ad22c8f296d6`.

Key defaults observed: `DefaultDifficulty = 0xfffff80000000000` (PoW pass probability
~1/2048, trivially solvable); block timestamp window 1 hour; vote window 5 minutes;
max gossip message 256 KiB; API/UI bind loopback by default; SSH gateway opt-in on
0.0.0.0.

## Audit passes

**First pass (breadth):** whole tree explored (README/docs, module layout), then
priority areas: consensus (quorum, vote, finalization, conflict, rollback,
attestation), networking (gossip, gossip validation/scoring, msg, netcheck, sync,
blocksync, votesync, host, discovery, tunnel), ledger (all 3,093 lines), node
(handleIncoming/votes, pull functions, marketplace/auto-accept/settle loops, tunnel,
attestation, certset, VM, policy, SSH gateway), directory, chat envelope, perf
certificates, API handlers, statechain (chain, types, kvstore, crypto, encoding,
sync), CLI wallet/send/receive/faucet/mint/burn/node sections, VM managers.

**Second pass (depth, per priority update):** re-examined all six priority areas —
consensus, networking/peer handling, mempool (this design has no mempool; stated
explicitly — there is no pending-transaction pool, blocks go straight to the ledger
via gossip/sync/API), RPC surface, wallet/crypto, genesis/config. Chased every
near-miss: systematic grep sweep of ALL `[:N]` slice expressions in the tree;
re-verified the certificate-hash slice, force-settle/renewal accounting, lease_cancel
accounting, cancel-wins-over-accept reachability, archive divergence, statechain sync
loop, `UnmarshalBlock`/`DecodeVote` bounds, `lowestHash` callers, `extractED25519Key`,
`shortHash`/`shortAddr` helpers, genesis anchoring on both chains (ledger + statechain),
and sibling guards (statechain `verifyMultisig` uses guarded `shortKey`; `vm_credentials`
checks sender peer while `ValidateTunnelLease` does not). Read the remaining files:
`net/banstore.go`, `ratelimit.go`, `features.go`, `dht.go`, `certsync.go`;
`node/observability.go`, `perf.go`, `activations.go`, `lease_renew.go`, `certset.go`,
`policy.go`, `vm.go`, node.go lines 556–705 and 2042–2510; `core/supply.go`,
`reputation.go`, `cascade_commit.go`, `store.go`, `activations.go`, `retryable.go`,
`genesis.go`, `multisig.go`, `lease_renew.go`; `statechain/activations.go`,
`genesis.go`, `store.go`, `sync.go`; `chat/chat.go`; `client/client.go`, `client/chat.go`;
`cmd/xe` lease/chat paths; `store` interfaces; `directory/*`; `vm/dev_target.go`,
`vfio.go`; `genesis/testnet-0005/*`.

## Surviving novel candidates

None. See "Duplicates found" for the five code-confirmed flaws and their existing
tickets, and "Near-misses rejected" for items that did not survive code analysis.

## Duplicates found (code-confirmed, already filed — DO NOT RE-REPORT)

Each item below was independently code-confirmed in this audit (file:line + static
trace) and then matched to an existing public ticket by reading the ticket's full
text via `https://bounty.xe.network/v1/tickets/<id>`. Dedup queries used:
`panic`, `multisig`, `directory`, `NodePeer`, `tunnel`, `ValidateTunnelLease`,
`force-settle`, `force_settle`, `renew`, `RequestLease`, `offer`, `marketplace`,
`crash`, `slice` (via read-only `curl` GET of the public JSON endpoint, normal rate,
plus title scans of all returned tickets).

### D1. Multisig short-pubkey panic → remote node crash

- Code: `core/multisig.go:94,99,103` (`VerifyMultisig`) formats `pk[:12]` where `pk`
  is the attacker-controlled `Signatures[].PublicKey`, with no length check. A pubkey
  shorter than 12 chars panics (slice out of range). Reachability: attacker crafts a
  `multisig_open` block (a spending op, `IsSpendingOp`, so `VerifyMultisig` — not
  `VerifyMultisigAny` — is called) with a well-formed keyset, `Signature` = 128 junk
  hex chars (passes the gossip pre-filter, `net/gossip.go:152`), `Signatures =
  [{PublicKey:"ab",...}]`. `HashBlock` does not cover `Signature`/`Signatures`, so the
  hash/PoW gossip validation passes; `VerifyBlock` returns nil early for multisig
  blocks (`core/crypto.go:158-160`); `AddBlock` → `verifyBlockCredential`
  (`core/ledger.go:1416+`, called before type dispatch) → panic. Crash paths have no
  `recover`: gossip `handleIncoming` (`node/node.go:705-711`), ledger sync
  `requestSync`, `PullBlocks` ingest. Only two `recover()` calls exist in the whole
  tree (`net/msg.go:71`, `node/observability.go:187`), neither guarding these paths.
  The block is never persisted, so re-gossip re-crashes restarted nodes.
- Would-have-been severity: Severe (unauthenticated, network-wide, repeatable node
  crash), PRIVATE-FORM-ONLY — moot, already public.
- Existing tickets: **XE-0096** (triaging, claimed high, GitHub issue #160 —
  identical flaw, same lines, same trace; its body notes the gossip/sync path
  distinction), **XE-8693**, **XE-9384** (same flaw, short pubkey / malformed
  `signatures[].public_key`).

### D2. Directory registration short-`NodePeer` panic → remote node crash

- Code: `node/node.go:2381` in `handleDirectoryGossip`:
  `logging.Debugf(..., reg.NodePeer[:12])`. Go evaluates arguments eagerly, so this
  panics even with debug logging off; the goroutine has no `recover`.
  `directory/verify.go` (`VerifyRegistration`) requires only `NodePeer != ""` plus a
  valid self-signature, so an attacker signs their own registration with
  `NodePeer="x"`; the directory gossip validator (`net/gossip_validate.go:143-158`)
  accepts it and it is relayed to all nodes; `Directory.Register`
  (`directory/directory.go:35`) performs no peer-ID/length validation; the directory
  Subscribe pre-filter (`net/gossip.go:428+`) checks only Account/Signature non-empty.
- Would-have-been severity: Severe (same class as D1), PRIVATE-FORM-ONLY — moot,
  already public.
- Existing tickets: **XE-2634** (identical flaw, same line, 1-byte NodePeer PoC),
  **XE-3392**, **XE-0136**, **XE-5650**, and **XE-5867** (whose body is entirely this
  directory-panic report despite a mismatched lease_cancel title — see D5 note).

### D3. `ValidateTunnelLease` ignores the peer argument — any peer can open a tunnel to any active lease's VM SSH port

- Code: `node/node.go:2176-2188` checks only lease existence, `LeaseAccepted` state,
  and that this node is the provider; the `peerID` parameter is unused, although the
  tunnel interface (`net/tunnel.go:25,83`) passes `RemotePeer` precisely for this
  check, and the sibling `vm_credentials` handler (`node/vm.go:15-35`) DOES check the
  sender peer (`providerPeer != from` → unauthorized). No per-peer/per-lease tunnel
  cap; the registry grows unboundedly. Mitigation noted in analysis: both VM types are
  key-only SSH (Lima template `PasswordAuthentication no`; QEMU cloud-init
  `ssh_pwauth: false`), so no direct takeover without the consumer's SSH key; impact
  is unauthenticated exposure of the VM SSH surface plus unbounded tunnels.
- Would-have-been severity: Medium at most.
- Existing ticket: **XE-0015** (status: fixing, claimed severe), Finding #2:
  "Unauthenticated P2P `/xe/tunnel/2.0.0` hijacking (`ValidateTunnelLease` ignores
  `peerID`) and post-expiry VM tunnel/SSH access". Adjacent: XE-4941 (tunnels not
  closed on lease abort/force-settle).

### D4. Force-settle after renewal always fails — node's own block builder uses base cost while the ledger requires the whole topped-up escrow

- Code: validation (`core/ledger.go:1971-1978`, `validateAndAddLeaseForceSettle`)
  requires `Balance = oldBal + pending.Amount`, where the pending escrow is topped up
  by every renewal (`core/lease_renew.go:137-138`, `TopUpPendingAmount`; applied in
  `store/mem_store.go:338-345` / `store/badger_store.go:866-867`). Renewal never
  updates `lease.Cost` (`core/lease_renew.go:140-151` only appends a `LeaseSegment`).
  Construction (`node/node.go:1930-1940`, `forceSettleLease`) builds
  `Balance = oldXUSD + lease.Cost` (base only). After any renewal, every force-settle
  block the node produces is rejected with "balance mismatch"; the settle loop logs
  and retries forever; the escrow survives until `LeaseEscrowExpiry` (365 days) and is
  then deleted by `archiveExpiredLease`. A manually constructed block with the correct
  balance would validate — the defect is in the node's automation, not the ledger rule.
- Would-have-been severity: Minor (functional, funds-locked-via-automation, manual
  workaround exists).
- Existing tickets: **XE-0102** (triaging, claimed high — identical flaw, same lines,
  same trace, including the renewal/escrow arithmetic and the archive consequence),
  and **XE-0015** Finding #3 (same force-settle/renewal accounting flaw).

### D5. `RequestLease` accepts the first offer with zero validation — no dimension, price, or certificate check

- Code: `node/node.go:2042-2081` (`RequestLease`) takes the first offer stored under
  its `RequestID` with no verification that the offer's VCPUs/memory/disk match the
  request, that `TotalCost` matches `LeaseCost` for those dimensions and the pinned
  certificate's multiplier, or that the certificate belongs to the offering provider.
  A racing attacker offer (smaller VM and/or up to 10x price via a self-issued
  high-multiplier certificate, `PriceMultiplierMax = 10000`) is signed into a lease
  block by `RequestAndCreateLease`/`CreateLeaseBlock` without any check. (The CLI
  lease path computes cost itself from the provider's cert and is not affected; only
  the admin-API `/lease/request` path uses `RequestLease`.)
- Would-have-been severity: Medium.
- Existing tickets: **XE-7695** (identical flaw, same "no dimension, price, or
  certificate check" wording), adjacent **XE-0106** (offer-store flood / last-wins
  overwrite diverting lease creation).

### Related already-filed items noted during dedup (not independent findings here)

- **XE-0067** (accepted) + **XE-5859**: lease_cancel after renewal refunds only the
  base cost while deleting the whole escrow. Independently verified in this audit:
  `core/ledger.go:1852-1863` refunds `oldBal + leaseBlock.Amount` and deletes the full
  pending escrow; reachable for a renewed lease via cancel-wins-over-accept
  (`resolveCancelWinsOverAccept`, `core/ledger.go:1749+`) when the accept is the
  provider chain tip and unfinalized. Not filed here — already accepted.
- **XE-0623** (triaging): `CertificateHash[:12]` at `core/ledger.go:1692`. See
  near-miss N1 — analyzed as not reachable; already filed regardless.
- **XE-0015** Finding #1: unauthenticated `vm_status` credential disclosure. Covers
  the `vm_status` near-miss (N4).
- **XE-0015** Finding #4, **XE-3058**, **XE-5926**, **XE-2614**: multi-asset
  accounting and `IsSpendingOp` omissions (lease types needing only 1-of-N multisig
  signatures). Noticed in passing during dedup; not independently developed here.
- **XE-4827**: statechain sync empty-page loop (near-miss N5). **XE-0480**: chat
  envelope cross-network replay (near-miss N6). **XE-9746**: `archiveExpiredLease`
  destroying renewal top-ups (near-miss N7). **XE-2754**: supply auditor under-counting
  `EscrowBurned` for renewed leases (near-miss N8). **XE-9646**: staged-block
  `MSKeyset` validation omission. **XE-9604**: unbounded `signatures[]` DoS in
  `VerifyMultisigAny`. **XE-6430**: `ValidateAttestations` negative-threshold panic.
  **XE-8973**: weak/small-order public keys accepted. **XE-5194**: statechain gossip
  validator omitting hash/signature verification. **XE-6998**: sync quarantine keyed on
  claimed hash. **XE-4845** / **XE-7924**: nil-block crashes in sync responses.
  **XE-9367**: post-commit gossip error causing double-charge retry.

## HELD — needs parent decision

**Empty.** Nothing is held: every code-confirmed flaw found was matched to an existing
public ticket (section above), and every uncertain item was resolved against the code
in the second pass and rejected for the reasons in "Near-misses rejected" — several of
those were also independently already filed. There is nothing partially verified left
outstanding that a parent decision could promote to filing-ready.

## Near-misses rejected (with reasons)

- **N1. `core/ledger.go:1692` `CertificateHash[:12]` in the lease_accept
  certificate-not-found error.** Analyzed as NOT reachable: the slice fires only when
  the cert lookup returns nil AND `b.CertificateHash` equals the lease block's
  `CertificateHash` (checked just above, line ~1687). Lease validation
  (`validateAndAddLease`, `core/ledger.go:1535-1538`) requires the certificate lookup
  to succeed at lease time, and the cert set (`node/certset.go`) is keyed by exact
  64-char sha256 hash with all entries verified at ingest
  (`perf.VerifyCertificateContent` → `HashCertificate` recomputation); persisted certs
  were verified before persist. So any lease block in the ledger carries a 64-char
  certificate hash, and the `[:12]` is safe. (Already filed as XE-0623 anyway; its
  body misstates the field as "raw []byte from the wire".)
- **N2. `MintForTesting` / `SeedAssetForTesting` (`core/ledger.go`).** No callers in
  the tree; dead exported code, not a live mint path.
- **N3. Statechain genesis unsigned tolerance.** `ValidateGenesis`
  (`statechain/genesis.go`) verifies multisig only if signatures are present. Not
  exploitable: the statechain genesis is anchored locally (embedded/operator-supplied),
  `Chain.AddBlock` requires `Index == tip+1` and `PrevHash == tip.Hash`, and the sync
  server never serves index 0 (`statechain/sync.go` forces `startIndex >= 1`). A peer
  cannot substitute genesis. Ledger genesis likewise: `validateAndAddGenesis`
  (`core/ledger.go:1241+`) requires an empty store AND hash equality with the embedded
  genesis; `preflightDataDirGenesis` (`node/genesis.go`) rejects data dirs from a
  different genesis; netcheck compares genesis hashes.
- **N4. `vm_status` P2P handler has no auth check.** QEMU/Lima `Get`/`List` return no
  credentials (SSH-only); only `MockManager` (used only when `XE_VM_MOCK=1`, test-only,
  `node/node.go:523`) includes credentials. Credential-mode leases are the exception
  noted in XE-0015 Finding #1 — already filed.
- **N5. Statechain sync empty-page loop** (`statechain/sync.go` `handleSyncStream`).
  Bounded by the 60s stream deadline. Already filed as XE-4827.
- **N6. Chat envelope has no network-ID/domain separation** in `envelopeCanonical`
  (`chat/envelope.go`) — cross-network replay possible within the 5-minute freshness
  window; low impact. Already filed as XE-0480.
- **N7. `archiveExpiredLease` deletes the pending escrow and marks the lease Expired
  locally with no block**, driven by the local clock — divergence needs >~1h clock
  skew; no attacker trigger identified. Renewal top-up destruction aspect already
  filed as XE-9746.
- **N8. Supply auditor under-counts `EscrowBurned` for expired renewed leases**
  (`core/supply.go` uses `l.Cost` only) — reporting-only conservation discrepancy.
  Already filed as XE-2754.
- **N9. Genesis network-ID swap race in `ValidateGenesisBlock`** (`core/genesis.go`):
  clears/restores the global network ID during verification; reachable only at startup
  or on an empty ledger. No attacker trigger.
- **N10. Tunnel `X-Signature` replay** (`api/tunnel.go`): SSH key auth still gates
  login. **N11. `clientIP` XFF handling** (loopback-only, last element): acceptable.
  **N12. `CapR` overflow fail-open**: payout cap bounded by epoch validation
  (≤100,000). **N13. `validateLockedEmissionAt` nil-`epochAtFn` fail-open**: the node
  always sets it. **N14. Ban-store / rate-limiter eviction**: attacker Sybils could
  flush the 4096-entry ban list, but bans are short-lived (10 min) and re-imposable;
  not a finding.
- **N15. `UnmarshalBlock` / `DecodeVote`** (`core/encoding.go:353,668`): bounds-checked
  and with no callers in the tree. **`lowestHash`** (`core/vote.go:271`): called only
  after a non-empty check. **`extractED25519Key`** (`node/ssh_gateway.go:253`):
  bounds-checked. **All `shortHash`/`shortAddr`/`shortStr`/`shortKey` helpers**:
  length-guarded. **`qemu_manager.go:169,294`** `leaseHash[:12]`: length-checked at
  Provision (line 151); Teardown uses keys from the internal VM map. **Lima `vmName`**:
  internal lease hashes only. **`net/tunnel.go:84,91`**: lease hash is hex of 32 bytes,
  always 64 chars. **`api/tunnel.go:57`**: reached only after `DecodeHash` (64 hex)
  succeeds. **`core/vote.go:243`**: `DecodePublicKey` enforces 32 bytes above.
  **`core/multisig.go:58`**: 64-char check above. **`node/attestation.go:48`**,
  **`node/perf.go:42`**, **`node/observability.go:667`**: guarded / own address /
  length-checked. **`store/badger_store.go` / `mem_store.go` `[:12]` on
  `ExpectLeaseHash`/`SettleLeaseHash`/etc.**: `Source` is 64-char hex enforced by
  `MarshalBlock` for lease types before any commit. The full-tree slice sweep found
  only D1 and D2 unguarded on attacker-controlled input.
- **N16. No slashing/equivocation handling.** No `slash`/`equivocat` code exists; the
  design handles equivocation via first-final-wins per rep per conflict
  (`receiveVoteInner`) plus the final-vote lock (`PutFinalVoteIfAbsent`). A design
  property, not a code-confirmed flaw; no concrete adversarial sequence producing a
  safety violation was established.
- **N17. `activateCascade` serialization failure.** Two concurrent `SwapBlock`
  promotions: one errors, but conflict re-evaluation on votes retries; no persistent
  stuck state.
- **N18. Chat-store / directory / cert-sync / ban-store / rate-limiter bounds.** All
  bounded with eviction or caps (chat `maxSeenIDs` 100k, cert retention 256/provider,
  ban store 4096, rate limiter 2048 peers, peer caps 4096). Directory registry
  unboundedness is already filed (XE-7024, XE-8697, XE-9889).

## Areas checked and clean

- **Consensus:** vote signature/timestamp/weight checks; `finalTally` counts only
  Final votes; first-final-wins; final-vote lock; winner must be promotable and parent
  finalized (`pickWinner` withhold behaviour, matching the HEAD commit message);
  rollback/cascade guards (finalized blocks refused); `depsFinalized`; conflict
  staging/validation; `SwapBlock` cascade commit + overlay reads; no double-finality
  path found.
- **Ledger/validation:** signature verification paths (open-block, stored-key,
  multisig, multisig-any); PoW + timestamp window enforcement order in `AddBlock`;
  asset/balance checks; delegation/weight accounting; emission math overflow-checked;
  lease state machine (open/accept/settle/cancel/force-settle/renew) except the
  already-filed items above; burn/mint authorization paths; `ValidateKeyset`
  duplicate/threshold checks; attestation threshold/median/skew handling.
- **Networking:** netcheck handshake + bans + genesis-hash comparison; gossip
  scoring; gossip topic validators; sync pagination/caps; statechain sync anchoring
  (above); DHT setup; cert sync ingest verification; messenger 64 KiB cap noted
  (XE-0436 covers the vote-sync consequence — already filed).
- **RPC/API surface:** rate limiting, 1 MB `MaxBytesReader`, admin-token constant-time
  compare; chat-auth HMAC challenge, single-use nonce, expiry; tunnel HTTP handler
  signature check over the lease hash (replay noted as N10).
- **Wallet/crypto:** BIP39/SLIP-0010 implementation (NFKD, PBKDF2-2048, hardened
  SLIP-0010); wallet/seed/host-key files 0600 with O_EXCL and 0700 dirs; key storage,
  signing, address derivation; marketplace signing (domain tags + network ID); SSH
  gateway key binding (lease hash as username + key must equal `AccessPubKey`).
- **Genesis/config:** both genesis anchors (N3); genesis override requires both files
  together + network ID present; `verify-genesis` expectations; feature activation
  one-directional transitions, frozen active triggers, rising-only protocol-version
  floor; min-protocol-version enforcement in the handshake.
- **Statechain:** multisig verification (guarded `shortKey` — the safe sibling of D1);
  KV validation (DAO threshold ≥2, oracle prefix separation, epoch value checks,
  write-once epoch keys); oracle scope guard in genesis validation.
- **VM/leases:** provider policy validation; certificate ingest verification;
  `acceptCertificateHash` provider/expiry checks; VFIO BDF regex validation before
  sysfs use; Lima/QEMU templates key-only SSH.

## Coverage limitations

1. **No Go toolchain (static review only).** The Go toolchain is NOT installed on this
   VM (`go version` prints nothing / command not found), verified 2026-11-12. No
   attempt was made to download/install one, per the task brief (VM egress truncates
   large downloads). This audit is STATIC REVIEW + precise code traces; no code was
   compiled, no test was executed, no node was run, and no dynamic reproduction was
   performed. All traces in this report are labelled static traces. No transcribed-
   logic verification in Python/Node was needed: every candidate reduced to a direct
   code reading (slice without a guard, unused parameter, arithmetic mismatch), and
   each was then confirmed as already filed.
2. **Dedup residual limitation.** Private/undisclosed tickets are unsearchable, so a
   private duplicate can never be fully excluded. All dedup queries hit the public
   `/v1/tickets` API only. (This limitation cuts in favour of the empty verdict here:
   the five flaws were matched to PUBLIC tickets, so no private-ticket uncertainty
   affects the conclusion.)
3. **Desk API quirk observed.** XE-5867's title describes the lease_cancel renewal
   bug while its body is entirely the directory-panic report. Title/body mismatches
   exist in desk data; dedup here read full bodies, not titles alone.
4. **Files not fully read.** `docs/api.md` (reference docs, 1,199 lines),
   `cmd/xe/chat.go` (CLI chat client), `web/embed.go` (6 lines, trivial),
   `perf/benchmark.go` internals, the remainder of `node/observability.go` and
   `store/badger_store.go` beyond the commit paths, and `vm/qemu_template.go` /
   `lima_template.go` beyond the SSH-auth excerpts. These were judged low-value for
   the six priority areas after the surrounding code was read; the two-pass coverage
   above is otherwise complete across all 99 Go files at least at the function level.
5. **Prior registry honoured.** The desk audit report
   (`~/workspace/xe-desk-audit/report-2026-11-12.md`, desk commit `ab9df7f`) and its
   dedup registry were read first; nothing in it, and none of XE-10091 / XE-10093 /
   XE-10095 / XE-10097 / XE-10100, is re-reported here.

## Dedup methodology

Every candidate was checked against the live desk API
(`https://bounty.xe.network/v1/tickets?q=<terms>`) with several different query terms
per candidate (listed in "Duplicates found"), via read-only `curl` GET of the public
JSON endpoint at normal rate (the permitted fallback; `browser.open` was not needed).
Full texts of adjacent tickets were read when titles looked close (XE-0096, XE-2634,
XE-0623, XE-5867, XE-0102, XE-0015). Web search was not relied upon. The node has been
very heavily reported on: the single query `q=panic` alone returned 49 tickets, and
the renewal/escrow family has multiple accepted/triaging tickets (XE-0067 accepted,
XE-0102 triaging, XE-0015 fixing).
