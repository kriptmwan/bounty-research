# HopV2 + OFT mesh — Dedup exclusion list (known issues, do not re-report)

**Phase 0A groundwork, Option 2 (HopV2 + OFT mesh). Read-only. No new-bug hunting.**
**Date:** 2026-11-14 (WIB).

Every entry below was already reported in a prior audit (or recorded as a
Discussion observation in one). A candidate finding that matches an entry —
same contract/function family and same mechanism, even if rediscovered
independently — is a **duplicate** and must not be filed as new. Severity and
fix status are as stated in the source report. "Acknowledged + fix in <commit>"
means the report's Remediation section says Frax acknowledged and implemented
a fix in that commit; this list does **not** independently verify that the fix
reached any live deployment — the Hunter phase must still confirm live
bytecode before treating a "fixed" entry as closed on-chain. Conversely, an
"Acknowledged only" entry is still a known issue: re-reporting the same
mechanism against the same code is a duplicate even if it was never fixed.

**"Hop" in this file = Frax's own HopV2/RemoteHop bridge contracts**
(repos `FraxFinance/fraxtal-lz-hop` + `frax-oft-upgradeable`, plus the
`hop-v2` repo that carried HopV2 before consolidation), **NOT** Hop Protocol
(the unrelated `repos/hop/` checkout of `hop-protocol/hop` was not used).

**Scope tags:** `HOPV2` = HopV2/RemoteHopV2/RemoteVault/FraxtalHop code;
`OFT` = OFT tokens/adapters/LayerZero receive/compose paths; `CUSTODIAN` =
RemoteCustodian/FrxUSDCustodian mint-redeem code that feeds the mesh;
`ADJACENT` = code that integrates with the mesh but is not Hop/OFT core
(underlying tokens, branded-stablecoin cross-chain code, deploy/upgrade
scripts); `TEMPO` = Tempo-chain variants (see variant rule below);
`OTHER-SYSTEM` = a different Frax system reviewed in the same report
(§Out of scope, noted only).

## Variant rule — READ BEFORE HUNTING (Tempo, absent modules, v1)

1. **Tempo variants are NOT the EVM code.** Several Eco-report findings
   (EX-H31/33/36/38/41/43/46) target `HopV201Tempo`, `RemoteHopV201Tempo`,
   `RemoteMintRedeemHopTempo`, and Tempo fee paths that live in the
   `hop-v2` repo / `dhruvinparikh` forks and are **absent** from
   `FraxFinance/fraxtal-lz-hop @ cb3240bb`. Do not re-report the Tempo
   instance. BUT the underlying patterns (zero/low-160-bit recipient,
   compose-settlement stranding via `setMessageProcessed`/`recoverERC20`,
   unguarded internal initializer) may also exist in the non-Tempo
   `HopV2.sol`/`RemoteHopV2.sol` at HEAD — an EVM instance is a **new**
   finding only if demonstrated in the EVM code **and** on a live EVM
   deployment. EX-H36/41/43 are flagged `CHECK-EVM-VARIANT` for this.
2. **Absent modules.** `MinterModule.sol` (USD 3.4, EX-H15) and
   `RateLimiterModule`/`RateLimiterLib` (Eco 3.10/3.15, EX-H39/44) do **not**
   exist anywhere in `frax-oft-upgradeable @ 6964529b` (verified by repo-wide
   grep; `contracts/modules/` holds EIP3009/FreezeThaw/Pause/Permit/
   SupplyTracking only, and there is no `contracts/libraries/` dir). Treat
   those entries as exclusions against the audited branch only; if the Hunter
   finds the code live on-chain, the known-issue status applies, not a new
   report. The same-pattern instance in the live `FrxUSD` token
   (EX-H34) is separately recorded and was **not** fixed in the deployed
   implementation per Eco §6.
3. **v1 RemoteHop is paused / being wound down.** Frax docs (crosschain
   overview, via web search 2026-11-14) state HopV2 replaced the
   first-generation `RemoteHop` contracts, "which are now paused", while
   `MintRedeemHop` contracts "remain live". The current hop repo HEAD
   corroborates this: `src/script/hop/winddown/` (WinddownLegacyHop) and
   `src/script/hop/fix/` (SetLegacyHopNumDVNs) scripts exist. Confirm
   pause/live status on-chain before spending Hunter effort on v1
   `RemoteHop.sol`/`FraxtalHop.sol`; a v1-only issue on a paused contract
   is unlikely to meet the bounty bar (current live deployments only).
4. **No DVN-config finding exists in this set.** No report finding touches
   DVN selection, `FraxDVN.sol`, `numDVNs` enforcement, enforced options, or
   peer wiring, except incidentally (EX-H41 lists `_numDVNs` among
   initializer args). DVN/peer/config surface is **unaudited in this set** —
   it is not excluded; it is open ground. (The hop repo's
   `SetLegacyHopNumDVNsDirect` fix scripts suggest DVN-count config was
   changed operationally; verify live config, do not assume.)
5. **Duplicate patterns across reports.** Dust/decimal truncation
   (EX-H01/13/14/20), minters-array growth (EX-H15/34), fee-bound checks
   (EX-H27/47), freeze-vs-burn (EX-H25/42), and refund-recipient handling
   (EX-H02/10/22) each appear in more than one report against different
   contracts. Each entry excludes its own contract instance; a genuinely
   different contract with the same pattern is a variant to verify, not an
   automatic duplicate — but check this list first and cite the prior
   instance in the Hunter note either way.

## Sources read (all 14 PDFs, local copies)

Local dir `repos/frax-solidity/src/audits/` (read via `pdftotext -layout`;
the 4 primary reports read in full including findings + discussion sections;
the other 10 skimmed via findings TOC + keyword grep for
hop/oft/layerzero/bridge/mint/redeem, with bridge-adjacent findings read).
Zero GitHub API calls. One web search (see Retrieval gaps).

| # | Report (firm, date) | Read | Hop/OFT findings |
|---|---|---|---|
| R1 | Frax0 Mesh — Zellic, **Sep 24, 2025** (review Sep 9–22, 2025), 83 pp. | Full | 8 findings + 3 discussions → EX-H01–H11 |
| R2 | Frax (USD Stablecoin) — Zellic, **Feb 13, 2026** (review Jan 23–Feb 12, 2026), 74 pp. | Full | 10 findings + 5 discussions → EX-H12–H24 (2 findings out of scope) |
| R3 | Frax (FraxNet) — Zellic, **Jul 7, 2025** (review Jun 23–Jul 7, 2025), 56 pp. | Full | 8 findings + 3 discussions → EX-H25–H30 (5 out of scope) |
| R4 | frxUSD Ecosystem — Zellic, **Oct 19, 2026** (review Sep 23–Oct 19, 2026), 505 pp. | Full (findings + discussion + §6 deployment inventory; threat-model §5 skimmed) | 20 findings + 2 discussion refs → EX-H31–H50 (2 findings out of scope) |
| R5 | Fraxswap Router Multihop V2 — CODESPECT, Oct 26, 2026, 20 pp. | Skim | None (router only; see Out of scope) |
| R6 | Frax Upgrade (FXB, sfrxUSD) — ChainSecurity, Jul 17, 2025, 23 pp. | Skim | None (see Out of scope; 1 cross-chain note) |
| R7 | Curve AMO — Frax Security Cartel, May 2024 (pub. Oct 30, 2024), 28 pp. | Skim | None (0 keyword hits) |
| R8 | FPISLocker + FraxtalERC4626MintRedeemer — Frax Security Cartel, May 2024 (pub. Oct 24, 2024), 20 pp. | Skim | None in Hop/OFT code (adjacent MintRedeemer items noted) |
| R9 | FXB, sFRAX, frxETH Redemption Queue, Frax Oracles — Trail of Bits, Oct 2023, 31 pp. | Skim | None |
| R10 | BAMM — Certora, Oct 2024, 33 pp. | Skim | None (lending AMM) |
| R11 | Fraxchain (Fraxtal) — Trail of Bits, Feb 2, 2024, 29 pp. | Skim | None (1 Informational; native bridge reviewed, no bridge finding) |
| R12 | Fraxtal + VestedFXS + Flox — Frax Security Cartel, Apr 15, 2024, 24 pp. | Skim | None in LZ mesh (native OP-bridge items noted) |
| R13 | Fraxtal North Star — Frax Security Cartel, Mar 27, 2025, 11 pp. | Skim | None in LZ mesh (native CGT-bridge items noted) |
| R14 | frxETH V2 — Frax Security Cartel, Mar 2024 (pub. Oct 30, 2024), 33 pp. | Skim | None (0 substantive keyword hits) |

**Correction to the Phase 0A brief:** the brief dated R2 "Oct 2026"; the
report itself is dated **February 13, 2026** (PDF creation Feb 21, 2026).
R4 is the October 2026 Zellic report (Oct 19, 2026).

**In-repo audit docs checked (task item 2):**

- `frax-oft-upgradeable/audits/v1.1.0.README.md` — read in full. It is a
  **scope** document for the v1.1.0 upgrade (the Mesh R1 OFT delta), not a
  findings report: mint/burn adapters with remote supply accounting
  (`FraxOFTMintableAdapterUpgradeable`), Permit + EIP-3009 on OFTs, and
  frxUSD OFT freeze/pause/owner-burn; lists proxy→v1.1.0 upgrades per token
  and the three `scripts/ops/V110/*` upgrade scripts. No findings, no
  remediation status. Current HEAD still reports adapter `version() =
  "1.1.0"` with `SupplyTrackingModule`.
- `fraxtal-lz-hop` README — read in full: **no audit references at all**
  (no "audit" string in README or the two `src/script/hop/*/README.md`
  files); no `docs/` or `audits/` dir. It does list live HopV2 (Fraxtal,
  Arbitrum, Base, Ethereum) and v1 RemoteHop/MintRedeemHop deployments.
- `frax-oft-upgradeable` README / OPERATIONS.md — **no audit/Zellic
  mentions**; no `docs/` dir; only `audits/` dir is the v1.1.0 scope README
  above. README documents the Solana→Fraxtal HopV2 compose path
  (`lz:oft:send:fraxtalhopv2`) and DVN-set-dependent lookup tables.

## Versions audited vs current HEADs

Current HEADs (verified 2026-11-14; both checkouts are **depth-1 shallow
clones, single commit** — audit-commit ancestry cannot be verified locally
and no fetch was performed, per the read-only instruction):

- `FraxFinance/fraxtal-lz-hop` @ `cb3240bb3d644ee30267b20f2d8b82e5de559c55`
  (2026-11-03, "Merge PR #50 … feat/celo-chain")
- `FraxFinance/frax-oft-upgradeable` @ `6964529b29b367d976d62a6df1efbbacb31d3205`
  (2026-10-29, "Merge PR #176 … ops/deprecate-blast-metis")

| Report | Code audited (as stated in report) | vs current HEADs / HopV2 flag |
|---|---|---|
| R1 Mesh (Sep 2025) | `frax-oft-upgradeable`: **only delta `d3d9d17...b8d76da`** (`b8d76da3a2bb5ff1fc557c194f8fe6496873959d`); `fraxnet-dev @ 4e10ffdb`; `dev-staked-frax-erc4626 @ afb47e07`; `dev-fraxchain-contracts @ 2c2cc85f`. | **PREDATES HopV2 coverage.** No Hop contract in scope; `RemoteHop.sol` referenced only as "previously audited" (Disc. 4.2). OFT coverage is the v1.1.0 delta only. |
| R3 FraxNet (Jul 2025) | `fraxnet-dev @ d0e4ef06` (FraxNetDeposit/V2, FrxUSDCustodian, FrxUSD, RWA coordinator; only `interfaces/IRemoteHop.sol` touches Hop). | **PREDATES HopV2 (v1-only, interface-only).** No Hop/OFT implementation audited. |
| R2 USD Stablecoin (Feb 2026) | **`fraxfinance/hop-v2 @ 3dbbbca723159c06eade93852c64a59ed42f61b1`** (RemoteAdmin, HopV2, FraxtalHopV2, RemoteHopV2, RemoteVaultDeposit/Hop) — **the HopV2 audit**; `frax-oft-upgradeable @ 705aea54c1072072b7b22e5cf777baf71a905f50` (**MinterModule.sol only**); plus fraxnet-dev delta PR #63, frax-flashloan PR #19, frax-tokens deltas, optimism-fraxtal-cgt PR #41. | HopV2 covered, but in the **separate `hop-v2` repo** (lowercase org path in report), not `fraxtal-lz-hop`; file layout corresponds (`src/contracts/hop/HopV2.sol` etc.). Commit ancestry vs `cb3240bb` unverifiable (shallow clones, different repo). OFT coverage is one module only, and that module is absent at current OFT HEAD (see Variant rule 2). |
| R4 frxUSD Ecosystem (Oct 2026) | `frax-oft-upgradeable`: **delta `b8d76da→7e86f99d18a02262f7d94028ac0f4ba5122ccbd0`** (new files in full: OFTs, adapters incl. Tempo/TIP20, modules, libraries) + `@ 981a7b96` (FrxUSDPolicyAdminTempo); **`dhruvinparikh/hop-v2 @ 02ab5d69`** (RemoteHopV201Tempo, TempoGasTokenBase, TempoFeeInclusiveWrapper; HopV201Tempo diff from `3dbbbca`); **`dhruvinparikh/fraxtal-lz-hop @ 31a50544`** (RemoteMintRedeemHopTempo; RemoteMintRedeemHop diff from `747051f`); `frax-tokens @ f0f24fb`; `dev-fraxswap-v3 @ cca72784`; `dev-staked-frax-erc4626 @ 67c54c48`; `fraxnet-dev @ b1dc5491`. §6: deployed OFT v1.2.0 @ `5ce22ca5` + LZ fork @ `9876b375`. | **Most current + broadest OFT coverage**, but Hop coverage is **Tempo variants + one RemoteMintRedeemHop diff**, audited in personal forks, not the `FraxFinance` repos at current HEADs. Non-Tempo EVM HopV2 at `cb3240bb` was last audited at R2's `3dbbbca` (Feb 2026) — ~9 months of drift. Tempo files are absent from `fraxtal-lz-hop @ cb3240bb` (verified); Tempo OFT files ARE present at OFT HEAD. |
| R5–R14 | Various (see Out of scope). No HopV2/OFT implementation coverage. | All predate or ignore the LZ mesh; native-bridge findings do not transfer to HopV2/OFT. |

**Bottom line for the Hunter:** EVM HopV2 has exactly one audit (R2,
Feb 2026, `hop-v2 @ 3dbbbca`); OFT core has two deltas (R1 v1.1.0,
R4 →`7e86f99d`/v1.2.0); everything after those commits, plus DVN/peer
config, BatchSend, AMOs, composers, Solana/Move programs, and the
`FraxDVN` contract, is **unaudited in this set**.

## Retrieval gaps

1. **v1 RemoteHop standalone audit — NOT RETRIEVED.** R1 Disc. 4.2 says
   `src/contracts/hop/RemoteHop.sol` "had been previously audited" but
   names no firm/report. Tried: (a) all 14 local PDFs — none scopes
   `RemoteHop.sol` implementation; (b) one web search
   ("Frax RemoteHop audit report Zellic LayerZero hop", 2026-11-14) —
   returned only the R1/R3 reports themselves, Frax docs, and unrelated
   pages; no standalone RemoteHop audit surfaced. The v1 findings list is
   therefore **unknown**; Hunter must treat v1-only mechanisms as
   unverified-against-prior-art (mitigated by v1 being paused — see
   Variant rule 3). No GitHub API calls were made (rate-limited, per
   brief); no `git fetch` was performed (read-only instruction).
2. **No other gaps.** All 14 PDFs named in the brief were present and
   readable locally. No report had to be fetched from the web.

---

## Main exclusion list

### R1 — Frax0 Mesh, Zellic, Sep 24, 2025 (8 findings, 1 Medium / 1 Low / 6 Informational; + 3 Discussion notes)

| ID | Report finding | Severity | Contract / function | Status (as stated) | Mechanism (one line) |
|---|---|---|---|---|---|
| EX-H01 | 3.1 Incorrect condition for determining dust removal `CUSTODIAN` | Medium | `RemoteCustodian` / `_removeDustFrxUsdFloor`, `_removeDustFrxUsdCeil`, `mint`/`deposit`/`previewMint`/`previewDeposit` | Acknowledged + fix in PR #69 (to be merged to production) | Dust removal gated on `custodianTknDecimals() > 6` instead of frxUSD decimals, so ≤6-decimal custodians skip it and cross-chain OFT conversion truncates shares the user already paid for. |
| EX-H02 | 3.2 Inconsistent native fee refund recipient in `_remoteMint` `CUSTODIAN` | Low | `RemoteCustodian` / `_remoteMint` | Acknowledged + fix in PR #68 | Local-EID branch refunds excess native fee to `_receiver` instead of `msg.sender` (payer); cross-chain branch correctly refunds payer. |
| EX-H03 | 3.3 Incorrect Transfer event parameters `ADJACENT` | Informational | `StakedFrxUSD3` / internal `__transfer` | Acknowledged + fix in PR #30 | `Transfer` emitted with `from = msg.sender` instead of the debited `owner`, breaking ERC-20 event semantics for indexers. |
| EX-H04 | 3.4 Incorrect EIP-712 domain separator in upgradable proxy `ADJACENT` | Informational | `StakedFrxUSD3` / `__domainSeparatorV4` (Solmate cached separator) | Acknowledged + fix in PR #30 | Solmate `DOMAIN_SEPARATOR()` binds the separator to the implementation address, not the proxy, so EIP-712 signatures (permit) verify against the wrong contract while chainid is unchanged. |
| EX-H05 | 3.5 Incorrect proxy contract addresses `OFT` | Informational | `UpgradeAdapterEthereum.s.sol` / `upgradeExistingLockboxes` (V1.1.0 OFT adapter upgrade script) | Acknowledged + fix in PR #106 | Ethereum upgrade script passes Fraxtal lockbox proxy addresses, which have no code on Ethereum, so execution fails. |
| EX-H06 | 3.6 Incorrect caller in script `OFT` | Informational | `UpgradeAdapterEthereum.s.sol` / `addMinterRoles` via `prankAndWriteTxs` | Acknowledged + fix in PR #106 | Single pranked caller used for `addMinter` on both tokens, but frxUSD requires owner while sfrxUSD requires timelock, so the script fails authorization. |
| EX-H07 | 3.7 Redundant call to `approve` `ADJACENT` | Informational | `FraxtalMinter` / `burnFrxUSD` | Acknowledged + fix in PR #67 | Self-approve before burning own balance is a no-op that wastes gas (burning own tokens consumes no allowance). |
| EX-H08 | 3.8 Centralization risk `CUSTODIAN` | Informational | `CustodianBase` / `setMintRedeemFee`, `recoverERC20`, `recoverETH` | Acknowledged only | `DEFAULT_ADMIN_ROLE` can set any fee <100% and withdraw arbitrary ERC-20/native balances including custodian token; single point of control. |
| EX-H09 | Disc. 4.1 Oracle issue in RemoteCustodianWithOracle `CUSTODIAN` | Discussion (no severity) | `RemoteCustodianWithOracle` / deposit/withdraw vs oracle price | Discussed; team clarified oracle price cached per block + fees for volatile assets | Deposit-then-withdraw across an oracle update (or sudden price move vs custodian balance) can extract value; same-block flash-loan/sandwich ruled out by per-block cache per team. |
| EX-H10 | Disc. 4.2 Refund recipient for native fee in RemoteHop `HOPV2` | Discussion (no severity) | `RemoteCustodian._remoteMint` → OFT `send(..., address(this))`; pattern from `RemoteHop.sol` | Discussed; Zellic confirmed acceptable | Native-fee refund to `address(this)` looks risky (nonpayable implementation) but deployed proxy is payable and refunds are rare given fresh `quoteSend`; `msg.sender` also reasonable. |
| EX-H11 | Disc. 4.3 Hop-fee handling vs lzCompose value in RemoteHop `HOPV2` | Discussion (no severity) | `RemoteHop` L2→Fraxtal→L2 hop-fee handling | Discussed; intentional design | Quoted-vs-actual fee difference intentionally accrues as surplus, later withdrawn via `recoverETH()` and allocated to FraxtalMinter to offset gas. |

### R2 — Frax (USD Stablecoin), Zellic, Feb 13, 2026 (10 findings, 2 Medium / 4 Low / 4 Informational; + 5 Discussion notes)

| ID | Report finding | Severity | Contract / function | Status (as stated) | Mechanism (one line) |
|---|---|---|---|---|---|
| EX-H12 | 3.1 BrandedSiloedCustodian passes shares where assets are expected `CUSTODIAN` | Medium | `BrandedSiloedCustodian.withdraw` → `withdrawInheritedExternal` → `FrxUSDCustodian.withdraw` | Acknowledged + fix in commit `f212df58` | frxUSD-denominated (18-dec) value passed where asset amount expected; with 6-dec collateral the 1e12-inflated value exceeds `maxWithdraw` and all withdrawals revert. |
| EX-H13 | 3.2 Cross-chain transfers truncate amounts to zero when branded stablecoin uses fewer than 18 decimals `ADJACENT` | Medium | `CrossChainRouter` / `send`, `mintAndSend`, `quote`, `quoteSend`, LZ `send` overload | Acknowledged only (no fix commit stated) | Hardcoded `1e12` dust factor assumes 18 decimals; a <18-dec token (via `setDollarImplementation`/proxy upgrade, unenforced) truncates nonzero amounts to zero while the caller loses the full messaging fee. |
| EX-H14 | 3.3 `RemoteVaultDeposit.deposit` transfers before truncation, leaving dust in RemoteVaultHop `HOPV2` | Low | `RemoteVaultDeposit.deposit` → `RemoteVaultHop.deposit` (`removeDust`) | Acknowledged + fix in commit `a11eb7fe` | Full `_amount` moved to RemoteVaultHop before `removeDust` truncates, stranding accumulating dust recoverable only by manual admin `recover`. |
| EX-H15 | 3.4 Unbounded `minters_array` growth risks DoS when removing minters `OFT` | Low | `MinterModule` (`frax-oft-upgradeable`) / `_addMinter`, `_removeMinter` | Acknowledged only (no fix commit stated) | Removed minters are zeroed, never deleted, so the array grows forever and the O(n) removal scan can eventually exceed the gas limit, blocking revocation. **Module absent at current OFT HEAD — see Variant rule 2.** Same pattern as EX-H34. |
| EX-H16 | 3.5 `FraxNetDepositV3.recoverERC20` uses unsafe transfer `ADJACENT` | Low | `FraxNetDepositV3.recoverERC20` | Acknowledged + fix in commit `59750197` | Raw `transfer` without return check silently fails for nonstandard tokens (false-returning, void-returning USDT), so recovery appears to succeed while tokens stay stuck. |
| EX-H17 | 3.8 Missing `_disableInitializers` in GeniusDollar constructor `ADJACENT` | Informational | `GeniusDollar` (branded stablecoin implementation) / constructor | Acknowledged + fix in commit `39ba159e` | Uninitialized implementation contract can be taken over by anyone (impact confined to the implementation itself). |
| EX-H18 | 3.9 Deprecated tokens incorrectly claim support for nonfunctional mintable interfaces `ADJACENT` | Informational | `ERC20ExWrappedPPOM`, `ERC20PermitPermissionedNonBridgeableMintable` / `supportsInterface`, `mint`, `burn` | Acknowledged + fix in commit `de163f9d` | `supportsInterface` claims `IOptimismMintableERC20`/`ILegacyMintableERC20` while `mint`/`burn` unconditionally revert `Deprecated()`, misleading ERC-165-based bridges/integrators. (Native-bridge deprecation component.) |
| EX-H19 | 3.10 Encoding backing token address in CREATE2 salt reduces entropy `ADJACENT` | Informational | `BrandedFactory` / CREATE2 deploy path (`bytes4(salt) == 0xFFFFFFFF` isolated-backing marker) | Acknowledged only (no fix commit stated) | Salt packs marker + 20-byte backing address, leaving 64 bits of entropy and coupling addressing to application config (not directly exploitable as stated). |
| EX-H20 | Disc. 4.1 No minimum amount validation after `removeDust` in HopV2 deposit flow `HOPV2` | Discussion (no severity) | HopV2 vault flow / `removeDust` (cf. LZ `OFTCore._debitView` slippage check) | Acknowledged (all §4 points acknowledged) | No post-truncation minimum check, so a deposit truncated to zero still pays the cross-chain fee and delivers nothing; LZ's own pattern checks `amountReceivedLD >= _minAmountLD`. |
| EX-H21 | Disc. 4.2 Redundant `removeDust` call in HopV2 deposit flow `HOPV2` | Discussion (no severity) | `RemoteVaultHop.deposit` → `HopV2.sendOFT` (both call `removeDust`) | Acknowledged | Second `removeDust` in `sendOFT` is a no-op on the already-truncated value; gas waste only, no security impact. |
| EX-H22 | Disc. 4.3 Refund logic in `RemoteVaultDeposit.deposit` refunds entire contract balance `HOPV2` | Discussion (no severity) | `RemoteVaultDeposit.deposit` (and `redeem`, per threat model §5.11) | Acknowledged + addressed in commit `0ebcb98` (fee return values; refund exactly `msg.value - fee`) | Refund uses `address(this).balance` as a proxy for excess fee, so ETH accidentally sent to the contract is swept to the next depositor; threat model notes `redeem(0)` can sweep historical balance. |
| EX-H23 | Disc. 4.4 Cross-chain deployment marked complete before destination confirms `ADJACENT` | Discussion (no severity) | `FraxtalBrandedDeployer.deployCrossChainBrandedStablecoin` / `config.isDeployed[eid] = true` | Acknowledged; intentional per protocol (admin recovery via `manuallySetDeploymentForEid`) | `isDeployed` set right after OFT `send` (submission, not destination execution); a failed destination deploy blocks retry with `TokenAlreadyDeployed()` until admin intervenes. |
| EX-H24 | Disc. 4.5 Custom initialization pattern instead of OZ Initializable `ADJACENT` | Discussion (no severity) | Branded Stablecoin contracts (`wasInitialized` flag; `BrandedCustodian.initialize`) | Acknowledged; intentional design choice | Custom boolean-flag init lacks OZ `Initializable` protections (versioned reinit, implementation locking); kept for storage-layout consistency. |

### R3 — Frax (FraxNet), Zellic, Jul 7, 2025 (8 findings, 1 Medium / 5 Low / 2 Informational; + 3 Discussion notes; 5 items out of scope — see §Out of scope)

| ID | Report finding | Severity | Contract / function | Status (as stated) | Mechanism (one line) |
|---|---|---|---|---|---|
| EX-H25 | 3.2 Frozen tokens cannot be burned by owner `ADJACENT` | Low | `FrxUSD` / `_update`, `burn`, `burnMany` | Acknowledged + fix in commit `59ba68bf` | `_update` blocks any transfer/mint/burn touching a frozen address, so owner burn of frozen (e.g. hacked) funds fails unless first unfrozen. Same freeze/burn interaction class as EX-H42 (OFT instance). |
| EX-H26 | 3.4 Incorrect address emitted in ProcessedRedemption event for Solana `ADJACENT` | Low | `FraxNetDeposit`, `FraxNetDepositV2` / `processRedemption` | Acknowledged only (no fix commit stated) | For Solana EID 30168 the real recipient is `targetUsdcAtaAddress` but the event logs `targetAddress`, misleading event consumers (CCTP/LZ redemption path). |
| EX-H27 | 3.5 Incorrect fee checking in `setMintRedeemFee` `CUSTODIAN` | Low | `FrxUSDCustodian` / `setMintRedeemFee` | Acknowledged + fix in commit `1faa7367` | `||` instead of `&&` lets one fee be ≥1e18 (not a fraction) while the other passes, corrupting mint/redeem math. See also EX-H47 (missing bound at init). |
| EX-H28 | 3.6 Lack of zero-address check in `initialize` `CUSTODIAN` | Low | `FrxUSDCustodian`, `FrxUSD` / `initialize` → `_transferOwnership` | Acknowledged + fix in commit `dfc64fc3` | Owner can be initialized to `address(0)`, permanently bricking all owner-only admin actions. |
| EX-H29 | 3.7 Inconsistent `frxUSDMinted` check `CUSTODIAN` | Informational | `FrxUSDCustodian` / `maxDeposit`, `maxMint` vs `_deposit` | Acknowledged + fix in commit `8365e22b` | Views return 0 at `frxUSDMinted >= mintCap` but `_deposit` reverts only at `> mintCap`, so a deposit can succeed exactly at the cap despite views saying 0. |
| EX-H30 | Disc. 4.3 Low value share redemptions result in loss of funds `CUSTODIAN` | Discussion (no severity) | `FrxUSDCustodian` / `_convertToAssets` (floor rounding), redeem | Discussed (ERC-4626-permitted rounding; guard or document) | Redeeming <1e12 frxUSD converts to 0 USDC while shares are still burned — silent loss on dust redemptions. Same dust/loss class as EX-H01/13/20. |

### R4 — frxUSD Ecosystem, Zellic, Oct 19, 2026 (20 findings, 0 Critical/High/Medium, 7 Low / 13 Informational; + Discussion refs)

Zellic IDs (`ZELLIC-*`) are the report's reference IDs. "Fix in <commit>" is
per the report's Remediation section; §6 deployment inventory notes where a
remediation did NOT reach a deployed implementation (flagged below).

| ID | Report finding | Severity | Contract / function | Status (as stated) | Mechanism (one line) |
|---|---|---|---|---|---|
| EX-H31 | 3.1 Some Tempo fee-paying entry points lack a caller-selected spend cap (ZELLIC-WWETDM) `TEMPO` `OFT` | Low | TempoAltTokenBase OFTs, `RemoteHopV201Tempo.sendOFT`, `RemoteMintRedeemHopTempo.mintRedeem` (2-arg legacy overload) | Acknowledged + fixes in `bf55e95d`, `8f23b072`, `a4880bf1` | TIP-20 fee token pulled via atomic DEX quote/swap with no caller cap (legacy overload uses `type(uint256).max`); a maker repricing before inclusion makes the caller overpay (~2.04% in the sampled −2% tick move); principal unaffected. |
| EX-H32 | 3.2 OFT transport recipients can decode to zero after source principal is debited (ZELLIC-4AVT21) `OFT` | Low | `OFTCoreUpgradeable` + Frax OFT implementations / `send`→`_debit`→`encode`; destination `_credit` | Acknowledged + fixes in `af76ecc1`, `5fb31cb2` | No source-side check that `SendParam.to` decodes to a usable EVM address: `bytes32(0)` or any value with low 160 bits zero debits/burns source supply, then destination credit reverts (message stalls) — except the Ethereum sfrxUSD lockbox, where Solmate `transfer` credits `address(0)` and funds are permanently unrecoverable. |
| EX-H33 | 3.3 Excess Tempo fees are refunded in LayerZeroEndpointDollar (ZELLIC-Z3RFKK) `TEMPO` `OFT` | Low | TempoAltTokenBase OFTs, `RemoteHopV201Tempo`, `RemoteMintRedeemHopTempo` | Acknowledged + fix in `2e10f596`; Frax comment: refunds stay in LZD by design, hop-held refunds zero by construction | Endpoint refunds excess in its native wrapper (LZD), not the caller's original TIP-20; hop contracts select themselves as refund recipient, so excess accrues to the hop pending privileged recovery instead of returning to the user. |
| EX-H34 | 3.4 Unbounded `minters_array` growth can prevent minter removal (ZELLIC-VTXKC7) `ADJACENT` | Low | `FrxUSD` / `addMinter`, `removeMinter` | Acknowledged only; **§6: "acknowledged and is not fixed in this implementation"** (live Ethereum FrxUSD @ `f0f24fb`) | Same tombstone/O(n)-scan mechanism as EX-H15, here in the `FrxUSD` token itself (live length 10 at review); sufficient growth can make removing a compromised late-index minter exceed the gas limit, blocking revocation. |
| EX-H35 | 3.5 A block-scoped oracle cache can outlive feed, scale, and validity changes (ZELLIC-NTTVDX) `CUSTODIAN` | Low | `FrxUSDCustodianWithOracle` / oracle-price cache (`lastOracleUpdate == block.number`), `setCustodianOracle` | Acknowledged + fix in `99df4a09` | Cached raw answer reused all block without revalidating feed/decimals/freshness; fork PoC primed the cache, swapped in a different-scale feed, and withdrew the full sampled reserve with 1 frxUSD. |
| EX-H36 | 3.6 Remote-hop sends accept unusable final recipients hidden from OFT validation (ZELLIC-CWSWSK) `TEMPO` `HOPV2` `CHECK-EVM-VARIANT` | Low | `RemoteHopV201Tempo.sendOFT`, `HopV201Tempo`, `TempoFeeInclusiveWrapper` → `HopMessage.recipient`, `_sendLocal`, `lzCompose` | Acknowledged + fixes in `8ef37e72`, `1be0b1ca` | Caller-supplied final recipient copied into `HopMessage` without zero/low-160 validation and principal pulled first; on data-bearing routes the OFT sees only the valid hop address, destination credit succeeds, and every compose retry reverts decoding the nested zero recipient, stranding principal at the destination hop pending admin action. **EVM HopV2 equivalent must be checked as a variant (see Variant rule 1).** |
| EX-H37 | 3.8 Custodian owners can recover active backing while liabilities remain (ZELLIC-B8ABDX) `CUSTODIAN` | Informational | `FrxUSDCustodianBase`, `FrxUSDCustodian`, `FrxUSDCustodianWithOracle` / `recoverERC20` | Acknowledged as intended; **no code change planned** (explicit trust/solvency assumption; owner multisig) | Owner-only recovery moves any ERC-20 incl. active `custodianTkn` without reducing `frxUSDMinted`, so full recovery leaves liabilities backed by zero redeemable capacity (fork-proven state). No non-owner path. |
| EX-H38 | 3.9 Initializers accept a zero owner, and `initializeWithPolicy` accepts unusable policies (ZELLIC-2SEV54) `TEMPO` `OFT` | Informational | `FrxUSDPolicyAdminTempo` / `initialize`, `initializeWithPolicy` | Acknowledged + fix in `5707025d`; **§6: remediation NOT in deployed Tempo impl** (initialized validly, will not be redeployed) | Zero owner leaves no local manager; arbitrary `policyId` (nonexistent / non-BLACKLIST / wrong admin) can make freeze/thaw revert or invert `isFrozen`; requires privileged deployment mistake. |
| EX-H39 | 3.10 Rate-limit configuration transitions can reprice historical usage (ZELLIC-PKHXR5) `OFT` | Informational | `RateLimiterModule`, `RateLimiterLib` / default setter vs per-EID checkpointing | Acknowledged + fixes in `363d430e`, `2c6ed6dc` | Default-config replacement does not checkpoint inheriting EIDs, so the new limit/window applies retroactively to elapsed time (e.g. 100-token bucket reports 1,000 available instead of checkpoint-preserving 910); zero-valued disable/reenable has the mirror hazard. **Code absent at current OFT HEAD — see Variant rule 2.** |
| EX-H40 | 3.11 Custom EIP-712 initializers omit the `onlyInitializing` guard (ZELLIC-SA8P5Q) `OFT` | Informational | `EIP712Upgradeable` (OFT signature module) / `__EIP712_init`, `__EIP712_init_unchained` | Acknowledged + fix in `22f00aac` | Helpers rewrite the EIP-712 domain + cached hashes without `onlyInitializing`; all reviewed call sites are inside `reinitializer(3/4)` and unexposed, so this is inheritance hardening — a future derived external call could change the domain and invalidate outstanding permit/EIP-3009 authorizations. |
| EX-H41 | 3.12 Internal Hop initializer omits the `onlyInitializing` guard (ZELLIC-TBDDM5) `TEMPO` `HOPV2` `CHECK-EVM-VARIANT` | Informational | `HopV201Tempo.__init_HopV201` (grants `DEFAULT_ADMIN_ROLE`, writes `localEid`/`endpoint`/`numDVNs`/executor/DVN/treasury, OFT approvals) | Acknowledged + fix in `04ccf6d3` | Only production caller is `initializer`-guarded and constructors disable initializers, so no live path exists; a future derived contract invoking the helper outside init would grant admin to the caller and overwrite routing/fee config. **Check the non-Tempo HopV2 initializer at HEAD for the same omission as a variant.** |
| EX-H42 | 3.13 Freezing the zero address blocks mint and burn operations (ZELLIC-AYPT3H) `OFT` | Informational | `FrxUSD`, `FrxUSDOFTUpgradeable` / `freeze`, transfer hooks (`isFrozen(to/from/msg.sender)`) | Acknowledged + fix in `0eb8908d` | `freeze(address(0))` blocks every non-owner mint (`from == 0`) and burn (`to == 0`), including OFT outbound-burn/inbound-mint settlement in both bridge directions; privileged, reversible via `thaw(0)`, owner already has pause. |
| EX-H43 | 3.14 Administrator transitions can strand principal awaiting compose settlement (ZELLIC-CWSWST) `TEMPO` `HOPV2` `CHECK-EVM-VARIANT` | Informational | `RemoteHopV201Tempo`, `HopV201Tempo` / `recoverERC20`, `setMessageProcessed`, OFT deapproval/pause, `remoteHop(srcEid)` replacement; destination `_credit` → `sendCompose` gap | Acknowledged + fix in `79ecfc5a` | Destination hop holds credited principal between `_credit` and `lzCompose` with no pending-GUID reservation: recovery can underfund it, `setMessageProcessed` pre-marking makes compose return success-as-duplicate without paying the recipient (terminal for auto-retry), and config changes delay/revert settlement. All triggers privileged; manual compensation possible. **EVM `HopV2.sol` at HEAD contains `setMessageProcessed` + compose validation — check EVM instance as a variant; do not re-report the Tempo instance.** |
| EX-H44 | 3.15 A shared timestamp can discard fractional rate-limit recovery (ZELLIC-BXHRC7) `OFT` | Informational | `RateLimiterModule`, `RateLimiterLib` / shared `lastUpdated`, `_decayUsage` flooring | Acknowledged + fix in `5359fde1` | One shared timestamp for both directions + per-direction flooring lets opposite-direction traffic discard fractional refill (<1 base unit per materialization; ~31.6 tokens/year at 1/sec with ≥6 decimals); full stall needs dust-scale limit/window; no affected deployed config found. **Code absent at current OFT HEAD — see Variant rule 2.** |
| EX-H45 | 3.16 Executable OFT sends do not enforce the shared-decimal ceiling (ZELLIC-BFHKMW) `OFT` | Informational | Frax OFT implementations + adapters / `_toSD` narrowing, `_debitView`, `quoteOFT`/`quoteSend` | Acknowledged + fixes in `3f4f816b`, `9876b375` (LZ fork) | `_toSD` narrows to `uint64` unchecked: at ≥2⁶⁴ shared units (18,446,744,073,709.551616 tokens at 6 shared decimals) the payload wraps (to zero at exactly 2⁶⁴) after the full amount is burned/locked/ledgered; slippage check runs pre-narrowing so it cannot catch it. Remote reachability (sampled supply ~89.8M). |
| EX-H46 | 3.17 Rebinding try-catch catches every revert from `quoteSend()` (ZELLIC-2AJ02J) `TEMPO` `HOPV2` | Informational | `RemoteMintRedeemHopTempo._quoteSendRebindingOnFailure`, `_bindFeeToken` | Acknowledged + fixes in `018261ce`, `755c85fc` | Bare `catch` rebinds the FeeManager fee token (caller-supplied in the 4-arg overload) on ANY quote failure — missing peer, unset enforced option, misconfigured OFT — wasting gas and masking the original error; no persistent state/funds at risk (final revert rolls back). |
| EX-H47 | 3.18 Missing fee bounds during initialization (ZELLIC-K7354C) `CUSTODIAN` | Informational | `FrxUSDCustodian` (fraxnet-dev), `FrxUSDCustodianBase` (dev-staked-frax-erc4626) / `initialize` vs `setMintRedeemFee` | Acknowledged + fixes in `05dbeade`, `e788e81d`; **§6: NOT in USDB/BUIDL/USDC/WTGXX impls** (already initialized, init-only effect) | `initialize` assigns `mintFee`/`redeemFee` without the `< 1e18` bound enforced by the setter; fee = 1e18 → division by zero in previews, > 1e18 → underflow revert in all four previews, bricking deposit/mint/withdraw/redeem until owner resets. Deployer-only trigger. |
| EX-H48 | 3.19 Fee exemption in `max*` functions depends on the caller instead of the queried owner (ZELLIC-T43RX6) `CUSTODIAN` | Informational | `FrxUSDCustodianWithReceiverV2`, `FrxUSDCustodianUsdcV2`, `FrxUSDCustodian` / `_isFeeExempt` (`msg.sender`/`tx.origin`), `maxWithdraw`/`maxRedeem`/`maxDeposit`/`maxMint` | Acknowledged only (no fix commit stated) | Limit views inherit the *caller's* fee-exemption via preview overrides, so third-party/integrator reads for an `_owner` differ from the owner's own read; on-chain flows stay consistent (`_owner == msg.sender` enforced). View/integration hazard only. |
| EX-H49 | Disc. 4.1 Legacy owner sentinels can reopen initialization after ownership renunciation (ZELLIC-VQC7AH) `ADJACENT` | Discussion/reference (no severity; out-of-scope legacy code) | Legacy bundled `FrxUSD.sol`, `FrxUSD2.sol`, `FrxUSD3.sol` in `dev-staked-frax-erc4626` (outside declared custodian scope) / `owner() == address(0)` init sentinel | Recorded for completeness; in-scope `frax-tokens` FrxUSD impl does NOT expose the legacy initializer | `renounceOwnership()` restores the zero-owner sentinel, letting a later permissionless caller re-initialize the proxy, become owner, self-authorize as minter, and mint (local proxy PoC for FrxUSD2/3). Trigger requires legacy governance renunciation. **Do not re-report against the bundled legacy contracts; a live-proxy instance would need fresh verification that the sentinel is reachable on a current deployment.** |
| EX-H50 | Disc. 4.1 Reviewed implementations are upgrade-only targets (ZELLIC-D53ZSV) `ADJACENT` | Discussion/reference (constraint, not a vulnerability) | `frax-tokens` FrxUSD/SfrxUSD implementations | Recorded for completeness | Implementations validated as upgrade targets for initialized legacy proxies (storage layout + forked upgrade tests) but are NOT fresh-proxy templates: new empty proxies cannot reconstruct legacy owner/timelock/token/accounting state via a current initializer. Documented assumption for Hunter PoCs (use forked upgrade state, not fresh deploys, when testing these impls). |

---

## Out of scope, noted (do not hunt here for Option 2; listed so the Hunter knows they were seen and classified)

Findings in unrelated systems — lending, bonds, staking, swaps, native
OP-stack bridging (NOT the LayerZero mesh). Native-bridge items are called
out explicitly because "bridge" keyword hits in older reports are almost
all OP-stack `StandardBridge`/`Portal` code, which HopV2/OFT does not use.

- **R2 USD Stablecoin (Zellic, Feb 2026):** 3.6 Emergency shutoff +
  borrow-limit checks permanently inactive in `FraxlendLeverOdos` (Low,
  fix `2ecc2a7d`); 3.7 unchecked low-level call in
  `FraxlendLeverOdos.recoverERC20` (Informational, fix `12a375c1`).
  Fraxlend leverage router — lending, out of scope.
- **R3 FraxNet (Zellic, Jul 2025):** 3.1 missing slippage check in
  `FrxUSDCustodian.shuffleToRwa` (Medium, fix `036bdc5b`); 3.3
  `maxSlippage` unvalidated at init in `RWARedemptionCoordinator` (Low,
  fix `72ef1668`); 3.8 shared `IRWAUSDCRedeemer` interface confusion
  (Informational, fix `caad8f2a`); Disc. 4.1 missing events; Disc. 4.2
  unused `scaleDownTo1e6`. RWA-swap / code-hygiene items, out of scope.
- **R4 frxUSD Ecosystem (Zellic, Oct 2026):** 3.7 UniV2 step prices
  fee-on-transfer/rebasing inputs at nominal amount, route reverts
  (ZELLIC-6249V4, Low, fix `488caac2`, FraxswapRouterMultihopV2 —
  **same issue as CODESPECT 7.1.1, R5**); 3.20 missing recipient
  validation lets swap output go to router/executor (ZELLIC-XG1WNJ,
  Informational, fix `488caac2`, router); Disc. 4.2 limited test
  coverage (2,503 markers, 582 checked — process note, not a finding).
  Swap-router items, out of scope.
- **R5 CODESPECT MultihopV2 (Oct 26, 2026)** — `dev-fraxswap-v3 @
  cca72784` → final `488caac2`. 5 findings, all router-only: 7.1.1
  Medium FoT/stETH step input (Fixed — duplicate of R4 3.7); 7.2.1 Info
  native routes on chains without WETH9 (Acknowledged); 7.2.2 Info
  `swapWithPermit` EIP-2612-only (Acknowledged); 7.2.3 Info UniV4 step
  `take` on zero output (Acknowledged); 7.2.4 Info misleading param
  name (Fixed). "Multihop" here = multi-hop *swaps*, not HopV2.
- **R6 ChainSecurity Frax Upgrade (Jul 17, 2025)** — Frax Bonds
  `fe4caf06`→`4ef235e6`, Staked Frax `1e0f2062`→`5e69987b`. 10 Low
  (3 Risk Accepted: ERC-4626 preview-0, MintRedeemer rounding,
  proxy/implementation name-vs-domain-separator mismatch; 7 Code
  Corrected, mostly oracle/rounding in `FraxtalERC4626MintRedeemer` and
  `SfrxUsd2OracleImplementation`) + 7 Informational + notes. No Hop/OFT
  finding. Closest items: Note 8.2 cross-chain oracle desynchronization
  enables arbitrage (note only, no vulnerability claimed);
  §7.6 users can lose funds on rounding in `FraxtalERC4626MintRedeemer`
  (Informational, Risk Accepted — single-chain Fraxtal vault, NOT
  `RemoteMintRedeemHop`; same rounding-to-zero class as EX-H30).
  Bonds/staking upgrade, out of scope.
- **R7 Curve AMO (Frax Security Cartel, May 2024):** 31 findings
  (2 High / 5 Medium / 13 Low / 8 Informational + 3 gas), all Curve
  AMO/liquidity/validator accounting. Zero hop/oft/layerzero/bridge
  hits. Out of scope.
- **R8 FPISLocker + MintRedeemer (Frax Security Cartel, May 2024):**
  15 findings (5 High / 5 Medium / 2 Low / 3 Informational), all
  addressed or acknowledged. Closest items (single-chain
  `FraxtalERC4626MintRedeemer @ cc0cde2b`, NOT Hop code): 3.1.3 High —
  attacker can sandwich oracle updates to extract funds from
  MintRedeemer; 3.1.4 High — deployment script sets incorrect
  MintRedeemer values; 3.2.1 Medium — sFRAX oracle freshness check.
  Recorded as known patterns for the Fraxtal-side vault that
  `RemoteMintRedeemHop` settles against; do not re-report against the
  2024 MintRedeemer. Staking/locker system, out of scope.
- **R9 Trail of Bits FXB/sFRAX/Oracles (Oct 2023):** FXB mint, sFRAX,
  frxETH redemption queue, oracles. No bridge/LayerZero finding
  (keyword hits are FRAX→FXB `mint()` only). Out of scope.
- **R10 Certora BAMM (Oct 2024):** 16 findings (3 Medium / 8 Low /
  5 Informational), all BAMM lending/liquidation math + formal
  verification properties. No Hop/OFT content. Out of scope.
- **R11 Trail of Bits Fraxchain (Feb 2, 2024):** 1 finding total —
  TOB-FRAXCHAIN-1 error-prone administrator management in
  `SnapshotDistributor` (Informational). The OP-stack native bridge
  (`FraxchainPortal`, `YieldBoosterBridge` burn-and-mint/lock) was
  reviewed with **no bridge finding**. Native bridge ≠ LZ mesh.
  Out of scope.
- **R12 Fraxtal + VestedFXS + Flox (Frax Security Cartel, Apr 15,
  2024):** 19 findings (1 Critical / 2 High / 4 Medium / 3 Low /
  8 Informational + 1 gas), all addressed or acknowledged. Native
  OP-bridge items (NOT LZ mesh, NOT HopV2/OFT): 3.2.2 High — smart
  contract wallets bridging frxETH via `FraxchainPortal.bridgeFrxETH`
  lose all funds (L1↔L2 address aliasing); 3.3.3 Medium — contracts
  with failed frxETH deposits may be unable to access funds; 3.3.4
  Medium — Cross Domain Messenger delegation claimable to steal FXTL
  points; 3.4.1 Low — tokens minted on L2 could lead to bridge
  insolvency (mechanism class to keep in mind for OFT mintable-adapter
  supply accounting, but the finding itself is about the native
  bridge's L1 escrow and is excluded as stated); 3.5.2/3.5.4/3.5.5
  Informational portal/bridge notes. Out of scope.
- **R13 Fraxtal North Star (Frax Security Cartel, Mar 27, 2025)** —
  `dev-fraxchain-contracts @ ff6684ae`, CGT contracts. 10 findings
  (2 Critical / 3 Low / 4 Informational + 1 gas), all addressed or
  acknowledged. Native CGT-bridge items (NOT LZ mesh): 3.2.2 Low —
  current FRAX deposit/withdrawal methods should be blocked
  (`L1StandardBridge` FRAX bridging reverts on L2 mint); 3.3.1
  Informational — ERC20 bridge hardfork edge case (pre-hardfork L2→L1
  wfrxETH bridge leaves unexpected L2 bridge balance). The 2 Criticals
  (StorageSetter re-init in deploy scripts; frxETH approval drain) are
  hardfork-migration issues, not mesh issues. Out of scope.
- **R14 frxETH V2 (Frax Security Cartel, Mar 2024):** 19 findings
  (2 Critical / 3 High / 5 Medium / 6 Low / 3 Informational), all
  validator/AMO/interest-rate code. No hop/oft/layerzero/bridge
  content (single keyword hit was a false positive). Out of scope.

## Hunter quick-reference: what is NOT excluded

For the avoidance of doubt, the following HopV2/OFT surface has **no**
entry in this list (not previously reported in the 14 reports) and is
open hunting ground, subject to the bounty bar (demonstrated
theft-of-funds / permanent-freezing on current live deployments + working
mainnet-fork PoC):

- DVN configuration, `numDVNs` enforcement, `FraxDVN.sol`, peer wiring,
  enforced options, endpoint config (see Variant rule 4).
- `lzReceive`/`lzCompose` authentication and replay handling in non-Tempo
  `HopV2`/`RemoteHopV2` beyond the patterns in EX-H36/43 (check variants,
  don't re-report Tempo instances).
- `RemoteHopV2` trusted/untrusted composer handling (`srcEid`/`sender`
  overwrite logic — threat-modeled in R2 §5.10 with no finding raised).
- `FraxOFTMintableAdapterUpgradeable` remote-supply accounting
  (`SupplyTrackingModule`, `setInitialTotalSupply`) — tracked, but no
  finding in this set constrains it; note R12 3.4.1's insolvency class.
- `BatchSend`, AMOs (`EthereumLZCurveAMO`/`FraxtalLZCurveAMO`),
  `FraxtalLZCurveComposer`, `RemoteAdmin`/`FraxtalRemoteAdminRegistry`,
  `FraxOFTWalletUpgradeable`, Solana/Move OFT programs.
- Live-deployment-only issues: wrong peer/endpoint/DVN on a specific
  chain, stale implementation behind a proxy, uninitialized proxy, or a
  remediation commit (e.g. EX-H32/36/42/43/45 fixes) not yet deployed to
  a given chain's proxy — verify against live bytecode + proxy admin
  state; a fix that exists in git but not on-chain is a live finding,
  not a duplicate, if it meets the bounty bar.
- FPI: retired from the mesh per Frax docs (FPI OFTs can no longer be
  bridged) — do not hunt FPI bridge paths without first confirming live
  status.

## Methods & provenance

- PDFs extracted with `pdftotext -layout` to ephemeral `/tmp` text;
  findings/discussion sections read in full for R1–R4 (R4: findings
  §3 pp. 17–56, discussion §4, deployment inventory §6 pp. 496–505;
  threat-model §5 skimmed for status annotations). R5–R14: TOC +
  keyword grep (`hop|oft|layerzero|bridge|mint|redeem`, case-insensitive)
  + full read of every bridge-adjacent finding.
- Repo checks (read-only `git rev-parse`/`log`, `grep`, `ls`): HEAD
  hashes/dates, shallow-clone status, presence/absence of
  `MinterModule`, `RateLimiter*`, Tempo files, `setMessageProcessed`,
  `removeDust`, in-repo audit docs. No file in either target repo was
  modified; no commit, fetch, or push. Zero GitHub API calls.
- Web: one `browser.search` query (v1 RemoteHop audit hunt, see
  Retrieval gap 1). No page fetches, no team contact, no gist, no
  submission, no live transactions.
- Existing `exclusions/EXCLUSION_LIST.md` (Fraxlend's) was read for
  format conventions only and **not modified**.

*End of list — 50 entries (EX-H01–EX-H50).*
