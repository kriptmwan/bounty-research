# Prerequisites — deployed-bytecode verification (Relay periphery)

**Date:** 2026-11-13 (WIB). **Agent:** prerequisites agent, local-only, read-only.
Nothing was filed, emailed, submitted, or transacted. No transaction was sent.
Live-chain interaction was limited to read-only `eth_getCode` / `eth_blockNumber`
JSON-RPC reads and Sourcify v2 lookups. Nothing in the target checkout was edited,
patched, or committed. No exploit/POC code was copied anywhere.

**Target repo:** `~/workspace/relay-audit/repos/relay-periphery`, pinned HEAD
`e221935f54df03f9f73f2645ff688370a87033d8`. Scope: `src/` only.
**Starting data:** `~/workspace/relay-audit/SCOPE.md` §2 + §7,
`deployments/v3/addresses.json`, `deployments/v3/instructions.md`.
**Machine-readable companion:** `~/workspace/relay-audit/artifacts/bytecode-verification.json`.
**Compiled bytecodes:** `~/workspace/relay-audit/evidence/compiled-bytecode/` (+ README).
**Raw chain reads / Sourcify responses:** `~/workspace/relay-audit/evidence/chain-reads/`.
**Build logs / comparison script:** `~/workspace/relay-audit/work/`.

## Verdicts at a glance

| Address | Contract | Chain | Verdict |
|---|---|---|---|
| 0x0729e2a4716d9f7dd17858d5d504426d228697f7 | RelayRouter 3.2 | 1 (Ethereum) | **MATCH** — byte-exact vs pinned HEAD |
| 0x5567954cd026cebfe486062cb75848e0f1c12e58 | RelayApprovalProxy 3.1 | 1 (Ethereum) | **MISMATCH** — deployed code is the HEAD~1 build; HEAD fix not deployed |
| 0xb92fe925dc43a0ecde6c8b1a2709c170ec4fff4f | RelayRouter, older gen | 1 (Ethereum) | **MISMATCH** — older V3-generation source, not pinned source at 200 runs |
| 0xccc88a9d1b4ed6b0eaba998850414b24f1c315be | RelayApprovalProxy, older gen | 1 (Ethereum) | **MISMATCH** — older V3-generation source, not pinned source at 200 runs |
| 0x6328ea02d28131e58b28e55c6258258a30d90e05 | RelayRouter_NonTstore 3.2 | 1 (Ethereum) | **NO_CODE** — not deployed on mainnet |
| 0x6328ea02d28131e58b28e55c6258258a30d90e05 | RelayRouter_NonTstore 3.2 | 25 (Cronos) | **MATCH** — byte-exact vs pinned HEAD (london build) |
| 0xe4dfbd5e6784db1058124e2c87554c0591f0fb7b | RelayApprovalProxy 3.1 (london) | 25 (Cronos) | **MISMATCH** — deployed code is the HEAD~1 build; HEAD fix not deployed |

`RelayReceiver` could not be verified on-chain: no deployed receiver address is
recorded anywhere in the repo (see §7).

---

## 1. Pinned-HEAD check

```text
$ git rev-parse HEAD
e221935f54df03f9f73f2645ff688370a87033d8   ← equals the pin
$ git status --porcelain
(empty — clean tree)
```

Checked before building and again after all work (including after `out/`/`cache/`
removal): HEAD unchanged, status empty. All 10 `src/` sha256 hashes re-checked at
the end and identical to the run-ledger baseline (`notes/run-ledger.md`).
`HEAD~1` is `f83bb913bf93b1122edeff141c74216672c4a6d4` ("chore: publish Router 3.2
deployment records (#76)", 2026-11-03); HEAD is the DEC-2400 proxy fix (2026-11-09).
`git show --stat HEAD` confirms HEAD touched exactly two files:
`src/RelayApprovalProxy.sol` (29 changed lines) and one new test file. No other
source file differs between HEAD~1 and HEAD — a fact the proxy verdicts turn on.

`foundry.toml` was read and matches the task's stated settings: default profile
solc 0.8.28, evm cancun, `via_ir = true`, optimizer on, `optimizer_runs =
1_000_000`, `bytecode_hash = "none"`, `cbor_metadata = false`; a `london` profile
(same, evm london) and a `receiver` profile (same as default but 200 runs).
`out/` is gitignored (`out/` in `.gitignore`, confirmed via `git check-ignore`).

## 2. Builds

Toolchain: forge/cast 1.5.1 (`~/.foundry/bin`, prepended to PATH in every command),
solc 0.8.28+commit.7893614a (downloaded by forge; `~/.svm` did not exist before).
One build at a time; no parallel builds. All three builds succeeded (exit 0).

### 2.1 Dependency setup (and two false starts, recorded honestly)

The checkout's git submodules were uninitialized (empty `lib/` directories).
The first `forge build` attempt triggered a full submodule clone that was
interrupted by a VM/runtime restart while fetching `0x-settler`, and the restart
wiped `/tmp` (the first round of chain reads and Sourcify fetches was lost with
it; everything was re-fetched afterwards into durable paths and reproduced
identical results — same code lengths, same Sourcify match IDs). Submodules were
then initialized shallowly at their pinned commits:

```bash
git submodule update --init --recursive --depth 1 --jobs 6
```

All 33 top-level + nested submodules verified at their recorded commits
(`git submodule status --recursive` shows no `-`/`+` flags). A second build
attempt then failed on the still-missing nested `solmate` submodule (the
non-recursive init had not covered it); the recursive init fixed that. No source
file was modified at any point. The submodule initialization itself does not
dirty the tree (gitlinks at pinned commits; `git status` empty).

### 2.2 Default profile — `forge build --force`

110 files, solc 0.8.28, 51.30s, exit 0, "Compiler run successful with warnings".
Artifact metadata confirms: optimizer `{enabled: true, runs: 1000000}`,
`viaIR: true`, evm `cancun`, metadata `{bytecodeHash: "none", appendCBOR: false}`.
Warnings (summary; full log in `work/build-default.log`):

- 1 solc warning: (3628) `RelayReceiver` has a payable fallback but no receive
  function.
- Forge-lint only: `unsafe-typecast` ×3 (RelayRouter, RelayRouter_NonTstore, one
  test), `unwrapped-modifier-logic` ×2 (both reentrancy guards),
  `unaliased-plain-import` (one script), `erc20-unchecked-transfer` (one test),
  `unused-import` (one test).

### 2.3 200-run build — `forge build --force --optimizer-runs 200`

110 files, 53.47s, exit 0, same warning set. Settings identical except
`optimizer_runs = 200`. This is the documented build for Router 3.0/3.1
(foundry.toml comment + `instructions.md`) and matches the Sourcify metadata of
the older-generation deployments (§4). It is also exactly the `receiver`
profile's settings, so no separate receiver-profile build was run.

### 2.4 London build (added — required for an honest NonTstore verdict)

Sourcify metadata shows the deployed NonTstore router was compiled for EVM
`london` (§4.5). Comparing it against the Cancun build would manufacture a
mismatch (7281 vs 7399 bytes), so a third build was run with the repo's own
`london` profile and the skip list from `deployments/v3/scripts/deploy_non_tstore.sh`
(the London EVM cannot compile the transient-storage sources):

```bash
FOUNDRY_PROFILE=london forge build --force \
  --skip Test.sol --skip RelayRouter.sol \
  --skip ReentrancyGuardMsgSender.sol \
  --skip RouterAndApprovalProxyDeployer.s.sol
```

78 files, 10.06s, exit 0. Settings: solc 0.8.28, evm `london`, via_ir, 1,000,000
runs, bytecode_hash none. Warnings: the same (3628) Receiver warning + 3 lint
notes (subset, since tests/router were skipped). There is no
`RelayRouter-london.hex`: `RelayRouter.sol` cannot compile under London by design.

### 2.5 Captured artifacts

Runtime bytecodes (`deployedBytecode`) were extracted from the forge artifacts
immediately after each build (later builds overwrite `out/`) into
`evidence/compiled-bytecode/` as `0x`-prefixed single-line `.hex` files: 4 default
+ 4 runs200 + 3 london (see that directory's README for the full table of lengths
and hashes). `out/` and `cache/` were removed after capture; the checkout was
re-verified clean.

## 3. Chain-read method

Only `eth_getCode` (plus `eth_blockNumber` bracketing) was used, via `curl`
JSON-RPC. No `eth_call`, no transactions, no probing beyond code reads.

- **Chain 1 (Ethereum):** `https://ethereum.publicnode.com` (working).
  Tried and failed first: `https://eth.llamarpc.com` (Cloudflare error 525 on
  every request) and `https://rpc.ankr.com/eth` (JSON-RPC `-32000 Unauthorized:
  must authenticate with an API key`). Block numbers: `0x192e958` (26,405,208)
  before the reads, `0x192e959` (26,405,209) after. Raw responses + extracted
  code saved under `evidence/chain-reads/` (`raw-1-*.json`, `code-1-*.txt`).
- **Chain 25 (Cronos):** `https://evm.cronos.org` (working, first try). Blocks
  `0x64b1d3b` (105,585,979) → `0x64b1d40` (105,585,984). Raw responses saved as
  `raw-25-*.json` / `code-25-*.txt`.

Code lengths/keccak256 were computed from the returned hex with Python
(`pycryptodome` keccak-256) and cross-checked with `cast keccak` (identical).
Byte-level comparison used `work/compare-bytecode.py`, which reports lengths,
hashes, diff ranges, immutable-reference slots from the artifact, masked
comparison, and immutable-patch attempts.

**Immutable handling (stated exactly).** `RelayRouter` and `RelayRouter_NonTstore`
have empty constructors and no immutables, so their comparisons are direct
byte-for-byte. `RelayApprovalProxy` has **7** immutable groups in the artifact:
`ROUTER` and `PERMIT2` (constructor args) plus 5 Solady EIP-712 cache values
(`_cachedThis`, `_cachedChainId`, `_cachedNameHash`, `_cachedVersionHash`,
`_cachedDomainSeparator` — `lib/solady/src/utils/EIP712.sol:24-28`). The proxy
owner is NOT in the bytecode (Solady `Ownable` storage via `_initializeOwner`).
The compiled `.hex` files contain zeros in the immutable slots, so a deployed
proxy legitimately differs there even with identical source — and differs
*between chains* in the chainId/domain-separator slots. **No patching or masking
was needed for any verdict in this run**: both deployed proxies differ in total
LENGTH from the pinned-HEAD builds, which settles the comparison before
immutables matter. Any future proxy comparison must patch/mask all 7 groups and
state the expected values; raw keccak comparison of proxy bytecode across chains
is meaningless. `RelayReceiver` has 1 immutable group (`SOLVER`, 3 occurrences).

**Sourcify.** `GET https://sourcify.dev/server/v2/contract/<chainId>/<address>`
for match status, plus `?fields=metadata` (compiler settings) and
`?fields=sources` (stored sources) where decisive. Responses saved under
`evidence/chain-reads/` (`sourcify-*.json`). A Sourcify miss was never treated
as a mismatch by itself — and, importantly, a Sourcify *match* was never treated
as proof of pinned-HEAD equivalence either: §5 shows both deployed proxies match
on Sourcify against HEAD~1 source. One Sourcify quirk: the mixed-case address
`0xB92fe925dc43a0ecde6c8b1a2709c170ec4fff4f` (as written in the task) returned
HTTP 400 "Invalid address" (bad EIP-55 checksum); the lowercase form returned
the match record. All addresses below are written lowercase, as stored in
`addresses.json`.

## 4. Per-address verification

### 4.1 RelayRouter 3.2 — 0x0729e2a4716d9f7dd17858d5d504426d228697f7, chain 1 — MATCH

| | Length (bytes) | keccak256 |
|---|---|---|
| On-chain code (block 26,405,208) | 7185 | `0x2c4c1b3111251359e5b023c8dee4e02cbbbb7136f1497f8b1088fe04f07df516` |
| Compiled, default profile | 7185 | `0x2c4c1b3111251359e5b023c8dee4e02cbbbb7136f1497f8b1088fe04f07df516` |

Byte-for-byte identical; zero diff bytes; no immutables. **The pinned HEAD's
`RelayRouter.sol` is exactly the live Router 3.2 on chain 1.** Sourcify:
`match`, creation + runtime, verified 2026-10-16T07:24:44Z (matchId 56209985),
settings solc 0.8.28 / 1,000,000 runs / viaIR / cancun / bytecodeHash none —
identical to the default profile.

### 4.2 RelayApprovalProxy — 0x5567954cd026cebfe486062cb75848e0f1c12e58, chain 1 — MISMATCH (deployed = HEAD~1)

| | Length (bytes) | keccak256 |
|---|---|---|
| On-chain code (block 26,405,208) | 13884 | `0x8f239c4d96517d00e3209694e3b527a12660a9cded6d41b226bb80388a83798f` |
| Compiled, default profile (HEAD) | 13923 | `0x5933e1d04987c009c4c16ce55a4aaedab99c849061d165c8512c32df2c15e93e` |

The HEAD build is 39 bytes longer. The cause is proven, not inferred: Sourcify's
stored `src/RelayApprovalProxy.sol` for this address is **byte-identical**
(sha256 `9602a37e10530e28…`) to the file at HEAD~1 `f83bb913` and differs from
HEAD (`668030fc9509f939…`). All other stored sources in the bundle equal the
HEAD versions (the HEAD commit touched only the proxy file), and the stored
settings equal the default profile. Sourcify itself reports a full match
(creation + runtime, verified 2026-10-16, matchId 56209995) — against the
HEAD~1 source. **Conclusion: the live proxy predates the pinned HEAD by one
commit; the DEC-2400 residue-sweep fix in HEAD is not deployed at this address.**
The common prefix with the HEAD build is only 30 bytes; under via-IR a small
source edit re-optimizes the whole output, so prefix length says nothing about
similarity — the source-equality evidence above is what carries the conclusion.
Immutables were not patched: the length difference decides the verdict first.

### 4.3 Older-gen Router — 0xb92fe925dc43a0ecde6c8b1a2709c170ec4fff4f, chain 1 — MISMATCH (older generation)

| | Length (bytes) | keccak256 |
|---|---|---|
| On-chain code (block 26,405,208) | 4720 | `0xde894e5c12e9513d50613c8fff375ecbf19b5d9a53bec0662e2b9667e3ec8f15` |
| Compiled, pinned source @ 200 runs | 5525 | `0x0ebbe83ab743b6228eea7d7725098269a87cb3fad95697bbfa76169791ee206b` |

Compared against the pinned source compiled at 200 runs (the documented
older-gen settings, confirmed by Sourcify metadata: solc 0.8.28 / 200 runs /
viaIR / cancun). The deployed code is a genuinely older source generation:
Sourcify's stored sources name the contract `RelayRouterV3` at
`src/v3/RelayRouterV3.sol` (360 lines, no `VERSION` constant), verified
2026-04-28 (matchId 28394278) — predating the unversioned-rename commit
`bb7aa14` (#67) and the 3.2 event change (`1cd1e2f`, #73). Note: code is present
on chain 1 even though `addresses.json` lists the 3.2 router for ethereum;
the file records the *current* deployment per chain, and this superseded
deployment still holds code.

### 4.4 Older-gen Proxy — 0xccc88a9d1b4ed6b0eaba998850414b24f1c315be, chain 1 — MISMATCH (older generation)

| | Length (bytes) | keccak256 |
|---|---|---|
| On-chain code (block 26,405,208) | 7746 | `0xa3b36a6aa3c2fb588b92336d88b0735b40dea0282c110d2034edf688ca661b5b` |
| Compiled, pinned source @ 200 runs | 10962 | `0x84d765875f3e68ed9f77abc60baa190e3eb94d4f712b28247edd647d3498b310` |

Same story, larger gap: Sourcify's stored source is `RelayApprovalProxyV3` at
`src/v3/RelayApprovalProxyV3.sol` (431 lines, `is Ownable` only — no EIP-712
inheritance, unlike the current 699-line proxy), verified 2026-08-26 (matchId
46824297), settings 200 runs / viaIR / cancun. The pinned source at 200 runs
does not reproduce it. Immutables not patched (length decides). Code present on
chain 1 as a superseded deployment, as in §4.3.

### 4.5 NonTstore Router — 0x6328ea02d28131e58b28e55c6258258a30d90e05

**Chain 1: NO_CODE.** `eth_getCode` returned `0x` (0 bytes; keccak of empty
`0xc5d24601…`). The NonTstore router is not deployed on mainnet, as expected —
`addresses.json` lists it only on London-EVM chains. Sourcify chain 1: HTTP 404,
no match (consistent; not itself the verdict).

**Chain 25 (Cronos): MATCH.** RPC `https://evm.cronos.org`, blocks
105,585,979–105,585,984:

| | Length (bytes) | keccak256 |
|---|---|---|
| On-chain code (Cronos) | 7399 | `0x835c05bef5af9aaacde03ec0c8fddf3a780816780c336b0a4b48c38c58fa896a` |
| Compiled, london profile | 7399 | `0x835c05bef5af9aaacde03ec0c8fddf3a780816780c336b0a4b48c38c58fa896a` |

Byte-for-byte identical; no immutables. Sourcify: runtime `match`
(creationMatch null), verified 2026-10-16T07:25:22Z (matchId 56210004), settings
solc 0.8.28 / 1,000,000 runs / viaIR / **london**. Sourcify's stored sources
(router, Multicall3, NonTstore guard) are byte-identical to the pinned HEAD
files. The Cancun build (7281 bytes) does NOT match — evmVersion is part of the
bytecode, which is why the london build was run.

### 4.6 Cronos Proxy — 0xe4dfbd5e6784db1058124e2c87554c0591f0fb7b, chain 25 — MISMATCH (deployed = HEAD~1)

| | Length (bytes) | keccak256 |
|---|---|---|
| On-chain code (Cronos) | 14041 | `0x32ebe67e7bfe186b90b13f6e598f9fa0b41f36afe16aedbd4f74e1081f6c95df` |
| Compiled, london profile (HEAD) | 14079 | `0xcc22471a33ee3d1dce93827a5924f5f2f3f8b8cd4cc619e1ba2f71dc1fc5efcd` |

38 bytes longer when compiled from HEAD. Sourcify's stored
`src/RelayApprovalProxy.sol` for this address is byte-identical to HEAD~1
(same sha256 `9602a37e10530e28…` as the chain-1 proxy) with london/1M-run
settings; runtime `match`, verified 2026-10-16T07:25:26Z (matchId 56210008).
Same conclusion as §4.2: the HEAD DEC-2400 fix is not deployed on Cronos
either. (This address was checked in addition to the five task-named targets
because it is the Cronos pairing of the NonTstore router.)

## 5. Sourcify source-equality evidence (summary)

| Bundle (chain/address) | Stored main source vs repo | Result |
|---|---|---|
| Chain 1 proxy 0x5567… | `src/RelayApprovalProxy.sol` | == HEAD~1 (sha `9602a37e…`), ≠ HEAD |
| Chain 25 proxy 0xe4df… | `src/RelayApprovalProxy.sol` | == HEAD~1 (same sha), ≠ HEAD |
| Chain 25 NonTstore 0x6328… | router + Multicall3 + NonTstore guard | == HEAD (all three files) |
| Chain 1 old router 0xb92f… | `src/v3/RelayRouterV3.sol` | older layout; no HEAD counterpart |
| Chain 1 old proxy 0xccc8… | `src/v3/RelayApprovalProxyV3.sol` | older layout; no HEAD counterpart |

Spot checks: the proxy bundle's unchanged `src/` files (Multicall3, Permits,
IERC3009, IRelayRouter) equal HEAD, and its Solady EIP-712 file equals the
pinned-submodule checkout — so the proxy mismatch is attributable to the single
HEAD commit, not to dependency drift. Sourcify metadata settings for every
matched contract equal the corresponding local build settings (§2).

Additional Sourcify attempts: chain 185 (mint) and chain 690 (redstone) →
HTTP 400 `unsupported_chain`; chain 1625 (gravity) → HTTP 404 no-match for both
older-gen addresses. None of these were treated as verdicts.

## 6. Version mapping (from `deployments/v3/addresses.json` + `instructions.md` only)

84 entries, 84 unique chainIds, all `compilerVersion: 0.8.28`. Each chain
carries exactly one router + one proxy; 6 distinct pairs (48 + 22 + 7 + 5 + 1
+ 1 = 84). Entries without an `optimizerRuns` field were compiled at 200 runs
(per `instructions.md`). The file does not record which older group is v3.0 vs
v3.1 — that distinction is **not** asserted below.

| Address | Contract | Generation / build | Chains |
|---|---|---|---|
| 0x0729e2a4716d9f7dd17858d5d504426d228697f7 | RelayRouter | **3.2** — cancun, 1M runs | 48 |
| 0x5567954cd026cebfe486062cb75848e0f1c12e58 | RelayApprovalProxy | **3.1** — cancun, 1M runs (redeployed for the 3.2 router; proxy code unchanged at 3.1) | 48 |
| 0xb92fe925dc43a0ecde6c8b1a2709c170ec4fff4f | RelayRouter | **3.0/3.1 older gen** — cancun, 200 runs (V3 layout) | 22 |
| 0xccc88a9d1b4ed6b0eaba998850414b24f1c315be | RelayApprovalProxy | **older gen** — cancun, 200 runs (V3 layout) | 22 |
| 0xe6b730e58088884704cdf11cbe95c224d4d34154 | RelayRouter | **3.0/3.1 older gen, distinct build** — cancun, 200 runs | 7 |
| 0x5a0fa369d634f49c76b08dc6c299800c1a2af977 | RelayApprovalProxy | **older gen** — cancun, 200 runs | 7 |
| 0x6328ea02d28131e58b28e55c6258258a30d90e05 | RelayRouter_NonTstore | **3.2** — london, 1M runs | 5 |
| 0xe4dfbd5e6784db1058124e2c87554c0591f0fb7b | RelayApprovalProxy | **3.1** — london, 1M runs | 5 |
| 0x9ef6d3c2f60d7b9008d74cab1fc0f899c957c819 | RelayRouter_NonTstore | older gen — london, 200 runs | 1 (polygon_zkevm 1101) |
| 0x8754bc615047de01228a7527b712806a71a8dc9a | RelayApprovalProxy | older gen — london, 200 runs | 1 (polygon_zkevm 1101) |
| 0xe16870b028704e38dbc254a84d3f72c8ba345ca9 | RelayRouter_NonTstore | older gen — london, 200 runs | 1 (zero 543210) |
| 0xf6e54bbf91e564fcf0df3ed9f2dd82913e9232c3 | RelayApprovalProxy | older gen — london, 200 runs; non-standard permit2 (see below) | 1 (zero 543210) |

Chain lists (name(chainId), ascending chainId; router and proxy lists are
identical within each pair):

- **3.2 (48):** ethereum(1), optimism(10), bnb(56), gnosis(100), unichain(130),
  polygon(137), monad(143), sonic(146), manta(169), xlayer(196), boba(288),
  zksync(324), shape(360), worldchain(480), flow(747), stable(988), hyperevm(999),
  lisk(1135), soneium(1868), ronin(2020), abstract(2741), morph(2818),
  tempo(4217), megaeth(4326), robinhood(4663), somnia(5031), arc(5042),
  superseed(5330), base(8453), plasma(9745), apechain(33139), mode(34443),
  mythos(42018), arbitrum(42161), celo(42220), avalanche(43114), zircuit(48900),
  ink(57073), bob(60808), berachain(80094), blast(81457), doma(97477),
  plume(98866), scroll(534352), gensyn(685689), katana(747474),
  ethereal(5064014), zora(7777777).
- **Older gen A, 0xb92f…/0xccc8… (22):** mint(185), appchain(466), redstone(690),
  eden(714), perennial(1424), gravity(1625), swellchain(1923), sanko(1996),
  cyber(7560), powerloom(7869), arena_z(7897), funki(33979), hemi(43111),
  superposition(55244), syndicate(510003), xai(660279), forma(984122),
  corn(21000000), lordchain(84530008), metacade(845300014),
  ancient8(888888888), rari(1380012617).
- **Older gen B, 0xe6b7…/0x5a0f… (7):** sei(1329), story(1514), b3(8333),
  arbitrum_nova(42170), gunz(43419), anime(69000), degen(666666666).
- **NonTstore 3.2, 0x6328…/0xe4df… (5):** cronos(25), metis(1088), mantle(5000),
  linea(59144), taiko(167000).
- **Singletons:** polygon_zkevm(1101), zero(543210) — see table.

CREATE2 / deployment notes (from `instructions.md` + the JSON file):

- Canonical proxy owner (constructor arg, part of the CREATE2 input, pinned so
  the proxy address is identical on every chain):
  `0x463cB782c8dd0a1887b77336DfF74D60F006F56E`.
- CREATE2 factory `0x4e59b44847b379578588920ca78fbf26c0b4956c` on 83 entries;
  the `zero` entry has no `create2Factory` field.
- Permit2 `0x000000000022d473030f116ddee9f6b43ac78ba3` on 83 entries; `zero`
  uses `0x6b4420f66de496d18a6c36367cf7f1440fd9289f` (which is why its proxy
  address is a singleton: the permit2 address is a constructor arg in the
  CREATE2 input).
- The proxy "stays at 3.1, no code change" but was redeployed at a new address
  for 3.2 because the router address is a constructor argument in its CREATE2
  input. Router 3.2 changes the `SolverCallExecuted` event (dataHash instead of
  calldata); the oracle must decode both shapes before a 3.2 router takes fills.
- No receiver addresses appear in the file (no `relayReceiver` key on any
  entry). `RelayReceiver` deploys via CREATE2 at 200 runs (`receiver` profile)
  per `instructions.md`, but the addresses are not recorded here.
- The Chains API was NOT fetched (per task instruction; SCOPE.md already
  captured it, and every mapping question was answerable from repo files).

## 7. What could NOT be verified, and why

1. **RelayReceiver deployed bytecode** — no deployed address in repo data or in
   the task; compiled only (all three builds). Its `SOLVER` immutable would
   need patching/masking for any future comparison.
2. **Older-gen group B (0xe6b7…/0x5a0f…, 7 chains)** — no RPC reads; not
   deployed on chain 1/Cronos; outside the one-primary-chain scope. Distinct
   build from group A (different CREATE2 address at the same recorded
   settings); 3.0-vs-3.1 assignment unknown from repo data.
3. **Singletons (polygon_zkevm, zero)** — no RPC reads on those chains.
4. **Code presence on the other 82 chains** — only chains 1 and 25 were read.
   Same-address CREATE2 deployments are expected to carry the same code
   (except proxy immutable slots, which embed chainId), but presence was not
   verified per chain.
5. **Proxy immutable-patched comparison** — not performed (length differences
   decide the verdicts; see §3). Any future attempt must patch all 7 groups.
6. **Sourcify on chains 185/690** — `unsupported_chain`; chain 1625 — no match.
   Not verdicts.
7. **Router 3.2 on non-Ethereum 3.2 chains** — byte-exactness was proven on
   chain 1 only (plus the CREATE2-address argument for the rest). The NonTstore
   proof is Cronos-only, likewise.

## 8. What this means for the audit (prerequisite conclusions, not findings)

- `RelayRouter.sol` at HEAD **is** the live Router 3.2 (48 chains). Findings in
  this file apply to the live deployment as written.
- `RelayRouter_NonTstore.sol` at HEAD **is** the live NonTstore 3.2 (5 chains).
  Findings in this file apply to the live deployment as written.
- `RelayApprovalProxy.sol` at HEAD is **newer** than the deployed proxies on
  chain 1 and Cronos (both HEAD~1 builds). Findings in proxy code paths
  unchanged by HEAD commit `e221935f` apply to the live proxies; findings that
  depend on the DEC-2400 delta (the `_cleanupErc20s` call added to
  `transferAndMulticall` and the empty-signature Permit2 path, per the
  HEAD diff) do **not** describe live behavior at the verified addresses. Every
  proxy finding must state which side of the HEAD~1/HEAD boundary it sits on.
- The 22 + 7 older-gen chains run V3-generation code predating the rename and
  the 3.2 event change. HEAD findings must be re-checked against the V3
  sources (retrievable from Sourcify, §5) before claiming impact there.
- A Sourcify "match" does not prove pinned-HEAD equivalence (both deployed
  proxies match against HEAD~1 source). Always compare stored sources or
  recompile before asserting a finding affects a live deployment.

## 9. Exact commands used

```bash
# PATH in every shell: export PATH="$HOME/.foundry/bin:$PATH"
# Repo: cd ~/workspace/relay-audit/repos/relay-periphery

git rev-parse HEAD; git status --porcelain
git submodule update --init --recursive --depth 1 --jobs 6
git submodule status --recursive
forge build --force                                              # default profile
forge build --force --optimizer-runs 200                         # 200-run build
FOUNDRY_PROFILE=london forge build --force \
  --skip Test.sol --skip RelayRouter.sol \
  --skip ReentrancyGuardMsgSender.sol \
  --skip RouterAndApprovalProxyDeployer.s.sol                    # london build

# Chain reads (curl JSON-RPC; eth_blockNumber + eth_getCode only):
#   chain 1: https://ethereum.publicnode.com
#   chain 25: https://evm.cronos.org
#   (failures: https://eth.llamarpc.com → Cloudflare 525;
#    https://rpc.ankr.com/eth → -32000 auth-required)
curl -sS -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_getCode","params":["<addr>","latest"]}' <rpc>

# Sourcify v2 (GET only):
curl "https://sourcify.dev/server/v2/contract/<chainId>/<address>"
curl "https://sourcify.dev/server/v2/contract/<chainId>/<address>?fields=metadata"
curl "https://sourcify.dev/server/v2/contract/<chainId>/<address>?fields=sources"

# Comparison + hashes:
python3 ~/workspace/relay-audit/work/compare-bytecode.py <artifact.json> <code.txt> [addrs...]
cast keccak <0x-hex>          # cross-check of Python keccak-256

# Source-equality checks (read-only git):
git show HEAD:src/RelayApprovalProxy.sol | sha256sum
git show HEAD~1:src/RelayApprovalProxy.sol | sha256sum
git diff HEAD~1 HEAD -- src/RelayApprovalProxy.sol

# Cleanup + final verification:
rm -rf out cache; git rev-parse HEAD; git status --porcelain
sha256sum src/... (all 10 files, vs run-ledger baseline)
```

Build logs: `work/build-default.log`, `work/build-runs200.log`,
`work/build-london.log` (the first, interrupted attempt's log was lost with
`/tmp` in the runtime restart; the successful builds' logs are all preserved).
