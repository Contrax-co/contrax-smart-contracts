// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "../lib/erc20.sol";
import "../interfaces/uniswapv3.sol";
import "../lib/OracleLibrary.sol";
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";

contract PriceCalculatorV3 is SphereXProtected {
  using SafeERC20 for IERC20;

  address public governance;
  address weth;

  uint256 public constant PRECISION = 1_000_000_000;

  uint24[] public poolsFee = [3000, 500, 100, 350, 80, 10000];

  // Array of stable tokens
  address[] public stableTokens;

  // [
  //   0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, // BASE USDC
  //   0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA // BASE USDBC
  //   // 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8
  // ];

  address public WETH_USDC_POOLV3;

  // Modifier to restrict access to governance only
  modifier onlyGovernance() {
    require(msg.sender == governance, "Caller is not the governance");
    _;
  }

  constructor(address _governance, address _weth_usdc_pool, address _weth, address[] memory _stableTokens) {
    require(_governance != address(0));
    require(_weth_usdc_pool != address(0));
    require(_weth != address(0));
    governance = _governance;
    WETH_USDC_POOLV3 = _weth_usdc_pool;
    weth = _weth;
    for (uint256 i = 0; i < _stableTokens.length; i++) {
      stableTokens.push(_stableTokens[i]);
    }
  }

  function setPoolFees(uint24 _fee) external onlyGovernance sphereXGuardExternal(0x65a8940c) {
    poolsFee.push(_fee);
  }

  // set func to add stable tokens address in the array
  function setStableTokens(address _stableTokens) external onlyGovernance sphereXGuardExternal(0x6edb969e) {
    stableTokens.push(_stableTokens);
  }

  function calculateTokenPriceInUsd(address _token, address _pairAddress) public view returns (uint256) {
    IUniswapV3Pool pool = IUniswapV3Pool(_pairAddress);
    (, int24 tick, , , , , ) = pool.slot0();

    address token0 = pool.token0();
    address token1 = pool.token1();

    //get token0 decimals
    uint256 token0base = 10 ** uint256(IERC20(token0).decimals());
    //get token1 decimals
    uint256 token1base = 10 ** uint256(IERC20(token1).decimals());

    uint256 priceAgainstEthInToken;
    if (_token == token0) {
      priceAgainstEthInToken = getPriceInTermsOfToken1(tick);
    } else {
      priceAgainstEthInToken = getPriceInTermsOfToken0(tick);
    }
    uint256 ethPriceInToken = (priceAgainstEthInToken * PRECISION) / (_token == token0 ? token0base : token1base);

    uint256 tokenPriceInEth = (PRECISION * PRECISION) / ethPriceInToken;

    uint256 ethPriceInUsd = calculateEthPriceInUsdc();

    uint256 tokenPriceInUsd = (tokenPriceInEth * ethPriceInUsd) / PRECISION;

    return tokenPriceInUsd;
  }

  function getPriceInTermsOfToken0(int24 tick) public pure returns (uint256 priceU18) {
    priceU18 = OracleLibrary.getQuoteAtTick(
      tick,
      1e18,
      address(0), // since we want the price in terms of token1/token0
      address(1)
    );
  }

  function getPriceInTermsOfToken1(int24 tick) public pure returns (uint256 priceU18) {
    priceU18 = OracleLibrary.getQuoteAtTick(
      tick,
      1e18,
      address(1), // since we want the price in terms of token0/token1
      address(0)
    );
  }

  function calculateEthPriceInUsdc() public view returns (uint256) {
    IUniswapV3Pool pool = IUniswapV3Pool(WETH_USDC_POOLV3);
    (, int24 tick, , , , , ) = pool.slot0();

    uint256 PriceFromOracle = getPriceInTermsOfToken0(tick);
    //removing usdc decimals
    return (PriceFromOracle * PRECISION) / 1e6;
  }
}
