# Run ledger — Relay periphery audit (Option 2)

- Run date: 2026-11-13 (WIB). Coordinator session: periphery audit for the Relay bug bounty.
- Target repo: ~/workspace/relay-audit/repos/relay-periphery
- Pinned HEAD: e221935f54df03f9f73f2645ff688370a87033d8 ("fix: sweep ERC20 residue … (DEC-2400) (#77)", 2026-11-09). Verified 2026-11-13; tree clean.
- Scope: src/ ONLY, 2,004 LOC, 10 files (see triage.json). Excluded: lib/ (vendored deps, context-only), test/ (context-only), script/, deployments/ (evidence only), docs. Out of scope entirely: relay-settlement, relay-protocol-oracle, depositories, vaults.
- Mode: single-pass (default). No loop order. Coverage is reported honestly; partial coverage is stated as partial.
- Budgets: file budget = all 10 src files (2,004 LOC, fits one pass); source-token budget per chunk 48,000 est. tokens (upstream default); no oversized file.
- Toolchain: Foundry forge/cast 1.5.1 at ~/.foundry/bin (prepend to PATH in every shell). solc 0.8.28 via forge. Node v24, Python 3.12. VM ~1.5 shared CPUs — serialize forge builds/tests.
- Rules: LOCAL ONLY. No filing/email/submission. No live-chain interaction beyond read-only verification reads (eth_getCode, Sourcify). Never patch target code; never commit in the target checkout. Fixes described in reports only.
- Skills followed: adversarial_code_audit (Hunter→Skeptic→Referee, JSON artifacts), triage_validation (7-Question Gate on every Referee-confirmed finding), web3_audit (10 bug classes). SCOPE.md §3–§4 exclusion list is MANDATORY (Cantina 0203/0310, Certora, Zellic Settlement + Oracle, public issue #2 — KNOWN/DISCLOSED, never re-report; variants distinguished by root cause/version/deployment).
- Bounty terms applied: $500 floor only with demonstrated EXTERNAL (unprivileged) path; admin-only = S1 max; runnable PoC required S3/S4, strongly preferred S2; no safe harbor stated → local-only.

## Source baseline (sha256, captured 2026-11-13 before dispatch)

- src/RelayApprovalProxy.sol 668030fc9509f93911a6ef2606e56a78c2304be00beb5cee00b2fc153ca2a27f
- src/RelayRouter.sol 5782ae3365d3efe54e642511ff3a742b062dae05812874520c1cf341b289ed5f
- src/RelayRouter_NonTstore.sol 136fff75d690387ef303411ba3cf32af498dbcc36ad826ccb127feb2d3abe343
- src/common/IERC3009.sol 9e6d88b689df211a2e6a6734f0972084fe8c0f6a232972ab4b663bf07d6e6770
- src/common/Multicall3.sol 1e94bc7d757267e5bac565a8f43253073e3710b9a86b50d5806cf64562ddbf87
- src/common/Permits.sol 0c1176842f867f4aa14b0e0eb28989a768b8e5aa65c075f6f609506b08551d49
- src/common/ReentrancyGuardMsgSender.sol 6084a7f749b50382c5d20067d56d4cedab50e4a69207e92b37e478d694737d44
- src/common/ReentrancyGuardMsgSender_NonTstore.sol 1f9156feb1b5863314742251236c39c1d60374f2cd672a37a5c150c99633514f
- src/interfaces/IRelayRouter.sol bbff591e64788e9404af4d160c64510d4cd902690db4b7af49bf271fb4c1f359
- src/receiver/RelayReceiver.sol 8587ff04ba179b24ee028fb2bf96a19152c7fee12ee72a0775dd3a89196ed53c

Recheck hashes immediately before concluding; changed source fails the affected chunk closed.
