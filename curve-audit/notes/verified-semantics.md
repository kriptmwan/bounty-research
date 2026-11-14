# Verified Vyper semantics (coordinator checks, titanoboa + vyper 0.4.3)

## convert(Bytes[32], uint256) on short input — VERIFIED 2026-11-13
Test: `boa.loads` contract with `convert(b, uint256)` for Bytes[32] inputs.
- 32-byte input ending 0x2a -> 42.
- 1-byte input b"\x01" -> 1 (no revert).
- 2-byte input b"\x01\x02" -> 258 (0x0102, big-endian, no revert).
- 0-byte input -> 0 (no revert).

Implication for HyperbolicDynamicMP `_target_rate`/`_target_rate_w`: a rate calculator
returning SHORT returndata with success=true does NOT revert the MP; the bytes are
interpreted big-endian and the result is clamped to [MIN_TARGET_RATE, MAX_TARGET_RATE].
The "non-reverting call cannot brick rate_write" design holds for short/malformed
returndata. A calculator returning garbage bytes yields a garbage-but-clamped rate,
not a revert. Any Hunter claim that short returndata bricks rate_write is DISPROVED
by this check.
