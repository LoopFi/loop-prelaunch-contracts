// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "../../src/interfaces/ILpETHStaking.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract MockLpETHStaking is ERC4626 {
    constructor(IERC20 lpETH) ERC4626(lpETH) ERC20("Staked lpETH", "slpETH") {}
}
