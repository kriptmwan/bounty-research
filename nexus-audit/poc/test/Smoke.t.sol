// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { EntryPoint } from "account-abstraction/core/EntryPoint.sol";
import { Nexus } from "contracts/Nexus.sol";
import { NexusProxy } from "contracts/utils/NexusProxy.sol";
import { NexusBootstrap } from "contracts/utils/NexusBootstrap.sol";
import { K1Validator } from "contracts/modules/validators/K1Validator.sol";

/// @notice Smoke test: proves the poc harness compiles the pinned Nexus code and
/// can deploy + initialize a Nexus account end to end. Scaffolding only — not a
/// finding. Mirrors the repo's own test setup (test/foundry/utils/TestHelper.t.sol).
contract SmokeTest is Test {
    address internal constant OWNER = address(0xBEEF);

    function test_InitializeAccountViaProxy() public {
        // 1. Deploy the default validator and a real EntryPoint v0.7.
        K1Validator validator = new K1Validator();
        EntryPoint entryPoint = new EntryPoint();

        // 2. Deploy the Nexus implementation. The constructor installs the default
        // validator on the implementation itself with an unusable owner, exactly
        // as the repo's tests do (abi.encodePacked sentinel address).
        Nexus implementation = new Nexus(
            address(entryPoint), address(validator), abi.encodePacked(address(0xeEeEeEeE))
        );

        // 3. Deploy the bootstrap contract with the same default validator.
        NexusBootstrap bootstrap =
            new NexusBootstrap(address(validator), abi.encodePacked(address(0xa11ce)));

        // 4. Build initData: abi.encode(bootstrap, bootstrapCall), where the
        // bootstrap call installs the default K1Validator with OWNER.
        bytes memory initData = abi.encode(
            address(bootstrap),
            abi.encodeCall(
                NexusBootstrap.initNexusWithDefaultValidator, (abi.encodePacked(OWNER))
            )
        );

        // 5. Deploy the proxy, running initializeAccount in the constructor.
        // NexusProxy sets the transient initializable flag first, so the
        // initializeAccount call passes requireInitializable().
        NexusProxy proxy = new NexusProxy(
            address(implementation), abi.encodeCall(Nexus.initializeAccount, (initData))
        );
        Nexus account = Nexus(payable(address(proxy)));

        // 6. Assertions: initialized, and the K1 owner is exactly OWNER.
        assertTrue(account.isInitialized(), "account not initialized");
        assertEq(validator.getOwner(address(account)), OWNER, "K1 owner mismatch");
    }

    /// @notice Harness-capability probe (not a finding): proves the EIP-7702
    /// delegation cheatcodes in forge-std 1.9.6 actually execute under forge
    /// 1.5.1. It does NOT prove end-to-end attachDelegation execution — later
    /// 7702/PREP POCs must verify that path themselves.
    function test_SignDelegationCheatcodeAvailable() public {
        (, uint256 aliceKey) = makeAddrAndKey("alice");
        address impl = address(0x1234);
        Vm.SignedDelegation memory d = vm.signDelegation(impl, aliceKey);
        assertEq(d.implementation, impl, "delegation implementation mismatch");
        assertLe(d.v, 1, "delegation v is not a y-parity bit");
    }
}
