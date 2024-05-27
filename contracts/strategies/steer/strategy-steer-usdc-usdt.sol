// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./strategy-steer-base.sol";
import "../../interfaces/uniswapv3.sol";

// Vault address for steer sushi USDT-USDC pool
//0x5DbAD371890C3A89f634e377c1e8Df987F61fB64

contract StrategySteerUsdcUsdt is StrategySteerBase {
  constructor(
    address _governance,
    address _strategist,
    address _controller,
    address _timelock
  ) StrategySteerBase(0x5DbAD371890C3A89f634e377c1e8Df987F61fB64, _governance, _strategist, _controller, _timelock) {}
  
  // Dex
  address public router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

  function _swap(address tokenIn, address tokenOut, uint256 amountIn) internal override {
    address[] memory path = new address[](2);
    path[0] = tokenIn;
    path[1] = tokenOut;

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
