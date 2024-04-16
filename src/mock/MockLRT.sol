// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LRToken is ERC20 {
    constructor() ERC20("LRT", "LRT") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
