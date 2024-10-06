// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/PrelaunchPoints.sol";

contract PrelaunchPointsScript is Script {
    address constant EXCHANGE_PROXY = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF; // Mainnet & Sepolia
    // address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // Mainnet
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // Sepolia
    address[] public allowedTokens;

    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        console.log("Deployer Account", deployer);

        address weETH = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe;
        allowedTokens.push(weETH);

        address ezETH = 0x2416092f143378750bb29b79eD961ab195CcEea5;
        allowedTokens.push(ezETH);

        vm.broadcast(privateKey);
        new PrelaunchPoints(EXCHANGE_PROXY, WETH, allowedTokens);
    }
}
