// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ZapperBase} from "./zapperBase.sol";
import {IUniProxy, IHypervisor} from "../../../interfaces/gamma/IGamma.sol";
import {IERC20, SafeERC20} from "../../../lib/erc20.sol";
import {OracleLibrary} from "../../../lib/OracleLibrary.sol";
import {IVault} from "../../../interfaces/vault.sol";
import {ISwapRouter, IUniswapV3Pool} from "../../../interfaces/uniswapv3.sol";

import "hardhat/console.sol";

contract GammaZapper is ZapperBase {
  using SafeERC20 for IERC20;
  IUniProxy public gammaUniProxy;

  constructor(
    address _wrappedNative,
    address _usdcToken,
    address _swapRouter,
    address _V3Factory,
    address[] memory _vaultsToWhitelist,
    address _gammaUniProxy
  ) ZapperBase(_wrappedNative, _usdcToken, _V3Factory, _swapRouter, _vaultsToWhitelist) {
    gammaUniProxy = IUniProxy(_gammaUniProxy);
  }

  // function _setWhitelistVault(address _vault, bool _whitelisted) internal override {
  //   // make sure token0 and token1 have swapping pools available with the swapRouter
  //   address gammaVault = address(IVault(_vault).token());
  //   (address token0, address token1) = (IHypervisor(gammaVault).token0(), IHypervisor(gammaVault).token1());
  //   _getDepositAmounts(gammaVault, address(wrappedNative), token0, token1, 1e18);
  //   _getDepositAmounts(gammaVault, address(usdcToken), token0, token1, 100e6);
  //   super._setWhitelistVault(_vault, _whitelisted);
  // }

  function _beforeDeposit(
    IVault vault,
    IERC20 tokenIn
  ) public virtual override returns (uint256 tokenOutAmount, ReturnedAsset[] memory returnedAssets) {
    address gammaVault = address(IVault(vault).token());
    (address token0, address token1) = (IHypervisor(gammaVault).token0(), IHypervisor(gammaVault).token1());

    uint256 tokenInAmount = tokenIn.balanceOf(address(this));
    (uint256 amount0, uint256 amount1) = _getDepositAmounts(
      gammaVault,
      address(tokenIn),
      token0,
      token1,
      tokenInAmount
    );

    console.log("amount0: ", amount0);
    console.log("amount1: ", amount1);

    if (token0 != address(tokenIn) && token1 != address(tokenIn)) {
      _swap(address(tokenIn), address(token0), amount0);
      _swap(address(tokenIn), address(token1), amount1);
    } else {
      address tokenOut = address(token0);
      uint256 amountToSwap = amount0;
      if (address(tokenIn) == address(token0)) {
        tokenOut = address(token1);
        amountToSwap = amount1;
      }

      _swap(address(tokenIn), tokenOut, amountToSwap);
    }

    uint256[4] memory minInAmounts = [uint256(0), uint256(0), uint256(0), uint256(0)];

    tokenOutAmount = IUniProxy(gammaUniProxy).deposit(
      amount0,
      amount1,
      address(this),
      address(vault.token()), // gamma vault
      minInAmounts
    );

    address[] memory tokens = new address[](3);
    tokens[0] = address(token0);
    tokens[1] = address(token1);
    tokens[2] = address(tokenIn);
    returnedAssets = _returnAssets(tokens);
  }

  function _afterWithdraw(
    IVault vault,
    IERC20 desiredToken
  ) public virtual override returns (uint256 tokenOutAmount, ReturnedAsset[] memory returnedAssets) {
    IHypervisor gammaVault = IHypervisor(address(IVault(vault).token()));
    (address token0, address token1) = (gammaVault.token0(), gammaVault.token1());

    uint256[4] memory minInAmounts = [uint256(0), uint256(0), uint256(0), uint256(0)];
    uint256 gammaVaultBalance = IERC20(gammaVault).balanceOf(address(this));
    (uint256 amount0, uint256 amount1) = gammaVault.withdraw(
      gammaVaultBalance,
      address(this),
      address(this),
      minInAmounts
    );

    if (token0 != address(desiredToken)) {
      tokenOutAmount = _swap(address(token0), address(desiredToken), amount0);
    }
    if (token1 != address(desiredToken)) {
      tokenOutAmount += _swap(address(token1), address(desiredToken), amount1);
    }
    address[] memory tokens = new address[](3);
    tokens[0] = address(token0);
    tokens[1] = address(token1);
    tokens[2] = address(desiredToken);
    returnedAssets = _returnAssets(tokens);
  }

  /**
   * @notice Calculates the optimal token0/token1 ratio for depositing into a Gamma vault.
   * The Uniproxy getDepositAmount function is used to find the amount of one token by providing the amount of the other token. We can use this to find the
   * ratio of the two tokens in the hypervisor, As a starting point we use half of the zapped amount as the amount of token0, then we use the getDepositAmount
   * function to find the amount of token1. With these two values we can find the ratio, first we need to convert both the amounts in base token (wrappedNative)
   * then we can find the ratio of token0 to token1. With this ratio we can convert the zapped amount to the correct amount of token0 and token1
   * @param gammaVault The address of the gamma vault
   * @param tokenIn The address of the token being zapped
   * @param token0 The address of the first token in the hypervisor
   * @param token1 The address of the second token in the hypervisor
   * @param tokenInAmount The amount of the token being zapped
   * @return amount0 The amount of the first token
   * @return amount1 The amount of the second token
   */

  // function _getDepositAmounts(
  //   address gammaVault,
  //   address tokenIn,
  //   address token0,
  //   address token1,
  //   uint256 tokenInAmount
  // ) public returns (uint256 amount0, uint256 amount1) {
  //   uint256 predictedAmount0 = tokenInAmount / 2;
  //   if (token0 != address(tokenIn)) {
  //     // get qoute for tokenIn -> token0
  //     predictedAmount0 = _getQuoteV3(address(tokenIn), address(token0), predictedAmount0, V3Factory);
  //   }

  //   (, uint256 predictedAmount1) = IUniProxy(gammaUniProxy).getDepositAmount(gammaVault, token0, predictedAmount0);

  //   uint256 predictedAmount0InEth =  _getQuoteV3(address(token0), address(wrappedNative), predictedAmount0, V3Factory);

  //   uint256 predictedAmount1InEth = _getQuoteV3(address(token1), address(wrappedNative), predictedAmount1, V3Factory);

  //   // calculate amount0 and amount1 in the same ratio as the predictedAmount0InEth and predictedAmount1InEth ratios
  //   amount0 = (tokenInAmount * predictedAmount0InEth) / (predictedAmount0InEth + predictedAmount1InEth);
  //   amount1 = tokenInAmount - amount0;
  // }

  function _getDepositAmounts(
    address gammaVault,
    address tokenIn,
    address token0,
    address token1,
    uint256 tokenInAmount
  ) public returns (uint256 amount0, uint256 amount1) {
    uint256 predictedAmount0 = tokenInAmount / 2;

    // If tokenIn is not equal to token0, get the quote, otherwise use the predictedAmount0 directly
    if (token0 != tokenIn) {
      // Get quote for tokenIn -> token0
      predictedAmount0 = _getQuoteV3(tokenIn, token0, predictedAmount0, V3Factory);
    }

    (, uint256 predictedAmount1) = IUniProxy(gammaUniProxy).getDepositAmount(gammaVault, token0, predictedAmount0);

    // If tokenIn matches token0 or token1, use predicted amounts directly without converting to wrappedNative
    uint256 predictedAmount0InEth = (token0 == address(wrappedNative))
      ? predictedAmount0
      : _getQuoteV3(token0, address(wrappedNative), predictedAmount0, V3Factory);
    uint256 predictedAmount1InEth = (token1 == address(wrappedNative))
      ? predictedAmount0
      : _getQuoteV3(token1, address(wrappedNative), predictedAmount1, V3Factory);

    // Calculate amount0 and amount1 in the same ratio as the predictedAmount0InEth and predictedAmount1InEth ratios
    amount0 = (tokenInAmount * predictedAmount0InEth) / (predictedAmount0InEth + predictedAmount1InEth);
    amount1 = tokenInAmount - amount0;
  }

  function _getQuoteV3(
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    address factory
  ) internal returns (uint256 amountOut) {
    address poolAddress = fetchPool(tokenIn, tokenOut, factory);

    if (poolAddress == address(0)) {
      // if no direct pool is found, try to find a pool between tokenIn and WETH and then between WETH and tokenOut
      address[] memory path = new address[](3);
      path[0] = tokenIn;
      path[1] = address(wrappedNative);
      path[2] = tokenOut;
      return _getQuoteV3WithPath(path, amountIn, factory);
    }

    IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
    (, int24 tick, , , , , ) = pool.slot0();

    // Call Oracle to get the price at the given tick
    amountOut = OracleLibrary.getQuoteAtTick(
      tick,
      uint128(amountIn), // Casting to uint128 since the library expects this type
      tokenIn,
      tokenOut
    );
  }

  function _getQuoteV3WithPath(
    address[] memory path,
    uint256 amountIn,
    address factory
  ) internal returns (uint256 amountOut) {
    for (uint256 i = 0; i < path.length - 2; i++) {
      address poolAddress = fetchPool(address(path[i]), path[i + 1], factory);

      require(poolAddress != address(0), "No pool found for multihop qoute");

      IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
      (, int24 tick, , , , , ) = pool.slot0();

      // Call Oracle to get the price at the given tick
      amountOut = OracleLibrary.getQuoteAtTick(
        tick,
        uint128(amountIn), // Casting to uint128 since the library expects this type
        path[i],
        path[i + 1]
      );
      // amount in is now the amount out of the last pool
      amountIn = amountOut;
    }
  }
}
