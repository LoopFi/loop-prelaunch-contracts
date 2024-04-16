// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "../../src/interfaces/ILpETHVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockLpETHVault is ILpETHVault, ERC20 {
    constructor() ERC20("Staked LoopETH", "stlpETH") {}

    function stake(uint256 amount, address receiver) external returns (uint256) {
        _mint(receiver, amount);
        return amount;
    }
}
