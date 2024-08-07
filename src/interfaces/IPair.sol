// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IPair {
    function fee() external view returns (uint24);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function liquidity() external view returns (uint128);
    function reserve0() external view returns (uint256);
    function reserve1() external view returns (uint256);

    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
}
