// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PrelaunchPoints.sol";
import "../src/interfaces/ILpETH.sol";

import "./mock/AttackContract.sol";
import "./mock/MockLpETH.sol";
import "./mock/MockLpETHVault.sol";
import {ERC20Token} from "./mock/MockERC20.sol";

import "forge-std/console.sol";

contract PrelaunchPointsTest is Test {
    PrelaunchPoints public prelaunchPoints;
    AttackContract public attackContract;
    ILpETH public lpETH;
    ILpETHVault public lpETHVault;
    uint256 public constant INITIAL_SUPPLY = 1000 ether;
    bytes32 referral = bytes32(uint256(1));

    function setUp() public {
        prelaunchPoints = new PrelaunchPoints();
        lpETH = new MockLpETH();
        // lpETH.deposit{value: INITIAL_SUPPLY}(address(this));
        lpETHVault = new MockLpETHVault();

        attackContract = new AttackContract(prelaunchPoints);
    }

    /// ======= Tests for stake ======= ///
    function testStake(uint256 stakeAmount) public {
        vm.assume(stakeAmount > 0);
        vm.deal(address(this), stakeAmount);
        prelaunchPoints.stake{value: stakeAmount}(referral);

        assertEq(prelaunchPoints.balances(address(this)), stakeAmount);
        assertEq(prelaunchPoints.totalSupply(), stakeAmount);
    }

    function testStakeFailActivation(uint256 stakeAmount) public {
        vm.assume(stakeAmount > 0);
        // Should revert after setting the loop addresses
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));

        vm.deal(address(this), stakeAmount);
        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.stake{value: stakeAmount}(referral);
    }

    function testStakeFailZero() public {
        vm.expectRevert(PrelaunchPoints.CannotStakeZero.selector);
        prelaunchPoints.stake{value: 0}(referral);
    }

    /// ======= Tests for stakeFor ======= ///
    function testStakeFor(uint256 stakeAmount) public {
        vm.assume(stakeAmount > 0);
        address staker = address(0x1234);

        vm.deal(address(this), stakeAmount);
        prelaunchPoints.stakeFor{value: stakeAmount}(staker, referral);

        assertEq(prelaunchPoints.balances(staker), stakeAmount);
        assertEq(prelaunchPoints.totalSupply(), stakeAmount);
    }

    function testStakeForFailActivation(uint256 stakeAmount) public {
        vm.assume(stakeAmount > 0);
        address staker = address(0x1234);
        // Should revert after setting the loop addresses
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));

        vm.deal(address(this), stakeAmount);
        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.stakeFor{value: stakeAmount}(staker, referral);
    }

    function testStakeForFailZero() public {
        address staker = address(0x1234);

        vm.expectRevert(PrelaunchPoints.CannotStakeZero.selector);
        prelaunchPoints.stakeFor{value: 0}(staker, referral);
    }

    /// ======= Tests for convertAll ======= ///
    function testConvertAll(uint256 stakeAmount) public {
        stakeAmount = bound(stakeAmount, 1, 1e36);
        vm.deal(address(this), stakeAmount);
        prelaunchPoints.stake{value: stakeAmount}(referral);

        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));

        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAll();

        assertEq(prelaunchPoints.totalLpETH(), stakeAmount);
        assertEq(lpETH.balanceOf(address(prelaunchPoints)), stakeAmount);
        assertEq(prelaunchPoints.startClaimDate(), block.timestamp);
    }

    function testConvertAllFailActivation(uint256 stakeAmount) public {
        vm.assume(stakeAmount > 0);
        vm.deal(address(this), stakeAmount);
        prelaunchPoints.stake{value: stakeAmount}(referral);

        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));

        vm.expectRevert(PrelaunchPoints.LoopNotActivated.selector);
        prelaunchPoints.convertAll();
    }

    /// ======= Tests for claim ======= ///
    function testClaim(uint256 stakeAmount) public {
        stakeAmount = bound(stakeAmount, 1, 1e36);
        vm.deal(address(this), stakeAmount);
        prelaunchPoints.stake{value: stakeAmount}(referral);

        // Set Loop Contracts and Convert to lpETH
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAll();

        vm.warp(prelaunchPoints.startClaimDate() + 1);
        prelaunchPoints.claim();

        uint256 balanceLpETH = prelaunchPoints.totalLpETH() * stakeAmount / prelaunchPoints.totalSupply();

        assertEq(prelaunchPoints.balances(address(this)), 0);
        assertEq(lpETH.balanceOf(address(this)), balanceLpETH);
    }

    function testClaimSeveralUsers(uint256 stakeAmount, uint256 stakeAmount1, uint256 stakeAmount2) public {
        stakeAmount = bound(stakeAmount, 1, 1e36);
        stakeAmount1 = bound(stakeAmount1, 1, 1e36);
        stakeAmount2 = bound(stakeAmount2, 1, 1e36);

        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        vm.deal(address(this), stakeAmount);
        vm.deal(user1, stakeAmount1);
        vm.deal(user2, stakeAmount2);

        prelaunchPoints.stake{value: stakeAmount}(referral);
        vm.prank(user1);
        prelaunchPoints.stake{value: stakeAmount1}(referral);
        vm.prank(user2);
        prelaunchPoints.stake{value: stakeAmount2}(referral);

        // Set Loop Contracts and Convert to lpETH
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAll();

        vm.warp(prelaunchPoints.startClaimDate() + 1);
        prelaunchPoints.claim();

        uint256 balanceLpETH = prelaunchPoints.totalLpETH() * stakeAmount / prelaunchPoints.totalSupply();

        assertEq(prelaunchPoints.balances(address(this)), 0);
        assertEq(lpETH.balanceOf(address(this)), balanceLpETH);

        vm.prank(user1);
        prelaunchPoints.claim();
        uint256 balanceLpETH1 = prelaunchPoints.totalLpETH() * stakeAmount1 / prelaunchPoints.totalSupply();

        assertEq(prelaunchPoints.balances(user1), 0);
        assertEq(lpETH.balanceOf(user1), balanceLpETH1);
    }

    function testClaimFailTwice(uint256 stakeAmount) public {
        stakeAmount = bound(stakeAmount, 1, 1e36);
        vm.deal(address(this), stakeAmount);
        prelaunchPoints.stake{value: stakeAmount}(referral);

        // Set Loop Contracts and Convert to lpETH
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAll();

        vm.warp(prelaunchPoints.startClaimDate() + 1);
        prelaunchPoints.claim();

        vm.expectRevert(PrelaunchPoints.NothingToClaim.selector);
        prelaunchPoints.claim();
    }

    function testClaimFailBeforeConvert(uint256 stakeAmount) public {
        stakeAmount = bound(stakeAmount, 1, 1e36);
        vm.deal(address(this), stakeAmount);
        prelaunchPoints.stake{value: stakeAmount}(referral);

        // Set Loop Contracts and Convert to lpETH
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);

        vm.expectRevert(PrelaunchPoints.CurrentlyNotPossible.selector);
        prelaunchPoints.claim();
    }

    /// ======= Tests for claimAndStake ======= ///
    function testClaimAndStake(uint256 stakeAmount) public {
        stakeAmount = bound(stakeAmount, 1, 1e36);
        vm.deal(address(this), stakeAmount);
        prelaunchPoints.stake{value: stakeAmount}(referral);

        // Set Loop Contracts and Convert to lpETH
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAll();

        vm.warp(prelaunchPoints.startClaimDate() + 1);
        prelaunchPoints.claimAndStake();

        uint256 balanceLpETH = prelaunchPoints.totalLpETH() * stakeAmount / prelaunchPoints.totalSupply();

        assertEq(prelaunchPoints.balances(address(this)), 0);
        assertEq(lpETH.balanceOf(address(this)), 0);
        assertEq(lpETHVault.balanceOf(address(this)), balanceLpETH);
    }

    function testClaimAndStakeSeveralUsers(uint256 stakeAmount, uint256 stakeAmount1, uint256 stakeAmount2) public {
        stakeAmount = bound(stakeAmount, 1, 1e36);
        stakeAmount1 = bound(stakeAmount1, 1, 1e36);
        stakeAmount2 = bound(stakeAmount2, 1, 1e36);

        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        vm.deal(address(this), stakeAmount);
        vm.deal(user1, stakeAmount1);
        vm.deal(user2, stakeAmount2);

        prelaunchPoints.stake{value: stakeAmount}(referral);
        vm.prank(user1);
        prelaunchPoints.stake{value: stakeAmount1}(referral);
        vm.prank(user2);
        prelaunchPoints.stake{value: stakeAmount2}(referral);

        // Set Loop Contracts and Convert to lpETH
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAll();

        vm.warp(prelaunchPoints.startClaimDate() + 1);
        prelaunchPoints.claimAndStake();

        uint256 balanceLpETH = prelaunchPoints.totalLpETH() * stakeAmount / prelaunchPoints.totalSupply();

        assertEq(prelaunchPoints.balances(address(this)), 0);
        assertEq(lpETH.balanceOf(address(this)), 0);
        assertEq(lpETHVault.balanceOf(address(this)), balanceLpETH);

        vm.prank(user1);
        prelaunchPoints.claimAndStake();
        uint256 balanceLpETH1 = prelaunchPoints.totalLpETH() * stakeAmount1 / prelaunchPoints.totalSupply();

        assertEq(prelaunchPoints.balances(user1), 0);
        assertEq(lpETH.balanceOf(user1), 0);
        assertEq(lpETHVault.balanceOf(user1), balanceLpETH1);
    }

    function testClaimAndStakeFailTwice(uint256 stakeAmount) public {
        stakeAmount = bound(stakeAmount, 1, 1e36);
        vm.deal(address(this), stakeAmount);
        prelaunchPoints.stake{value: stakeAmount}(referral);

        // Set Loop Contracts and Convert to lpETH
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAll();

        vm.warp(prelaunchPoints.startClaimDate() + 1);
        prelaunchPoints.claim();

        vm.expectRevert(PrelaunchPoints.NothingToClaim.selector);
        prelaunchPoints.claimAndStake();
    }

    function testClaimAndStakeFailBeforeConvert(uint256 stakeAmount) public {
        stakeAmount = bound(stakeAmount, 1, 1e36);
        vm.deal(address(this), stakeAmount);
        prelaunchPoints.stake{value: stakeAmount}(referral);

        // Set Loop Contracts and Convert to lpETH
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);

        vm.expectRevert(PrelaunchPoints.CurrentlyNotPossible.selector);
        prelaunchPoints.claimAndStake();
    }

    /// ======= Tests for withdraw ======= ///
    receive() external payable {}

    function testWithdraw(uint256 stakeAmount) public {
        vm.assume(stakeAmount > 0);
        vm.deal(address(this), stakeAmount);
        prelaunchPoints.stake{value: stakeAmount}(referral);

        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + 1);
        prelaunchPoints.withdraw();

        assertEq(prelaunchPoints.balances(address(this)), 0);
        assertEq(prelaunchPoints.totalSupply(), 0);
        assertEq(address(this).balance, stakeAmount);
    }

    function testWithdrawFailBeforeActivation(uint256 stakeAmount) public {
        vm.assume(stakeAmount > 0);
        vm.deal(address(this), stakeAmount);
        prelaunchPoints.stake{value: stakeAmount}(referral);

        vm.expectRevert(PrelaunchPoints.CurrentlyNotPossible.selector);
        prelaunchPoints.withdraw();
    }

    function testWithdrawFailAfterConvert(uint256 stakeAmount) public {
        stakeAmount = bound(stakeAmount, 1, 1e36);
        vm.deal(address(this), stakeAmount);
        prelaunchPoints.stake{value: stakeAmount}(referral);

        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAll();

        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.withdraw();
    }

    function testWithdrawFailNotReceive(uint256 stakeAmount) public {
        vm.assume(stakeAmount > 0);
        vm.deal(address(lpETHVault), stakeAmount);
        vm.prank(address(lpETHVault)); // Contract withiut receive
        prelaunchPoints.stake{value: stakeAmount}(referral);

        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + 1);

        vm.prank(address(lpETHVault));
        vm.expectRevert(PrelaunchPoints.FailedToSendEther.selector);
        prelaunchPoints.withdraw();
    }

    /// ======= Tests for recoverERC20 ======= ///
    function testRecoverERC20() public {
        ERC20Token token = new ERC20Token();
        uint256 amount = 100 ether;
        token.mint(address(prelaunchPoints), amount);

        prelaunchPoints.recoverERC20(address(token), amount);

        assertEq(token.balanceOf(prelaunchPoints.owner()), amount);
        assertEq(token.balanceOf(address(prelaunchPoints)), 0);
    }

    function testRecoverERC20FailLpETH(uint256 amount) public {
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));

        vm.expectRevert(PrelaunchPoints.NotValidToken.selector);
        prelaunchPoints.recoverERC20(address(lpETH), amount);
    }

    /// ======= Tests for SetLoopAddresses ======= ///
    function testSetLoopAddressesFailTwice() public {
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));

        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
    }

    function testSetLoopAddressesFailAfterDeadline(uint256 stakeAmount) public {
        vm.assume(stakeAmount > 0);
        vm.deal(address(this), stakeAmount);
        prelaunchPoints.stake{value: stakeAmount}(referral);

        vm.warp(prelaunchPoints.loopActivation() + 1);

        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
    }

    /// ======= Tests for SetOwner ======= ///
    function testSetOwner() public {
        address user1 = vm.addr(1);
        prelaunchPoints.setOwner(user1);

        assertEq(prelaunchPoints.owner(), user1);
    }

    function testSetOwnerFailNotAuthorized() public {
        address user1 = vm.addr(1);
        vm.prank(user1);
        vm.expectRevert(PrelaunchPoints.NotAuthorized.selector);
        prelaunchPoints.setOwner(user1);
    }

    function testReentrancyOnWithdraw() public {
        uint256 stakeAmount = 1 ether;

        vm.deal(address(this), stakeAmount);
        vm.prank(address(this));
        prelaunchPoints.stake{value: stakeAmount}(referral);

        vm.warp(prelaunchPoints.loopActivation() + 1 days);
        vm.prank(address(attackContract));
        vm.expectRevert();
        attackContract.attackWithdraw();
    }

    function testReentrancyOnClaim() public {
        uint256 stakeAmount = 1 ether;

        vm.deal(address(this), stakeAmount);
        vm.prank(address(this));
        prelaunchPoints.stake{value: stakeAmount}(referral);

        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1 days);
        prelaunchPoints.convertAll();

        vm.warp(prelaunchPoints.startClaimDate() + 1 days);
        vm.prank(address(attackContract));
        vm.expectRevert();
        attackContract.attackClaim();
    }
}
