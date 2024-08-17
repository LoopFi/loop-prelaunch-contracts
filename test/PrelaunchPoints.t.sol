// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PrelaunchPoints.sol";
import "../src/interfaces/ILpBTC.sol";

import "../src/mock/AttackContract.sol";
import "../src/mock/MockLpBTC.sol";
import "../src/mock/MockLpBTCVault.sol";
import {ERC20Token} from "../src/mock/MockERC20.sol";
import {LRToken} from "../src/mock/MockLRT.sol";
import {MockWBTC} from "../src/mock/MockWBTC.sol";

import "forge-std/console.sol";

contract PrelaunchPointsTest is Test {
    PrelaunchPoints public prelaunchPoints;
    AttackContract public attackContract;
    ILpBTC public lpBTC;
    MockWBTC public wbtc;
    LRToken public lrt;
    ILpBTCVault public lpBTCVault;
    uint256 public constant INITIAL_SUPPLY = 1000 ether;
    bytes32 referral = bytes32(uint256(1));

    address constant EXCHANGE_PROXY = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5;
    address public WBTC; //
    address[] public allowedTokens;
    uint256[] public initialMaxBalance;

    function setUp() public {
        lrt = new LRToken();
        lrt.mint(address(this), INITIAL_SUPPLY);
        wbtc = new MockWBTC();
        WBTC = address(wbtc);
        vm.deal(address(this), INITIAL_SUPPLY);
        wbtc.mint(address(this), INITIAL_SUPPLY);

        address[] storage allowedTokens_ = allowedTokens;
        uint256[] storage initialMaxBalance_ = initialMaxBalance;
        allowedTokens_.push(address(lrt));
        initialMaxBalance_.push(UINT256_MAX); // WBTC
        initialMaxBalance_.push(UINT256_MAX); // LRT

        prelaunchPoints = new PrelaunchPoints(EXCHANGE_PROXY, WBTC, allowedTokens_, initialMaxBalance_);

        lpBTC = new MockLpBTC();
        lpBTCVault = new MockLpBTCVault();

        attackContract = new AttackContract(prelaunchPoints);
    }

    /// ======= Tests for lock ======= ///
    function testLock(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        lrt.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(address(lrt), lockAmount, referral);

        assertEq(prelaunchPoints.balances(address(this), address(lrt)), lockAmount);
    }

    function testLockWBTC(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(WBTC, lockAmount, referral);

        assertEq(prelaunchPoints.balances(address(this), WBTC), lockAmount);
    }

    function testLockFailActivation(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        lrt.approve(address(prelaunchPoints), lockAmount);
        // Should revert after starting the claim
        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllBTC();
        vm.warp(prelaunchPoints.startClaimDate() + 1);

        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.lock(address(lrt), lockAmount, referral);
    }

    function testLockWBTCFailActivation(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        // Should revert after starting the claim
        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllBTC();
        vm.warp(prelaunchPoints.startClaimDate() + 1);

        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.lock(WBTC, lockAmount, referral);
    }

    function testLockFailZero() public {
        vm.expectRevert(PrelaunchPoints.CannotLockZero.selector);
        prelaunchPoints.lock(address(lrt), 0, referral);

        vm.expectRevert(PrelaunchPoints.CannotLockZero.selector);
        prelaunchPoints.lock(WBTC, 0, referral);
    }

    function testLockFailTokenNotAllowed(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        lrt.approve(address(prelaunchPoints), lockAmount);
        vm.expectRevert(abi.encodeWithSelector(PrelaunchPoints.TokenNotAllowed.selector, address(lpBTC)));
        prelaunchPoints.lock(address(lpBTC), lockAmount, referral);
    }

    function testLockFailMaxCap(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);

        _setLowerCaps(address(lrt), lockAmount - 1);

        // Try to lock LRT
        lrt.approve(address(prelaunchPoints), lockAmount);
        vm.expectRevert(abi.encodeWithSelector(PrelaunchPoints.MaxDepositCapReached.selector, address(lrt)));
        prelaunchPoints.lock(address(lrt), lockAmount, referral);
    }

    function testLockWBTCFailMaxCap(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY * 1e10);

        _setLowerCaps(WBTC, lockAmount - 1);

        // Try to lock WBTC
        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        vm.expectRevert(abi.encodeWithSelector(PrelaunchPoints.MaxDepositCapReached.selector, WBTC));
        prelaunchPoints.lock(WBTC, lockAmount, referral);
    }

    /// ======= Tests for lockFor ======= ///
    function testLockFor(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        lrt.approve(address(prelaunchPoints), lockAmount);
        address recipient = address(0x1234);

        prelaunchPoints.lockFor(address(lrt), lockAmount, recipient, referral);

        assertEq(prelaunchPoints.balances(recipient, address(lrt)), lockAmount);
    }

    function testLockForWBTC(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        address recipient = address(0x1234);

        prelaunchPoints.lockFor(WBTC, lockAmount, recipient, referral);

        assertEq(prelaunchPoints.balances(recipient, WBTC), lockAmount);
    }

    function testLockForFailActivation(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        address recipient = address(0x1234);
        // Should revert after starting the claim
        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllBTC();
        vm.warp(prelaunchPoints.startClaimDate() + 1);

        lrt.approve(address(prelaunchPoints), lockAmount);
        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.lockFor(address(lrt), lockAmount, recipient, referral);
    }

    function testLockForWBTCFailActivation(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        address recipient = address(0x1234);
        // Should revert after starting the claim
        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllBTC();
        vm.warp(prelaunchPoints.startClaimDate() + 1);

        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.lockFor(WBTC, lockAmount, recipient, referral);
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

        vm.expectRevert(abi.encodeWithSelector(PrelaunchPoints.TokenNotAllowed.selector, address(lpBTC)));
        prelaunchPoints.lockFor(address(lpBTC), lockAmount, recipient, referral);
    }

    function testLockForFailMaxCap(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        address recipient = address(0x1234);

        _setLowerCaps(address(lrt), lockAmount - 1);

        // Try to lock LRT
        lrt.approve(address(prelaunchPoints), lockAmount);
        vm.expectRevert(abi.encodeWithSelector(PrelaunchPoints.MaxDepositCapReached.selector, address(lrt)));
        prelaunchPoints.lockFor(address(lrt), lockAmount, recipient, referral);
    }

    function testLockForWBTCFailMaxCap(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY * 1e10);
        address recipient = address(0x1234);

        _setLowerCaps(WBTC, lockAmount - 1);

        // Try to lock WBTC
        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        vm.expectRevert(abi.encodeWithSelector(PrelaunchPoints.MaxDepositCapReached.selector, WBTC));
        prelaunchPoints.lockFor(WBTC, lockAmount, recipient, referral);
    }

    /// ======= Tests for convertAllBTC ======= ///
    function testConvertAllBTC(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(WBTC, lockAmount, referral);

        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));

        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllBTC();

        assertEq(prelaunchPoints.totalLpBTC(), lockAmount);
        assertEq(lpBTC.balanceOf(address(prelaunchPoints)), lockAmount);
        assertEq(prelaunchPoints.startClaimDate(), block.timestamp);
    }

    function testConvertAllFailActivation(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY * 1e10);
        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(WBTC, lockAmount, referral);

        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));

        vm.expectRevert(PrelaunchPoints.LoopNotActivated.selector);
        prelaunchPoints.convertAllBTC();
    }

    /// ======= Tests for claim BTC======= ///
    bytes emptydata = new bytes(1);

    function testClaim(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(WBTC, lockAmount, referral);

        // Set Loop Contracts and Convert to lpBTC
        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllBTC();

        vm.warp(prelaunchPoints.startClaimDate() + 1);
        prelaunchPoints.claim(WBTC, 100, PrelaunchPoints.Exchange.Swap, emptydata);

        uint256 balanceLpBTC = prelaunchPoints.totalLpBTC() * lockAmount / prelaunchPoints.totalSupply();

        assertEq(prelaunchPoints.balances(address(this), WBTC), 0);
        assertEq(lpBTC.balanceOf(address(this)), balanceLpBTC);
    }

    function testClaimSeveralUsers(uint256 lockAmount, uint256 lockAmount1, uint256 lockAmount2) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        lockAmount1 = bound(lockAmount1, 1, 1e36);
        lockAmount2 = bound(lockAmount2, 1, 1e36);

        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        wbtc.mint(address(this), lockAmount);
        wbtc.mint(user1, lockAmount1);
        wbtc.mint(user2, lockAmount2);

        wbtc.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(WBTC, lockAmount, referral);
        
        vm.startPrank(user1);
        wbtc.approve(address(prelaunchPoints), lockAmount1);
        prelaunchPoints.lock(WBTC, lockAmount1, referral);
        vm.stopPrank();

        vm.startPrank(user2);
        wbtc.approve(address(prelaunchPoints), lockAmount2);
        prelaunchPoints.lock(WBTC, lockAmount2, referral);
        vm.stopPrank();

        // Set Loop Contracts and Convert to lpBTC
        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllBTC();

        vm.warp(prelaunchPoints.startClaimDate() + 1);
        prelaunchPoints.claim(WBTC, 100, PrelaunchPoints.Exchange.Swap, emptydata);

        uint256 balanceLpBTC = prelaunchPoints.totalLpBTC() * lockAmount / prelaunchPoints.totalSupply();

        assertEq(prelaunchPoints.balances(address(this), WBTC), 0);
        assertEq(lpBTC.balanceOf(address(this)), balanceLpBTC);

        vm.prank(user1);
        prelaunchPoints.claim(WBTC, 100, PrelaunchPoints.Exchange.Swap, emptydata);
        uint256 balanceLpBTC1 = prelaunchPoints.totalLpBTC() * lockAmount1 / prelaunchPoints.totalSupply();

        assertEq(prelaunchPoints.balances(user1, WBTC), 0);
        assertEq(lpBTC.balanceOf(user1), balanceLpBTC1);
    }

    function testClaimFailTwice(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(WBTC, lockAmount, referral);

        // Set Loop Contracts and Convert to lpBTC
        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllBTC();

        vm.warp(prelaunchPoints.startClaimDate() + 1);
        prelaunchPoints.claim(WBTC, 100, PrelaunchPoints.Exchange.Swap, emptydata);

        vm.expectRevert(PrelaunchPoints.NothingToClaim.selector);
        prelaunchPoints.claim(WBTC, 100, PrelaunchPoints.Exchange.Swap, emptydata);
    }

    function testClaimFailBeforeConvert(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(WBTC, lockAmount, referral);

        // Set Loop Contracts and Convert to lpBTC
        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);

        vm.expectRevert(PrelaunchPoints.CurrentlyNotPossible.selector);
        prelaunchPoints.claim(WBTC, 100, PrelaunchPoints.Exchange.Swap, emptydata);
    }

    /// ======= Tests for claimAndStake ======= ///
    function testClaimAndStake(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(WBTC, lockAmount, referral);

        // Set Loop Contracts and Convert to lpBTC
        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllBTC();

        vm.warp(prelaunchPoints.startClaimDate() + 1);
        prelaunchPoints.claimAndStake(WBTC, 100, PrelaunchPoints.Exchange.Swap, 0, emptydata);

        uint256 balanceLpBTC = prelaunchPoints.totalLpBTC() * lockAmount / prelaunchPoints.totalSupply();

        assertEq(prelaunchPoints.balances(address(this), WBTC), 0);
        assertEq(lpBTC.balanceOf(address(this)), 0);
        assertEq(lpBTCVault.balanceOf(address(this)), balanceLpBTC);
    }

    function testClaimAndStakeSeveralUsers(uint256 lockAmount, uint256 lockAmount1, uint256 lockAmount2) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        lockAmount1 = bound(lockAmount1, 1, 1e36);
        lockAmount2 = bound(lockAmount2, 1, 1e36);

        address user1 = vm.addr(1);
        address user2 = vm.addr(2);

        wbtc.mint(address(this), lockAmount);
        wbtc.mint(user1, lockAmount1);
        wbtc.mint(user2, lockAmount2);

        wbtc.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(WBTC, lockAmount, referral);

        vm.startPrank(user1);
        wbtc.approve(address(prelaunchPoints), lockAmount1);
        prelaunchPoints.lock(WBTC, lockAmount1, referral);
        vm.stopPrank();

        vm.startPrank(user2);
        wbtc.approve(address(prelaunchPoints), lockAmount2);
        prelaunchPoints.lock(WBTC, lockAmount2, referral);
        vm.stopPrank();

        // Set Loop Contracts and Convert to lpBTC
        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllBTC();

        vm.warp(prelaunchPoints.startClaimDate() + 1);
        prelaunchPoints.claimAndStake(WBTC, 100, PrelaunchPoints.Exchange.Swap, 0, emptydata);

        uint256 balanceLpBTC = prelaunchPoints.totalLpBTC() * lockAmount / prelaunchPoints.totalSupply();

        assertEq(prelaunchPoints.balances(address(this), WBTC), 0);
        assertEq(lpBTC.balanceOf(address(this)), 0);
        assertEq(lpBTCVault.balanceOf(address(this)), balanceLpBTC);

        vm.prank(user1);
        prelaunchPoints.claimAndStake(WBTC, 100, PrelaunchPoints.Exchange.Swap, 0, emptydata);
        uint256 balanceLpBTC1 = prelaunchPoints.totalLpBTC() * lockAmount1 / prelaunchPoints.totalSupply();

        assertEq(prelaunchPoints.balances(user1, WBTC), 0);
        assertEq(lpBTC.balanceOf(user1), 0);
        assertEq(lpBTCVault.balanceOf(user1), balanceLpBTC1);
    }

    function testClaimAndStakeFailTwice(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(WBTC, lockAmount, referral);

        // Set Loop Contracts and Convert to lpBTC
        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllBTC();

        vm.warp(prelaunchPoints.startClaimDate() + 1);
        prelaunchPoints.claim(WBTC, 100, PrelaunchPoints.Exchange.Swap, emptydata);

        vm.expectRevert(PrelaunchPoints.NothingToClaim.selector);
        prelaunchPoints.claimAndStake(WBTC, 100, PrelaunchPoints.Exchange.Swap, 0, emptydata);
    }

    function testClaimAndStakeFailBeforeConvert(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(WBTC, lockAmount, referral);

        // Set Loop Contracts and Convert to lpBTC
        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);

        vm.expectRevert(PrelaunchPoints.CurrentlyNotPossible.selector);
        prelaunchPoints.claimAndStake(WBTC, 100, PrelaunchPoints.Exchange.Swap, 0, emptydata);
    }

    /// ======= Tests for withdraw BTC ======= ///
    receive() external payable {}

    // function testWithdrawBTC(uint256 lockAmount) public {
    //     lockAmount = bound(lockAmount, 1, 1e36);
    //     wbtc.mint(address(this), lockAmount);
    //     // prelaunchPoints.lockBTC{value: lockAmount}(referral);

    //     // prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
    //     // vm.warp(prelaunchPoints.loopActivation() + 1);
    //     // prelaunchPoints.withdraw(WBTC);

    //     // assertEq(prelaunchPoints.balances(address(this), WBTC), 0);
    //     // assertEq(prelaunchPoints.totalSupply(), 0);
    //     // assertEq(wbtc.balanceOf(address(this)), lockAmount + INITIAL_SUPPLY);
    // }

    function testWithdrawBTCBeforeActivation(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY * 1e10);
        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(WBTC, lockAmount, referral);

        prelaunchPoints.withdraw(WBTC);

        assertEq(prelaunchPoints.balances(address(this), WBTC), 0);
        assertEq(prelaunchPoints.totalSupply(), 0);
        assertEq(wbtc.balanceOf(address(this)), lockAmount + INITIAL_SUPPLY);
    }

    function testWithdrawBTCBeforeActivationEmergencyMode(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY * 1e10);
        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(WBTC, lockAmount, referral);

        prelaunchPoints.setEmergencyMode(true);

        prelaunchPoints.withdraw(WBTC);
        assertEq(prelaunchPoints.balances(address(this), WBTC), 0);
        assertEq(prelaunchPoints.totalSupply(), 0);
        assertEq(wbtc.balanceOf(address(this)), lockAmount + INITIAL_SUPPLY);
    }

    function testWithdrawBTCFailAfterConvert(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e36);
        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(WBTC, lockAmount, referral);

        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllBTC();

        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.withdraw(WBTC);
    }


    /// ======= Tests for withdraw ======= ///
    function testWithdraw(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        lrt.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(address(lrt), lockAmount, referral);

        uint256 balanceBefore = lrt.balanceOf(address(this));

        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
        vm.warp(prelaunchPoints.loopActivation() + 1);
        prelaunchPoints.withdraw(address(lrt));

        assertEq(prelaunchPoints.balances(address(this), address(lrt)), 0);
        assertEq(lrt.balanceOf(address(this)) - balanceBefore, lockAmount);
    }

    function testWithdrawBeforeActivation(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        lrt.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(address(lrt), lockAmount, referral);

        uint256 balanceBefore = lrt.balanceOf(address(this));
        prelaunchPoints.withdraw(address(lrt));

        assertEq(prelaunchPoints.balances(address(this), address(lrt)), 0);
        assertEq(lrt.balanceOf(address(this)) - balanceBefore, lockAmount);
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

        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllBTC();

        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.withdraw(address(this));
    }

    function testWithdrawAfterConvertEmergencyMode(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY);
        lrt.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(address(lrt), lockAmount, referral);

        uint256 balanceBefore = lrt.balanceOf(address(this));

        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1);
        prelaunchPoints.convertAllBTC();

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

    function testRecoverERC20FailLpBTC(uint256 amount) public {
        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));

        vm.expectRevert(PrelaunchPoints.NotValidToken.selector);
        prelaunchPoints.recoverERC20(address(lpBTC), amount);
    }

    function testRecoverERC20FailLRT(uint256 amount) public {
        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));

        vm.expectRevert(PrelaunchPoints.NotValidToken.selector);
        prelaunchPoints.recoverERC20(address(lrt), amount);
    }

    /// ======= Tests for SetLoopAddresses ======= ///
    function testSetLoopAddressesFailTwice() public {
        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));

        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
    }

    function testSetLoopAddressesFailAfterDeadline(uint256 lockAmount) public {
        lockAmount = bound(lockAmount, 1, INITIAL_SUPPLY) * 1e10;
        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(WBTC, lockAmount, referral);

        vm.warp(prelaunchPoints.loopActivation() + 1);

        vm.expectRevert(PrelaunchPoints.NoLongerPossible.selector);
        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
    }

    /// ======= Tests for SetOwner ======= ///
    function testSetOwner() public {
        address user1 = vm.addr(1);
        prelaunchPoints.proposeOwner(user1);

        assertEq(prelaunchPoints.proposedOwner(), user1);

        vm.prank(user1);
        prelaunchPoints.acceptOwnership();

        assertEq(prelaunchPoints.owner(), user1);
    }

    function testSetOwnerFailNotAuthorized() public {
        address user1 = vm.addr(1);
        vm.prank(user1);
        vm.expectRevert(PrelaunchPoints.NotAuthorized.selector);
        prelaunchPoints.proposeOwner(user1);
    }

    function testAcceptOwnershipNotAuthorized() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        prelaunchPoints.proposeOwner(user1);

        assertEq(prelaunchPoints.proposedOwner(), user1);

        vm.prank(user2);
        vm.expectRevert(PrelaunchPoints.NotProposedOwner.selector);
        prelaunchPoints.acceptOwnership();
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
        address token = address(0x1234);
        prelaunchPoints.allowToken(token);

        assertEq(prelaunchPoints.isTokenAllowed(token), true);
    }

    function testAllowTokenFailNotAuthorized() public {
        address user1 = vm.addr(1);
        address token = address(0x1234);
        vm.prank(user1);
        vm.expectRevert(PrelaunchPoints.NotAuthorized.selector);
        prelaunchPoints.allowToken(token);
    }

    /// ======= Tests for SetDepositMaxCaps ======= ///
    function testSetDepositMaxCaps(uint256 amount0, uint256 amount1) public {
        address[] memory allowedTokens_ = new address[](2);
        uint256[] memory initialMaxBalance_ = new uint256[](2);
        allowedTokens_[0] = WBTC;
        allowedTokens_[1] = address(lrt);
        initialMaxBalance_[0] = amount0;
        initialMaxBalance_[1] = amount1;

        prelaunchPoints.setDepositMaxCaps(allowedTokens_, initialMaxBalance_);

        assertEq(prelaunchPoints.maxDepositCap(WBTC), amount0);
        assertEq(prelaunchPoints.maxDepositCap(address(lrt)), amount1);
    }

    function testSetDepositMaxCapsNotAuthorized(uint256 amount0, uint256 amount1) public {
        address[] memory allowedTokens_ = new address[](2);
        uint256[] memory initialMaxBalance_ = new uint256[](2);
        allowedTokens_[0] = WBTC;
        allowedTokens_[1] = address(lrt);
        initialMaxBalance_[0] = amount0;
        initialMaxBalance_[1] = amount1;

        address user1 = vm.addr(1);
        vm.prank(user1);
        vm.expectRevert(PrelaunchPoints.NotAuthorized.selector);
        prelaunchPoints.setDepositMaxCaps(allowedTokens_, initialMaxBalance_);
    }

    function testSetDepositMaxCapsTokenNotAllowed(uint256 amount0, uint256 amount1) public {
        address[] memory allowedTokens_ = new address[](2);
        uint256[] memory initialMaxBalance_ = new uint256[](2);
        allowedTokens_[0] = WBTC;
        allowedTokens_[1] = address(0x12345);
        initialMaxBalance_[0] = amount0;
        initialMaxBalance_[1] = amount1;

        vm.expectRevert(abi.encodeWithSelector(PrelaunchPoints.TokenNotAllowed.selector, address(0x12345)));
        prelaunchPoints.setDepositMaxCaps(allowedTokens_, initialMaxBalance_);
    }

    /// ======== Test for receive BTC ========= ///
    function testReceiveDirectEthFail() public {
        vm.deal(address(this), 1 ether);

        vm.expectRevert(PrelaunchPoints.ReceiveDisabled.selector);
        address(prelaunchPoints).call{value: 1 ether}("");
    }

    /// ======= Reentrancy Tests ======= ///
    function testReentrancyOnWithdraw() public {
        uint256 lockAmount = 1 ether;
        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(WBTC, lockAmount, referral);

        vm.warp(prelaunchPoints.loopActivation() + 1 days);
        vm.prank(address(attackContract));
        vm.expectRevert();
        attackContract.attackWithdraw();
    }

    function testReentrancyOnClaim() public {
        uint256 lockAmount = 1 ether;

        vm.prank(address(this));
        wbtc.mint(address(this), lockAmount);
        wbtc.approve(address(prelaunchPoints), lockAmount);
        prelaunchPoints.lock(WBTC, lockAmount, referral);

        prelaunchPoints.setLoopAddresses(address(lpBTC), address(lpBTCVault));
        vm.warp(prelaunchPoints.loopActivation() + prelaunchPoints.TIMELOCK() + 1 days);
        prelaunchPoints.convertAllBTC();

        vm.warp(prelaunchPoints.startClaimDate() + 1 days);
        vm.prank(address(attackContract));
        vm.expectRevert();
        attackContract.attackClaim();
    }

    // HELPERS
    function _setLowerCaps(address _token, uint256 _amount) internal {
        address[] memory allowedTokens_ = new address[](1);
        uint256[] memory initialMaxBalance_ = new uint256[](1);
        allowedTokens_[0] = _token;
        initialMaxBalance_[0] = _amount;
        prelaunchPoints.setDepositMaxCaps(allowedTokens_, initialMaxBalance_);
    }
}
