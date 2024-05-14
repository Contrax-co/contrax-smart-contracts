// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/uniswapv2.sol";

contract PriceCalculator {

    // function calculateTokenPriceInUsdc(address _token,address _pairAddress) public view returns (uint256) {
    //     IUniswapV2Pair _pair = IUniswapV2Pair(_pairAddress);
    //     (uint112 _reserve0, uint112 _reserve1,)  = _pair.getReserves();
    //     address token0 = _pair.token0();
    //     address token1 = _pair.token1();

    //     //get token decimals for both tokens
    //     uint8 token0Decimals = IERC20(token0).decimals();
    //     uint8 token1Decimals = IERC20(token1).decimals();

    //     if(_token == token0){
    //         return _reserve0 * 10**18 / _reserve1;
    //     }else if (_token == token1){
    //         return _reserve1 * 10**18 / _reserve0;
    //     }
    //     return 0;

    // }

    function calculateTokenPriceInUsdc(address _token, address _pairAddress) public view returns (uint256) {
    IUniswapV2Pair _pair = IUniswapV2Pair(_pairAddress);
    (uint112 _reserve0, uint112 _reserve1,) = _pair.getReserves();
    address token0 = _pair.token0();
    address token1 = _pair.token1();

    address usdcAddress = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDC address

    // Get token decimals
    uint8 token0Decimals = IERC20(token0).decimals();
    uint8 token1Decimals = IERC20(token1).decimals();

    // Check if the token of interest is token0 or token1 and calculate price accordingly
    if (_token == token0) {
        if (token1 == usdcAddress) {
            // Token1 is USDC
            return _getPrice(_reserve0, _reserve1, token0Decimals, token1Decimals);
        }
    } else if (_token == token1) {
        if (token0 == usdcAddress) {
            // Token0 is USDC
            return _getPrice(_reserve1, _reserve0, token1Decimals, token0Decimals);
        }
    }

    return 0; // If USDC is not part of the pair
}

function _getPrice(uint112 tokenReserve, uint112 usdcReserve, uint8 tokenDecimals, uint8 usdcDecimals) private pure returns (uint256) {
    if (tokenDecimals > usdcDecimals) {
        uint256 factor = 10 ** (tokenDecimals - usdcDecimals);
        return (usdcReserve * factor * 10**18) / tokenReserve;
    } else if (tokenDecimals < usdcDecimals) {
        uint256 factor = 10 ** (usdcDecimals - tokenDecimals);
        return (usdcReserve * 10**18) / (tokenReserve * factor);
    } else {
        return (usdcReserve * 10**18) / tokenReserve;
    }
}



}