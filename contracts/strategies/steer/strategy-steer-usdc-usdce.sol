// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./strategy-steer-base.sol";
import "../../interfaces/uniswapv3.sol";

// Vault address for steer sushi USDC-USDC.e pool
//0x3eE813a6fCa2AaCAF0b7C72428fC5BC031B9BD65

contract StrategySteerUsdcUsdce is StrategySteerBase {
  constructor(
    address _governance,
    address _strategist,
    address _controller,
    address _timelock
  ) StrategySteerBase(0x3eE813a6fCa2AaCAF0b7C72428fC5BC031B9BD65, _governance, _strategist, _controller, _timelock) {}

  // Dex
  address public router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

  function _swap(address tokenIn, address tokenOut, uint256 amountIn) internal override {
    address[] memory path = new address[](2);
    path[0] = tokenIn;
    path[1] = tokenOut;

    address pair;

    if (poolFees[tokenIn][tokenOut] == 0)  pair = fetchPool(tokenIn, tokenOut, uniV3Factory);

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
}
