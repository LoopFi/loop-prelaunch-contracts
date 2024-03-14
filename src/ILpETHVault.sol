// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILpETHVault is IERC20 {
    function stake(uint256 amount, address receiver) external returns (uint256);
}
