// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {SplitsWarehouse} from "splits-v2/SplitsWarehouse.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract WarehouseHandler is Test {
    SplitsWarehouse public warehouse;
    MockERC20 public token;
    address public native;
    uint256 public nativeId;
    uint256 public erc20Id;

    address[] public actors;
    // Ghost accounting: expected total ERC6909 supply per token id.
    mapping(uint256 => uint256) public expectedSupply;

    uint256 public calls;
    uint256 public reverts;

    constructor(SplitsWarehouse _w, MockERC20 _t, address[] memory _actors) {
        warehouse = _w;
        token = _t;
        native = _w.NATIVE_TOKEN();
        nativeId = uint256(uint160(native));
        erc20Id = uint256(uint160(address(_t)));
        actors = _actors;
        token.mint(address(this), type(uint128).max);
        token.approve(address(warehouse), type(uint256).max);
    }

    function _actor(uint256 i) internal view returns (address) {
        return actors[i % actors.length];
    }

    function _tokenAddr(uint256 i) internal view returns (address) {
        return i % 2 == 0 ? native : address(token);
    }

    function _tokenId(address t) internal view returns (uint256) {
        return t == native ? nativeId : erc20Id;
    }

    // ---- actions ----

    function deposit(uint256 actorSeed, uint256 tokenSeed, uint256 amount) external {
        amount = bound(amount, 0, 10 ether);
        address receiver = _actor(actorSeed);
        address t = _tokenAddr(tokenSeed);
        uint256 id = _tokenId(t);
        if (t == native) {
            try warehouse.deposit{value: amount}(receiver, t, amount) {
                expectedSupply[id] += amount;
            } catch {
                reverts++;
            }
        } else {
            try warehouse.deposit(receiver, t, amount) {
                expectedSupply[id] += amount;
            } catch {
                reverts++;
            }
        }
        calls++;
    }

    function batchDeposit(uint256 tokenSeed, uint256 n, uint256 amount) external {
        n = bound(n, 1, 3);
        amount = bound(amount, 0, 5 ether);
        address t = _tokenAddr(tokenSeed);
        uint256 id = _tokenId(t);
        address[] memory receivers = new address[](n);
        uint256[] memory amounts = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            receivers[i] = actors[i % actors.length];
            amounts[i] = amount;
        }
        uint256 sum = amount * n;
        bool ok;
        if (t == native) {
            try warehouse.batchDeposit{value: sum}(receivers, t, amounts) {
                ok = true;
            } catch {
                reverts++;
            }
        } else {
            try warehouse.batchDeposit(receivers, t, amounts) {
                ok = true;
            } catch {
                reverts++;
            }
        }
        if (ok) expectedSupply[id] += sum;
        calls++;
    }

    function withdrawSingle(uint256 actorSeed, uint256 tokenSeed, bool asOwner) external {
        address owner = _actor(actorSeed);
        address t = _tokenAddr(tokenSeed);
        uint256 id = _tokenId(t);
        uint256 balBefore = warehouse.balanceOf(owner, id);
        uint256 ethBefore = owner.balance;
        uint256 tokBefore = token.balanceOf(owner);
        bool ok;
        if (asOwner) {
            vm.startPrank(owner);
            try warehouse.withdraw(owner, t) {
                ok = true;
            } catch {
                reverts++;
            }
            vm.stopPrank();
        } else {
            try warehouse.withdraw(owner, t) {
                ok = true;
            } catch {
                reverts++;
            }
        }
        if (ok) {
            // Leave-1: exactly 1 wei of ERC6909 balance remains (when balBefore >= 1).
            assertEq(warehouse.balanceOf(owner, id), 1, "leave-1 violated");
            uint256 burned = balBefore - 1;
            expectedSupply[id] -= burned;
            if (t == native) assertEq(owner.balance - ethBefore, burned, "eth payout mismatch");
            else assertEq(token.balanceOf(owner) - tokBefore, burned, "erc20 payout mismatch");
        }
        calls++;
    }

    struct Balances {
        uint256 ownerEth;
        uint256 ownerTok;
        uint256 wdEth;
        uint256 wdTok;
    }

    function _snapshot(address owner, address withdrawer) internal view returns (Balances memory b) {
        b.ownerEth = owner.balance;
        b.ownerTok = token.balanceOf(owner);
        b.wdEth = withdrawer.balance;
        b.wdTok = token.balanceOf(withdrawer);
    }

    function _assertBatchPayout(
        address owner,
        address withdrawer,
        address t,
        uint256 amount,
        uint256 reward,
        Balances memory before
    ) internal view {
        uint256 ownerExpected = withdrawer == owner ? amount : amount - reward;
        if (t == native) {
            assertEq(owner.balance - before.ownerEth, ownerExpected, "batch eth owner payout");
            if (withdrawer != owner) assertEq(withdrawer.balance - before.wdEth, reward, "batch eth reward");
        } else {
            assertEq(token.balanceOf(owner) - before.ownerTok, ownerExpected, "batch erc20 owner payout");
            if (withdrawer != owner) assertEq(token.balanceOf(withdrawer) - before.wdTok, reward, "batch erc20 reward");
        }
    }

    function withdrawBatch(uint256 actorSeed, uint256 tokenSeed, uint256 amount, uint256 withdrawerSeed) external {
        address owner = _actor(actorSeed);
        address t = _tokenAddr(tokenSeed);
        address withdrawer = _actor(withdrawerSeed);
        amount = bound(amount, 0, 10 ether);
        (uint16 incentive,) = warehouse.withdrawConfig(owner);
        uint256 reward = amount * incentive / 1e6;
        Balances memory before = _snapshot(owner, withdrawer);

        address[] memory tokens = new address[](1);
        tokens[0] = t;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        bool ok;
        try warehouse.withdraw(owner, tokens, amounts, withdrawer) {
            ok = true;
        } catch {
            reverts++;
        }
        if (ok) {
            expectedSupply[_tokenId(t)] -= amount;
            _assertBatchPayout(owner, withdrawer, t, amount, reward, before);
        }
        calls++;
    }

    function setConfig(uint256 actorSeed, uint16 incentive, bool paused) external {
        address owner = _actor(actorSeed);
        incentive = uint16(bound(incentive, 0, 1e6));
        vm.startPrank(owner);
        warehouse.setWithdrawConfig(SplitsWarehouse.WithdrawConfig(incentive, paused));
        vm.stopPrank();
        calls++;
    }

    function transfer6909(uint256 fromSeed, uint256 toSeed, uint256 tokenSeed, uint256 amount) external {
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        uint256 id = _tokenId(_tokenAddr(tokenSeed));
        amount = bound(amount, 0, 10 ether);
        vm.startPrank(from);
        try warehouse.transfer(to, id, amount) {} catch {
            reverts++;
        }
        vm.stopPrank();
        calls++;
    }

    function batchTransfer6909(uint256 fromSeed, uint256 tokenSeed, uint256 amount) external {
        address from = _actor(fromSeed);
        address t = _tokenAddr(tokenSeed);
        amount = bound(amount, 0, 5 ether);
        address[] memory receivers = new address[](2);
        receivers[0] = actors[0];
        receivers[1] = actors[1];
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;
        vm.startPrank(from);
        try warehouse.batchTransfer(receivers, t, amounts) {} catch {
            reverts++;
        }
        vm.stopPrank();
        calls++;
    }

    function approveAndTransferFrom(uint256 fromSeed, uint256 toSeed, uint256 tokenSeed, uint256 amount) external {
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        uint256 id = _tokenId(_tokenAddr(tokenSeed));
        amount = bound(amount, 0, 10 ether);
        vm.startPrank(from);
        warehouse.approve(address(this), id, amount);
        vm.stopPrank();
        try warehouse.transferFrom(from, to, id, amount) {} catch {
            reverts++;
        }
        calls++;
    }

    // ---- ghost helpers ----

    function sumBalances(uint256 id) external view returns (uint256 sum) {
        for (uint256 i; i < actors.length; ++i) {
            sum += warehouse.balanceOf(actors[i], id);
        }
        sum += warehouse.balanceOf(address(this), id);
        sum += warehouse.balanceOf(address(warehouse), id);
    }
}

contract WarehouseInvariantTest is Test {
    SplitsWarehouse warehouse;
    MockERC20 token;
    WarehouseHandler handler;

    function setUp() public {
        warehouse = new SplitsWarehouse("Ether", "ETH");
        token = new MockERC20();
        address[] memory actors = new address[](4);
        actors[0] = address(0xA1);
        actors[1] = address(0xA2);
        actors[2] = address(0xA3);
        actors[3] = address(0xA4);
        handler = new WarehouseHandler(warehouse, token, actors);
        vm.deal(address(handler), 1_000_000 ether);
        targetContract(address(handler));
    }

    function invariant_accountingIdentity() public view {
        uint256 nativeId = uint256(uint160(warehouse.NATIVE_TOKEN()));
        uint256 erc20Id = uint256(uint160(address(token)));
        assertEq(handler.sumBalances(nativeId), handler.expectedSupply(nativeId), "native accounting identity");
        assertEq(handler.sumBalances(erc20Id), handler.expectedSupply(erc20Id), "erc20 accounting identity");
    }

    function invariant_solvency() public view {
        uint256 nativeId = uint256(uint160(warehouse.NATIVE_TOKEN()));
        uint256 erc20Id = uint256(uint160(address(token)));
        assertGe(address(warehouse).balance, handler.expectedSupply(nativeId), "native insolvency");
        assertGe(token.balanceOf(address(warehouse)), handler.expectedSupply(erc20Id), "erc20 insolvency");
    }

    function invariant_noPhantomBalances() public view {
        // No actor can hold more than the total minted supply for the id.
        uint256 nativeId = uint256(uint160(warehouse.NATIVE_TOKEN()));
        uint256 erc20Id = uint256(uint160(address(token)));
        address[4] memory actors = [address(0xA1), address(0xA2), address(0xA3), address(0xA4)];
        for (uint256 i; i < 4; ++i) {
            assertLe(warehouse.balanceOf(actors[i], nativeId), handler.expectedSupply(nativeId));
            assertLe(warehouse.balanceOf(actors[i], erc20Id), handler.expectedSupply(erc20Id));
        }
    }
}
