// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";
import "../src/PrelaunchPoints.sol";

contract PrelaunchPointsScript is Script {
    address constant EXCHANGE_PROXY = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5; // Scroll
    address public constant WETH = 0x5300000000000000000000000000000000000004; // Scroll

 address public constant weETH = 0x01f0a31698C4d065659b9bdC21B3610292a1c506;
        address public constant wrsETH = 0xa25b25548B4C98B0c7d3d27dcA5D5ca743d68b7F;
        address public constant pufETH = 0xc4d46E8402F476F269c379677C99F18E22Ea030e;
        address public constant STONE = 0x80137510979822322193FC997d400D5A6C747bf7;


    address[] public allowedTokens;
    uint256[] public initialMaxDepositCaps;

    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        vm.setNonce(deployer, 3);
        uint256 nonce = vm.getNonce(deployer);
        
        console.log("Deployer Account", deployer);
        console.log("Deployer Nonce", nonce);
        console.log("Chain ID", block.chainid);
        initialMaxDepositCaps.push(1 ether);
        //vm.prompt("Press enter to deploy");

        allowedTokens.push(weETH);
        initialMaxDepositCaps.push(1 ether);

        allowedTokens.push(wrsETH);
        initialMaxDepositCaps.push(1 ether);

        allowedTokens.push(pufETH);
        initialMaxDepositCaps.push(1 ether);

        allowedTokens.push(STONE);
        initialMaxDepositCaps.push(1 ether);

        vm.broadcast(privateKey);
        vm.txGasPrice(2);
        new PrelaunchPoints(EXCHANGE_PROXY, WETH, allowedTokens, initialMaxDepositCaps);
    }
}
