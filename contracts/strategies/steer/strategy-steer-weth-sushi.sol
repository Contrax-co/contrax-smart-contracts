// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./strategy-steer-base.sol";
import "../../interfaces/uniswapv2.sol";

// Vault address for steer sushi WETH-Sushi pool
// 0x6723b8E1B28E924857C02F96f7B23041758AfA98

contract StrategySteerWethSushi is StrategySteerBase {
  constructor(
    address _governance,
    address _strategist,
    address _controller,
    address _timelock
  ) StrategySteerBase(0x6723b8E1B28E924857C02F96f7B23041758AfA98, _governance, _strategist, _controller, _timelock) {}

  
  // Dex
  address public router = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506; // suhsi V2 router;
  address public sushi = 0xd4d42F0b6DEF4CE0383636770eF773390d85c61A;


  function _swap(address tokenIn, address tokenOut, uint256 amountIn) internal override {
    address[] memory path;

    // sushi only has liquidity with eth, so always route with weth to swap sushi
    if (tokenIn != weth && tokenOut != weth && (tokenIn == sushi || tokenOut == sushi)) {
      path = new address[](3);
      path[0] = tokenIn;
      path[1] = weth;
      path[2] = tokenOut;

      _approveTokenIfNeeded(weth, address(router));
    } else {
      path = new address[](2); 
      path[0] = tokenIn;
      path[1] = tokenOut;
    }

    _approveTokenIfNeeded(path[0], address(router));

    UniswapRouterV2(router).swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp);
  }
}
