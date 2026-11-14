# Filing precheck — HackenProof "Account Abstraction Bugs" (Ethereum Foundation)
Verified: 2026-11-14 ~16:30 WIB by live text fetch of https://hackenproof.com/programs/account-abstraction-bugs (page crawled 2026-11-14 09:07 UTC).

## Verdict: PASS (with one unverifiable item, recorded below)

## Verified program facts
- Scope: ONLY `core` and `utils` folders of eth-infinitism/account-abstraction + protocol (ERC-4337/7562) definitions. Attacks on any specific bundler, account or paymaster are OUT.
- Eligible commits (exact, verified against git tags — all four match):
  - v0.9.0 = b36a1ed52ae00da6f8a4c8d50181e2877e4fa410
  - v0.8.0 = 4cbc06072cdc19fd60f285c5997f4f7f57a588de
  - v0.7.0 = 7af70c8993a6f42973f520ae0752386a5032abe7
  - v0.6.0 = abff2aca61a8f0934e533d0d352978055fddbd96
  - "Code that is not present on either of these tags is not eligible."
- Cost: NO fee, credit, deposit, or purchase wording anywhere on the public program page. Submission is free. (The "Create a free researcher account" wording from the sweep was not re-observed on this fetch, but nothing contradicts free submission.)
- PoC: "You must send a clear textual description ... along with steps to reproduce the issue, include attachments such as screenshots or proof of concept code as necessary." Foundry PoC expected per sweep; program rules say test on a private testnet wherever possible.
- Disclosure: report NO LATER THAN 24 HOURS after discovery, exclusively through hackenproof.com. No public disclosure (even partial) without consent. First reporter wins, including via audits/other channels.
- KYC: "In case that your finding is valid you will be asked for extra KYC verification to proceed with payments" — payout-only, not needed to audit or submit.
- Severity (program's own): Critical = EntryPoint bugs causing major financial damage / redeployment (exec without validation, stealing deposits/stakes). High = on-chain griefing/censorship of an ERC-4337 component. Medium = off-chain mempool DoS not solved by ERC-7562. Low = negligible financial damage/inconvenience.
- Out of scope: network-level DoS; attacks on specific bundler/account/paymaster implementations.
- Reputation gate: NOTHING on the public program page mentions a reputation minimum or researcher-score gate. Status remains UNVERIFIED (dashboard-gated).

## Unverifiable without account creation (forbidden by task order)
- The live submit form lives behind login at dashboard.hackenproof.com. It could NOT be opened without creating a HackenProof researcher account, which the task order forbids. Re-check the live form on filing day (per skill) — including any reputation gate and the exact asset list — before submitting anything.

## 24-hour clock warning
If this audit confirms a finding, the 24-hour disclosure clock starts at discovery. The parent must decide on filing promptly; the discovery timestamp must be recorded in the report.
