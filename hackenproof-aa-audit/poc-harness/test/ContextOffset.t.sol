// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "account-abstraction/contracts/core/EntryPoint.sol";
import "account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import "account-abstraction/contracts/core/Helpers.sol";

/// Minimal account fixture: returns a configurable validationData, ignores signature.
/// Used ONLY as a test fixture; not part of the audit target.
contract MockAccount is IAccount {
    uint256 public validationDataToReturn;
    IEntryPoint public immutable ep;

    constructor(IEntryPoint _ep) {
        ep = _ep;
    }

    function setValidationData(uint256 vd) external {
        validationDataToReturn = vd;
    }

    function validateUserOp(
        PackedUserOperation calldata,
        bytes32,
        uint256 missingAccountFunds
    ) external override returns (uint256 validationData) {
        require(msg.sender == address(ep), "only EP");
        if (missingAccountFunds > 0) {
            ep.depositTo{value: missingAccountFunds}(address(this));
        }
        return validationDataToReturn;
    }

    receive() external payable {}
}

contract ContextOffsetTest is Test {
    EntryPoint ep;
    MockAccount acct1;
    MockAccount acct2;
    address payable beneficiary = payable(address(0xBEEF));

    function setUp() public {
        vm.warp(1_700_000_000);
        ep = new EntryPoint();
        acct1 = new MockAccount(ep);
        acct2 = new MockAccount(ep);
        // Pre-fund deposits so missingAccountFunds == 0.
        ep.depositTo{value: 1 ether}(address(acct1));
        ep.depositTo{value: 1 ether}(address(acct2));
    }

    function _packUints(uint256 high, uint256 low) internal pure returns (bytes32) {
        return bytes32((high << 128) | low);
    }

    function _mkOp(address sender, uint256 nonce) internal view returns (PackedUserOperation memory op) {
        op.sender = sender;
        op.nonce = nonce;
        op.initCode = "";
        op.callData = "";
        op.accountGasLimits = _packUints(500_000, 100_000);
        op.preVerificationGas = 50_000;
        op.gasFees = _packUints(1 gwei, 10 gwei);
        op.paymasterAndData = "";
        op.signature = "";
    }

    function _handle(PackedUserOperation[] memory ops) internal {
        // Satisfy nonReentrant: tx.origin == msg.sender == EOA.
        vm.prank(beneficiary, beneficiary);
        ep.handleOps(ops, beneficiary);
    }

    function test_paymasterless_zeroValidationData() public {
        acct1.setValidationData(0);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _mkOp(address(acct1), 0);
        uint256 benBefore = beneficiary.balance;
        _handle(ops);
        assertGt(beneficiary.balance, benBefore, "beneficiary not compensated");
        assertEq(ep.getNonce(address(acct1), 0), 1, "nonce not consumed");
    }

    function test_paymasterless_timeRangeValidationData() public {
        // Nonzero validationData: validUntil in the future. This is the H81
        // discriminator: validationData is left in scratch memory word 0 by
        // _callValidateUserOp; the no-paymaster context path must still work.
        uint256 vd = _packValidationData(false, uint48(block.timestamp + 1000), 0);
        acct1.setValidationData(vd);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _mkOp(address(acct1), 0);
        uint256 benBefore = beneficiary.balance;
        _handle(ops);
        assertGt(beneficiary.balance, benBefore, "beneficiary not compensated");
        assertEq(ep.getNonce(address(acct1), 0), 1, "nonce not consumed");
    }

    function test_bundle_mixedValidationData_timeRangeLast() public {
        acct1.setValidationData(0);
        uint256 vd = _packValidationData(false, uint48(block.timestamp + 1000), uint48(block.timestamp - 10));
        acct2.setValidationData(vd);
        PackedUserOperation[] memory ops = new PackedUserOperation[](2);
        ops[0] = _mkOp(address(acct1), 0);
        ops[1] = _mkOp(address(acct2), 0);
        uint256 benBefore = beneficiary.balance;
        _handle(ops);
        assertGt(beneficiary.balance, benBefore, "beneficiary not compensated");
        assertEq(ep.getNonce(address(acct1), 0), 1);
        assertEq(ep.getNonce(address(acct2), 0), 1);
    }

    function test_bundle_mixedValidationData_timeRangeFirst() public {
        uint256 vd = _packValidationData(false, uint48(block.timestamp + 1000), 0);
        acct1.setValidationData(vd);
        acct2.setValidationData(0);
        PackedUserOperation[] memory ops = new PackedUserOperation[](2);
        ops[0] = _mkOp(address(acct1), 0);
        ops[1] = _mkOp(address(acct2), 0);
        uint256 benBefore = beneficiary.balance;
        _handle(ops);
        assertGt(beneficiary.balance, benBefore, "beneficiary not compensated");
        assertEq(ep.getNonce(address(acct1), 0), 1);
        assertEq(ep.getNonce(address(acct2), 0), 1);
    }
}
