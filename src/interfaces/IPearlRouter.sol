// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IPearlRouter {
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint24 fee,
        bool feeOnTransfer
    ) external returns (uint256);

    function getAmountOut(address tokenIn, address tokenOut, uint256 amountIn, uint24 fee)
        external
        returns (uint256 amountOut);
}
