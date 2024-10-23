// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../strategy-steer-base.sol";
import "../../../interfaces/uniswapv3.sol";

// Vault address for steer sushi WETH-SNSY vault
// 0x3c88c76783a9f2975c6d58f2aa1437f1e8229335
// V3 Factory sushi => 0xc35DADB65012eC5796536bD9864eD8773aBc74C4

contract StrategySteerWethSnsy is StrategySteerBase {
  constructor(
    address _governance,
    address _strategist,
    address _controller, 
    address _timelock,
    address _weth,
    address _V3Factory,
    address _steerPeriphery,
    address _weth_usdc_pool,
    address[] memory _stableTokens
  )
    StrategySteerBase(
      0x3C88c76783a9f2975C6d58F2aa1437f1E8229335,
      _governance,
      _strategist,
      _controller,
      _timelock,
      _weth,
      _V3Factory,
      _steerPeriphery,
      _weth_usdc_pool,
      _stableTokens
    )
  {}

  // Dex
  address public constant router = 0xFB7eF66a7e61224DD6FcD0D7d9C3be5C8B049b9f;

  function _swapBase(address tokenIn, address tokenOut, uint256 amountIn) internal {
    address[] memory path = new address[](2);
    path[0] = tokenIn;
    path[1] = tokenOut;

    if (poolFees[tokenIn][tokenOut] == 0) fetchPool(tokenIn, tokenOut, V3FACTORY);

    _approveTokenIfNeeded(path[0], address(router));
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

    ISwapRouter(address(router)).exactInputSingle(params);
  }

  function _swap(address tokenIn, address tokenOut, uint256 amountIn) internal override {

     if (tokenIn == weth || tokenOut == weth) {
      _swapBase(tokenIn, tokenOut, amountIn);
      return;
    }
 
    address[] memory path = new address[](3);
    path[0] = tokenIn;
    path[1] = weth;
    path[2] = tokenOut;

    if (poolFees[weth][tokenOut] == 0) fetchPool(weth, tokenOut, V3FACTORY);
    if (poolFees[tokenIn][weth] == 0) fetchPool(tokenIn, weth, V3FACTORY);

    _approveTokenIfNeeded(path[0], address(router));

    ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
      path: abi.encodePacked(path[0], getPoolFee(path[0], path[1]), path[1], getPoolFee(path[1], path[2]), path[2]),
      recipient: address(this),
      deadline: block.timestamp,
      amountIn: amountIn,
      amountOutMinimum: 0
    });

    // Executes the swap
    ISwapRouter(router).exactInput(params);
  }
}
