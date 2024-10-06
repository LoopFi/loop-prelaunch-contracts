// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/StakingLpEthWrapper.sol";

contract StakingLpEthWrapperScript is Script {
    address public constant lpETH = address(0x0);
    address public constant lpETHStaking = address(0x0);

    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        console.log("Deployer Account", deployer);

        vm.broadcast(privateKey);
        new StakingLpEthWrapper(lpETH, lpETHStaking);
    }
}
