// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {SplitsWarehouse} from "splits-v2/SplitsWarehouse.sol";
import {PushSplit} from "splits-v2/splitters/push/PushSplit.sol";
import {PushSplitFactory} from "splits-v2/splitters/push/PushSplitFactory.sol";
import {SplitV2Lib} from "splits-v2/libraries/SplitV2.sol";

/// @notice A recipient that always rejects ETH: forces the warehouse-deposit fallback path.
contract Rejector {
    fallback() external payable {
        revert("no eth");
    }
}

/// @notice Distributor that reenters PushSplit.distribute from its receive() up to `maxDepth` times.
contract ReentrantDistributor {
    PushSplit public split;
    SplitV2Lib.Split public splitParams;
    address public token;
    uint256 public maxDepth;
    uint256 public depth;

    constructor(PushSplit _split, SplitV2Lib.Split memory _params, address _token, uint256 _maxDepth) {
        split = _split;
        splitParams = _params;
        token = _token;
        maxDepth = _maxDepth;
    }

    receive() external payable {
        if (depth < maxDepth) {
            depth++;
            split.distribute(splitParams, token, address(this));
        }
    }
}

/// @notice Distributor whose receive() tries to overdraw via the 5-arg distribute.
contract OverdraftDistributor {
    PushSplit public split;
    SplitV2Lib.Split public splitParams;
    address public token;
    bool public attempted;

    constructor(PushSplit _split, SplitV2Lib.Split memory _params, address _token) {
        split = _split;
        splitParams = _params;
        token = _token;
    }

    receive() external payable {
        if (!attempted) {
            attempted = true;
            // Try to distribute far more than the split holds, without a warehouse pull.
            split.distribute(splitParams, token, 1000 ether, false, address(this));
        }
    }
}

contract Hunt2Test is Test {
    SplitsWarehouse warehouse;
    PushSplitFactory factory;
    address constant ALICE = address(0xA11CE);
    uint16 constant INCENTIVE = 65000; // 6.5% max

    function _deploy() internal returns (PushSplit split, SplitV2Lib.Split memory params, Rejector rejector) {
        warehouse = new SplitsWarehouse("Ether", "ETH");
        factory = new PushSplitFactory(address(warehouse));
        rejector = new Rejector();

        address[] memory recipients = new address[](2);
        recipients[0] = ALICE;
        recipients[1] = address(rejector);
        uint256[] memory allocations = new uint256[](2);
        allocations[0] = 500_000;
        allocations[1] = 500_000;
        params = SplitV2Lib.Split(recipients, allocations, 1_000_000, INCENTIVE);
        address splitAddr = factory.createSplit(params, address(this), address(this));
        split = PushSplit(splitAddr);
    }

    function _fund(PushSplit split, uint256 amount) internal {
        (bool ok,) = address(split).call{value: amount}("");
        require(ok, "fund failed");
    }

    struct Outcome {
        uint256 distributorGain;
        uint256 aliceGain;
        uint256 rejectorWarehouse;
        uint256 leftover;
    }

    function _runReentrant(uint256 fund, uint256 k) internal returns (Outcome memory o) {
        (PushSplit split, SplitV2Lib.Split memory params, Rejector rej) = _deploy();
        ReentrantDistributor attacker = new ReentrantDistributor(split, params, warehouse.NATIVE_TOKEN(), k);
        _fund(split, fund);
        uint256 aliceBefore = ALICE.balance;
        split.distribute(params, warehouse.NATIVE_TOKEN(), address(attacker));
        o.distributorGain = address(attacker).balance;
        o.aliceGain = ALICE.balance - aliceBefore;
        uint256 tokenId = uint256(uint160(warehouse.NATIVE_TOKEN()));
        o.rejectorWarehouse = warehouse.balanceOf(address(rej), tokenId);
        o.leftover = address(split).balance + warehouse.balanceOf(address(split), tokenId);
    }

    function _runSequential(uint256 fund, uint256 calls) internal returns (Outcome memory o) {
        (PushSplit split, SplitV2Lib.Split memory params, Rejector rej) = _deploy();
        address distributorEOA = address(0xD15);
        _fund(split, fund);
        uint256 aliceBefore = ALICE.balance;
        for (uint256 i; i < calls; ++i) {
            split.distribute(params, warehouse.NATIVE_TOKEN(), distributorEOA);
        }
        o.distributorGain = distributorEOA.balance;
        o.aliceGain = ALICE.balance - aliceBefore;
        uint256 tokenId = uint256(uint160(warehouse.NATIVE_TOKEN()));
        o.rejectorWarehouse = warehouse.balanceOf(address(rej), tokenId);
        o.leftover = address(split).balance + warehouse.balanceOf(address(split), tokenId);
    }

    /// @notice Reentrant grinding must gain NO MORE than the same number of sequential
    /// permissionless distribute() calls, and honest recipients must be unaffected.
    function testReentrantGrindBoundedBySequential() public {
        uint256 fund = 100 ether;
        uint256 k = 5;

        Outcome memory r = _runReentrant(fund, k);
        Outcome memory s = _runSequential(fund, k + 1);

        emit log_named_uint("reentrant attacker gain", r.distributorGain);
        emit log_named_uint("sequential distributor gain", s.distributorGain);
        emit log_named_uint("alice gain reentrant", r.aliceGain);
        emit log_named_uint("alice gain sequential", s.aliceGain);
        emit log_named_uint("rejector warehouse reentrant", r.rejectorWarehouse);
        emit log_named_uint("rejector warehouse sequential", s.rejectorWarehouse);

        // Reentrancy grants no advantage over the permissionless sequential path (1 wei dust tolerance).
        assertLe(r.distributorGain, s.distributorGain + 1, "reentrancy amplified gain");
        // Honest recipient unaffected by the reentrancy.
        assertEq(r.aliceGain, s.aliceGain, "alice gain differs");
        // Failed recipient's funds remain claimable in the warehouse in both cases.
        assertEq(r.rejectorWarehouse, s.rejectorWarehouse, "rejector warehouse differs");
        // Conservation: everything is accounted for (leftovers are the 1-wei leave-1 + rounding dust).
        assertEq(r.distributorGain + r.aliceGain + r.rejectorWarehouse + r.leftover, fund, "conservation (reentrant)");
        assertEq(s.distributorGain + s.aliceGain + s.rejectorWarehouse + s.leftover, fund, "conservation (sequential)");
        assertLe(r.leftover, 10, "unexpected leftover");
    }

    /// @notice A reentrant overdraft attempt must revert the ENTIRE tx (atomicity), leaving state untouched.
    function testReentrantOverdraftRevertsAtomically() public {
        (PushSplit split, SplitV2Lib.Split memory params, Rejector rej) = _deploy();
        OverdraftDistributor attacker = new OverdraftDistributor(split, params, warehouse.NATIVE_TOKEN());
        _fund(split, 100 ether);

        uint256 splitBalBefore = address(split).balance;
        uint256 aliceBefore = ALICE.balance;
        address native = warehouse.NATIVE_TOKEN();
        uint256 rejWarehouseBefore = warehouse.balanceOf(address(rej), uint256(uint160(native)));

        vm.expectRevert();
        split.distribute(params, native, address(attacker));

        assertEq(address(split).balance, splitBalBefore, "split balance changed after revert");
        assertEq(ALICE.balance, aliceBefore, "alice balance changed after revert");
        assertEq(
            warehouse.balanceOf(address(rej), uint256(uint160(warehouse.NATIVE_TOKEN()))),
            rejWarehouseBefore,
            "rejector warehouse changed after revert"
        );
        assertEq(address(attacker).balance, 0, "attacker kept funds after revert");
        // Note: attacker.attempted() reads false here because the revert rolled
        // back the flag itself; the revert (expected above) + unchanged state
        // is the evidence. The same setup with a benign distributor succeeds
        // (see testReentrantGrindBoundedBySequential), so the reentrant
        // overdraft is what caused the revert.
    }
}
