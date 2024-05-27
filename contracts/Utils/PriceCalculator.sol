// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "../lib/erc20.sol";

import "../interfaces/uniswapv2.sol";

contract PriceCalculator {
  using SafeERC20 for IERC20;
  address public governance;

  uint256 public constant PRECISION = 10_000_000;

  address public weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
  //For arb weth/usdc
  address public weth_Usdc_Pair = 0x905dfCD5649217c42684f23958568e533C711Aa3;

  // Array of stable tokens
  address[] public stableTokens = [
    0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
    0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9,
    0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8
  ];

  // Modifier to restrict access to governance only
  modifier onlyGovernance() {
    require(msg.sender == governance, "Caller is not the governance");
    _;
  }

  constructor(address _governance) {
    require(_governance != address(0));
    governance = _governance;
  }

  // set func to add stable tokens address in the array
  function setStableTokens(address _stableTokens) external onlyGovernance {
    stableTokens.push(_stableTokens);
  }

  function calculateTokenPriceInUsdc(address _token, address _pairAddress) public view returns (uint256) {
    IUniswapV2Pair _pair = IUniswapV2Pair(_pairAddress);
    (uint112 _reserve0, uint112 _reserve1, ) = _pair.getReserves();
    address token0 = _pair.token0();
    address token1 = _pair.token1();
    // Get token decimals
    uint8 token0Decimals = IERC20(token0).decimals();
    uint8 token1Decimals = IERC20(token1).decimals();

    // Check if the token of interest is token0 or token1 and calculate price accordingly
    if (_token == token0) {
      //check if token1 is in stable tokens array
      for (uint256 i = 0; i < stableTokens.length; i++) {
        if (stableTokens[i] == token1) {
          uint256 assetPrice = _getPrice(_reserve0, _reserve1, token0Decimals, token1Decimals);
          return assetPrice;
        }
      }
    } else if (_token == token1) {
      //check if token0 is in stable tokens array
      for (uint256 i = 0; i < stableTokens.length; i++) {
        if (stableTokens[i] == token0) {
          uint256 assetPrice = _getPrice(_reserve1, _reserve0, token1Decimals, token0Decimals);
          return assetPrice;
        }
      }
    }
    return 0;
  }

  // pair should be of WEth/LpToken eg weth/Sushi
  function calculateLpPriceInUsdc(address _lpToken, address _pairAddress) public view returns (uint256) {
    IUniswapV2Pair _pair = IUniswapV2Pair(_pairAddress);
    (uint112 _reserve0, uint112 _reserve1, ) = _pair.getReserves();
    address token0 = _pair.token0();
    address token1 = _pair.token1();
    uint8 token0Decimals = IERC20(token0).decimals();
    uint8 token1Decimals = IERC20(token1).decimals();
    //Calculate price of eth in usdc
    uint256 priceOfEthInUsdc = calculateTokenPriceInUsdc(weth, weth_Usdc_Pair);

    //Get price of lp in Eth
    uint256 lpPriceInEth;
    if (_lpToken == token0) {
      lpPriceInEth = _getPrice(_reserve0, _reserve1, token0Decimals, token1Decimals);
    } else {
      lpPriceInEth = _getPrice(_reserve1, _reserve0, token1Decimals, token0Decimals);
    }

    return (priceOfEthInUsdc * lpPriceInEth) / PRECISION;
  }

  function _getPrice(
    uint112 tokenReserve,
    uint112 priceInTokenReserve,
    uint8 tokenDecimals,
    uint8 priceInTokenDecimals
  ) private pure returns (uint256) {
    if (tokenDecimals > priceInTokenDecimals) {
      uint256 factor = 10 ** (tokenDecimals - priceInTokenDecimals);
      return ((priceInTokenReserve * factor) * PRECISION) / tokenReserve;
    } else if (tokenDecimals < priceInTokenDecimals) {
      uint256 factor = 10 ** (priceInTokenDecimals - tokenDecimals);
      return ((priceInTokenReserve) * PRECISION) / (tokenReserve * factor);
    } else {
      return ((priceInTokenReserve) * PRECISION) / tokenReserve;
    }
  }
}
