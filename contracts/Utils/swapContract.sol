// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "../lib/erc20.sol";
import "../lib/ABDKMath64x64.sol";
import "../interfaces/uniswapv2.sol";
import "../interfaces/uniswapv3.sol";

contract SwapRouter {
  using SafeERC20 for IERC20;
  using ABDKMath64x64 for uint256;
  address public governance;

  // tokenIn => tokenOut => poolFee
  mapping(address => mapping(address => uint24)) public poolFees;

  uint256 private minimumLiquidityV3 = 1e18;

  uint24[] public poolsFee = [3000, 500, 100, 10000];

  address[] public routerAddresses = [
    0xE592427A0AEce92De3Edee1F18E0157C05861564, // uniswap v3
    0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506, // sushiswap v2
    0x8A21F6768C1f8075791D08546Dadf6daA0bE820c, // sushiswap v3
    0xc873fEcbd354f5A56E00E710B90EF4201db2448d, // camelotswap v2
    0x1F721E2E82F6676FCE4eA07A5958cF098D339e18 // camelotswap v3
  ];

  address[] public factoryAddressesV2 = [
    0xc35DADB65012eC5796536bD9864eD8773aBc74C4, // sushiswap v2
    0x6EcCab422D763aC031210895C81787E87B43A652 // camelotswap v2
  ];

  address[] public factoryAddressesV3 = [
    0x1F98431c8aD98523631AE4a59f267346ea31F984, // uniswap v3
    0x1af415a1EbA07a4986a52B6f2e7dE7003D82231e, // sushiswap v3
    0x1a3c9B1d2F0529D97f2afC5136Cc23e58f1FD35B // camelotswap v3
  ];

  function setRouter(address _router) external onlyGovernance {
    routerAddresses.push(_router);
  }

  // Modifier to restrict access to governance only
  modifier onlyGovernance() {
    require(msg.sender == governance, "Caller is not the governance");
    _;
  }

  constructor(address _governance) {
    require(_governance != address(0));
    governance = _governance;
  }

  function fetchPoolV2(address tokenIn, address tokenOut) internal view returns (address) {
    address pairWithMaxLiquidity = address(0);
    uint256 maxLiquidity = 0;

    for (uint256 i = 0; i < factoryAddressesV2.length; i++) {
      address currentPair = IUniswapV2Factory(factoryAddressesV2[i]).getPair(tokenIn, tokenOut);
      if (currentPair != address(0)) {
        (uint128 _reserve0, uint128 _reserve1, ) = IUniswapV2Pair(currentPair).getReserves();
        uint256 currenctLiq = uint256(int256(ABDKMath64x64.sqrt(int128(_reserve0 * _reserve1))));

        if (currenctLiq > maxLiquidity) {
          maxLiquidity = currenctLiq;
          pairWithMaxLiquidity = currentPair;
        }
      }
    }
    return pairWithMaxLiquidity;
  }

  function fetchPoolV3(address tokenIn, address tokenOut) internal returns (address) {
    address pair;
    for (uint256 i = 0; i < factoryAddressesV3.length; i++) {
      pair = fetchMaxLiquidPoolV3(tokenIn, tokenOut, factoryAddressesV3[i]);
      if (pair != address(0)) break;
    }
    return pair;
  }

  function fetchMaxLiquidPoolV3(address token0, address token1, address _V3Factory) internal returns (address) {
    address pairWithMaxLiquidity = address(0);
    uint256 maxLiquidity = 0;

    for (uint256 i = 0; i < poolsFee.length; i++) {
      address currentPair = IUniswapV3Factory(_V3Factory).getPool(token0, token1, poolsFee[i]);
      if (currentPair != address(0)) {
        uint256 currentLiquidity = IUniswapV3Pool(currentPair).liquidity();
        if (currentLiquidity > maxLiquidity) {
          maxLiquidity = currentLiquidity;
          pairWithMaxLiquidity = currentPair;
          poolFees[token0][token1] = poolsFee[i];
          // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
          poolFees[token1][token0] = poolsFee[i];
        }
      }
    }
    return pairWithMaxLiquidity;
  }

  function swap(address tokenIn, address tokenOut, uint256 amountIn) external {
    for (uint256 i = 0; i < routerAddresses.length; i++) {}
  }
}
