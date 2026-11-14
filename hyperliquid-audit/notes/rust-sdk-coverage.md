# Rust SDK Hunter — Coverage

- Target: `~/workspace/hyperliquid-audit/repos/hyperliquid-rust-sdk` at pinned HEAD `aac75585daf12d0a3761126cc7da7a5e035b5853` (verified before and after the pass; working tree clean, target unmodified).
- Mode: static review only (see limitation below). Python SDK checkout at `2fdb18f9517675ea03695a0962bd19eece9c83f0` read as cross-reference evidence only; no Python findings reported.
- Skills followed: `adversarial_code_audit` (Hunter §4, confidence §10) and `triage_validation` (7-Question Gate, prove-it discipline). Severities use the Hunter rubric tempered by the program context in the task (no finding is claimed Critical: none demonstrates significant loss of user funds or an L1 invariant violation on its own).
- Findings: 11 total — 5 Medium, 6 Low, 0 Critical, 0 High. See `rust-sdk-hunter-findings.json`.

## Files read (all assigned files, full reads)

CRITICAL:
- `src/eip712.rs` (18 lines), `src/signature/create_signature.rs` (103) — plus `src/signature/agent.rs` and `src/signature/mod.rs` as evidence (phantom-agent domain/struct; not in the assigned list, no findings reported there).
- `src/exchange/exchange_client.rs` (1167), `src/exchange/actions.rs` (293).

HIGH:
- `src/exchange/order.rs`, `src/exchange/builder.rs`, `src/exchange/cancel.rs`, `src/exchange/modify.rs`, `src/exchange/mod.rs`, `src/exchange/exchange_responses.rs`.
- `src/ws/ws_manager.rs` (497), `src/ws/message_types.rs`, `src/ws/sub_structs.rs` (plus `src/ws/mod.rs`).
- `src/info/info_client.rs` (323), `src/info/mod.rs`, `src/info/response_structs.rs`, `src/info/sub_structs.rs`.

HIGH/MEDIUM:
- `src/helpers.rs`, `src/meta.rs`, `src/consts.rs`, `src/errors.rs`, `src/req.rs`, `src/market_maker.rs` (330), `src/lib.rs` (plus `src/prelude.rs` as evidence).
- `Cargo.toml` (dependency/feature context only). Grep sweeps over `src/` (excluding `src/bin/`): `unsafe` (none found), `unwrap`/`expect`/`panic!`/`unreachable!`, `vault_address`, nonce helpers.

## Files skipped

- `src/bin/*` (all 30 example binaries): context-only per the task; never reported, not systematically read.
- No assigned file was skipped. Nothing was skipped for capacity; the full assigned set (4,155 lines) was covered.

## Cross-references checked against the Python SDK (evidence only)

- EIP-712 field order and type strings for UsdSend, SpotSend, Withdraw, SendAsset, ApproveAgent, ApproveBuilderFee: all match the Rust `struct_hash` implementations. L1 phantom-agent domain (name `Exchange`, version `1`, chain 1337, zero address) and `action_hash` construction (msgpack + big-endian nonce + vault byte) match.
- `update_isolated_margin` hardcodes `isBuy: true` in both SDKs — not a divergence, not reported.
- `float_to_wire` (Python) raises on >1e-12 rounding; Rust `float_to_string_for_hashing` silently rounds to 8 decimals. Not reported: harm not established (server tick validation bounds the effect).
- `float_to_int` (Python) raises on inexact conversion; Rust saturates — supports RS-7.
- Python `vault_usd_transfer` hashes with vault `None` and takes the vault address as a required parameter — supports RS-1.
- Python `send_asset` posts `vaultAddress: None` and `fromSubAccount` = raw vault string; Rust always posts `self.vault_address` and formats `from_sub_account` with `{:?}` on an `Address`. See unresolved items below.

## Unresolved cross-references (not reported as findings)

1. `approve_agent` posts `"agentName": null` when no name is given (Rust `Option<String>` without `skip_serializing_if`); Python signs with `""` and then deletes `agentName` from the posted action. Whether the server accepts `null` could not be determined without a network call — unresolved, not reported.
2. `send_asset` `from_sub_account` uses `format!("{vault_addr:?}")` on an alloy `Address`; the exact `Debug` rendering (checksummed vs lowercase) could not be verified without a toolchain, so a mismatch against the server's expected string is unresolved, not reported.
3. Rust `post()` always sends `vault_address: self.vault_address`, while Python sends `None` for `sendAsset`/`usdClassTransfer` actions. Server behavior on the extra vault context is unresolved, not reported.
4. Whether the Hyperliquid server accepts the RS-1 vault-hashed signature (funds to the wrong vault) or rejects it (failed call) is unresolved — RS-1 is scored Medium at confidence 72 for that reason.
5. `MarketMaker::place_order` treats a `Filled` status as a resting order (full amount). Harm depends on WS fill-event interleaving with the REST response and could not be established statically — considered, not reported.
6. `MarketMaker` `unreachable!()` arms in `attempt_cancel`/`place_order` and fills arriving before the first mid price being dropped (`continue` in `start`) depend on unobserved server-response shapes/timing — considered, not reported.
7. `market_close` with a zero-size position signs a zero-size reduce-only order; expected server rejection bounds the harm — considered, not reported.

## Static-only limitation

No cargo/rustc toolchain is installed (per task boundaries, none was installed). No code was built, run, or tested; no network calls were made to Hyperliquid services; no accounts, wallets, or filings were created. Every finding rests on a code trace plus a concrete runtime trigger stated in the JSON; each finding's `runtimeTrigger`/`evidence` states plainly where execution would be needed for proof (signature acceptance, server rejection behavior, deadlock/race timing, panic paths). Confidence scores are capped accordingly and no finding is presented as execution-verified.
