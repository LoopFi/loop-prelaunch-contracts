// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILpETHVault is IERC20 {
    /**
	 * @notice Stake tokens to receive rewards.
	 * @dev Locked tokens cannot be withdrawn for defaultLockDuration and are eligible to receive rewards.
	 * @param amount to stake.
	 * @param onBehalfOf address for staking.
	 * @param typeIndex lock type index determining lock period and rewards multiplier.
	 */
	function stake(uint256 amount, address onBehalfOf, uint256 typeIndex) external;
}
