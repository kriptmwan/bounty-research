// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import { MockERC20 } from "./MockERC20.sol";

/// @notice Minimal standard ERC-4626 vault: shares = assets * totalShares / totalAssets,
/// 1:1 when empty. Supports yield accrual (assets donated without shares) so the
/// exchange rate drifts above 1, exercising non-1:1 deposits.
contract MockERC4626 {
    MockERC20 public immutable asset;
    string public name = "Mock Vault";
    string public symbol = "mVault";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(MockERC20 asset_) {
        asset = asset_;
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets_) public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply == 0) return assets_;
        return assets_ * supply / totalAssets();
    }

    function convertToAssets(uint256 shares_) public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply == 0) return shares_;
        return shares_ * totalAssets() / supply;
    }

    function deposit(uint256 assets_, address receiver) external returns (uint256 shares) {
        shares = convertToShares(assets_);
        asset.transferFrom(msg.sender, address(this), assets_);
        totalSupply += shares;
        balanceOf[receiver] += shares;
    }

    /// @notice Simulate yield: donate assets to the vault without minting shares.
    function accrueYield(uint256 amount) external {
        asset.mint(address(this), amount);
    }
}
