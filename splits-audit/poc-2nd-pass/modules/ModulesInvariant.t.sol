// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import { AutoEarnModule } from "src/AutoEarnModule.sol";
import { AutoEarnEnrollerModule } from "src/AutoEarnEnrollerModule.sol";
import { Call, ISmartVault } from "src/interfaces/ISmartVault.sol";
import { MockVault } from "./mocks/MockVault.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { MockERC4626 } from "./mocks/MockERC4626.sol";

/// @notice Invariant fuzz over the unaudited smart-vault-modules package.
/// Topology: TREASURY (owner = test) owns SUB (owner = treasury). OUTSIDER is owned
/// by the test and is NOT treasury-owned. The enroller is enabled on the treasury;
/// the earn module starts disabled everywhere and can only arrive via enroll or the
/// owner path.
contract ModulesInvariantTest is Test {
    MockERC20 asset;
    MockERC4626 vault;
    AutoEarnModule earn;
    AutoEarnEnrollerModule enroller;
    MockVault treasury;
    MockVault sub;
    MockVault outsider;
    ModulesHandler handler;

    function setUp() public {
        asset = new MockERC20();
        vault = new MockERC4626(asset);
        earn = new AutoEarnModule(address(asset), address(vault));
        enroller = new AutoEarnEnrollerModule(address(earn));
        treasury = new MockVault(address(this), address(0xE17));
        sub = new MockVault(address(treasury), address(0xE17));
        outsider = new MockVault(address(this), address(0xE17));

        // Owner enables the enroller on the treasury (the documented setup).
        treasury.execute(Call({target: address(treasury), value: 0, data: abi.encodeCall(ISmartVault.enableModule, (address(enroller)))}));

        handler = new ModulesHandler(asset, vault, earn, enroller, treasury, sub, outsider, address(this));
        targetContract(address(handler));
    }

    /// @notice Every minted asset is either in an account or in the vault; nothing is lost or created.
    function invariant_assetConservation() public view {
        uint256 held = asset.balanceOf(address(treasury)) + asset.balanceOf(address(sub))
            + asset.balanceOf(address(outsider)) + asset.balanceOf(address(vault));
        assertEq(held, asset.totalSupply(), "asset conservation");
    }

    /// @notice No account ever carries a leftover allowance to the vault (deposit approves exactly what it pulls).
    function invariant_noLeftoverAllowance() public view {
        assertEq(asset.allowance(address(treasury), address(vault)), 0, "treasury allowance");
        assertEq(asset.allowance(address(sub), address(vault)), 0, "sub allowance");
        assertEq(asset.allowance(address(outsider), address(vault)), 0, "outsider allowance");
    }

    /// @notice The earn module can never become enabled on the outsider (not treasury-owned).
    function invariant_outsiderNeverEnrolled() public view {
        assertFalse(outsider.isModuleEnabled(address(earn)), "outsider enrolled");
    }

    /// @notice Shares held by accounts are fully backed by vault assets.
    function invariant_sharesBacked() public view {
        uint256 shares = vault.balanceOf(address(treasury)) + vault.balanceOf(address(sub))
            + vault.balanceOf(address(outsider));
        assertEq(shares, vault.totalSupply(), "all shares held by accounts");
        assertGe(vault.totalAssets(), vault.convertToAssets(shares), "shares backed");
    }
}

contract ModulesHandler is Test {
    MockERC20 public asset;
    MockERC4626 public vault;
    AutoEarnModule public earn;
    AutoEarnEnrollerModule public enroller;
    MockVault public treasury;
    MockVault public sub;
    MockVault public outsider;
    address public treasuryOwner;

    uint256 public calls;
    uint256 public reverts;

    constructor(
        MockERC20 asset_,
        MockERC4626 vault_,
        AutoEarnModule earn_,
        AutoEarnEnrollerModule enroller_,
        MockVault treasury_,
        MockVault sub_,
        MockVault outsider_,
        address treasuryOwner_
    ) {
        asset = asset_;
        vault = vault_;
        earn = earn_;
        enroller = enroller_;
        treasury = treasury_;
        sub = sub_;
        outsider = outsider_;
        treasuryOwner = treasuryOwner_;
    }

    function _account(uint256 seed) internal view returns (MockVault) {
        uint256 i = seed % 3;
        if (i == 0) return treasury;
        if (i == 1) return sub;
        return outsider;
    }

    function fund(uint256 accountSeed, uint256 amount) external {
        MockVault acct = _account(accountSeed);
        amount = bound(amount, 0, 1000 ether);
        asset.mint(address(acct), amount);
        calls++;
    }

    function deposit(uint256 accountSeed, uint256 callerSeed) external {
        MockVault acct = _account(accountSeed);
        address caller = address(uint160(bound(callerSeed, 1, 100)));
        uint256 balBefore = asset.balanceOf(address(acct));
        uint256 sharesBefore = vault.balanceOf(address(acct));
        // Exact shares the vault will mint for this deposit (0 when the amount
        // rounds down against a yield-heavy vault — vault rounding, not a module bug).
        uint256 expectedShares = vault.convertToShares(balBefore);
        bool enabledBefore = acct.isModuleEnabled(address(earn));

        vm.prank(caller);
        try earn.deposit(ISmartVault(address(acct))) {
            if (enabledBefore && balBefore > 0) {
                // Full sweep: account drained, exactly the vault-computed shares credited.
                assertEq(asset.balanceOf(address(acct)), 0, "account not swept");
                assertEq(vault.balanceOf(address(acct)) - sharesBefore, expectedShares, "wrong shares minted");
                assertEq(asset.allowance(address(acct), address(vault)), 0, "leftover allowance");
            } else {
                // Disabled module or zero balance: no-op, state unchanged.
                assertEq(asset.balanceOf(address(acct)), balBefore, "balance changed on no-op");
                assertEq(vault.balanceOf(address(acct)), sharesBefore, "shares changed on no-op");
            }
        } catch {
            // Reverts are only legitimate when the module is not enabled on the account.
            assertFalse(enabledBefore, "deposit reverted while enabled");
            assertEq(asset.balanceOf(address(acct)), balBefore, "balance changed on revert");
            reverts++;
        }
        calls++;
    }

    function accrueYield(uint256 amount) external {
        amount = bound(amount, 0, 100 ether);
        vault.accrueYield(amount);
        calls++;
    }

    function enroll(uint256 accountSeed, uint256 callerSeed) external {
        MockVault acct = _account(accountSeed);
        address caller = address(uint160(bound(callerSeed, 1, 100)));
        bool enabledBefore = acct.isModuleEnabled(address(earn));
        bool enrollerEnabled = treasury.isModuleEnabled(address(enroller));
        bool allowed = address(acct) == address(treasury) || acct.owner() == address(treasury);

        vm.prank(caller);
        try enroller.enroll(ISmartVault(address(treasury)), ISmartVault(address(acct))) {
            // Success requires: allowed target, and (already enabled OR enroller enabled on treasury).
            assertTrue(allowed, "enroll succeeded on disallowed account");
            assertTrue(enabledBefore || enrollerEnabled, "enroll succeeded without enroller");
            assertTrue(acct.isModuleEnabled(address(earn)), "enroll did not enable");
        } catch {
            // Revert legitimate only when: disallowed, or not-yet-enabled while enroller disabled.
            assertTrue(!allowed || (!enabledBefore && !enrollerEnabled), "enroll reverted unexpectedly");
            assertEq(acct.isModuleEnabled(address(earn)), enabledBefore, "enabled flag changed on revert");
            reverts++;
        }
        calls++;
    }

    function toggleEnroller(uint256 enableSeed) external {
        // Owner path: prank the treasury owner, who toggles via execute.
        bool enable = enableSeed % 2 == 0;
        bytes memory data = enable
            ? abi.encodeCall(ISmartVault.enableModule, (address(enroller)))
            : abi.encodeCall(ISmartVault.disableModule, (address(enroller)));
        vm.prank(treasuryOwner);
        treasury.execute(Call({target: address(treasury), value: 0, data: data}));
        calls++;
    }
}
