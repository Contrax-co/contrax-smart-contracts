// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ISwapRouter {
    enum DexType {
        UNISWAP_V2,
        UNISWAP_V3,
        SUSHISWAP_V2,
        SUSHISWAP_V3,
        CAMELOT_V3
    }

    function wrappedNative() external view returns (address);

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address recipient
    ) external returns (uint256 amountOut);

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address recipient,
        DexType dex
    ) external returns (uint256 amountOut);

    function swapWithPath(
        address[] calldata path,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address recipient
    ) external returns (uint256 amountOut);

    function swapWithPath(
        address[] calldata path,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address recipient,
        DexType dex
    ) external returns (uint256 amountOut);

    function getQuoteV3(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        DexType dex
    ) external view returns (uint256 amountOut);

    function getQuoteV3WithPath(
        address[] memory path,
        uint256 amountIn,
        DexType dex
    ) external view returns (uint256 amountOut);
}