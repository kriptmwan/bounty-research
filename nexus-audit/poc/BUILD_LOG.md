# Nexus POC harness — build log

Scratch Foundry project for writing POCs against the pinned Nexus repo, WITHOUT
modifying the repo. Built 2026-11-13.

- Repo: `~/workspace/nexus-audit/repos/nexus`, `main` HEAD
  `9007ba1352e606575e32456512e25c41a9bf449c` (verified clean before and after;
  `git status --porcelain` empty at the end of this build).
- This project: `~/workspace/nexus-audit/poc/`
- Toolchain: forge 1.5.1 (`~/.foundry/bin/forge`, NOT on default PATH),
  solc 0.8.27 (provisioned automatically by forge on first build; no system
  solc is installed), EVM Prague, optimizer on, 777 runs, `via-ir = false`,
  `bytecode_hash = "none"` — mirroring the repo's `foundry.toml`.

## 1. How the repo code is referenced (read-only)

No files were copied out of the repo and no symlink was needed. The repo's
`contracts/` directory is pulled in via ONE absolute remapping in
`remappings.txt`:

```
contracts/=/home/hatch/workspace/nexus-audit/repos/nexus/contracts/
```

All other remappings are verbatim copies of the repo's `remappings.txt`,
pointing at this project's `node_modules/`. Relative imports inside the repo
files resolve against their real location, so the whole import closure works
unchanged. `src/Aggregator.sol` imports the four audit entry points
(`Nexus.sol`, `NexusBootstrap.sol`, `LibPREP.sol`, `K1Validator.sol`, plus
`NexusProxy.sol`) so `forge build` compiles them.

## 2. Exact commands run

All run from `~/workspace/nexus-audit/poc/` unless noted. Forge is NOT on the
default PATH; every forge command below was run with:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
```

### 2a. Scaffold

```bash
mkdir -p ~/workspace/nexus-audit/poc/src ~/workspace/nexus-audit/poc/test
```

Then `package.json`, `foundry.toml`, `remappings.txt`, and
`src/Aggregator.sol` were written by hand (see §3 for the dependency pins in
`package.json`).

### 2b. Dependencies — npm route (NOT `forge install`)

`forge install` was NOT used. The repo's dependency layout is npm-shaped
(`libs = ["node_modules", "lib"]`, remappings into `node_modules/`), and
several deps have transitive Solidity imports (e.g. `erc7739-validator-base`
imports `modulekit/`, `enumerableset4337/`, `@rhinestone/module-bases/`)
that only resolve via the npm tree + the nested `remappings.txt` files those
packages ship — exactly how the original repo builds. Replicating the npm
tree avoids hand-maintaining those transitive remappings.

```bash
cd ~/workspace/nexus-audit/poc
npm install --ignore-scripts --no-audit --no-fund
```

Result: exit 0, `added 690 packages in 20m`. It is SLOW (git clones of the
pinned repos + a very large transitive JS tree via `@rhinestone/modulekit`)
and prints only deprecation warnings. Do NOT kill it for being quiet — it
finishes. `node_modules/` is ~605M. `package-lock.json` (352 KB) records the
resolved tree; `npm ci` reproduces it. `--ignore-scripts` skips all install
scripts (nothing in the Solidity deps needs a build step).

No GitHub API calls were made anywhere in this build; network use was `npm`
fetching public packages/git repos plus forge fetching solc 0.8.27.

### 2c. Build

```bash
cd ~/workspace/nexus-audit/poc
export PATH="$HOME/.foundry/bin:$PATH"
forge build
```

First attempt FAILED for a poc-side config reason only: `remappings.txt`
contained `#` comment lines and forge rejected them
(`invalid remapping format, found '# Same remappings...', expected
'<key>=<value>'`). Fix: removed all comment lines from `remappings.txt`
(comments are NOT allowed in that file). No repo code was touched.

Second attempt: PASS. Clean rebuild (`forge clean && forge build`) also PASS.

### 2d. Smoke test

```bash
cd ~/workspace/nexus-audit/poc
export PATH="$HOME/.foundry/bin:$PATH"
forge test
```

## 3. Dependency pins resolved

From `package-lock.json` (every git pin matches the repo's `yarn.lock`
resolved commit exactly):

| Package | Version | Resolved commit / source |
|---|---|---|
| `@biconomy/composability` | 0.0.1 (tag `v1.1.0`) | `e22f8199dd48b9dbc04586d7334f11767d7b043d` |
| `@openzeppelin/contracts` | 5.1.0 | npm registry tarball (see note below) |
| `account-abstraction` | 0.7.0 (tag `v0.7.0`) | `7af70c8993a6f42973f520ae0752386a5032abe7` |
| `erc7579` | 0.3.1 | `2081c0f9dc31b2e054a91956968180ea3fccf307` |
| `erc7739-validator-base` | 0.1.1 (tag `v1.0.0`) | `d1e38493f58f28e62e12e41773086a90e8f60840` |
| `excessively-safe-call` | 0.0.1-rc.1 | `81cd99ce3e69117d665d7601c330ea03b97acce0` |
| `forge-std` | 1.9.6 (tag `v1.9.6`) | `3b20d60d14b343ee4f908cb8079495c07f5e8981` |
| `sentinellist` | 1.0.1 (tag `v1.0.0`) | `6dff696f39fb55bfdde9581544d788932f145e47` |
| `solady` | 0.1.9 (tag `v0.1.9`) | `1eb89b9af0a09468c6ccff51ce8ed5eb520b4fb5` |
| `solarray` | 1.0.0 | `6bf10cb34cdace52a3ba5fe437e78cc82df92684` (pinned to the yarn.lock commit; the repo's `package.json` leaves it floating) |

Transitive Solidity deps (resolved automatically by npm, versions match the
repo's yarn.lock): `@erc7579/enumerablemap4337` 1.0.0,
`@rhinestone/modulekit` 0.4.17, `@rhinestone/module-bases`,
`@rhinestone/sentinellist`, `ds-test`.

OpenZeppelin note: the repo's `package.json` does NOT pin OZ directly; it
arrives transitively. `yarn.lock` contains both 5.0.1 (pinned by
`@rhinestone/modulekit`-tree packages) and 5.1.0 (for `^5.0.0`, incl.
`account-abstraction`). This project pins the top-level copy to **5.1.0**;
npm nests 5.0.1 under the packages that require it exactly. The Nexus files
use only `Proxy`, `ERC1967Utils`, and `MessageHashUtils` from OZ, all
API-stable across 5.0.1 → 5.1.0, and the build passes. If a future POC hits
an OZ-behavior discrepancy, 5.0.1 is the alternative to try — but there is
currently no evidence of any difference.

## 4. Build result

```
Compiling 102 files with Solc 0.8.27
Solc 0.8.27 finished in 8.91s
Compiler run successful with warnings:
```

0 errors. 6 warnings, ALL pre-existing in repo code (never modified here):

- `Nexus.sol:192` — unused local variable `innerCallRet` (2072)
- `Nexus.sol:511` — unused parameter `newImplementation` (5667)
- `NexusBootstrap.sol:444` — three unused parameters + pure-mutability note
  (5667 x3, 2018)

## 5. Smoke-test result

`test/Smoke.t.sol` — `SmokeTest`, 2 tests, both PASS:

```
Ran 2 tests for test/Smoke.t.sol:SmokeTest
[PASS] test_InitializeAccountViaProxy() (gas: 13809620)
[PASS] test_SignDelegationCheatcodeAvailable() (gas: 6213)
Suite result: ok. 2 passed; 0 failed; 0 skipped
```

`test_InitializeAccountViaProxy` (the required end-to-end proof, mirroring
the repo's own `test/foundry/utils/TestHelper.t.sol` setup):

1. Deploys `K1Validator` + a real `EntryPoint` v0.7.
2. Deploys the `Nexus` implementation with the K1 validator as default
   validator and `abi.encodePacked(address(0xeEeEeEeE))` init data.
3. Deploys `NexusBootstrap` with the same default validator and
   `abi.encodePacked(address(0xa11ce))` init data.
4. Builds `initData = abi.encode(bootstrap, abi.encodeCall(
   NexusBootstrap.initNexusWithDefaultValidator, (abi.encodePacked(OWNER))))`.
5. Deploys `NexusProxy` with `abi.encodeCall(Nexus.initializeAccount,
   (initData))` as constructor data (the proxy sets the transient
   initializable flag, so `requireInitializable()` passes).
6. Asserts `account.isInitialized() == true` AND
   `validator.getOwner(account) == OWNER` (`0xBEEF`).

`test_SignDelegationCheatcodeAvailable` is a harness-capability probe: it
executes `vm.signDelegation` and checks the returned `SignedDelegation`
carries the requested implementation and a 0/1 y-parity `v`. See §7 caveats.

## 6. Instructions for the next worker: adding a POC test

1. Write the new test file under `test/`, e.g. `test/PocXxx.t.sol`.
   Import repo contracts via the `contracts/` prefix, deps via their
   remappings, exactly as `test/Smoke.t.sol` does:

   ```solidity
   // SPDX-License-Identifier: MIT
   pragma solidity ^0.8.27;

   import { Test } from "forge-std/Test.sol";
   import { Nexus } from "contracts/Nexus.sol";
   import { NexusProxy } from "contracts/utils/NexusProxy.sol";
   import { NexusBootstrap } from "contracts/utils/NexusBootstrap.sol";
   import { K1Validator } from "contracts/modules/validators/K1Validator.sol";
   ```

   Copy the deploy + initialize sequence from `Smoke.t.sol`
   (`test_InitializeAccountViaProxy`) as the starting point for any POC that
   needs an initialized account. Do NOT edit anything under
   `~/workspace/nexus-audit/repos/nexus/` — if a build error looks like a
   repo bug, stop and report it; fix only poc-side config.

2. Run ONLY the new test (fast iteration; full-suite runs recompile
   everything the first time):

   ```bash
   cd ~/workspace/nexus-audit/poc
   export PATH="$HOME/.foundry/bin:$PATH"
   forge test --match-contract <ContractName> -vvv
   ```

   Replace `<ContractName>` with the test contract name (e.g. `SmokeTest`).
   Add `--match-test <testFunction>` to run a single test function.

3. Run the whole suite before handing off:

   ```bash
   cd ~/workspace/nexus-audit/poc
   export PATH="$HOME/.foundry/bin:$PATH"
   forge test
   ```

4. If the build cache ever looks stale, `forge clean && forge build`
   reproduces a clean build in ~10s.

5. Before finishing ANY work in this project, verify the repo is untouched:

   ```bash
   cd ~/workspace/nexus-audit/repos/nexus && git status --porcelain
   ```

   Output must be EMPTY. Never run `forge build`, `forge test`, `npm`, or
   `git` write commands inside the repo checkout.

## 7. Caveats for POC writers

- **Prague EVM / transient storage: VERIFIED WORKING.** `foundry.toml` sets
  `evm_version = "prague"` and forge 1.5.1's test EVM honors it: the smoke
  test executes the `NexusProxy` constructor's `tstore` +
  `initializeAccount`'s `tload`-and-clear (`Initializable.requireInitializable`,
  the GHSA-q47q-h6x2-f5qg fix) successfully. Do not downgrade `evm_version`
  — transient storage (EIP-1153, Cancun+) is required, and Prague matches
  the repo config.
- **EIP-7702 cheatcodes: DECLARED + `signDelegation` EXECUTED, but
  end-to-end delegation NOT proven.** `forge-std` 1.9.6's `Vm.sol` declares
  `signDelegation`, `signAndAttachDelegation`, and `attachDelegation`
  (with the `SignedDelegation` struct), and `vm.signDelegation` runs
  correctly under forge 1.5.1 (proven by the second smoke test). No test in
  this scaffold calls `attachDelegation`/`signAndAttachDelegation` or
  executes a call through a delegated EOA — the first 7702/PREP POC must
  verify that path itself before relying on it.
- **`remappings.txt` takes NO comments.** A `#` line breaks config parsing
  (`invalid remapping format`). Keep it bare `<key>=<value>` lines only.
- **No `lib/` directory.** Dependencies live in `node_modules/` (npm route,
  §2b). Do not `forge install` into this project without checking for
  remapping conflicts first — auto-detected remappings from `lib/` could
  shadow the npm ones.
- **Gas numbers are large.** Deploying `EntryPoint` + implementation +
  proxy costs ~13.8M gas in the smoke test. That is normal for this
  codebase (the real `EntryPoint` is big); it is not a problem for local
  forge tests, which have no block gas limit by default.
- **Repo tests were NOT run.** Only this project's `src/` + `test/` were
  compiled. The repo's own `test/` tree (13k+ LOC, incl. fork tests) was
  never built here and must not be built inside the repo checkout.
