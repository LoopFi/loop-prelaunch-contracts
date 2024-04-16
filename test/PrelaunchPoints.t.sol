// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PrelaunchPoints.sol";
import "../src/interfaces/ILpETH.sol";

import "../src/mock/AttackContract.sol";
import "../src/mock/MockLpETH.sol";
import "../src/mock/MockLpETHVault.sol";
import {ERC20Token} from "../src/mock/MockERC20.sol";
import {LRToken} from "../src/mock/MockLRT.sol";

import "forge-std/console.sol";

contract PrelaunchPointsTest is Test {
    PrelaunchPoints public prelaunchPoints;
    AttackContract public attackContract;
    ILpETH public lpETH;
    LRToken public lrt;
    ILpETHVault public lpETHVault;
    uint256 public constant INITIAL_SUPPLY = 1000 ether;
    bytes32 referral = bytes32(uint256(1));

    address constant EXCHANGE_PROXY = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address[] public allowedTokens;

    function setUp() public {
        lrt = new LRToken();
        lrt.mint(address(this), INITIAL_SUPPLY);

        address[] storage allowedTokens_ = allowedTokens;
        allowedTokens_.push(address(lrt));

        prelaunchPoints = new PrelaunchPoints(EXCHANGE_PROXY, WETH, allowedTokens_);

        lpETH = new MockLpETH();
        lpETHVault = new MockLpETHVault();

        attackContract = new AttackContract(prelaunchPoints);
    }

    /// ======= Tests for lockETH ======= ///
    function testLockETH(uint256 lockAmount) public {
        vm.assume(lockAmount > 0);
        vm.deal(address(this), lockAmount);
        prelaunchPoints.lockETH{value: lockAmount}(referral);

        assertEq(prelaunchPoints.balances(address(this), ETH), lockAmount);
        assertEq(prelaunchPoints.totalSupply(), lockAmount);
    }

    function testLockETHFailActivation(uint256 lockAmount) public {
        vm.assume(lockAmount > 0);
        // Should revert after setting the loop addresses
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));

        vm.deal(address(this), lockAmount);
        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.lockETH{value: lockAmount}(referral);
    }

    function testLockETHFailZero() public {
        vm.expectRevert(PrelaunchPoints.CannotLockZero.selector);
        prelaunchPoints.lockETH{value: 0}(referral);
    }

    /// ======= Tests for lockETHFor ======= ///
    function testLockETHFor(uint256 lockAmount) public {
        vm.assume(lockAmount > 0);
        address recipient = address(0x1234);

        vm.deal(address(this), lockAmount);
        prelaunchPoints.lockETHFor{value: lockAmount}(recipient, referral);

        assertEq(prelaunchPoints.balances(recipient, ETH), lockAmount);
        assertEq(prelaunchPoints.totalSupply(), lockAmount);
    }

    function testLockETHForFailActivation(uint256 lockAmount) public {
        vm.assume(lockAmount > 0);
        address recipient = address(0x1234);
        // Should revert after setting the loop addresses
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));

        vm.deal(address(this), lockAmount);
        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.lockETHFor{value: lockAmount}(recipient, referral);
    }

    function testLockETHForFailZero() public {
        address recipient = address(0x1234);

        vm.expectRevert(PrelaunchPoints.CannotLockZero.selector);
        prelaunchPoints.lockETHFor{value: 0}(recipient, referral);
    }

    /// ======= Tests for lock ======= ///
    function testLock(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        lrt.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(address(lrt), lockAmount, referral);

        assertEq(prelaunchPoints.balances(address(this), address(lrt)), lockAmount);
    }

    function testLockailActivation(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        lrt.approve(address(prelaunchPoints), lockAmount);
        // Should revert after setting the loop addresses
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));

        vm.deal(address(this), lockAmount);
        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.lock(address(lrt), lockAmount, referral);
    }

    function testLockFailZero() public {
        vm.expectRevert(PrelaunchPoints.CannotLockZero.selector);
        prelaunchPoints.lock(address(lrt), 0, referral);
    }

    function testLockFailTokenNotAllowed(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        lrt.approve(address(prelaunchPoints), lockAmount);
        vm.expectRevert(PrelaunchPoints.TokenNotAllowed.selector);
        prelaunchPoints.lock(address(lpETH), lockAmount, referral);
    }

    /// ======= Tests for lockFor ======= ///
    function testLockFor(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        lrt.approve(address(prelaunchPoints), lockAmount);
        address recipient = address(0x1234);

        prelaunchPoints.lockFor(address(lrt), lockAmount, recipient, referral);

        assertEq(prelaunchPoints.balances(recipient, address(lrt)), lockAmount);
    }

    function testLockForFailActivation(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        address recipient = address(0x1234);
        // Should revert after setting the loop addresses
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));

        lrt.approve(address(prelaunchPoints), lockAmount);
        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.lockFor(address(lrt), lockAmount, recipient, referral);
    }

    function testLockForFailZero() public {
        address recipient = address(0x1234);

        vm.expectRevert(PrelaunchPoints.CannotLockZero.selector);
        prelaunchPoints.lockFor(address(lrt), 0, recipient, referral);
    }

    function testLockForFailTokenNotAllowed(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        lrt.approve(address(prelaunchPoints), lockAmount);
        address recipient = address(0x1234);

        vm.expectRevert(PrelaunchPoints.TokenNotAllowed.selector);
        prelaunchPoints.lockFor(address(lpETH), lockAmount, recipient, referral);
    }

    /// ======= Tests for convertAllETH ======= ///
    function testConvertAllETH(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        vm.deal(address(this), lockAmount);
        prelaunchPoints.lockETH{value: lockAmount}(referral);

        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));

        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllETH();

        assertEq(prelaunchPoints.totalLpETH(), lockAmount);
        assertEq(lpETH.balanceOf(address(prelaunchPoints)), lockAmount);
        assertEq(prelaunchPoints.startClaimDate(), block.timestamp);
    }

    function testConvertAllFailActivation(uint256 lockAmount) public {
        vm.assume(lockAmount > 0);
        vm.deal(address(this), lockAmount);
        prelaunchPoints.lockETH{value: lockAmount}(referral);

        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));

        vm.expectRevert(PrelaunchPoints.LoopNotActivated.selector);
        prelaunchPoints.convertAllETH();
    }

    /// ======= Tests for claim ETH======= ///
    bytes emptydata = new bytes(1);

    function testClaim(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        vm.deal(address(this), lockAmount);
        prelaunchPoints.lockETH{value: lockAmount}(referral);

        // Set Loop Contracts and Convert to lpETH
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllETH();

        vm.warp(prelaunchPoints.startClaimDate() + 1);
        prelaunchPoints.claim(ETH, 100, PrelaunchPoints.Exchange.UniswapV3, emptydata);

        uint256 balanceLpETH = prelaunchPoints.totalLpETH() * lockAmount / prelaunchPoints.totalSupply();

        assertEq(prelaunchPoints.balances(address(this), ETH), 0);
        assertEq(lpETH.balanceOf(address(this)), balanceLpETH);
    }

    function testClaimSeveralUsers(uint256 lockAmount, uint256 lockAmount1, uint256 lockAmount2) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        lockAmount1 = bound(lockAmount1, 1, 1e36);
        lockAmount2 = bound(lockAmount2, 1, 1e36);

        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        vm.deal(address(this), lockAmount);
        vm.deal(user1, lockAmount1);
        vm.deal(user2, lockAmount2);

        prelaunchPoints.lockETH{value: lockAmount}(referral);
        vm.prank(user1);
        prelaunchPoints.lockETH{value: lockAmount1}(referral);
        vm.prank(user2);
        prelaunchPoints.lockETH{value: lockAmount2}(referral);

        // Set Loop Contracts and Convert to lpETH
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllETH();

        vm.warp(prelaunchPoints.startClaimDate() + 1);
        prelaunchPoints.claim(ETH, 100, PrelaunchPoints.Exchange.UniswapV3, emptydata);

        uint256 balanceLpETH = prelaunchPoints.totalLpETH() * lockAmount / prelaunchPoints.totalSupply();

        assertEq(prelaunchPoints.balances(address(this), ETH), 0);
        assertEq(lpETH.balanceOf(address(this)), balanceLpETH);

        vm.prank(user1);
        prelaunchPoints.claim(ETH, 100, PrelaunchPoints.Exchange.UniswapV3, emptydata);
        uint256 balanceLpETH1 = prelaunchPoints.totalLpETH() * lockAmount1 / prelaunchPoints.totalSupply();

        assertEq(prelaunchPoints.balances(user1, ETH), 0);
        assertEq(lpETH.balanceOf(user1), balanceLpETH1);
    }

    function testClaimFailTwice(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        vm.deal(address(this), lockAmount);
        prelaunchPoints.lockETH{value: lockAmount}(referral);

        // Set Loop Contracts and Convert to lpETH
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllETH();

        vm.warp(prelaunchPoints.startClaimDate() + 1);
        prelaunchPoints.claim(ETH, 100, PrelaunchPoints.Exchange.UniswapV3, emptydata);

        vm.expectRevert(PrelaunchPoints.NothingToClaim.selector);
        prelaunchPoints.claim(ETH, 100, PrelaunchPoints.Exchange.UniswapV3, emptydata);
    }

    function testClaimFailBeforeConvert(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        vm.deal(address(this), lockAmount);
        prelaunchPoints.lockETH{value: lockAmount}(referral);

        // Set Loop Contracts and Convert to lpETH
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);

        vm.expectRevert(PrelaunchPoints.CurrentlyNotPossible.selector);
        prelaunchPoints.claim(ETH, 100, PrelaunchPoints.Exchange.UniswapV3, emptydata);
    }

    /// ======= Tests for claimAndStake ======= ///
    function testClaimAndStake(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        vm.deal(address(this), lockAmount);
        prelaunchPoints.lockETH{value: lockAmount}(referral);

        // Set Loop Contracts and Convert to lpETH
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllETH();

        vm.warp(prelaunchPoints.startClaimDate() + 1);
        prelaunchPoints.claimAndStake(ETH, 100, PrelaunchPoints.Exchange.UniswapV3, emptydata);

        uint256 balanceLpETH = prelaunchPoints.totalLpETH() * lockAmount / prelaunchPoints.totalSupply();

        assertEq(prelaunchPoints.balances(address(this), ETH), 0);
        assertEq(lpETH.balanceOf(address(this)), 0);
        assertEq(lpETHVault.balanceOf(address(this)), balanceLpETH);
    }

    function testClaimAndStakeSeveralUsers(uint256 lockAmount, uint256 lockAmount1, uint256 lockAmount2) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        lockAmount1 = bound(lockAmount1, 1, 1e36);
        lockAmount2 = bound(lockAmount2, 1, 1e36);

        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        vm.deal(address(this), lockAmount);
        vm.deal(user1, lockAmount1);
        vm.deal(user2, lockAmount2);

        prelaunchPoints.lockETH{value: lockAmount}(referral);
        vm.prank(user1);
        prelaunchPoints.lockETH{value: lockAmount1}(referral);
        vm.prank(user2);
        prelaunchPoints.lockETH{value: lockAmount2}(referral);

        // Set Loop Contracts and Convert to lpETH
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllETH();

        vm.warp(prelaunchPoints.startClaimDate() + 1);
        prelaunchPoints.claimAndStake(ETH, 100, PrelaunchPoints.Exchange.UniswapV3, emptydata);

        uint256 balanceLpETH = prelaunchPoints.totalLpETH() * lockAmount / prelaunchPoints.totalSupply();

        assertEq(prelaunchPoints.balances(address(this), ETH), 0);
        assertEq(lpETH.balanceOf(address(this)), 0);
        assertEq(lpETHVault.balanceOf(address(this)), balanceLpETH);

        vm.prank(user1);
        prelaunchPoints.claimAndStake(ETH, 100, PrelaunchPoints.Exchange.UniswapV3, emptydata);
        uint256 balanceLpETH1 = prelaunchPoints.totalLpETH() * lockAmount1 / prelaunchPoints.totalSupply();

        assertEq(prelaunchPoints.balances(user1, ETH), 0);
        assertEq(lpETH.balanceOf(user1), 0);
        assertEq(lpETHVault.balanceOf(user1), balanceLpETH1);
    }

    function testClaimAndStakeFailTwice(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        vm.deal(address(this), lockAmount);
        prelaunchPoints.lockETH{value: lockAmount}(referral);

        // Set Loop Contracts and Convert to lpETH
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllETH();

        vm.warp(prelaunchPoints.startClaimDate() + 1);
        prelaunchPoints.claim(ETH, 100, PrelaunchPoints.Exchange.UniswapV3, emptydata);

        vm.expectRevert(PrelaunchPoints.NothingToClaim.selector);
        prelaunchPoints.claimAndStake(ETH, 100, PrelaunchPoints.Exchange.UniswapV3, emptydata);
    }

    function testClaimAndStakeFailBeforeConvert(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        vm.deal(address(this), lockAmount);
        prelaunchPoints.lockETH{value: lockAmount}(referral);

        // Set Loop Contracts and Convert to lpETH
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);

        vm.expectRevert(PrelaunchPoints.CurrentlyNotPossible.selector);
        prelaunchPoints.claimAndStake(ETH, 100, PrelaunchPoints.Exchange.UniswapV3, emptydata);
    }

    /// ======= Tests for withdraw ETH ======= ///
    receive() external payable {}

    function testWithdrawETH(uint256 lockAmount) public {
        vm.assume(lockAmount > 0);
        vm.deal(address(this), lockAmount);
        prelaunchPoints.lockETH{value: lockAmount}(referral);

        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + 1);
        prelaunchPoints.withdraw(ETH);

        assertEq(prelaunchPoints.balances(address(this), ETH), 0);
        assertEq(prelaunchPoints.totalSupply(), 0);
        assertEq(address(this).balance, lockAmount);
    }

    function testWithdrawETHFailBeforeActivation(uint256 lockAmount) public {
        vm.assume(lockAmount > 0);
        vm.deal(address(this), lockAmount);
        prelaunchPoints.lockETH{value: lockAmount}(referral);

        vm.expectRevert(PrelaunchPoints.CurrentlyNotPossible.selector);
        prelaunchPoints.withdraw(ETH);
    }

    function testWithdrawETHBeforeActivationEmergencyMode(uint256 lockAmount) public {
        vm.assume(lockAmount > 0);
        vm.deal(address(this), lockAmount);
        prelaunchPoints.lockETH{value: lockAmount}(referral);

        prelaunchPoints.setEmergencyMode(true);

        prelaunchPoints.withdraw(ETH);
        assertEq(prelaunchPoints.balances(address(this), ETH), 0);
        assertEq(prelaunchPoints.totalSupply(), 0);
        assertEq(address(this).balance, lockAmount);
    }

    function testWithdrawETHFailAfterConvert(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        vm.deal(address(this), lockAmount);
        prelaunchPoints.lockETH{value: lockAmount}(referral);

        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllETH();

        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.withdraw(ETH);
    }

    function testWithdrawETHFailNotReceive(uint256 lockAmount) public {
        vm.assume(lockAmount > 0);
        vm.deal(address(lpETHVault), lockAmount);
        vm.prank(address(lpETHVault)); // Contract withiut receive
        prelaunchPoints.lockETH{value: lockAmount}(referral);

        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + 1);

        vm.prank(address(lpETHVault));
        vm.expectRevert(PrelaunchPoints.FailedToSendEther.selector);
        prelaunchPoints.withdraw(ETH);
    }

    /// ======= Tests for withdraw ======= ///
    function testWithdraw(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        lrt.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(address(lrt), lockAmount, referral);

        uint256 balanceBefore = lrt.balanceOf(address(this));

        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + 1);
        prelaunchPoints.withdraw(address(lrt));

        assertEq(prelaunchPoints.balances(address(this), address(lrt)), 0);
        assertEq(lrt.balanceOf(address(this)) - balanceBefore, lockAmount);
    }

    function testWithdrawFailBeforeActivation(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        lrt.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(address(lrt), lockAmount, referral);

        vm.expectRevert(PrelaunchPoints.CurrentlyNotPossible.selector);
        prelaunchPoints.withdraw(address(lrt));
    }

    function testWithdrawBeforeActivationEmergencyMode(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        lrt.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(address(lrt), lockAmount, referral);

        uint256 balanceBefore = lrt.balanceOf(address(this));

        prelaunchPoints.setEmergencyMode(true);

        prelaunchPoints.withdraw(address(lrt));
        assertEq(prelaunchPoints.balances(address(this), address(lrt)), 0);
        assertEq(lrt.balanceOf(address(this)) - balanceBefore, lockAmount);
    }

    function testWithdrawFailAfterConvert(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        lrt.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(address(lrt), lockAmount, referral);

        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllETH();

        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.withdraw(address(this));
    }

    function testWithdrawAfterConvertEmergencyMode(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        lrt.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(address(lrt), lockAmount, referral);

        uint256 balanceBefore = lrt.balanceOf(address(this));

        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllETH();

        prelaunchPoints.setEmergencyMode(true);

        prelaunchPoints.withdraw(address(lrt));
        assertEq(prelaunchPoints.balances(address(this), address(lrt)), 0);
        assertEq(lrt.balanceOf(address(this)) - balanceBefore, lockAmount);
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

    function testRecoverERC20FailLRT(uint256 amount) public {
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));

        vm.expectRevert(PrelaunchPoints.NotValidToken.selector);
        prelaunchPoints.recoverERC20(address(lrt), amount);
    }

    /// ======= Tests for SetLoopAddresses ======= ///
    function testSetLoopAddressesFailTwice() public {
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));

        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
    }

    function testSetLoopAddressesFailAfterDeadline(uint256 lockAmount) public {
        vm.assume(lockAmount > 0);
        vm.deal(address(this), lockAmount);
        prelaunchPoints.lockETH{value: lockAmount}(referral);

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

    /// ======= Tests for SetEmergencyMode ======= ///
    function testSetEmergencyMode() public {
        prelaunchPoints.setEmergencyMode(true);

        assertEq(prelaunchPoints.emergencyMode(), true);
    }

    function testSetEmergencyModeFailNotAuthorized() public {
        address user1 = vm.addr(1);
        vm.prank(user1);
        vm.expectRevert(PrelaunchPoints.NotAuthorized.selector);
        prelaunchPoints.setEmergencyMode(true);
    }

    /// ======= Tests for AllowToken ======= ///
    function testAllowToken() public {
        prelaunchPoints.allowToken(ETH);

        assertEq(prelaunchPoints.isTokenAllowed(ETH), true);
    }

    function testAllowTokenFailNotAuthorized() public {
        address user1 = vm.addr(1);
        vm.prank(user1);
        vm.expectRevert(PrelaunchPoints.NotAuthorized.selector);
        prelaunchPoints.allowToken(ETH);
    }

    /// ======= Reentrancy Tests ======= ///
    function testReentrancyOnWithdraw() public {
        uint256 lockAmount = 1 ether;

        vm.deal(address(this), lockAmount);
        vm.prank(address(this));
        prelaunchPoints.lockETH{value: lockAmount}(referral);

        vm.warp(prelaunchPoints.loopActivation() + 1 days);
        vm.prank(address(attackContract));
        vm.expectRevert();
        attackContract.attackWithdraw();
    }

    function testReentrancyOnClaim() public {
        uint256 lockAmount = 1 ether;

        vm.deal(address(this), lockAmount);
        vm.prank(address(this));
        prelaunchPoints.lockETH{value: lockAmount}(referral);

        prelaunchPoints.setLoopAddresses(address(lpETH), address(lpETHVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1 days);
        prelaunchPoints.convertAllETH();

        vm.warp(prelaunchPoints.startClaimDate() + 1 days);
        vm.prank(address(attackContract));
        vm.expectRevert();
        attackContract.attackClaim();
    }
}
