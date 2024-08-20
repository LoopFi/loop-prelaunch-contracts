// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";
import "../src/PrelaunchPoints.sol";

contract PrelaunchPointsScript is Script {
    address constant EXCHANGE_PROXY = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5; // Mainnet
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; // Mainnet

    address public constant swBTC = 0x8DB2350D78aBc13f5673A411D4700BCF87864dDE;

    address[] public allowedTokens;
    uint256[] public initialMaxDepositCaps;

    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        console.log("Deployer Account", deployer);
        console.log("Chain ID", block.chainid);
        initialMaxDepositCaps.push(1000000);
        //vm.prompt("Press enter to deploy");

        allowedTokens.push(swBTC);
        initialMaxDepositCaps.push(1000000);

        vm.broadcast(privateKey);
        new PrelaunchPoints(EXCHANGE_PROXY, WBTC, allowedTokens, initialMaxDepositCaps);
    }
}
