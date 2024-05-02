// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
import "../lib/erc20.sol";

interface ICamelotRouter {
  function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    address referrer,
    uint deadline
  ) external;

  function addLiquidity(
    address tokenA,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
  ) external returns (uint amountA, uint amountB, uint liquidity);

  function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
}

interface ICamelotPair is IERC20 {
  function burn(address to) external returns (uint amount0, uint amount1);
  function factory() external view returns (address);

  function token0() external view returns (address);

  function token1() external view returns (address);

  function getAmountOut(uint amountIn, address tokenIn) external view returns (uint);
  function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint16 token0feePercent, uint16 token1FeePercent);
}