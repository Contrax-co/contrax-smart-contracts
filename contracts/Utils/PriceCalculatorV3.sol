// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "../lib/erc20.sol";
import "../interfaces/uniswapv3.sol";
import "../lib/OracleLibrary.sol";

contract PriceCalculatorV3 {
  using SafeERC20 for IERC20;

  address public governance;

  uint256 public constant PRECISION = 10_000_000;

  uint24[] public poolsFee = [3000, 500, 100, 350, 80, 10000];

  // Array of stable tokens
  address[] public stableTokens = [
    0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, // BASE USDC
    0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA // BASE USDBC
    // 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8
  ];

  address public WETH_USDC_POOLV3_BASE;

  // Modifier to restrict access to governance only
  modifier onlyGovernance() {
    require(msg.sender == governance, "Caller is not the governance");
    _;
  }

  constructor(address _governance, address _weth_usdc_pool) {
    require(_governance != address(0));
    require(_weth_usdc_pool != address(0));
    governance = _governance;
    WETH_USDC_POOLV3_BASE = _weth_usdc_pool;
  }

  function setPoolFees(uint24 _fee) external onlyGovernance {
    poolsFee.push(_fee);
  }

  // set func to add stable tokens address in the array
  function setStableTokens(address _stableTokens) external onlyGovernance {
    stableTokens.push(_stableTokens);
  }

  function calculateTokenPriceInUsd(address _token, address _pairAddress) public view returns (uint256) {
    IUniswapV3Pool pool = IUniswapV3Pool(_pairAddress);
    (, int24 tick, , , , , ) = pool.slot0();

    address token0 = pool.token0();

    uint256 lpPriceInWei;
    if (_token == token0) {
      lpPriceInWei = getPriceInTermsOfToken0(tick);
    } else {
      lpPriceInWei = getPriceInTermsOfToken1(tick);
    }
    uint256 lpPriceInEth = (lpPriceInWei * PRECISION) / 1e18;
    uint256 ethPriceInUsd = calculateEthPriceInUsdc();
    ethPriceInUsd = ethPriceInUsd / PRECISION;
    return lpPriceInEth * ethPriceInUsd;
  }

  function getPriceInTermsOfToken0(int24 tick) public pure returns (uint256 priceU18) {
    priceU18 = OracleLibrary.getQuoteAtTick(
      tick,
      1e18, // fixed point to 18 decimals
      address(0), // since we want the price in terms of token1/token0
      address(1)
    );
  }

  function getPriceInTermsOfToken1(int24 tick) public pure returns (uint256 priceU18) {
    priceU18 = OracleLibrary.getQuoteAtTick(
      tick,
      1e18, // fixed point to 18 decimals
      address(1), // since we want the price in terms of token0/token1
      address(0)
    );
  }

  function calculateEthPriceInUsdc() public view returns (uint256) {
    IUniswapV3Pool pool = IUniswapV3Pool(WETH_USDC_POOLV3_BASE);
    (, int24 tick, , , , , ) = pool.slot0();

    uint256 PriceFromOracle = getPriceInTermsOfToken0(tick);

    //removing usdc decimals
    return (PriceFromOracle * PRECISION) / 1e6;
  }
}
