// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IPair} from "./interfaces/IPair.sol";
import {IPearlRouter} from "./interfaces/IPearlRouter.sol";
import {IPairFactory} from "./interfaces/IPairFactory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract UnRealTradeBot is Ownable {
    using SafeERC20 for IERC20;

    IPearlRouter router;
    IPairFactory factory;

    uint64 public slippage;
    uint256 constant STABLE_FEE = 100;
    uint256 constant PERCENTAGE = 1_000;

    error UnRealTradeBot_BelowAmountOutMinimum();

    constructor(IPairFactory _factory, IPearlRouter _router) Ownable(msg.sender) {
        router = _router;
        factory = _factory;
    }

    function setSlippage(uint64 _slippage) external onlyOwner {
        slippage = _slippage;
    }

    function swap() external {
        uint256 length = factory.allPairsLength();

        for (uint256 i = 0; i < length;) {
            IPair pool = IPair(factory.allPairs(i));

            if (pool.liquidity() > 0) {
                uint24 fee = pool.fee();
                address token0 = pool.token0();
                address token1 = pool.token1();

                uint256 token0ContractBalance = IERC20(token0).balanceOf(address(this));
                uint256 token1ContractBalance = IERC20(token1).balanceOf(address(this));

                if (token0ContractBalance == 0 && token1ContractBalance == 0) {
                    unchecked {
                        i++;
                    }
                    continue;
                }

                if (token0ContractBalance > 0 && token1ContractBalance > 0) {
                    uint256 reserve0 = pool.reserve0();
                    uint256 reserve1 = pool.reserve1();

                    (address tokenIn, address tokenOut) = reserve0 > reserve1 ? (token1, token0) : (token0, token1);
                    _swap(tokenIn, tokenOut, fee, true);
                } else if (token0ContractBalance > 0) {
                    _swap(token0, token1, fee, true);
                } else if (token1ContractBalance > 0) {
                    _swap(token1, token0, fee, true);
                }
            }

            unchecked {
                i++;
            }
        }
    }

    function _swap(address tokenIn, address tokenOut, uint24 fee, bool feeOnTransfer) internal {
        IERC20 token = IERC20(tokenIn);
        uint256 partBalance = token.balanceOf(address(this)) / 2;

        uint256 amountIn =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % (partBalance + 1);

        uint256 tokenOutBalanceBeforeTx = IERC20(tokenOut).balanceOf(address(this));
        uint256 amountOut = router.getAmountOut(tokenIn, tokenOut, amountIn, fee);
        uint256 amountOutMinimum = (amountOut * slippage) / PERCENTAGE;

        token.forceApprove(address(router), amountIn);
        amountOut = router.swap(tokenIn, tokenOut, amountIn, amountOutMinimum, fee, feeOnTransfer);

        token.forceApprove(address(router), 0);
        uint256 amountRecieved = IERC20(tokenOut).balanceOf(address(this)) - tokenOutBalanceBeforeTx;

        if (amountRecieved < amountOutMinimum) {
            revert UnRealTradeBot_BelowAmountOutMinimum();
        }
    }
}
