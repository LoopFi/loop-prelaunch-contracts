// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/PrelaunchPoints.sol";

contract PrelaunchPointsScript is Script {
    address constant EXCHANGE_PROXY = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF; // Mainnet & Sepolia
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // Mainnet
    address[] public allowedTokens;

    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        console.log("Deployer Account", deployer);

        vm.broadcast(privateKey);
        new PrelaunchPoints(EXCHANGE_PROXY, WETH, allowedTokens);
    }
}
