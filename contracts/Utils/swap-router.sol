// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;
pragma abicoder v2;

import "../lib/erc20.sol";
import "../lib/ABDKMath64x64.sol";
import "../interfaces/uniswapv2.sol";
import "../interfaces/uniswapv3.sol";
import "../interfaces/camelot.sol";

contract SwapRouter {
  using SafeERC20 for IERC20;
  using ABDKMath64x64 for uint256;

  address public governance;

  uint256 private maxLiquidityV3 = 0;
  uint256 private maxLiquidityV2 = 0;
  // uint256 private maxLiquidityV1 = 0;

  address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
  address constant CAMELOT_ROUTER = 0x1F721E2E82F6676FCE4eA07A5958cF098D339e18;
  address constant CAMELOT_FACTORY_V3 = 0x1a3c9B1d2F0529D97f2afC5136Cc23e58f1FD35B;

  // tokenIn => tokenOut => poolFee
  mapping(address => mapping(address => uint24)) public poolFees;

  // factory => router && router => factory
  mapping(address => address) public factoryToRouter;

  uint24[] private poolsFee = [3000, 500, 100, 10000];

  address[] private routerAddressesv2 = [
    0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506, // sushiswap v2
    0xc873fEcbd354f5A56E00E710B90EF4201db2448d // camelotswap v2
  ];

  address[] private factoryAddressesV2 = [
    0xc35DADB65012eC5796536bD9864eD8773aBc74C4, // sushiswap v2
    0x6EcCab422D763aC031210895C81787E87B43A652 // camelotswap v2
  ];

  address[] private routerAddressesv3 = [
    0xE592427A0AEce92De3Edee1F18E0157C05861564, // uniswap v3
    0x8A21F6768C1f8075791D08546Dadf6daA0bE820c // sushiswap v3
  ];

  address[] private factoryAddressesV3 = [
    0x1F98431c8aD98523631AE4a59f267346ea31F984, // uniswap v3
    0x1af415a1EbA07a4986a52B6f2e7dE7003D82231e // sushiswap v3
  ];

  // Modifier to restrict access to governance only
  modifier onlyGovernance() {
    require(msg.sender == governance, "Caller is not the governance");
    _;
  }

  constructor(address _governance) {
    require(_governance != address(0));
    governance = _governance;
    //set routers
    for (uint i = 0; i < routerAddressesv2.length; i++) {
      factoryToRouter[factoryAddressesV2[i]] = routerAddressesv2[i]; // bi directional mapping
      factoryToRouter[routerAddressesv2[i]] = factoryAddressesV2[i];
    }
    for (uint i = 0; i < routerAddressesv3.length; i++) {
      factoryToRouter[factoryAddressesV3[i]] = routerAddressesv3[i];
      factoryToRouter[routerAddressesv3[i]] = factoryAddressesV3[i];
    }
  }

  function getPoolFee(address token0, address token1) public view returns (uint24) {
    uint24 fee = poolFees[token0][token1];
    return fee;
  }

  function fetchPoolV2(address tokenIn, address tokenOut) internal returns (address pair, address factory) {
    pair = address(0);
    factory = address(0);
    uint256 maxLiquidity = 0;

    for (uint256 i = 0; i < factoryAddressesV2.length; i++) {
      address currentPair = IUniswapV2Factory(factoryAddressesV2[i]).getPair(tokenIn, tokenOut);
      if (currentPair != address(0)) {
        (uint128 _reserve0, uint128 _reserve1, ) = IUniswapV2Pair(currentPair).getReserves();
        uint256 currenctLiq = uint256(int256(ABDKMath64x64.sqrt(int128(_reserve0 * _reserve1))));

        if (currenctLiq > maxLiquidity) {
          maxLiquidityV2 = currenctLiq;
          maxLiquidity = currenctLiq;
          pair = currentPair;
          factory = factoryAddressesV2[i];
        }
      }
    }
  }

  function fetchPoolV3(address tokenIn, address tokenOut) internal returns (address pair, address factory) {
    factory = address(0);
    for (uint256 i = 0; i < factoryAddressesV3.length; i++) {
      pair = fetchMaxLiquidPoolV3(tokenIn, tokenOut, factoryAddressesV3[i]);
      if (pair != address(0)) {
        factory = factoryAddressesV3[i];
        break;
      }
    }
  }

  function fetchMaxLiquidPoolForCamelot(
    address token0,
    address token1
  ) internal returns (address pairWithMaxLiquidity) {
    pairWithMaxLiquidity = address(0);
    uint256 maxLiquidity = 0;

    address currentPair = IAlgebraFactory(CAMELOT_FACTORY_V3).poolByPair(token0, token1);
    if (currentPair != address(0)) {
      // get pair tokens
      address token0Address = IUniswapV3Pool(currentPair).token0();
      address token1Address = IUniswapV3Pool(currentPair).token1();

      uint256 token0Reserve = IERC20(currentPair).balanceOf(token0Address);
      uint256 token1Reserve = IERC20(currentPair).balanceOf(token1Address);

      // get pair liquidity
      uint256 currentLiquidity = uint256(int256(ABDKMath64x64.sqrt(int128(uint128(token0Reserve * token1Reserve)))));

      if (currentLiquidity > maxLiquidity && currentLiquidity > maxLiquidityV3) {
        maxLiquidityV3 = currentLiquidity;
        maxLiquidity = currentLiquidity;
        pairWithMaxLiquidity = currentPair;
      }
      pairWithMaxLiquidity;
    }
  }

  function fetchMaxLiquidPoolV3(address token0, address token1, address _V3Factory) internal returns (address) {
    address pairWithMaxLiquidity = address(0);
    uint256 maxLiquidity = 0;

    for (uint256 i = 0; i < poolsFee.length; i++) {
      address currentPair = IUniswapV3Factory(_V3Factory).getPool(token0, token1, poolsFee[i]);
      if (currentPair != address(0)) {
        // get pair tokens
        address token0Address = IUniswapV3Pool(currentPair).token0();
        address token1Address = IUniswapV3Pool(currentPair).token1();

        uint256 token0Reserve = IERC20(currentPair).balanceOf(token0Address);
        uint256 token1Reserve = IERC20(currentPair).balanceOf(token1Address);

        // get pair liquidity
        uint256 currentLiquidity = uint256(int256(ABDKMath64x64.sqrt(int128(uint128(token0Reserve * token1Reserve)))));

        if (currentLiquidity > maxLiquidity && currentLiquidity > maxLiquidityV3) {
          maxLiquidityV3 = currentLiquidity;
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

  function swapCamelotV3(address _tokenIn, address _tokenOut, uint256 _amountIn) internal {
    address[] memory path = new address[](2);
    path[0] = _tokenIn;
    path[1] = _tokenOut;

    _approveTokenIfNeeded(path[0], address(CAMELOT_ROUTER));

    ICamelotRouterV3.ExactInputSingleParams memory params = ICamelotRouterV3.ExactInputSingleParams({
      tokenIn: path[0],
      tokenOut: path[1],
      recipient: address(this),
      deadline: block.timestamp,
      amountIn: _amountIn,
      amountOutMinimum: 0,
      sqrtPriceLimitX96: 0
    });

    // The call to `exactInputSingle` executes the swap.
    ICamelotRouterV3(CAMELOT_ROUTER).exactInputSingle(params);
    _returnAssets(path);
  }

  function swapCamelotV2(address tokenIn, address tokenOut, uint256 _amount) internal {
    address[] memory path;

    path = new address[](2);
    path[0] = tokenIn;
    path[1] = tokenOut;

    _approveTokenIfNeeded(path[0], address(CAMELOT_ROUTER));

    ICamelotRouter(CAMELOT_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
      _amount,
      0,
      path,
      address(this),
      address(0),
      block.timestamp
    );
  }

  function swapV2(address tokenIn, address tokenOut, uint256 amountIn, address _router) internal {
    address[] memory path;

    path = new address[](2); // 2 path
    path[0] = tokenIn;
    path[1] = tokenOut;

    _approveTokenIfNeeded(path[0], address(_router));

    UniswapRouterV2(_router).swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp);

    _returnAssets(path);
  }

  function multiPathSwapV2(address tokenIn, address tokenOut, uint256 amountIn, address _router) internal {
    address[] memory path = new address[](3);
    path[0] = tokenIn;
    path[1] = WETH;
    path[2] = tokenOut;

    _approveTokenIfNeeded(WETH, address(_router));

    _approveTokenIfNeeded(path[0], address(_router));

    UniswapRouterV2(_router).swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp);

    _returnAssets(path);
  }

  function multiPathSwapCamelotV2(address tokenIn, address tokenOut, uint256 _amount) internal {
    address[] memory path = new address[](3);
    path[0] = tokenIn;
    path[1] = WETH;
    path[2] = tokenOut;

    _approveTokenIfNeeded(WETH, address(CAMELOT_ROUTER));

    _approveTokenIfNeeded(path[0], address(CAMELOT_ROUTER));

    ICamelotRouter(CAMELOT_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
      _amount,
      0,
      path,
      address(this),
      address(0),
      block.timestamp
    );
  }

  function multiPathSwapV3(address tokenIn, address tokenOut, uint256 amountIn, address _router) internal {
    address[] memory path = new address[](3);
    path[0] = tokenIn;
    path[1] = WETH;
    path[2] = tokenOut;

    if (poolFees[WETH][tokenOut] == 0) {
      (, address factoryV3) = fetchPoolV3(WETH, tokenOut);
      require(factoryToRouter[factoryV3] == _router, "router mismatch");
    }

    _approveTokenIfNeeded(path[0], address(_router));

    ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
      path: abi.encodePacked(path[0], getPoolFee(path[0], path[1]), path[1], getPoolFee(path[1], path[2]), path[2]),
      recipient: address(this),
      deadline: block.timestamp,
      amountIn: amountIn,
      amountOutMinimum: 0
    });

    // Executes the swap
    ISwapRouter(_router).exactInput(params);

    _returnAssets(path);
  }

  function swapV3(address tokenIn, address tokenOut, uint256 amountIn, address _router) internal {
    address[] memory path = new address[](2);
    path[0] = tokenIn;
    path[1] = tokenOut;

    if (poolFees[tokenIn][tokenOut] == 0) {
      (, address factoryV3) = fetchPoolV3(tokenIn, tokenOut);
      if (factoryV3 != address(0)) _router = factoryToRouter[factoryV3];
    }

    _approveTokenIfNeeded(path[0], address(_router));
    ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
      tokenIn: path[0],
      tokenOut: path[1],
      fee: getPoolFee(tokenIn, tokenOut),
      recipient: address(this),
      deadline: block.timestamp,
      amountIn: amountIn,
      amountOutMinimum: 0,
      sqrtPriceLimitX96: 0
    });

    ISwapRouter(address(_router)).exactInputSingle(params);

    _returnAssets(path);
  }

  function multiRouteSwap(address tokenIn, address tokenOut, uint256 amountIn) internal {
    (, address factoryV2) = fetchPoolV2(tokenIn, WETH);
    (, address factoryV3) = fetchPoolV3(tokenIn, WETH);
    if (factoryV2 != address(0) && maxLiquidityV2 > maxLiquidityV3) {
      multiPathSwapV2(tokenIn, tokenOut, amountIn, factoryToRouter[factoryV2]);
    } else if (factoryV3 != address(0) && maxLiquidityV3 > maxLiquidityV2) {
      multiPathSwapV3(tokenIn, tokenOut, amountIn, factoryToRouter[factoryV3]);
    }
  }

  function swap(address tokenIn, address tokenOut, uint256 amountIn) external {
    (, address factoryV2) = fetchPoolV2(tokenIn, tokenOut);
    (, address factoryV3) = fetchPoolV3(tokenIn, tokenOut);
    if (factoryV2 != address(0) && maxLiquidityV2 > maxLiquidityV3) {
      swapV2(tokenIn, tokenOut, amountIn, factoryToRouter[factoryV2]);
    } else if (factoryV3 != address(0) && maxLiquidityV3 > maxLiquidityV2) {
      swapV3(tokenIn, tokenOut, amountIn, factoryToRouter[factoryV3]);
    } else {
      multiRouteSwap(tokenIn, tokenOut, amountIn);
    }
  }

  function _approveTokenIfNeeded(address token, address spender) internal {
    if (IERC20(token).allowance(address(this), spender) == 0) {
      IERC20(token).safeApprove(spender, type(uint256).max);
    }
  }

  //returns DUST
  function _returnAssets(address[] memory tokens) internal {
    uint256 balance;
    for (uint256 i; i < tokens.length; i++) {
      balance = IERC20(tokens[i]).balanceOf(address(this));
      if (balance > 0) {
        IERC20(tokens[i]).safeTransfer(msg.sender, balance);
      }
    }
  }
}
