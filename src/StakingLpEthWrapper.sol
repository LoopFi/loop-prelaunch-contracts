// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ILpETHStaking} from "./interfaces/ILpETHStaking.sol";
import {ILpETHVault} from "./interfaces/ILpETHVault.sol";
import {ILpETH} from "./interfaces/ILpETH.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakingLpEthWrapper is ILpETHVault{
    ILpETH lpETH;
    ILpETHStaking lpETHStaking;

    constructor(address _lpETH, address _stakingContract){
        lpETH = ILpETH(_lpETH);
        lpETHStaking = ILpETHStaking(_stakingContract);
    }

    /**
	 * @notice Stake tokens to receive rewards.
	 * @dev Locked tokens cannot be withdrawn for defaultLockDuration and are eligible to receive rewards.
	 * @param amount to stake.
	 * @param onBehalfOf address for staking.
	 */
    function stake(uint256 amount, address onBehalfOf, uint256 /*typeIndex*/) external {
        SafeERC20.safeTransferFrom(lpETH, msg.sender, address(this), amount);
        lpETH.approve(address(lpETHStaking), amount);
        lpETHStaking.deposit(amount, onBehalfOf);
    }
    
}