# Exclusion List — Safe Audit (check every candidate against these FIRST, by root cause)

Any candidate whose root cause overlaps an entry below is NOT a finding. Record the overlap in the
finding's exclusion check. "Fixed" statuses below describe the audit reports' final state; the
pinned code was verified by reading for the H-01/M1/W1 mechanisms (see notes). Variants with a
DIFFERENT root cause are not excluded — but the Hunter must state precisely how the root cause differs.

## A. Certora — Safenet Beta Staking (Jan 2026, commit e97ed617)
Source: exclusions/certora-safenet-staking.txt (full report text, 625 lines).
CRITICAL: Staking.sol is byte-identical between e97ed617 and the audited tag v0.1.0-rc.1 (0 diff lines).
Every finding below was evaluated against exactly this code.

- H-01 (High, Fixed in PR#123, fix confirmed): initiateWithdrawalAtPosition() missing withdrawal-node
  ownership validation → cross-queue insertion corrupts victim linked list → permanent fund lock.
  ROOT CAUSE: previousId not validated against the caller's own queue. VERIFIED in pinned code:
  withdrawalNodes is keyed per-staker AND withdrawal IDs come from one global counter, so a foreign
  previousId reads an empty node (claimableAt==0) and reverts InvalidPreviousId(). Mechanism absent.
- L-01 (Low, Acknowledged): single-step Ownable transfer risks permanent loss of admin control.
  ROOT CAUSE: Ownable vs Ownable2Step. Team response: owner is Safe DAO, scrutiny suffices. EXCLUDED.
- L-02 (Low, Acknowledged): renounceOwnership() can permanently orphan admin functions.
  ROOT CAUSE: inherited renounceOwnership. Team intentionally keeps it (DAO signaling). EXCLUDED.
- L-03 (Low, Fixed in PR#151, documented): proposeValidators() overwrites a pending validator
  proposal with no cancel function. ROOT CAUSE: no pending-proposal guard. Team: intentional,
  documented in NatSpec ("This will overwrite the existing pending proposal"). EXCLUDED.
- I-01 (Info, Fixed in PR#150, documented): staking allowed on validators pending deregistration.
  ROOT CAUSE: undocumented behavior. Now documented in stake() NatSpec. EXCLUDED.
- I-02 (Info, Acknowledged): proposeValidators() allows duplicate validators / conflicting flags.
  ROOT CAUSE: no duplicate check (owner-only, DAO scrutiny expected). EXCLUDED.
- I-03 (Info, Fixed in PR#147): claimWithdrawal() callable by anyone (claim on behalf of users).
  ROOT CAUSE: permissionless claim. VERIFIED in pinned code: claimWithdrawal() operates only on
  msg.sender's queue. Mechanism absent. EXCLUDED.
- I-04 (Info, Fixed in PR#148): staking contract itself could be proposed as a validator.
  ROOT CAUSE: only zero-address check. VERIFIED: proposeValidators rejects address(this). EXCLUDED.
- I-05 (Info, Acknowledged): no batch staking/withdrawal operations. Gas/UX. EXCLUDED (also gas scope).
- I-06 (Info, Fixed in PR#149): redundant SLOADs in initiateWithdrawal(). Gas only. EXCLUDED.
- I-07 (Info, Fixed): redundant mapping-hash computations. Gas only. EXCLUDED.

## B. Ackee — Social Recovery Module v0.1.0 (Jun 2024, commit 113d3c05 = pinned commit)
Source: exclusions/ackee-social-recovery.txt (full report text, 548 lines). Audit.md: "All discovered
findings were addressed." Report revision 1.1 describes the fixed state; pinned commit contains it.

- M1 (Medium, Fixed): other enabled modules could call GuardianStorage entrypoints (onlyModule
  checked isModuleEnabled(msg.sender), not identity) → arbitrary guardian/threshold changes →
  wallet takeover via recovery. ROOT CAUSE: storage contract trusted ANY enabled module.
  FIX: GuardianStorage is now inherited directly by SocialRecoveryModule; writes gated by
  onlyWhenModuleIsEnabled + msg.sender-keyed state. VERIFIED in pinned code: `contract
  SocialRecoveryModule is GuardianStorage`, no separate storage contract, no onlyModule modifier.
  EXCLUDED. (A variant requiring a DIFFERENT trust confusion must show a different root cause.)
- W1 (Warning, Fixed): confirmed hashes stay in storage across guardian-set changes within one
  nonce epoch (revoked-then-readded guardian's old confirmation still counts; threshold changes
  can lower the bar for stale confirmations). ROOT CAUSE: nonce only increments on recovery
  execution; no owner invalidation path. FIX: invalidateNonce() lets the owner increment the nonce
  and void the epoch. VERIFIED in pinned code: invalidateNonce() exists. The residual behavior
  (stale confirmations count until the owner invalidates) is the DOCUMENTED, accepted behavior
  with the mitigation in place. Re-reporting W1's exact scenario is EXCLUDED. A variant must show
  harm WITHOUT owner inaction as the sole precondition, or a bypass of the invalidation mechanism.

## C. Certora formal verification — Social Recovery (candide/certora/specs/*.spec)
Verified properties (rule names): storeHookPreservesInvariants, isGuardianDoesNotRevert,
sentinelCantBeGuardian, isGuardianInList, addGuardianChangesEntries, removeGuardianChangesGuardians,
addGuardianWorksAsExpected, guardianCanAlwaysBeAdded, addGuardianRevertPossibilities,
revokeGuardiansWorksAsExpected, guardianCanAlwaysBeRevoked, revokeGuardianRevertPossibilities,
confirmRecoveryCanAlwaysBeInitiatedByGuardian, confirmRecoveryIsInitiatedOnlyByGuardian,
disabledRecoveryModuleResultsInFinalizationRevert, guardiansCanInitiateRecoveryForAssignedAccount,
cancelRecovery, cancelRecoveryDoesNotAffectOtherWallet, finalizeRecovery, invalidatingNonceInRecovery.
A candidate contradicting a verified property must FIRST explain why the property does not cover it
(e.g. different precondition, harness assumption). Unverified paths are the hunting surface.

## D. Safe past bounties (docs.safefoundation.org/security/past-bounties) — all paid, all excluded
1. MultiSend library suicide via selfdestruct (Low, $1,000). 2. Safe cannot receive via transfer/send
   (gas/event edge, fixed). 3. Duplicate owners during setup render Safe unusable (Medium, $2,500).
4. Safe as its own owner reduces threshold by 1 (Medium, $5,000). 5. getModulesPaginated skips the
   `next` module (Low, $2,000). 6. checkNSignatures unbounded signature bytes → gas griefing via
   4337 (Low, $1,000). 7. Allowance Module nonce overflow → transfer replay after 65536 transfers
   (Medium, $30,000). None targets the two in-scope contracts, but shared mechanisms (linked-list
   pagination, nonce handling, signature-size handling) must be checked for root-cause overlap.

## E. Bounty scope exclusions (docs.safefoundation.org/security/bug-bounty)
- Gas optimizations. - Known issues in audits/docs. - Issues fixed in newer versions (note: Staking.sol
  identical across rc.1/rc.2/rc.3/beta, so no newer-version fix exists in the v0.1.0 line; for
  recovery, the pinned commit IS the audited/fixed commit). - Safe{Wallet} web/mobile/backend.
- Contracts/modules/libraries not listed (core Safe contracts, Allowance, 4337, Passkey are
  OUTSIDE this run's user order even though in bounty scope — do not expand scope).

## F. Intended behaviors documented in code (not findings)
- Staking: overwrite of pending validator proposals is intentional (NatSpec); staking on
  pending-deregistration validators is intentional (NatSpec); duplicates in proposeValidators are
  acknowledged; execute* functions are intentionally public; owner is trusted (Safe DAO).
- Recovery: finalizeRecovery is intentionally callable by anyone after the timelock; replacement
  of an ongoing request by strictly-more approvals is intentional; guardian confirmations persist
  within a nonce epoch until invalidated (W1 mitigation = owner action).
