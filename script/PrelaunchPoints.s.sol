// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";
import "../src/PrelaunchPoints.sol";

contract PrelaunchPointsScript is Script {
    address constant EXCHANGE_PROXY = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5; // Mainnet
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // Mainnet

    address public constant ynETH = 0x09db87A538BD693E9d08544577d5cCfAA6373A48;

    address[] public allowedTokens;
    uint256[] public initialMaxDepositCaps;

    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        
        console.log("Deployer Account", deployer);
        console.log("Chain ID", block.chainid);
        initialMaxDepositCaps.push(1 ether);

        allowedTokens.push(ynETH);
        initialMaxDepositCaps.push(1 ether);

        vm.broadcast(privateKey);
        vm.txGasPrice(2);
        new PrelaunchPoints(EXCHANGE_PROXY, WETH, allowedTokens, initialMaxDepositCaps);
    }
}
