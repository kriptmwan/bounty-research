# Bug Bounty Research Archive

A public-safe archive of bug bounty security research: audit reports,
methodology notes, scope documents, and proof-of-concept source for
completed audits. All work was read-only and local: no live exploitation,
no transactions, no interaction with production systems beyond read-only
verification reads.

## Method

Audits in this archive generally follow an adversarial pipeline: independent
Hunter passes, a Skeptic pass that re-verifies every claim against the pinned
source, and a Referee adjudication, with runnable local proofs for surviving
candidates. Target repositories are pinned by commit hash in the per-project
notes; only authored analysis is kept here, never vendored target code.

## Projects

| Project | Status |
|---|---|
| XE Network | Audit reports included cover filed public reports only; private-report and held-item material withheld |
| Curve (LlamaLend v2 periphery) | Filed, awaiting triage; finding details withheld |
| Hyperliquid | Audit complete; filing candidate withheld |
| Plether (Immunefi competition) | Sprint complete; submission skipped; findings withheld |
| DeXe Protocol | Audit complete; findings withheld (filing gated) |
| 1inch | Audit complete; finding withheld (filing gated) |
| Splits | Audited, no findings (two passes) |
| Vercel / better-auth | Audited, reports filed/closed, details withheld |
| Deriv | Reconnaissance and manual-test preparation; no findings filed |
| Cronos (VVS) | Audited, no findings |
| Hastra | Scoping only; track declined (fee) |
| Biconomy Nexus | Audited, no findings (four options) |
| Relay | Audit complete; findings withheld |
| Safe | Audit complete; finding filed and rejected; details withheld |
| Ticko | Scoping and test plan only; track skipped |
| Account Abstraction (HackenProof) | Audited, no findings |
| Frax | Fraxlend and FXB audited, no findings; HopV2/OFT finding withheld |

Program surveys and preparation notes that contain account identifiers were
withheld entirely rather than published in edited form.

## What is intentionally missing

Live, unfiled, or untriaged findings are intentionally excluded until they
are safe to publish. Nothing in this archive describes an undisclosed
vulnerability in a live system. `EXCLUDED.md` lists everything that was left
out and the generic reason for each exclusion.

## Layout

Each top-level directory is one engagement and keeps its original relative
structure: reports, scope notes, audit-pipeline artifacts (recon, triage,
skeptic/referee adjudication), and proof-of-concept source where the
engagement concluded with no findings. Target source code, dependencies,
build output, and credentials are never included.
