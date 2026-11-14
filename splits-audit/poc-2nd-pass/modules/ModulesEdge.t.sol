// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import { AutoEarnModule } from "src/AutoEarnModule.sol";
import { AutoEarnEnrollerModule } from "src/AutoEarnEnrollerModule.sol";
import { Call, ISmartVault } from "src/interfaces/ISmartVault.sol";
import { MockVault } from "./mocks/MockVault.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { MockERC4626 } from "./mocks/MockERC4626.sol";

/// @notice Targeted edge-case tests for the documented AutoEarnModule / AutoEarnEnrollerModule behaviors.
contract ModulesEdgeTest is Test {
    MockERC20 asset;
    MockERC4626 vault;
    AutoEarnModule earn;
    AutoEarnEnrollerModule enroller;
    MockVault treasury;
    MockVault sub;
    MockVault outsider;

    function setUp() public {
        asset = new MockERC20();
        vault = new MockERC4626(asset);
        earn = new AutoEarnModule(address(asset), address(vault));
        enroller = new AutoEarnEnrollerModule(address(earn));
        treasury = new MockVault(address(this), address(0xE17));
        sub = new MockVault(address(treasury), address(0xE17));
        outsider = new MockVault(address(this), address(0xE17));
        // Owner enables the enroller on the treasury (the documented setup).
        treasury.execute(
            Call({target: address(treasury), value: 0, data: abi.encodeCall(ISmartVault.enableModule, (address(enroller)))})
        );
    }

    function _disableOnTreasury(address module_) internal {
        treasury.execute(
            Call({target: address(treasury), value: 0, data: abi.encodeCall(ISmartVault.disableModule, (module_))})
        );
    }

    function test_EnrollTreasurySelf() public {
        enroller.enroll(ISmartVault(address(treasury)), ISmartVault(address(treasury)));
        assertTrue(treasury.isModuleEnabled(address(earn)));
    }

    function test_EnrollSubAccount() public {
        enroller.enroll(ISmartVault(address(treasury)), ISmartVault(address(sub)));
        assertTrue(sub.isModuleEnabled(address(earn)));
    }

    function test_EnrollOutsiderReverts() public {
        vm.expectRevert(AutoEarnEnrollerModule.NotOwnedByTreasury.selector);
        enroller.enroll(ISmartVault(address(treasury)), ISmartVault(address(outsider)));
        assertFalse(outsider.isModuleEnabled(address(earn)));
    }

    function test_EnrollUndeployedAccountReverts() public {
        ISmartVault ghost = ISmartVault(address(0x60A57));
        vm.expectRevert(AutoEarnEnrollerModule.AccountNotDeployed.selector);
        enroller.enroll(ISmartVault(address(treasury)), ghost);
    }

    function test_EnrollUndeployedTreasuryReverts() public {
        ISmartVault ghost = ISmartVault(address(0x60A57));
        vm.expectRevert(AutoEarnEnrollerModule.TreasuryNotDeployed.selector);
        enroller.enroll(ghost, ISmartVault(address(treasury)));
    }

    function test_EnrollAlreadyEnabledIsNoopEvenWithoutEnroller() public {
        // Enroll once, then disable the enroller on the treasury. Re-enroll must still
        // succeed (no-op path never calls the treasury).
        enroller.enroll(ISmartVault(address(treasury)), ISmartVault(address(sub)));
        _disableOnTreasury(address(enroller));
        assertFalse(treasury.isModuleEnabled(address(enroller)));
        enroller.enroll(ISmartVault(address(treasury)), ISmartVault(address(sub)));
        assertTrue(sub.isModuleEnabled(address(earn)));
    }

    function test_EnrollFreshRevertsWhenEnrollerDisabled() public {
        _disableOnTreasury(address(enroller));
        vm.expectRevert(MockVault.OnlyModule.selector);
        enroller.enroll(ISmartVault(address(treasury)), ISmartVault(address(sub)));
        assertFalse(sub.isModuleEnabled(address(earn)));
    }

    function test_DepositRevertsWhenModuleDisabled() public {
        asset.mint(address(sub), 100 ether);
        vm.expectRevert(MockVault.OnlyModule.selector);
        earn.deposit(ISmartVault(address(sub)));
        assertEq(asset.balanceOf(address(sub)), 100 ether);
    }

    function test_DepositZeroBalanceIsNoop() public {
        // Even with the module disabled, a zero balance returns silently (no vault call).
        earn.deposit(ISmartVault(address(sub)));
        assertEq(vault.balanceOf(address(sub)), 0);
    }

    function test_DepositSweepsFullBalanceAnyCaller() public {
        enroller.enroll(ISmartVault(address(treasury)), ISmartVault(address(sub)));
        asset.mint(address(sub), 123.456 ether);
        vm.prank(address(0xBEEF));
        earn.deposit(ISmartVault(address(sub)));
        assertEq(asset.balanceOf(address(sub)), 0);
        assertEq(vault.balanceOf(address(sub)), 123.456 ether);
        assertEq(asset.allowance(address(sub), address(vault)), 0);
    }

    function test_DepositAfterYieldCreditsAtCurrentRate() public {
        enroller.enroll(ISmartVault(address(treasury)), ISmartVault(address(sub)));
        asset.mint(address(sub), 100 ether);
        earn.deposit(ISmartVault(address(sub)));
        vault.accrueYield(100 ether); // 1 share now worth 2 assets
        asset.mint(address(sub), 100 ether);
        earn.deposit(ISmartVault(address(sub)));
        assertEq(vault.balanceOf(address(sub)), 150 ether); // 100 + 50
        assertEq(vault.convertToAssets(vault.balanceOf(address(sub))), 300 ether);
    }

    function test_ConstructorZeroAddressReverts() public {
        vm.expectRevert(AutoEarnModule.ZeroAddress.selector);
        new AutoEarnModule(address(0), address(vault));
        vm.expectRevert(AutoEarnModule.ZeroAddress.selector);
        new AutoEarnModule(address(asset), address(0));
        vm.expectRevert(AutoEarnEnrollerModule.ZeroAddress.selector);
        new AutoEarnEnrollerModule(address(0));
    }
}
