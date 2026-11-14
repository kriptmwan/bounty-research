// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {SplitsWarehouse} from "splits-v2/SplitsWarehouse.sol";

/// @notice Reentrant withdrawer: on receiving ETH, reenters the batch withdraw
/// to try to multiply the incentive reward.
contract ReentrantWithdrawer {
    SplitsWarehouse public warehouse;
    address public owner;
    address public token;
    uint256 public reentries;
    uint256 public maxReentries;

    constructor(SplitsWarehouse warehouse_, address owner_, address token_, uint256 maxReentries_) {
        warehouse = warehouse_;
        owner = owner_;
        token = token_;
        maxReentries = maxReentries_;
    }

    receive() external payable {
        if (reentries < maxReentries) {
            reentries++;
            address[] memory tokens = new address[](1);
            tokens[0] = token;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = 1 ether;
            warehouse.withdraw(owner, tokens, amounts, address(this));
        }
    }
}

/// @notice Negative proof for sweep candidate H2-15: warehouse withdrawals burn
/// before sending (CEI), so reentrancy cannot multiply payouts or rewards.
/// A reentrant withdrawer gains exactly what the sequential permissionless path pays.
contract WarehouseReentrancyTest is Test {
    SplitsWarehouse warehouse;
    address constant OWNER = address(0x0A1);
    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public {
        warehouse = new SplitsWarehouse("Ether", "ETH");
    }

    function testReentrantBatchWithdrawEqualsSequential() public {
        uint256 fund = 100 ether;
        uint16 incentive = 65000; // 6.5%
        vm.prank(OWNER);
        warehouse.setWithdrawConfig(SplitsWarehouse.WithdrawConfig(incentive, false));
        vm.deal(OWNER, fund);
        vm.prank(OWNER);
        warehouse.deposit{value: fund}(OWNER, NATIVE, fund);

        // Sequential baseline: plain EOA withdrawer, 4 x 1 ether batch withdraws.
        address seqWithdrawer = address(0x5E9);
        for (uint256 i; i < 4; i++) {
            address[] memory tokens = new address[](1);
            tokens[0] = NATIVE;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = 1 ether;
            warehouse.withdraw(OWNER, tokens, amounts, seqWithdrawer);
        }
        uint256 seqGain = seqWithdrawer.balance;
        uint256 ownerBalAfterSeq = warehouse.balanceOf(OWNER, uint256(uint160(NATIVE)));

        // Fresh state for the reentrant run.
        SplitsWarehouse warehouse2 = new SplitsWarehouse("Ether", "ETH");
        vm.prank(OWNER);
        warehouse2.setWithdrawConfig(SplitsWarehouse.WithdrawConfig(incentive, false));
        vm.deal(OWNER, fund);
        vm.prank(OWNER);
        warehouse2.deposit{value: fund}(OWNER, NATIVE, fund);

        ReentrantWithdrawer attacker = new ReentrantWithdrawer(warehouse2, OWNER, NATIVE, 3);
        address[] memory tokens = new address[](1);
        tokens[0] = NATIVE;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;
        warehouse2.withdraw(OWNER, tokens, amounts, address(attacker));

        // 1 outer + 3 reentrant = 4 withdrawals of 1 ether, same as the baseline.
        assertEq(attacker.reentries(), 3, "expected 3 reentries");
        assertEq(address(attacker).balance, seqGain, "reentrant gain must equal sequential gain");
        assertEq(
            warehouse2.balanceOf(OWNER, uint256(uint160(NATIVE))), ownerBalAfterSeq, "owner balance must match baseline"
        );
        // Conservation in the reentrant run: warehouse balance owed to the owner
        // + ETH the owner received + ETH the attacker received == the funding.
        uint256 ownerBal2 = warehouse2.balanceOf(OWNER, uint256(uint160(NATIVE)));
        assertEq(ownerBal2 + OWNER.balance + address(attacker).balance, fund, "conservation");
    }

    function testReentrantSingleWithdrawCannotDoubleSpend() public {
        uint256 fund = 10 ether;
        vm.deal(OWNER, fund);
        vm.prank(OWNER);
        warehouse.deposit{value: fund}(OWNER, NATIVE, fund);

        // Single withdraw pays the owner (not the caller); a reentrant owner
        // contract can only withdraw the remaining balance-1 each time.
        ReentrantOwner ownerContract = new ReentrantOwner(warehouse, NATIVE, 3);
        vm.deal(address(ownerContract), fund);
        vm.prank(address(ownerContract));
        warehouse.deposit{value: fund}(address(ownerContract), NATIVE, fund);
        uint256 balBefore = address(ownerContract).balance;
        warehouse.withdraw(address(ownerContract), NATIVE);
        // Total received across the outer + reentrant calls == fund - 1 (leave-1).
        assertEq(address(ownerContract).balance - balBefore, fund - 1, "no double spend");
        assertEq(warehouse.balanceOf(address(ownerContract), uint256(uint160(NATIVE))), 1, "leave-1 remains");
    }
}

/// @notice Owner contract that reenters the single-owner withdraw on receive.
contract ReentrantOwner {
    SplitsWarehouse public warehouse;
    address public token;
    uint256 public reentries;
    uint256 public maxReentries;

    constructor(SplitsWarehouse warehouse_, address token_, uint256 maxReentries_) {
        warehouse = warehouse_;
        token = token_;
        maxReentries = maxReentries_;
    }

    receive() external payable {
        if (reentries < maxReentries) {
            reentries++;
            warehouse.withdraw(address(this), token);
        }
    }
}
