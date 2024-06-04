// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.4;

import "../interfaces/uniswapv3.sol";

/// @title Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
library FullMath {
  /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
  /// @param a The multiplicand
  /// @param b The multiplier
  /// @param denominator The divisor
  /// @return result The 256-bit result
  /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
  function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
    // 512-bit multiply [prod1 prod0] = a * b
    // Compute the product mod 2**256 and mod 2**256 - 1
    // then use the Chinese Remainder Theorem to reconstruct
    // the 512 bit result. The result is stored in two 256
    // variables such that product = prod1 * 2**256 + prod0
    uint256 prod0; // Least significant 256 bits of the product
    uint256 prod1; // Most significant 256 bits of the product
    assembly {
      let mm := mulmod(a, b, not(0))
      prod0 := mul(a, b)
      prod1 := sub(sub(mm, prod0), lt(mm, prod0))
    }

    // Handle non-overflow cases, 256 by 256 division
    if (prod1 == 0) {
      require(denominator > 0);
      assembly {
        result := div(prod0, denominator)
      }
      return result;
    }

    // Make sure the result is less than 2**256.
    // Also prevents denominator == 0
    require(denominator > prod1);

    ///////////////////////////////////////////////
    // 512 by 256 division.
    ///////////////////////////////////////////////

    // Make division exact by subtracting the remainder from [prod1 prod0]
    // Compute remainder using mulmod
    uint256 remainder;
    assembly {
      remainder := mulmod(a, b, denominator)
    }
    // Subtract 256 bit number from 512 bit number
    assembly {
      prod1 := sub(prod1, gt(remainder, prod0))
      prod0 := sub(prod0, remainder)
    }

    // Factor powers of two out of denominator
    // Compute largest power of two divisor of denominator.
    // Always >= 1.
    uint256 twos = (~denominator + 1) & denominator;
    // Divide denominator by power of two
    assembly {
      denominator := div(denominator, twos)
    }

    // Divide [prod1 prod0] by the factors of two
    assembly {
      prod0 := div(prod0, twos)
    }
    // Shift in bits from prod1 into prod0. For this we need
    // to flip `twos` such that it is 2**256 / twos.
    // If twos is zero, then it becomes one
    assembly {
      twos := add(div(sub(0, twos), twos), 1)
    }
    prod0 |= prod1 * twos;

    // Invert denominator mod 2**256
    // Now that denominator is an odd number, it has an inverse
    // modulo 2**256 such that denominator * inv = 1 mod 2**256.
    // Compute the inverse by starting with a seed that is correct
    // correct for four bits. That is, denominator * inv = 1 mod 2**4
    uint256 inv = (3 * denominator) ^ 2;
    // Now use Newton-Raphson iteration to improve the precision.
    // Thanks to Hensel's lifting lemma, this also works in modular
    // arithmetic, doubling the correct bits in each step.
    inv *= 2 - denominator * inv; // inverse mod 2**8
    inv *= 2 - denominator * inv; // inverse mod 2**16
    inv *= 2 - denominator * inv; // inverse mod 2**32
    inv *= 2 - denominator * inv; // inverse mod 2**64
    inv *= 2 - denominator * inv; // inverse mod 2**128
    inv *= 2 - denominator * inv; // inverse mod 2**256

    // Because the division is now exact we can divide by multiplying
    // with the modular inverse of denominator. This will give us the
    // correct result modulo 2**256. Since the precoditions guarantee
    // that the outcome is less than 2**256, this is the final result.
    // We don't need to compute the high bits of the result and prod1
    // is no longer required.
    result = prod0 * inv;
    return result;
  }

  /// @notice Calculates ceil(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
  /// @param a The multiplicand
  /// @param b The multiplier
  /// @param denominator The divisor
  /// @return result The 256-bit result
  function mulDivRoundingUp(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
    result = mulDiv(a, b, denominator);
    if (mulmod(a, b, denominator) > 0) {
      require(result < type(uint256).max);
      result++;
    }
  }
}

/// @title Math library for computing sqrt prices from ticks and vice versa
/// @notice Computes sqrt price for ticks of size 1.0001, i.e. sqrt(1.0001^tick) as fixed point Q64.96 numbers. Supports
/// prices between 2**-128 and 2**128
library TickMath {
  /// @dev The minimum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**-128
  int24 internal constant MIN_TICK = -887272;
  /// @dev The maximum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**128
  int24 internal constant MAX_TICK = -MIN_TICK;

  /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
  uint160 internal constant MIN_SQRT_RATIO = 4295128739;
  /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
  uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

  /// @notice Calculates sqrt(1.0001^tick) * 2^96
  /// @dev Throws if |tick| > max tick
  /// @param tick The input tick for the above formula
  /// @return sqrtPriceX96 A Fixed point Q64.96 number representing the sqrt of the ratio of the two assets (token1/token0)
  /// at the given tick
  function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
    uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));
    require(absTick <= uint256(uint24(MAX_TICK)), "T");

    uint256 ratio = absTick & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
    if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
    if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
    if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
    if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
    if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
    if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
    if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
    if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
    if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
    if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
    if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
    if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
    if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
    if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
    if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
    if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
    if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
    if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
    if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

    if (tick > 0) ratio = type(uint256).max / ratio;

    // this divides by 1<<32 rounding up to go from a Q128.128 to a Q128.96.
    // we then downcast because we know the result always fits within 160 bits due to our tick input constraint
    // we round up in the division so getTickAtSqrtRatio of the output price is always consistent
    sqrtPriceX96 = uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
  }

  /// @notice Calculates the greatest tick value such that getRatioAtTick(tick) <= ratio
  /// @dev Throws in case sqrtPriceX96 < MIN_SQRT_RATIO, as MIN_SQRT_RATIO is the lowest value getRatioAtTick may
  /// ever return.
  /// @param sqrtPriceX96 The sqrt ratio for which to compute the tick as a Q64.96
  /// @return tick The greatest tick for which the ratio is less than or equal to the input ratio
  function getTickAtSqrtRatio(uint160 sqrtPriceX96) internal pure returns (int24 tick) {
    // second inequality must be < because the price can never reach the price at the max tick
    require(sqrtPriceX96 >= MIN_SQRT_RATIO && sqrtPriceX96 < MAX_SQRT_RATIO, "R");
    uint256 ratio = uint256(sqrtPriceX96) << 32;

    uint256 r = ratio;
    uint256 msb = 0;

    assembly {
      let f := shl(7, gt(r, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
      msb := or(msb, f)
      r := shr(f, r)
    }
    assembly {
      let f := shl(6, gt(r, 0xFFFFFFFFFFFFFFFF))
      msb := or(msb, f)
      r := shr(f, r)
    }
    assembly {
      let f := shl(5, gt(r, 0xFFFFFFFF))
      msb := or(msb, f)
      r := shr(f, r)
    }
    assembly {
      let f := shl(4, gt(r, 0xFFFF))
      msb := or(msb, f)
      r := shr(f, r)
    }
    assembly {
      let f := shl(3, gt(r, 0xFF))
      msb := or(msb, f)
      r := shr(f, r)
    }
    assembly {
      let f := shl(2, gt(r, 0xF))
      msb := or(msb, f)
      r := shr(f, r)
    }
    assembly {
      let f := shl(1, gt(r, 0x3))
      msb := or(msb, f)
      r := shr(f, r)
    }
    assembly {
      let f := gt(r, 0x1)
      msb := or(msb, f)
    }

    if (msb >= 128) r = ratio >> (msb - 127);
    else r = ratio << (127 - msb);

    int256 log_2 = (int256(msb) - 128) << 64;

    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(63, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(62, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(61, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(60, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(59, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(58, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(57, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(56, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(55, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(54, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(53, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(52, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(51, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(50, f))
    }

    int256 log_sqrt10001 = log_2 * 255738958999603826347141; // 128.128 number

    int24 tickLow = int24((log_sqrt10001 - 3402992956809132418596140100660247210) >> 128);
    int24 tickHi = int24((log_sqrt10001 + 291339464771989622907027621153398088495) >> 128);

    tick = tickLow == tickHi
      ? tickLow
      : getSqrtRatioAtTick(tickHi) <= sqrtPriceX96
        ? tickHi
        : tickLow;
  }
}

/// @title Oracle library
/// @notice Provides functions to integrate with V3 pool oracle
library OracleLibrary {
  /// @notice Calculates time-weighted means of tick and liquidity for a given Uniswap V3 pool
  /// @param pool Address of the pool that we want to observe
  /// @param secondsAgo Number of seconds in the past from which to calculate the time-weighted means
  /// @return arithmeticMeanTick The arithmetic mean tick from (block.timestamp - secondsAgo) to block.timestamp
  /// @return harmonicMeanLiquidity The harmonic mean liquidity from (block.timestamp - secondsAgo) to block.timestamp
  function consult(
    address pool,
    uint32 secondsAgo
  ) internal view returns (int24 arithmeticMeanTick, uint128 harmonicMeanLiquidity) {
    require(secondsAgo != 0, "BP");

    uint32[] memory secondsAgos = new uint32[](2);
    secondsAgos[0] = secondsAgo;
    secondsAgos[1] = 0;

    (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) = IUniswapV3Pool(pool)
      .observe(secondsAgos);

    int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
    uint160 secondsPerLiquidityCumulativesDelta = secondsPerLiquidityCumulativeX128s[1] -
      secondsPerLiquidityCumulativeX128s[0];

    arithmeticMeanTick = int24(int256(tickCumulativesDelta) /int256(uint256(secondsAgo)));
    // Always round to negative infinity
    if (tickCumulativesDelta < 0 && (int256(tickCumulativesDelta) % int256(uint256(secondsAgo)) != 0)) arithmeticMeanTick--;

    // We are multiplying here instead of shifting to ensure that harmonicMeanLiquidity doesn't overflow uint128
    uint192 secondsAgoX160 = uint192(secondsAgo) * type(uint160).max;
    harmonicMeanLiquidity = uint128(secondsAgoX160 / (uint192(secondsPerLiquidityCumulativesDelta) << 32));
  }

  /// @notice Given a tick and a token amount, calculates the amount of token received in exchange
  /// @param tick Tick value used to calculate the quote
  /// @param baseAmount Amount of token to be converted
  /// @param baseToken Address of an ERC20 token contract used as the baseAmount denomination
  /// @param quoteToken Address of an ERC20 token contract used as the quoteAmount denomination
  /// @return quoteAmount Amount of quoteToken received for baseAmount of baseToken
  function getQuoteAtTick(
    int24 tick,
    uint128 baseAmount,
    address baseToken,
    address quoteToken
  ) internal pure returns (uint256 quoteAmount) {
    uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);

    // Calculate quoteAmount with better precision if it doesn't overflow when multiplied by itself
    if (sqrtRatioX96 <= type(uint128).max) {
      uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
      quoteAmount = baseToken < quoteToken
        ? FullMath.mulDiv(ratioX192, baseAmount, 1 << 192)
        : FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
    } else {
      uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
      quoteAmount = baseToken < quoteToken
        ? FullMath.mulDiv(ratioX128, baseAmount, 1 << 128)
        : FullMath.mulDiv(1 << 128, baseAmount, ratioX128);
    }
  }

  /// @notice Given a pool, it returns the number of seconds ago of the oldest stored observation
  /// @param pool Address of Uniswap V3 pool that we want to observe
  /// @return secondsAgo The number of seconds ago of the oldest observation stored for the pool
  function getOldestObservationSecondsAgo(address pool) internal view returns (uint32 secondsAgo) {
    (, , uint16 observationIndex, uint16 observationCardinality, , , ) = IUniswapV3Pool(pool).slot0();
    require(observationCardinality > 0, "NI");

    (uint32 observationTimestamp, , , bool initialized) = IUniswapV3Pool(pool).observations(
      (observationIndex + 1) % observationCardinality
    );

    // The next index might not be initialized if the cardinality is in the process of increasing
    // In this case the oldest observation is always in index 0
    if (!initialized) {
      (observationTimestamp, , , ) = IUniswapV3Pool(pool).observations(0);
    }

    secondsAgo = uint32(block.timestamp) - observationTimestamp;
  }

  /// @notice Given a pool, it returns the tick value as of the start of the current block
  /// @param pool Address of Uniswap V3 pool
  /// @return The tick that the pool was in at the start of the current block
  function getBlockStartingTickAndLiquidity(address pool) internal view returns (int24, uint128) {
    (, int24 tick, uint16 observationIndex, uint16 observationCardinality, , , ) = IUniswapV3Pool(pool).slot0();

    // 2 observations are needed to reliably calculate the block starting tick
    require(observationCardinality > 1, "NEO");

    // If the latest observation occurred in the past, then no tick-changing trades have happened in this block
    // therefore the tick in `slot0` is the same as at the beginning of the current block.
    // We don't need to check if this observation is initialized - it is guaranteed to be.
    (uint32 observationTimestamp, int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128, ) = IUniswapV3Pool(
      pool
    ).observations(observationIndex);
    if (observationTimestamp != uint32(block.timestamp)) {
      return (tick, IUniswapV3Pool(pool).liquidity());
    }

    uint256 prevIndex = (uint256(observationIndex) + observationCardinality - 1) % observationCardinality;
    (
      uint32 prevObservationTimestamp,
      int56 prevTickCumulative,
      uint160 prevSecondsPerLiquidityCumulativeX128,
      bool prevInitialized
    ) = IUniswapV3Pool(pool).observations(prevIndex);

    require(prevInitialized, "ONI");

    uint32 delta = observationTimestamp - prevObservationTimestamp;
    tick = int24(int256(tickCumulative - prevTickCumulative) / int256(uint256(delta)));
    uint128 liquidity = uint128(
      (uint192(delta) * type(uint160).max) /
        (uint192(secondsPerLiquidityCumulativeX128 - prevSecondsPerLiquidityCumulativeX128) << 32)
    );
    return (tick, liquidity);
  }

  /// @notice Information for calculating a weighted arithmetic mean tick
  struct WeightedTickData {
    int24 tick;
    uint128 weight;
  }

  /// @notice Given an array of ticks and weights, calculates the weighted arithmetic mean tick
  /// @param weightedTickData An array of ticks and weights
  /// @return weightedArithmeticMeanTick The weighted arithmetic mean tick
  /// @dev Each entry of `weightedTickData` should represents ticks from pools with the same underlying pool tokens. If they do not,
  /// extreme care must be taken to ensure that ticks are comparable (including decimal differences).
  /// @dev Note that the weighted arithmetic mean tick corresponds to the weighted geometric mean price.
  function getWeightedArithmeticMeanTick(
    WeightedTickData[] memory weightedTickData
  ) internal pure returns (int24 weightedArithmeticMeanTick) {
    // Accumulates the sum of products between each tick and its weight
    int256 numerator;

    // Accumulates the sum of the weights
    uint256 denominator;

    // Products fit in 152 bits, so it would take an array of length ~2**104 to overflow this logic
    for (uint256 i; i < weightedTickData.length; i++) {
      numerator += weightedTickData[i].tick * int256(uint256(weightedTickData[i].weight));
      denominator += weightedTickData[i].weight;
    }

    weightedArithmeticMeanTick = int24(numerator / int256(denominator));
    // Always round to negative infinity
    if (numerator < 0 && (numerator % int256(denominator) != 0)) weightedArithmeticMeanTick--;
  }

  /// @notice Returns the "synthetic" tick which represents the price of the first entry in `tokens` in terms of the last
  /// @dev Useful for calculating relative prices along routes.
  /// @dev There must be one tick for each pairwise set of tokens.
  /// @param tokens The token contract addresses
  /// @param ticks The ticks, representing the price of each token pair in `tokens`
  /// @return syntheticTick The synthetic tick, representing the relative price of the outermost tokens in `tokens`
  function getChainedPrice(address[] memory tokens, int24[] memory ticks) internal pure returns (int256 syntheticTick) {
    require(tokens.length - 1 == ticks.length, "DL");
    for (uint256 i = 1; i <= ticks.length; i++) {
      // check the tokens for address sort order, then accumulate the
      // ticks into the running synthetic tick, ensuring that intermediate tokens "cancel out"
      tokens[i - 1] < tokens[i] ? syntheticTick += ticks[i - 1] : syntheticTick -= ticks[i - 1];
    }
  }
}
