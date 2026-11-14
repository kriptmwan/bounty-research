// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {SplitsWarehouse} from "splits-v2/SplitsWarehouse.sol";
import {PushSplit} from "splits-v2/splitters/push/PushSplit.sol";
import {PushSplitFactory} from "splits-v2/splitters/push/PushSplitFactory.sol";
import {SplitV2Lib} from "splits-v2/libraries/SplitV2.sol";

interface IHook {
    function onHook(address from, uint256 amount) external;
}

/// @notice ERC20 with an ERC777-style transfer hook: calls back into a registered
/// hook target after every `transfer` to it. Balances update BEFORE the hook fires.
contract HookToken {
    string public name = "Hook";
    string public symbol = "HOOK";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    address public hookTarget;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setHookTarget(address t) external {
        hookTarget = t;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _move(msg.sender, to, amount);
        if (to == hookTarget) IHook(to).onHook(msg.sender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        _move(from, to, amount);
        return true;
    }

    function _move(address from, address to, uint256 amount) internal {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}

/// @notice Distributor/recipient that reenters distribute() from the token hook.
/// Target is configured post-deployment so the contract can be a split recipient.
contract HookDistributor is IHook {
    PushSplit public split;
    SplitV2Lib.Split public splitParams;
    address public token;
    uint256 public maxDepth;
    uint256 public depth;

    constructor(uint256 _maxDepth) {
        maxDepth = _maxDepth;
    }

    function configure(PushSplit _split, SplitV2Lib.Split memory _params, address _token) external {
        split = _split;
        splitParams = _params;
        token = _token;
    }

    function onHook(address, uint256) external override {
        if (depth < maxDepth) {
            depth++;
            split.distribute(splitParams, token, address(this));
        }
    }
}

contract Hunt3Test is Test {
    SplitsWarehouse warehouse;
    PushSplitFactory factory;
    HookToken token;
    address constant ALICE = address(0xA11CE);
    address constant BOB = address(0xB0B);
    uint16 constant INCENTIVE = 65000;

    struct Outcome {
        uint256 distributorGain;
        uint256 aliceGain;
        uint256 bobGain;
        uint256 leftover;
    }

    function _fresh() internal {
        warehouse = new SplitsWarehouse("Ether", "ETH");
        factory = new PushSplitFactory(address(warehouse));
        token = new HookToken();
    }

    function _makeSplit(address[] memory recipients) internal returns (PushSplit split, SplitV2Lib.Split memory params) {
        uint256[] memory allocations = new uint256[](recipients.length);
        for (uint256 i; i < recipients.length; ++i) allocations[i] = 500_000;
        params = SplitV2Lib.Split(recipients, allocations, 1_000_000, INCENTIVE);
        split = PushSplit(factory.createSplit(params, address(this), address(this)));
    }

    function _fundSplitAndWarehouse(PushSplit split, uint256 splitAmt, uint256 warehouseAmt) internal {
        token.mint(address(split), splitAmt);
        token.mint(address(this), warehouseAmt);
        token.approve(address(warehouse), warehouseAmt);
        warehouse.deposit(address(split), address(token), warehouseAmt);
    }

    function _leftover(PushSplit split) internal view returns (uint256) {
        return token.balanceOf(address(split))
            + warehouse.balanceOf(address(split), uint256(uint160(address(token))));
    }

    function _runHook(uint256 fund, uint256 k) internal returns (Outcome memory o) {
        _fresh();
        address[] memory recipients = new address[](2);
        recipients[0] = ALICE;
        recipients[1] = BOB;
        (PushSplit split, SplitV2Lib.Split memory params) = _makeSplit(recipients);
        HookDistributor attacker = new HookDistributor(k);
        attacker.configure(split, params, address(token));
        token.setHookTarget(address(attacker));
        _fundSplitAndWarehouse(split, fund / 2, fund / 2);
        uint256 aliceBefore = token.balanceOf(ALICE);
        uint256 bobBefore = token.balanceOf(BOB);
        split.distribute(params, address(token), address(attacker));
        o.distributorGain = token.balanceOf(address(attacker));
        o.aliceGain = token.balanceOf(ALICE) - aliceBefore;
        o.bobGain = token.balanceOf(BOB) - bobBefore;
        o.leftover = _leftover(split);
    }

    function _runSequential(uint256 fund, uint256 calls) internal returns (Outcome memory o) {
        _fresh();
        address[] memory recipients = new address[](2);
        recipients[0] = ALICE;
        recipients[1] = BOB;
        (PushSplit split, SplitV2Lib.Split memory params) = _makeSplit(recipients);
        address distributorEOA = address(0xD15);
        _fundSplitAndWarehouse(split, fund / 2, fund / 2);
        uint256 aliceBefore = token.balanceOf(ALICE);
        uint256 bobBefore = token.balanceOf(BOB);
        for (uint256 i; i < calls; ++i) {
            split.distribute(params, address(token), distributorEOA);
        }
        o.distributorGain = token.balanceOf(distributorEOA);
        o.aliceGain = token.balanceOf(ALICE) - aliceBefore;
        o.bobGain = token.balanceOf(BOB) - bobBefore;
        o.leftover = _leftover(split);
    }

    /// @notice Hook-driven reentry gains no more than the same number of sequential calls.
    function testHookGrindBoundedBySequential() public {
        uint256 fund = 100 ether;
        Outcome memory r = _runHook(fund, 5);
        Outcome memory s = _runSequential(fund, 6);

        emit log_named_uint("hook attacker gain", r.distributorGain);
        emit log_named_uint("sequential distributor gain", s.distributorGain);

        assertLe(r.distributorGain, s.distributorGain + 1, "hook reentrancy amplified gain");
        assertEq(r.aliceGain, s.aliceGain, "alice gain differs");
        assertEq(r.bobGain, s.bobGain, "bob gain differs");
        assertEq(r.distributorGain + r.aliceGain + r.bobGain + r.leftover, fund, "conservation (hook)");
        assertEq(s.distributorGain + s.aliceGain + s.bobGain + s.leftover, fund, "conservation (sequential)");
    }

    /// @notice Attacker as FIRST recipient: the hook fires mid-loop, the reentrant
    /// distribution depletes the funds the outer loop still owes BOB, so the
    /// whole tx reverts and state is unchanged.
    function testMidLoopHookReentryRevertsAtomically() public {
        _fresh();
        HookDistributor attacker = new HookDistributor(3);
        address[] memory recipients = new address[](2);
        recipients[0] = address(attacker);
        recipients[1] = BOB;
        (PushSplit split, SplitV2Lib.Split memory params) = _makeSplit(recipients);
        attacker.configure(split, params, address(token));
        token.setHookTarget(address(attacker));
        _fundSplitAndWarehouse(split, 50 ether, 50 ether);

        uint256 splitBalBefore = token.balanceOf(address(split));
        uint256 warehouseBalBefore = warehouse.balanceOf(address(split), uint256(uint160(address(token))));
        uint256 bobBefore = token.balanceOf(BOB);

        vm.expectRevert();
        split.distribute(params, address(token), address(attacker));

        assertEq(token.balanceOf(address(split)), splitBalBefore, "split balance changed");
        assertEq(
            warehouse.balanceOf(address(split), uint256(uint160(address(token)))),
            warehouseBalBefore,
            "warehouse balance changed"
        );
        assertEq(token.balanceOf(BOB), bobBefore, "bob balance changed");
        assertEq(token.balanceOf(address(attacker)), 0, "attacker kept funds");
    }
}
