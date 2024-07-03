// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/UnRealTradeBot.sol";

contract UnRealTradeBotTest is Test {
    UnRealTradeBot public bot;

    address DAI = 0x75d0cBF342060b14c2fC756fd6E717dFeb5B1B70;
    address MORE = 0x25ea98ac87A38142561eA70143fd44c4772A16b6;
    address UKRE = 0x835d3E1C0aA079C6164AAd21DCb23E60eb71AF48;
    address USDC = 0x8D7dd0C2FbfAF1007C733882Cd0ccAdEFFf275D2; //no liquidity
    address USTB = 0x83feDBc0B85c6e29B589aA6BdefB1Cc581935ECD;
    address REAL = 0x4644066f535Ead0cde82D209dF78d94572fCbf14;
    address pearl = 0xCE1581d7b4bA40176f0e219b2CaC30088Ad50C7A;
    address arcUSD = 0xAEC9e50e3397f9ddC635C6c429C8C7eca418a143;
    address WREETH = 0x90c6E93849E06EC7478ba24522329d14A5954Df4;
    address CAVIAR = 0xB08F026f8a096E6d92eb5BcbE102c273A7a2d51C;

    IPairFactory factor = IPairFactory(0xeF0b0a33815146b599A8D4d3215B18447F2A8101);
    IPearlRouter router = IPearlRouter(0x60a6c99d0005b89c6F0E736E212004000f330aed);
    string REAL_RPC_URL = vm.envString("REAL_RPC_URL");

    function setUp() public {
        vm.createSelectFork(REAL_RPC_URL, 118350);

        bot = new UnRealTradeBot(factor, router);

        vm.prank(0x4313e375882B1dAf17b036D9a45aA39796b988b4);
        IERC20(USTB).transfer(address(bot), 10 ether);

        vm.prank(0x6DE6E901Bbefd26a9888798a25E4A49309D04CA9);
        IERC20(DAI).transfer(address(bot), 3 ether);
    }

    function testShouldTrade() public {
        bot.swap();
    }
}
