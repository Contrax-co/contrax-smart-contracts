// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface ISwapRouter {
    struct ExactInputSingleParams {
      address tokenIn;
      address tokenOut;
      uint24 fee;
      address recipient;
      uint256 deadline;
      uint256 amountIn;
      uint256 amountOutMinimum;
      uint160 sqrtPriceLimitX96;
   }

    struct ExactInputParams {
      bytes path;
      address recipient;
      uint256 deadline;
      uint256 amountIn;
      uint256 amountOutMinimum;
    }


    struct ExactOutputSingleParams {
      address tokenIn;
      address tokenOut;
      uint24 fee;
      address recipient;
      uint256 deadline;
      uint256 amountOut;
      uint256 amountInMaximum;
      uint160 sqrtPriceLimitX96;
    }

    struct ExactOutputParams {
      bytes path;
      address recipient;
      uint256 deadline;
      uint256 amountOut;
      uint256 amountInMaximum;
    }

  /// @notice Swaps `amountIn` of one token for as much as possible of another token
  function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

  /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
  function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

  /// @notice Swaps as little as possible of one token for `amountOut` of another token
  function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

  /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
  function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}



interface IUniswapV3PoolImmutables {
    /// @notice The contract that deployed the pool, which must adhere to the IUniswapV3Factory interface
    /// @return The contract address
    function factory() external view returns (address);

    /// @notice The first of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token0() external view returns (address);

    /// @notice The second of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token1() external view returns (address);

    /// @notice The pool's fee in hundredths of a bip, i.e. 1e-6
    /// @return The fee
    function fee() external view returns (uint24);

    /// @notice The pool tick spacing
    /// @dev Ticks can only be used at multiples of this value, minimum of 1 and always positive
    /// e.g.: a tickSpacing of 3 means ticks can be initialized every 3rd tick, i.e., ..., -6, -3, 0, 3, 6, ...
    /// This value is an int24 to avoid casting even though it is always positive.
    /// @return The tick spacing
    function tickSpacing() external view returns (int24);

    /// @notice The maximum amount of position liquidity that can use any tick in the range
    /// @dev This parameter is enforced per tick to prevent liquidity from overflowing a uint128 at any point, and
    /// also prevents out-of-range liquidity from being used to prevent adding in-range liquidity to a pool
    /// @return The max amount of liquidity per tick
    function maxLiquidityPerTick() external view returns (uint128);
}