// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "account-abstraction/contracts/core/EntryPoint.sol";
import "account-abstraction/contracts/core/EntryPointSimulations.sol";
import "account-abstraction/contracts/interfaces/IEntryPointSimulations.sol";
import "account-abstraction/contracts/interfaces/PackedUserOperation.sol";

contract MockAccount2 is IAccount {
    IEntryPoint public immutable ep;
    constructor(IEntryPoint _ep) { ep = _ep; }
    function validateUserOp(PackedUserOperation calldata, bytes32, uint256)
        external override returns (uint256) {
        require(msg.sender == address(ep), "only EP");
        return 0;
    }
    receive() external payable {}
}

/// Paymaster that returns hand-crafted returndata:
/// offset=64, validationData=0, contextLength=2**256-1, total 96 bytes.
/// If the AA35 size check overflows, it passes (expected size wraps to 96).
contract EvilPaymaster {
    function validatePaymasterUserOp(PackedUserOperation calldata, bytes32, uint256)
        external pure returns (bytes memory, uint256) {
        assembly ("memory-safe") {
            mstore(0, 64)
            mstore(32, 0)
            mstore(64, sub(0, 1))
            return(0, 96)
        }
    }
    function postOp(IPaymaster.PostOpMode, bytes calldata, uint256, uint256) external {}
}

contract H8OverflowTest is Test {
    EntryPointSimulations eps;
    MockAccount2 acct;
    EvilPaymaster pm;

    function setUp() public {
        vm.warp(1_700_000_000);
        eps = new EntryPointSimulations();
        acct = new MockAccount2(eps);
        pm = new EvilPaymaster();
        eps.depositTo{value: 1 ether}(address(acct));
        eps.depositTo{value: 1 ether}(address(pm));
    }

    function _mkOp() internal view returns (PackedUserOperation memory op) {
        op.sender = address(acct);
        op.nonce = 0;
        op.initCode = "";
        op.callData = "";
        op.accountGasLimits = bytes32((uint256(500_000) << 128) | uint256(100_000));
        op.preVerificationGas = 50_000;
        op.gasFees = bytes32((uint256(1 gwei) << 128) | uint256(10 gwei));
        op.paymasterAndData = abi.encodePacked(address(pm), uint128(200_000), uint128(100_000));
        op.signature = "";
    }

    /// Observe what simulateValidation does with the crafted paymaster.
    /// If the AA35 check passes (overflow), simulation must still fail
    /// (OOG/panic while encoding the giant context) — proving the bundler's
    /// simulation filter catches this input before any bundle is built.
    function test_simulateValidation_craftedPaymaster() public {
        PackedUserOperation memory op = _mkOp();
        try eps.simulateValidation(op) returns (IEntryPointSimulations.ValidationResult memory) {
            emit log("SIMULATION SUCCEEDED (unexpected)");
            fail();
        } catch (bytes memory reason) {
            emit log_named_bytes("simulation reverted, reason", reason);
        }
    }
}
