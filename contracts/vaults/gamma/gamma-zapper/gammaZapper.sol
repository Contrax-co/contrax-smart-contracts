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
    address _governance,
    address _weth_usdc_pool,
    address _weth,
    address[] memory _vaultsToWhitelist,
    address[] memory _stableTokens,
    address _gammaUniProxy
  )
    ZapperBase(
      _wrappedNative,
      _usdcToken,
      _swapRouter,
      _V3Factory,
      _governance,
      _weth_usdc_pool,
      _weth,
      _stableTokens,
      _vaultsToWhitelist
    )
  {
    gammaUniProxy = IUniProxy(_gammaUniProxy);
  }

  function _setWhitelistVault(address _vault, bool _whitelisted) internal override {
    // make sure token0 and token1 have swapping pools available with the swapRouter

    _getDepositAmounts(IVault(_vault), 1e18);
    _getDepositAmounts(IVault(_vault), 100e6);
    super._setWhitelistVault(_vault, _whitelisted);
  }

  function _beforeDeposit(
    IVault vault,
    IERC20 tokenIn
  ) public virtual override returns (uint256 tokenOutAmount, ReturnedAsset[] memory returnedAssets) {
    address gammaVault = address(IVault(vault).token());
    (address token0, address token1) = (IHypervisor(gammaVault).token0(), IHypervisor(gammaVault).token1());

    uint256 tokenInAmount = tokenIn.balanceOf(address(this));

    (uint256 amount0, uint256 amount1) = _getDepositAmounts(vault, tokenInAmount);

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

    
    _approveTokenIfNeeded(token0, gammaVault);
    _approveTokenIfNeeded(token1, gammaVault);

    tokenOutAmount = IUniProxy(gammaUniProxy).deposit(
      IERC20(token0).balanceOf(address(this)),
      IERC20(token1).balanceOf(address(this)),
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
    (address token0, address token1) = gammaVaultTokens(vault);

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

  // /**
  //  * @notice Calculates the optimal token0/token1 ratio for depositing into a Gamma vault.
  //  * The Uniproxy getDepositAmount function is used to find the amount of one token by providing the amount of the other token. We can use this to find the
  //  * ratio of the two tokens in the hypervisor, As a starting point we use half of the zapped amount as the amount of token0, then we use the getDepositAmount
  //  * function to find the amount of token1. With these two values we can find the ratio, first we need to convert both the amounts in base token (wrappedNative)
  //  * then we can find the ratio of token0 to token1. With this ratio we can convert the zapped amount to the correct amount of token0 and token1
  //  * @param gammaVault The address of the gamma vault
  //  * @param tokenIn The address of the token being zapped
  //  * @param token0 The address of the first token in the hypervisor
  //  * @param token1 The address of the second token in the hypervisor
  //  * @param tokenInAmount The amount of the token being zapped
  //  * @return amount0 The amount of the first token
  //  * @return amount1 The amount of the second token
  //  */

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

  function _getDepositAmounts(IVault vault, uint256 _amountIn) public returns (uint256, uint256) {
    (address token0, address token1) = gammaVaultTokens(vault);
    (uint256 amount0, uint256 amount1) = getTotalAmounts(vault);
    (uint256 token0Price, uint256 token1Price) = calculateGammaVaultTokensPrices(vault);

    uint256 token0Value = ((token0Price * amount0) / (10 ** uint256(IERC20(token0).decimals())));
    uint256 token1Value = ((token1Price * amount1) / (10 ** uint256(IERC20(token1).decimals())));

    uint256 totalValue = token0Value + token1Value;
    uint256 token0Amount = (_amountIn * token0Value) / totalValue;
    uint256 token1Amount = _amountIn - token0Amount;

    return (token0Amount, token1Amount);
  }

  function calculateGammaVaultTokensPrices(IVault vault) internal returns (uint256 token0Price, uint256 token1Price) {
    (address token0, address token1) = gammaVaultTokens(vault);

    bool isToken0Stable = isStableToken(token0);
    bool isToken1Stable = isStableToken(token1);

    if (isToken0Stable) token0Price = 1 * PRECISION;
    if (isToken1Stable) token1Price = 1 * PRECISION;

    if (!isToken0Stable) {
      token0Price = getPrice(token0, vault);
    }

    if (!isToken1Stable) {
      token1Price = getPrice(token1, vault);
    }

    return (token0Price, token1Price);
  }

  function isStableToken(address token) internal view returns (bool) {
    for (uint256 i = 0; i < stableTokens.length; i++) {
      if (stableTokens[i] == token) return true;
    }
    return false;
  }

  function getPrice(address token, IVault vault) internal returns (uint256) {
    if (token == weth) {
      return calculateEthPriceInUsdc();
    } else {
      (address token0, address token1) = gammaVaultTokens(vault);
      // get pair address from factory contract for weth and desired token
      address pair;
      if (token == token0) {
        pair = fetchPool(token0, weth, V3Factory);

        return calculateTokenPriceInUsd(token0, pair);
      }

      pair = fetchPool(token1, weth, V3Factory);

      return calculateTokenPriceInUsd(token1, pair);
    }
  }

  function gammaVaultTokens(IVault vault) internal view returns (address token0, address token1) {
    IHypervisor gammaVault = IHypervisor(address(IVault(vault).token()));
    (token0, token1) = (gammaVault.token0(), gammaVault.token1());
  }

  function getTotalAmounts(IVault _localVault) public view returns (uint256 amount0, uint256 amount1) {
    (amount0, amount1) = IHypervisor(address(IVault(_localVault).token())).getTotalAmounts();
  }
}
