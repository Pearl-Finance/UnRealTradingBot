// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/UnRealTradeBot.sol";

/**
 * @title UnRealTradeBotTest
 * @author c-n-o-t-e
 * @dev Contract is used to test out UnRealTradeBot Contract in a stateless way.
 *
 * Functionalities Tested:
 *  - AddPath()
 *  - Withdraw()
 *  - RunTrades()
 *  - UpdatePath()
 *  - RemovePath()
 *  - Failed Scenarios
 *  - UpdateAmountToTrade()
 */
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

    IQuoter quoter = IQuoter(0xDe43aBe37aB3b5202c22422795A527151d65Eb18);
    ISwapRouter router = ISwapRouter(0xa1F56f72b0320179b01A947A5F78678E8F96F8EC);
    string REAL_RPC_URL = vm.envString("REAL_RPC_URL");

    function setUp() public {
        vm.createSelectFork(REAL_RPC_URL, 118350);

        bytes memory firstPath = abi.encodePacked(USTB, uint24(100), arcUSD, uint24(500), UKRE);
        bytes memory secondPath = abi.encodePacked(UKRE, uint24(500), arcUSD, uint24(100), USTB);

        bytes memory firstPath0 = abi.encodePacked(USTB, uint24(10000), pearl, uint24(500), CAVIAR);
        bytes memory secondPath0 = abi.encodePacked(CAVIAR, uint24(500), pearl, uint24(10000), USTB);

        bytes memory firstPath1 = abi.encodePacked(USTB, uint24(3000), WREETH, uint24(3000), REAL);
        bytes memory secondPath1 = abi.encodePacked(REAL, uint24(3000), WREETH, uint24(3000), USTB);

        bytes memory firstPath2 = abi.encodePacked(DAI, uint24(100), USTB, uint24(100), MORE);
        bytes memory secondPath2 = abi.encodePacked(MORE, uint24(100), USTB, uint24(100), DAI);

        bytes[] memory firstPaths = new bytes[](4);
        bytes[] memory secondPaths = new bytes[](4);

        firstPaths[0] = firstPath;
        secondPaths[0] = secondPath;

        firstPaths[1] = firstPath0;
        secondPaths[1] = secondPath0;

        firstPaths[2] = firstPath1;
        secondPaths[2] = secondPath1;

        firstPaths[3] = firstPath2;
        secondPaths[3] = secondPath2;

        bot = new UnRealTradeBot(firstPaths, secondPaths, router, quoter, 0.01 ether);
        bot.setSlippage(50);

        vm.prank(0x4313e375882B1dAf17b036D9a45aA39796b988b4);
        IERC20(USTB).transfer(address(bot), 10 ether);

        vm.prank(0x6DE6E901Bbefd26a9888798a25E4A49309D04CA9);
        IERC20(DAI).transfer(address(bot), 3 ether);
    }

    function testShouldTrade() public {
        assertEq(IERC20(USTB).balanceOf(address(bot)), 9999999999999999999);
        assertEq(IERC20(DAI).balanceOf(address(bot)), 2999999999999999999);

        assertEq(IERC20(MORE).balanceOf(address(bot)), 0);
        assertEq(IERC20(REAL).balanceOf(address(bot)), 0);
        assertEq(IERC20(CAVIAR).balanceOf(address(bot)), 0);

        // trade first paths
        bot.runTrades();

        assertEq(IERC20(USTB).balanceOf(address(bot)), 9970000000000000002);
        assertEq(IERC20(DAI).balanceOf(address(bot)), 2989999999999999999);

        assertGt(IERC20(MORE).balanceOf(address(bot)), 0);
        assertGt(IERC20(REAL).balanceOf(address(bot)), 0);
        assertGt(IERC20(CAVIAR).balanceOf(address(bot)), 0);

        // trade second paths
        bot.runTrades();

        assertEq(IERC20(USTB).balanceOf(address(bot)), 9999268475700985426);
        assertEq(IERC20(DAI).balanceOf(address(bot)), 2999996000599964342);

        assertEq(IERC20(MORE).balanceOf(address(bot)), 0);
        assertEq(IERC20(REAL).balanceOf(address(bot)), 0);
        assertEq(IERC20(CAVIAR).balanceOf(address(bot)), 0);
    }

    function testShouldUpdatePath() external {
        bytes memory oldFirstPath = abi.encodePacked(USTB, uint24(100), arcUSD, uint24(500), UKRE);
        bytes memory oldSecondPath = abi.encodePacked(UKRE, uint24(500), arcUSD, uint24(100), USTB);

        bytes memory newFirstPath = abi.encodePacked(address(1), uint24(100), address(2), uint24(500), address(3));
        bytes memory newSecondPath = abi.encodePacked(address(4), uint24(500), address(5), uint24(100), address(6));

        bytes[] memory firstPaths = new bytes[](1);
        bytes[] memory secondPaths = new bytes[](1);
        uint256[] memory amountToTrade = new uint256[](1);

        firstPaths[0] = newFirstPath;
        secondPaths[0] = newSecondPath;
        amountToTrade[0] = 0.01 ether;

        (bool isPath,) = bot.pathInfo(oldFirstPath);
        assertEq(isPath, true);

        (isPath,) = bot.pathInfo(oldSecondPath);
        assertEq(isPath, true);

        (isPath,) = bot.pathInfo(newFirstPath);
        assertEq(isPath, false);

        (isPath,) = bot.pathInfo(newSecondPath);
        assertEq(isPath, false);

        bot.updatePaths(firstPaths, secondPaths, amountToTrade);

        (isPath,) = bot.pathInfo(oldFirstPath);
        assertEq(isPath, false);

        (isPath,) = bot.pathInfo(oldSecondPath);
        assertEq(isPath, false);

        uint256 amtToTrade;
        (isPath, amtToTrade) = bot.pathInfo(newFirstPath);

        assertEq(isPath, true);
        assertEq(amtToTrade, 0.01 ether);

        (isPath, amtToTrade) = bot.pathInfo(newSecondPath);
        assertEq(isPath, true);
        assertEq(amtToTrade, 0);

        firstPaths = new bytes[](2);

        vm.expectRevert(abi.encodeWithSelector(UnRealTradeBot.UnRealTradeBot_MismatchLength.selector));
        bot.updatePaths(firstPaths, secondPaths, amountToTrade);
    }

    function testShouldUpdateAmountToTrade() external {
        bytes memory firstPath = abi.encodePacked(USTB, uint24(3000), WREETH, uint24(3000), REAL);
        bytes memory secondPath = abi.encodePacked(REAL, uint24(3000), WREETH, uint24(3000), USTB);
        bytes memory fakePath = abi.encodePacked(USTB, uint24(3000), WREETH, uint24(3000), USTB);

        bytes[] memory paths = new bytes[](2);
        uint256[] memory amountToTrade = new uint256[](2);

        paths[0] = firstPath;
        paths[1] = secondPath;
        amountToTrade[0] = 1 ether;
        amountToTrade[1] = 1 ether;

        vm.expectRevert(abi.encodeWithSelector(UnRealTradeBot.UnRealTradeBot_LowBalance.selector));
        bot.updateAmountToTrade(paths, amountToTrade);

        vm.prank(0xbe3d5144BafE54eB5Cb8E20F464746C5E96D1A03);
        IERC20(REAL).transfer(address(bot), 10 ether);

        (, uint256 amtToTrade) = bot.pathInfo(firstPath);
        assertEq(amtToTrade, 0.01 ether);

        (, amtToTrade) = bot.pathInfo(secondPath);
        assertEq(amtToTrade, 0);

        bot.updateAmountToTrade(paths, amountToTrade);

        (, amtToTrade) = bot.pathInfo(firstPath);
        assertEq(amtToTrade, 1 ether);

        (, amtToTrade) = bot.pathInfo(secondPath);
        assertEq(amtToTrade, 1 ether);

        paths[0] = fakePath;
        vm.expectRevert(abi.encodeWithSelector(UnRealTradeBot.UnRealTradeBot_PathDoesNotExist.selector));
        bot.updateAmountToTrade(paths, amountToTrade);

        paths = new bytes[](1);
        vm.expectRevert(abi.encodeWithSelector(UnRealTradeBot.UnRealTradeBot_MismatchLength.selector));
        bot.updateAmountToTrade(paths, amountToTrade);
    }

    function testShouldAddPath() external {
        bytes memory fakePath = abi.encodePacked(USTB, uint24(3000), WREETH, uint24(3000), USTB);
        bytes memory fakePath0 = abi.encodePacked(USTB, uint24(3000), WREETH, uint24(3000), WREETH);

        bytes[] memory firstPaths = new bytes[](1);
        bytes[] memory secondPaths = new bytes[](1);
        uint256[] memory amountToTrade = new uint256[](1);

        firstPaths[0] = fakePath;
        secondPaths[0] = fakePath0;
        amountToTrade[0] = 1 ether;

        bot.runTrades();
        vm.expectRevert(abi.encodeWithSelector(UnRealTradeBot.UnRealTradeBot_MustBeAddedWhenFirstPathIsTrue.selector));

        bot.addPaths(firstPaths, secondPaths, amountToTrade);
        bot.runTrades();

        (bool isPath,) = bot.pathInfo(fakePath);
        assertEq(isPath, false);

        (isPath,) = bot.pathInfo(fakePath0);
        assertEq(isPath, false);

        bot.addPaths(firstPaths, secondPaths, amountToTrade);

        (isPath,) = bot.pathInfo(fakePath);
        assertEq(isPath, true);

        (isPath,) = bot.pathInfo(fakePath0);
        assertEq(isPath, true);

        assertEq(bot.firstPath(4), fakePath);
        assertEq(bot.secondPath(4), fakePath0);

        vm.expectRevert(abi.encodeWithSelector(UnRealTradeBot.UnRealTradeBot_PathAlreadyExist.selector));
        bot.addPaths(firstPaths, secondPaths, amountToTrade);
    }

    function testShouldRemovePath() external {
        bytes memory firstPathToBeRemove = abi.encodePacked(USTB, uint24(100), arcUSD, uint24(500), UKRE);
        bytes memory secondPathToBeRemove = abi.encodePacked(UKRE, uint24(500), arcUSD, uint24(100), USTB);

        bytes memory newFirstPath = abi.encodePacked(DAI, uint24(100), USTB, uint24(100), MORE);
        bytes memory newSecondPath = abi.encodePacked(MORE, uint24(100), USTB, uint24(100), DAI);

        (bool isPath,) = bot.pathInfo(firstPathToBeRemove);
        assertEq(isPath, true);

        (isPath,) = bot.pathInfo(secondPathToBeRemove);
        assertEq(isPath, true);

        assertEq(bot.firstPath(0), firstPathToBeRemove);
        assertEq(bot.secondPath(0), secondPathToBeRemove);

        assertEq(bot.firstPath(3), newFirstPath);
        assertEq(bot.secondPath(3), newSecondPath);

        bot.removePaths(0);

        (isPath,) = bot.pathInfo(firstPathToBeRemove);
        assertEq(isPath, false);

        (isPath,) = bot.pathInfo(secondPathToBeRemove);
        assertEq(isPath, false);

        assertEq(bot.firstPath(0), newFirstPath);
        assertEq(bot.secondPath(0), newSecondPath);

        vm.expectRevert(abi.encodeWithSelector(UnRealTradeBot.UnRealTradeBot_InvalidID.selector));
        bot.removePaths(3);
    }

    function testShouldWithdrawTokens() external {
        uint256 amountToWithdraw = IERC20(USTB).balanceOf(address(bot));
        assertEq(IERC20(USTB).balanceOf(address(1)), 0);

        assertEq(IERC20(USTB).balanceOf(address(bot)), amountToWithdraw);
        bot.withdraw(USTB, address(1), amountToWithdraw);

        assertEq(IERC20(USTB).balanceOf(address(1)), amountToWithdraw);
        assertEq(IERC20(USTB).balanceOf(address(bot)), 0);
    }
}
