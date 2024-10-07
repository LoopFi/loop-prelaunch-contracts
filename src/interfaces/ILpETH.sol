// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILpETH is IERC20 {
    /// @notice Deposits given amount of underlying tokens to the pool in exchange for pool shares
    /// @param assets Amount of underlying to deposit
    /// @param receiver Account to mint pool shares to
    /// @return shares Number of shares minted
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
}
