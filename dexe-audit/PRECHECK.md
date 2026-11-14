# PRECHECK — DeXe Protocol Smart Contracts (HackenProof)

**Program page:** https://hackenproof.com/programs/dexe-protocol-smart-contracts
**Fetched:** 2026-11-14 ~20:16 WIB (browser.open text fetch; page crawled 2026-11-14 12:54 UTC).
**Auditor:** subagent, audit + runnable proofs ONLY. No account created, no filing, no submission, no live testing.

## 1. Live-page verification (verbatim rules)

- Program description: "Is an innovative infrastructure of 50+ smart contracts for building and governing effective DAOs."
- Focus area links: whitepaper https://whitepaper.dexe.network/ , docs https://docs.dexe.network/
- Scope table: a single row — Target cell is **BLANK** (no repo URL, no commit, no address in the rendered table), Type "Smart Contract", Severity "Critical".
  - Consequence: the program page itself pins NO repository/commit. This audit pins the public repo
    `github.com/dexe-network/DeXe-Protocol` at HEAD `f09a3ba98c2e44c5c026667bb1a1495db74f6ee3`
    (2024-12-13, "Dev (#221)"), the repo the program page itself links for prior audits (see below).
    Any filing must re-confirm with the program which commit/addresses are in scope.

## 2. In-scope severity classes (verbatim)

Critical: governance-vote manipulation deviating from voted outcome; direct theft of user funds (at-rest or
in-motion, other than unclaimed yield); direct theft of user NFTs (other than unclaimed royalties);
permanent freezing of funds; permanent freezing of NFTs; unauthorized NFT minting; unintended alteration
of what an NFT represents; protocol insolvency.
High: theft/permanent freezing of unclaimed yield/royalties; temporary freezing of funds; temporary freezing of NFTs.
Medium: unauthorized transaction; smart contract unable to operate due to lack of token funds; griefing.
**Low severity issues are "Out of scope" and are not eligible for a bounty.**

## 3. Out-of-scope items material to this audit (verbatim, abridged)

- Theoretical vulnerabilities without proof/demonstration; old/unlocked compiler version; vulnerabilities
  in imported contracts; style/redundant code/gas; best-practice recommendations; feature requests.
- Impacts requiring leaked keys/credentials, privileged addresses (governance, strategist) except where
  contracts are intended to have no privileged access to the attacking functions; 51% / basic economic
  and governance attacks; Sybil attacks; centralization risks; lack of liquidity.
- Incorrect data from third-party oracles (oracle manipulation / flash-loan attacks NOT excluded).
- "We do not limit parameters of TokenSale proposal. Users may create proposals that will not ever end."
- "The project operates with NFTs that users may use to vote in DAOs. There is a possibility to hit an
  'unbounded loop' here. The protocol does not work with deflationary/rebasing tokens."
- "Lack of treasury tokens on DAO pool with voting rewards set."
- "DAOs created intentionally with exploitable ERC20/ERC721 tokens which as a result lead to exploitable DAOs"
- "Malcreated DAOs, for example with 100% quorum that make them unusable"
- "We are using SphereX on-chain protection, so some suspicious transactions may get reverted. This is expected behavior"
- **"Any issue that was described in the previous security audit reports"** — reports at
  https://github.com/dexe-network/DeXe-Protocol/tree/master/audits (see §6 dedup).

## 4. Payout / gates

- Critical: "10% of the funds directly affected up to a maximum of USD 500 000 in $DEXE with a 6-month
  linear vesting schedule." "Medium bounties are paid in stable, while high and critical bounties are paid in $DEXE."
- SphereX downgrade: "Each bounty for a potentially malicious transaction that can be reverted through the
  SphereX security system, whether it is qualified as Critical, High or Medium, will be estimated among the
  ranges of one level lower. But if a transaction can overcome our protection, and cause critical
  vulnerability it is rewarded as Critical."
- **Payout KYC (flagged, payout-only):** "In case that your finding is valid you might be asked for extra KYC
  verification to proceed with payments." No upfront KYC wording on the page.
- **Free submission proof (grade P):** no fee, credit, purchase, or token requirement anywhere in the full
  fetched program rules, eligibility, or disclosure text.
- **Reputation gate: UNVERIFIED.** No reputation minimum is stated on the public program page. HackenProof
  reputation gates are dashboard-gated; no account was created to check. Must be re-verified at filing time.
- No AI/automation-report ban wording on this program page (unlike the 1inch/Cronos pages).
- No deadline published — rolling program.

## 5. Disclosure rule (exact)

- "Any vulnerability found must be reported no later than 24 hours after discovery and exclusively through hackenproof.com"
- "You must be the first reporter of a vulnerability."
- "Do not discuss this program or any vulnerabilities (even resolved ones) outside of the program without
  express consent from the organization" / "No vulnerability disclosure, including partial is allowed for the moment."
- Report must include "a clear textual description of the report along with steps to reproduce the issue,
  include attachments such as screenshots or proof of concept code as necessary."
- **24-HOUR CLOCK WARNING:** the 24-hour reporting rule runs from discovery. If a filing decision is wanted,
  it must be made within 24h of the finding's discovery (discovery date for findings herein: 2026-11-14).
  This audit itself files nothing; the clock is the user's/filer's risk to manage.

## 6. Early dedup — prior audit reports (all in repo `audits/`)

Extracted with pdftotext to `evidence/audits/*.txt`. Reports: Certik 2023-05-04, Hacken 2023-05-22,
Ambisafe 2023-07-18, Ambisafe 2023-11-10, Cyfrin 2023-11-10, Ambisafe 2024-08-30.
Mechanisms described there are OUT of scope and were treated as NOT_A_BUG for filing (see REPORT.md dedup table).
Headline dedup items: TokenSaleProposal duplicate-tierIds drain (Ambisafe 5.3/5.5, fixed); flashloan +
delegation proposal execution (Cyfrin C-2, fixed); ERC721Power totalPower corruption incl. unminted-token
recalculate (Cyfrin C-3/H-6, Ambisafe-2 5.4, fixed); TokenSale decimals loss (Cyfrin C-1, fixed);
maxAllocationPerUser bypass (Cyfrin H-2, fixed); DistributionProposal reward dilution/stuck funds
(Cyfrin H-7, fixed); delegation bypass of voting restrictions (Cyfrin H-4, fixed); static totalPowerInTokens
quorum denominator (Cyfrin H-9/M-11, fixed); validator influence after power reduced to 0 (Cyfrin M-12,
ACKNOWLEDGED — still described, still out of scope); return-bomb execution DoS (Cyfrin M-14, acknowledged);
quorum semantics (Ambisafe 6.9, acknowledged); TokenAllocator closeAllocation balance clearing
(Ambisafe-2024 5.1/6.1); GovValidatorsToken snapshot/flashloan checks (Certik GUK-01/TPD-02/GPB-03).

## 7. Testing rules

- "Any testing on mainnet or public testnet deployed code [is prohibited]; all testing should be done on
  local-forks of either public testnet or mainnet." — This audit used local Foundry tests only, zero live calls.
- "Any testing with pricing oracles or third-party smart contracts" prohibited — no oracle/third-party testing done.
- No DoS, no automated traffic, no phishing/social engineering. None performed.

## PRECHECK VERDICT: PROCEED TO AUDIT (with caveats)

- Scope pin: WEAK — page table has a blank target; repo/commit pinned by auditor inference from the
  program's own audit link. Re-confirm before filing.
- Free submission: CONFIRMED on page text (grade P).
- Gates: payout-only KYC (flagged); SphereX one-level downgrade (applies to SphereX-revertible malicious
  transactions only); reputation gate UNVERIFIED (dashboard-gated, no account created).
- Disclosure: 24h + exclusive + no-disclosure rule — filing decision is time-sensitive once a finding is
  treated as discovered.
