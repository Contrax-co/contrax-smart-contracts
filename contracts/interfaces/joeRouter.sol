// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

  struct LiquidityParameters {
    address tokenX;
    address tokenY;
    uint256 binStep;
    uint256 amountX;
    uint256 amountY;
    uint256 amountXMin;
    uint256 amountYMin;
    uint256 activeIdDesired;
    uint256 idSlippage;
    int256[] deltaIds;
    uint256[] distributionX;
    uint256[] distributionY;
    address to;
    uint256 deadline;
  }

interface LBRouter {
  function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    uint256[] memory pairBinSteps,
    address[] memory tokenPath,
    address to,
    uint256 deadline
  ) external returns (uint256 amountOut);

  function addLiquidityAVAX(LiquidityParameters calldata _liquidityParameters)
    external
    payable
    returns (uint256[] memory depositIds, uint256[] memory liquidityMinted);
}