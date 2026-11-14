# Infra Hunter Coverage

Pinned HEADs verified before and after reading (working trees clean, read-only, nothing modified):
- order_book_server: `8b4f237904f683aca2dba21a07d87e831ead2a97`
- hyper-evm-sync: `d0945c699d9d4774417f4355b10744e7cd420df8`
- block-importer: `703f10ed0d49193161a53be7e34086c2117858e8`

## Files read (assigned, in full)

order_book_server (16/16 assigned):
- server/src/listeners/order_book/mod.rs
- server/src/listeners/order_book/state.rs
- server/src/listeners/order_book/utils.rs
- server/src/order_book/mod.rs
- server/src/order_book/multi_book.rs
- server/src/order_book/levels.rs
- server/src/order_book/linked_list.rs
- server/src/order_book/types.rs
- server/src/servers/websocket_server.rs
- server/src/listeners/directory.rs
- server/src/types/inner.rs
- server/src/types/mod.rs
- server/src/types/node_data.rs
- server/src/types/subscription.rs
- server/src/lib.rs
- binaries/src/bin/websocket_server.rs

hyper-evm-sync (9/9 assigned):
- src/run.rs, src/state.rs, src/fs.rs, src/types.rs, src/cli.rs, src/evm_map.rs, src/precompile.rs, src/main.rs, src/lib.rs

block-importer (2/2 assigned):
- src/main.rs, src/types.rs

Evidence-only reads outside the assigned set (no findings reported there):
- order_book_server server/src/prelude.rs, server/src/servers/mod.rs, server/src/listeners/mod.rs (context for Result/Error types and module wiring); Cargo.toml/Cargo.lock yawc version (0.2.6) via grep.

## Files skipped

- order_book_server/binaries/src/bin/example_client.rs — context-only per the task brief; not read, no findings. Nothing in the assigned files depended on it as evidence.

No assigned file was skipped for capacity reasons; all three repos were covered in full.

## Unresolved cross-references

1. yawc 0.2.6 frame-size, max-message, and connection limits — not verifiable (no yawc source on the VM, no cargo). Affects the exhaustion threshold of INF-7 only; the unbounded-subscription + per-snapshot fan-out code path is established.
2. yawc `IncomingUpgrade::upgrade()` failure modes — checked against public docs: the axum extractor validates the handshake before the handler runs, and the crate's own examples `.unwrap()` the upgrade. The `unwrap()` at websocket_server.rs:82 was NOT reported on that basis; a residual internal-error panic cannot be fully excluded for 0.2.6.
3. Node fill-batch pairing guarantee (even count, adjacent opposite-side fills) — undocumented in assigned files; INF-4's trigger precondition. Not traced to the node writer (out of scope).
4. Whether node-written files / snapshot output can contain negative/NaN px/sz strings or pre-epoch timestamps — INF-5's precondition; node output is trusted local input in the normal deployment. The related `unwrap()`s on timestamp conversion (state.rs convert_trigger call site, node_data.rs `block_time()`) were NOT reported: same trusted-input precondition, and the panic would be fail-loud in the listener task.
5. `notify` events with empty `paths` (`event.paths[0]` in listeners/order_book/mod.rs) — not verified against notify docs; not reported.
6. Overlapping `fetch_snapshot` tasks (10s ticker, `begin_caching` replaces the cache) — a race is plausible if a snapshot fetch takes >10s, but no timing evidence exists; not reported.
7. AbciState `state2` pre/post `latest_block2` semantics (types.rs `into_next_block_num_and_in_memory_db` returns `sealed_block.number`, not +1, while EvmState snapshots store block+1) — cannot be resolved from assigned files; if off by one, re-execution would fail loudly on the receipt assert, so not reported.
8. block-importer does not check `block.number == requested height` before indexing under the requested key — considered, not reported: requires misnamed files in an operator-supplied ingest dir.
9. hyper-evm-sync warm-precompile loop bound (`highest_precompile_address` from block files) and unbounded LZ4 decompression in both fs.rs decompressors — crafted/corrupt-file preconditions against a local operator tool; considered, not reported.
10. `Subscription::validate` accepting `@`-prefixed coins for Trades while L2Book/L4Book reject them — judged intentional (trades are event-driven; spot L2 books go stale when `ignore_spot` skips diffs); not reported.

## Static-only limitation

No cargo/rustc is installed on this VM and none was installed, per task boundaries. No code was built, run, or tested; no network calls were made to Hyperliquid services or nodes (one public-docs web search for yawc behavior only). Every finding is a static code trace: code behavior is quoted at file:line, but no runtime trigger was executed. Findings whose proof needs execution are marked "Static trace only" in their runtimeTrigger. Confidence scores reflect that gap, and low-confidence findings (INF-4, INF-5, INF-7) name their unresolved preconditions explicitly.

## Method notes

- Read order followed the brief: order_book_server fully, then hyper-evm-sync, then block-importer.
- Severity mapping follows the brief: auxiliary-server crash/corruption capped at High/Medium; no finding claims fund loss or L1 invariant violation. INF-1 is High as a feed-killing crash under normal concurrent load (partial reads are an anticipated condition in the code's own comment); the rest are Medium/Low.
- Checked and found clean (no finding): LinkedList insert/remove invariants, match_order progress (zero-size makers are removed, so no infinite loop), L2 re-bucketing chain incl. the mantissa-5 superset comment, `remove_triggers` tail-pop assumption (could not establish a concrete violation), `blake3_hash_slow` canonicalization, snapshot write/read round-trip shape, `pop_cache` synchronization (mismatches fail loudly via gap error + process exit), partial `apply_updates` application (all callers discard state / exit on error, so no corrupted state is served).
