// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "../../src/interfaces/ILpETH.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockLpETH is ILpETH, ERC20 {
    constructor() ERC20("LoopETH", "lpETH") {}

    function deposit(address receiver) external payable returns (uint256) {
        super._mint(receiver, msg.value);
        return msg.value;
    }
}
