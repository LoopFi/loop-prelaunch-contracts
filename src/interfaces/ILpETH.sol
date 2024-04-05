// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILpETH is IERC20 {
    function deposit(address receiver) external payable returns (uint256);
}
