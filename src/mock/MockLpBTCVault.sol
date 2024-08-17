// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "../../src/interfaces/ILpBTCVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockLpBTCVault is ILpBTCVault, ERC20 {
    constructor() ERC20("Staked LoopBTC", "stlpBTC") {}

    function stake(uint256 amount, address receiver, uint256 /* index */ ) external {
        _mint(receiver, amount);
    }
}
