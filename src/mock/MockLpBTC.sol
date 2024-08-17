// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "../../src/interfaces/ILpBTC.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockLpBTC is ILpBTC, ERC20 {
    constructor() ERC20("LoopBTC", "lpBTC") {}

    function deposit(uint256 amount, address receiver) external returns (uint256) {
        super._mint(receiver, amount);
        return amount;
    }
}
