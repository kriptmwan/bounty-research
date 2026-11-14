// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {SplitsWarehouse} from "splits-v2/SplitsWarehouse.sol";
import {PushSplit} from "splits-v2/splitters/push/PushSplit.sol";
import {PushSplitFactory} from "splits-v2/splitters/push/PushSplitFactory.sol";
import {PullSplit} from "splits-v2/splitters/pull/PullSplit.sol";
import {PullSplitFactory} from "splits-v2/splitters/pull/PullSplitFactory.sol";
import {SplitV2Lib} from "splits-v2/libraries/SplitV2.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract DistributionFuzzTest is Test {
    SplitsWarehouse warehouse;
    PushSplitFactory pushFactory;
    PullSplitFactory pullFactory;
    MockERC20 token;
    address constant DISTRIBUTOR = address(0xD15);

    address[5] recipientsFixed = [address(0x1001), address(0x1002), address(0x1003), address(0x1004), address(0x1005)];

    function setUp() public {
        warehouse = new SplitsWarehouse("Ether", "ETH");
        pushFactory = new PushSplitFactory(address(warehouse));
        pullFactory = new PullSplitFactory(address(warehouse));
        token = new MockERC20();
    }

    function _buildSplit(uint256 n, uint256[5] memory allocSeeds, uint16 incentive)
        internal
        view
        returns (SplitV2Lib.Split memory params, uint256 total)
    {
        address[] memory recipients = new address[](n);
        uint256[] memory allocations = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            recipients[i] = recipientsFixed[i];
            allocations[i] = bound(allocSeeds[i], 0, 1_000_000);
            total += allocations[i];
        }
        vm.assume(total > 0);
        params = SplitV2Lib.Split(recipients, allocations, total, incentive);
    }

    function _expected(uint256 distAmount, SplitV2Lib.Split memory params)
        internal
        pure
        returns (uint256[] memory amounts, uint256 reward)
    {
        reward = distAmount * params.distributionIncentive / 1e6;
        uint256 toDistribute = distAmount - reward;
        amounts = new uint256[](params.recipients.length);
        for (uint256 i; i < amounts.length; ++i) {
            amounts[i] = toDistribute * params.allocations[i] / params.totalAllocation;
        }
    }

    function _distAmount(uint256 splitBal, uint256 warehouseBal) internal pure returns (uint256) {
        uint256 adjSplit = splitBal > 0 ? splitBal - 1 : 0;
        uint256 adjWh = warehouseBal > 0 ? warehouseBal - 1 : 0;
        return adjSplit + adjWh;
    }

    function _fundEth(address split, uint256 splitAmt, uint256 warehouseAmt) internal {
        if (splitAmt > 0) {
            (bool ok,) = split.call{value: splitAmt}("");
            require(ok, "fund split");
        }
        if (warehouseAmt > 0) {
            warehouse.deposit{value: warehouseAmt}(split, warehouse.NATIVE_TOKEN(), warehouseAmt);
        }
    }

    function _fundErc20(address split, uint256 splitAmt, uint256 warehouseAmt) internal {
        if (splitAmt > 0) {
            token.mint(split, splitAmt);
        }
        if (warehouseAmt > 0) {
            token.mint(address(this), warehouseAmt);
            token.approve(address(warehouse), warehouseAmt);
            warehouse.deposit(split, address(token), warehouseAmt);
        }
    }

    struct DistResult {
        uint256[] gains;
        uint256 rewardGain;
        uint256 leftover;
    }

    function _runPushEth(SplitV2Lib.Split memory params, uint256 n, uint256 splitAmt, uint256 whAmt)
        internal
        returns (DistResult memory r, uint256 distAmount, uint256[] memory expected, uint256 reward)
    {
        PushSplit split = PushSplit(pushFactory.createSplit(params, address(this), address(this)));
        _fundEth(address(split), splitAmt, whAmt);
        (uint256 splitBal, uint256 whBal) = split.getSplitBalance(warehouse.NATIVE_TOKEN());
        distAmount = _distAmount(splitBal, whBal);
        (expected, reward) = _expected(distAmount, params);
        uint256[] memory before = new uint256[](n);
        for (uint256 i; i < n; ++i) before[i] = recipientsFixed[i].balance;
        uint256 distBefore = DISTRIBUTOR.balance;
        split.distribute(params, warehouse.NATIVE_TOKEN(), DISTRIBUTOR);
        r.gains = new uint256[](n);
        for (uint256 i; i < n; ++i) r.gains[i] = recipientsFixed[i].balance - before[i];
        r.rewardGain = DISTRIBUTOR.balance - distBefore;
        r.leftover = address(split).balance
            + warehouse.balanceOf(address(split), uint256(uint160(warehouse.NATIVE_TOKEN())));
    }

    function _runPushErc20(SplitV2Lib.Split memory params, uint256 n, uint256 splitAmt, uint256 whAmt)
        internal
        returns (DistResult memory r, uint256 distAmount, uint256[] memory expected, uint256 reward)
    {
        PushSplit split = PushSplit(pushFactory.createSplit(params, address(this), address(this)));
        _fundErc20(address(split), splitAmt, whAmt);
        (uint256 splitBal, uint256 whBal) = split.getSplitBalance(address(token));
        distAmount = _distAmount(splitBal, whBal);
        (expected, reward) = _expected(distAmount, params);
        uint256[] memory before = new uint256[](n);
        for (uint256 i; i < n; ++i) before[i] = token.balanceOf(recipientsFixed[i]);
        uint256 distBefore = token.balanceOf(DISTRIBUTOR);
        split.distribute(params, address(token), DISTRIBUTOR);
        r.gains = new uint256[](n);
        for (uint256 i; i < n; ++i) r.gains[i] = token.balanceOf(recipientsFixed[i]) - before[i];
        r.rewardGain = token.balanceOf(DISTRIBUTOR) - distBefore;
        r.leftover = token.balanceOf(address(split))
            + warehouse.balanceOf(address(split), uint256(uint160(address(token))));
    }

    function _assertDist(DistResult memory r, uint256[] memory expected, uint256 reward, uint256 totalFunded) internal pure {
        uint256 accounted;
        for (uint256 i; i < expected.length; ++i) {
            assertEq(r.gains[i], expected[i], "recipient amount");
            accounted += expected[i];
        }
        assertEq(r.rewardGain, reward, "distributor reward");
        accounted += reward;
        assertEq(accounted + r.leftover, totalFunded, "conservation");
    }

    /// @notice Push/ETH: exact per-recipient amounts, exact reward, conservation.
    function testFuzz_PushEth(uint256 nSeed, uint256[5] memory allocSeeds, uint16 incentive, uint256 splitAmt, uint256 whAmt)
        public
    {
        uint256 n = bound(nSeed, 1, 5);
        (SplitV2Lib.Split memory params, ) = _buildSplit(n, allocSeeds, uint16(bound(incentive, 0, 65000)));
        splitAmt = bound(splitAmt, 0, 1000 ether);
        whAmt = bound(whAmt, 0, 1000 ether);
        (DistResult memory r,, uint256[] memory expected, uint256 reward) = _runPushEth(params, n, splitAmt, whAmt);
        _assertDist(r, expected, reward, splitAmt + whAmt);
    }

    /// @notice Push/ERC20: same exactness for token distributions.
    function testFuzz_PushErc20(uint256 nSeed, uint256[5] memory allocSeeds, uint16 incentive, uint256 splitAmt, uint256 whAmt)
        public
    {
        uint256 n = bound(nSeed, 1, 5);
        (SplitV2Lib.Split memory params, ) = _buildSplit(n, allocSeeds, uint16(bound(incentive, 0, 65000)));
        splitAmt = bound(splitAmt, 0, 1000 ether);
        whAmt = bound(whAmt, 0, 1000 ether);
        (DistResult memory r,, uint256[] memory expected, uint256 reward) = _runPushErc20(params, n, splitAmt, whAmt);
        _assertDist(r, expected, reward, splitAmt + whAmt);
    }

    /// @notice Pull/ETH: warehouse balances credited exactly; split keeps only the 1-wei crumbs.
    function testFuzz_PullEth(uint256 nSeed, uint256[5] memory allocSeeds, uint16 incentive, uint256 splitAmt, uint256 whAmt)
        public
    {
        uint256 n = bound(nSeed, 1, 5);
        (SplitV2Lib.Split memory params, ) = _buildSplit(n, allocSeeds, uint16(bound(incentive, 0, 65000)));
        splitAmt = bound(splitAmt, 0, 1000 ether);
        whAmt = bound(whAmt, 0, 1000 ether);
        PullSplit split = PullSplit(pullFactory.createSplit(params, address(this), address(this)));
        _fundEth(address(split), splitAmt, whAmt);
        (uint256 splitBal, uint256 whBal) = split.getSplitBalance(warehouse.NATIVE_TOKEN());
        (uint256[] memory expected, uint256 reward) = _expected(_distAmount(splitBal, whBal), params);
        split.distribute(params, warehouse.NATIVE_TOKEN(), DISTRIBUTOR);
        uint256 tokenId = uint256(uint160(warehouse.NATIVE_TOKEN()));
        DistResult memory r;
        r.gains = new uint256[](n);
        for (uint256 i; i < n; ++i) r.gains[i] = warehouse.balanceOf(recipientsFixed[i], tokenId);
        r.rewardGain = warehouse.balanceOf(DISTRIBUTOR, tokenId);
        r.leftover = address(split).balance + warehouse.balanceOf(address(split), tokenId);
        _assertDist(r, expected, reward, splitAmt + whAmt);
    }

    /// @notice 5-arg distribute with an amount above the available balance reverts (fail-closed).
    /// @dev Rounding dust (at most n-1 wei across n recipients) can absorb a tiny excess, so the
    /// excess is bounded to >= 5 (max n) to guarantee the transfer total exceeds the balance.
    /// A sub-dust excess succeeds and emits the caller-supplied amount while moving less; the
    /// split can never send more than it holds, so this is cosmetic, not a finding.
    function testFuzz_PushOverAmountReverts(uint256 nSeed, uint256[5] memory allocSeeds, uint256 splitAmt, uint256 excess)
        public
    {
        uint256 n = bound(nSeed, 1, 5);
        splitAmt = bound(splitAmt, 1, 100 ether);
        excess = bound(excess, 5, 100 ether);
        (SplitV2Lib.Split memory params, ) = _buildSplit(n, allocSeeds, 0);
        PushSplit split = PushSplit(pushFactory.createSplit(params, address(this), address(this)));
        _fundEth(address(split), splitAmt, 0);

        address native = warehouse.NATIVE_TOKEN(); // hoist: a call here would consume expectRevert
        vm.expectRevert();
        split.distribute(params, native, splitAmt + excess, false, DISTRIBUTOR);
    }

    /// @notice Extreme allocations overflow the multiplication and revert (fail-closed, no mis-distribution).
    function test_ExtremeAllocationsRevert() public {
        address[] memory recipients = new address[](1);
        recipients[0] = recipientsFixed[0];
        uint256[] memory allocations = new uint256[](1);
        allocations[0] = type(uint256).max;
        SplitV2Lib.Split memory params = SplitV2Lib.Split(recipients, allocations, type(uint256).max, 65000);
        PushSplit split = PushSplit(pushFactory.createSplit(params, address(this), address(this)));
        _fundEth(address(split), 3 ether, 0); // distAmount = 3e18-1 -> (3e18-1-reward) * type(uint256).max overflows
        address native = warehouse.NATIVE_TOKEN(); // hoist: a call here would consume expectRevert
        vm.expectRevert();
        split.distribute(params, native, DISTRIBUTOR);
    }
}
