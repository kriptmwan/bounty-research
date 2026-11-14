# Run Ledger — Curve LlamaLend v2 Periphery Audit

- **Order:** user picked "Opsi 1" 2026-11-13 13:37 WIB; audit + toolchain install authorized.
- **Target repo:** curve-stablecoin, `~/workspace/curve-audit/repos/curve-stablecoin`
- **Pinned HEAD:** `81b3bea490e9b45221c82e78387920ccfeb05b33` (verified 2026-11-13; clone deepened to full history, 3437 commits; HEAD unchanged after fetch).
- **Scope (files ONLY):** `curve_stablecoin/price_oracles/v2/**`, `curve_stablecoin/mpolicies/v2/**`, `curve_stablecoin/zaps/transient_leverage_zap/**`, `curve_stablecoin/factory/OwnerProxy.vy`, `curve_stablecoin/Configurator.vy`, `curve_stablecoin/ControllerView.vy` (~4,161 LOC by wc).
- **Context-only (read as evidence, never report):** `controller.vy`, `AMM.vy`, `lending/**`, `interfaces/**`, `tests/**`, `curve_std` (ema/token), `stableswap_ng` LPOracle module.
- **Out of scope:** crvUSD core, StableSwap-NG pool math, frontend, all other repos.
- **Bounty:** Curve bug bounty, email + responsible disclosure, up to $250k (likelihood x severity). Known vulnerabilities EXCLUDED.
- **Exclusion set (checked first):** Jul 2023 Vyper compiler bug; Mar 2026 sDOLA oracle attack (~822k crvUSD); Oct 2025 CRV-long bad debt; ChainSecurity LLV2 remediation commits `CS-CURVE-LLV2-002..109` (38 IDs in commit messages; 11 touch scoped files — see notes/exclusions.md); ChainlinkEMA upstream fixes (decimals-at-deploy, phase-decimals, dead next-phase fallback removal).
- **Toolchain (installed 2026-11-13, authorized):** `~/workspace/curve-audit/venv` — Python 3.12, vyper 0.4.3 (0.4.3+commit.bff19ea2), titanoboa @ ed81f209bc407fe4c990d4875dcd4106e976a27f, snekmate, curve-std @ 68a13eb2, boa-solidity @ main, stableswap-ng @ 3332cd44, pytest, hypothesis. Installed via `uv` 0.13.8 (`pip3 install --user --break-system-packages uv`).
- **Toolchain gap:** `factory/OwnerProxy.vy` is Vyper **0.3.10** (`# @version 0.3.10`), not 0.4.3. The 0.4.3 venv cannot compile it. A separate 0.3.10 venv is needed if an OwnerProxy POC is required.
- **Pipeline:** Recon (coordinator) -> 4 Hunters (oracles / mpolicies / zaps / admin+view) -> Skeptic per domain -> Referee -> titanoboa POCs for survivors -> consolidated report.
- **Boundaries:** local only. NO mainnet/testnet interaction, NO live RPC, NO transactions, NO filing, NO email, NO disclosure. Findings to parent only.
- **Time-box:** ~8 hours from 13:37 WIB. Priority: price_oracles/v2 + mpolicies/v2 first, then zaps/proxy.
