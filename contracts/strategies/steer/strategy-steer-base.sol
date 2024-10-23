// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./strategy-steer.sol";
import "../../interfaces/ISteerPeriphery.sol";
import "../../interfaces/vault.sol"; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 

abstract contract StrategySteerBase is StrategySteer {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  using SafeERC20 for IVault;

  address public V3FACTORY;
  address STEER_PERIPHERY;

  uint256 public constant minimumAmount = 1000;

  constructor(
    address _want,
    address _governance,
    address _strategist,
    address _controller,
    address _timelock,
    address _weth,
    address _V3Factory,
    address _steerPeriphery,
    address _weth_usdc_pool,
    address[] memory _stableTokens
  ) StrategySteer(_want, _governance, _strategist, _controller, _timelock, _weth, _weth_usdc_pool,_stableTokens) {
    require(_V3Factory != address(0));
    V3FACTORY = _V3Factory;
    STEER_PERIPHERY = _steerPeriphery;
  }

  // Declare a Harvest Event
  event Harvest(uint _timestamp, uint _value);

  function _swap(address, address, uint256) internal virtual;

  function harvest() public override onlyBenevolent sphereXGuardPublic(0xc0d2c698, 0x4641257d) {
    require(rewardToken != address(0), "!rewardToken");
    uint256 _reward = IERC20(rewardToken).balanceOf(address(this));
    require(_reward > 0, "!reward");
    uint256 _keepReward = _reward.mul(keepReward).div(keepMax);
    IERC20(rewardToken).safeTransfer(IController(controller).treasury(), _keepReward);

    _reward = IERC20(rewardToken).balanceOf(address(this));

    //get strategy steer vault tokens before balances
    uint256 beforeBal = IERC20(want).balanceOf(address(this));

    (address token0, address token1) = steerVaultTokens();

    (uint256 tokenInAmount0, uint256 tokenInAmount1) = calculateSteerVaultTokensRatio(_reward);

    uint256 tokenInAmount = tokenInAmount0 + tokenInAmount1;
    require(_reward >= minimumAmount, "Insignificant input amount");
    require(_reward >= tokenInAmount, "Insignificant token in amounts");

    if (rewardToken != token0 && rewardToken != token1) {
      _swap(rewardToken, token0, tokenInAmount0);
      _swap(rewardToken, token1, tokenInAmount1);
    } else {
      address tokenOut = token0;
      uint256 amountToSwap = tokenInAmount0;
      if (rewardToken == token0) {
        tokenOut = token1;
        amountToSwap = tokenInAmount1;
      }
      _swap(rewardToken, tokenOut, amountToSwap);
    }

    depositToSteerVault(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));

    //get strategy steer vault tokens after balances
    uint256 afterBal = IERC20(want).balanceOf(address(this));

    emit Harvest(block.timestamp, afterBal.sub(beforeBal));
  }

  function depositToSteerVault(uint256 _amount0, uint256 _amount1) internal override sphereXGuardInternal(0xf2f01eff) {
    (address token0, address token1) = steerVaultTokens();

    //approve both tokens to Steer Periphery contract
    _approveTokenIfNeeded(token0, STEER_PERIPHERY);
    _approveTokenIfNeeded(token1, STEER_PERIPHERY);

    //deposit to Steer Periphery contract
    ISteerPeriphery(STEER_PERIPHERY).deposit(want, _amount0, _amount1, 0, 0, address(this));

    address[] memory tokens = new address[](3);
    tokens[0] = token0;
    tokens[1] = token1;
    tokens[2] = rewardToken;

    _returnAssets(tokens);
  }

  function calculateSteerVaultTokensPrices() internal sphereXGuardInternal(0x78dd547f) returns (uint256 token0Price, uint256 token1Price) {
    (address token0, address token1) = steerVaultTokens();

    bool isToken0Stable = isStableToken(token0);
    bool isToken1Stable = isStableToken(token1);

    if (isToken0Stable) token0Price = 1 * PRECISION;
    if (isToken1Stable) token1Price = 1 * PRECISION;

    if (isToken0Stable && isToken1Stable) {
      // For stable pairs, set the pool fee to 500 which is 0.05% pool fee
      poolFees[token0][token1] = 500;
      // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
      poolFees[token1][token0] = 500;
    }
    if (!isToken0Stable) {
      token0Price = getPrice(token0);
    }

    if (!isToken1Stable) {
      token1Price = getPrice(token1);
    }

    return (token0Price, token1Price);
  }

  function isStableToken(address token) internal view returns (bool) {
    for (uint256 i = 0; i < stableTokens.length; i++) {
      if (stableTokens[i] == token) return true;
    }
    return false;
  }

  function getPrice(address token) internal sphereXGuardInternal(0xf32b18f4) returns (uint256) {
    if (token == weth) {
      return calculateEthPriceInUsdc();
    } else {
      (address token0, address token1) = steerVaultTokens();
      // get pair address from factory contract for weth and desired token
      address pair;
      if (token == token0) {
        pair = fetchPool(token0, weth, V3FACTORY);

        return calculateTokenPriceInUsd(token0, pair);
      }

      pair = fetchPool(token1, weth, V3FACTORY);

      return calculateTokenPriceInUsd(token1, pair);
    }
  }

  function fetchPool(address token0, address token1, address _uniV3Factory) internal sphereXGuardInternal(0xdbb0f839) returns (address) {
    address pairWithMaxLiquidity = address(0);
    uint256 maxLiquidity = 0;

    for (uint256 i = 0; i < poolsFee.length; i++) {
      address currentPair = IUniswapV3Factory(_uniV3Factory).getPool(token0, token1, poolsFee[i]);
      if (currentPair != address(0)) {
        uint256 currentLiquidity = IUniswapV3Pool(currentPair).liquidity();
        if (currentLiquidity > maxLiquidity) {
          maxLiquidity = currentLiquidity;
          pairWithMaxLiquidity = currentPair;
          poolFees[token0][token1] = poolsFee[i];
          // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
          poolFees[token1][token0] = poolsFee[i];
        }
      }
    }
    require(pairWithMaxLiquidity != address(0), "No pool found with sufficient liquidity");

    return pairWithMaxLiquidity;
  }

function calculateSteerVaultTokensRatio(uint256 _amountIn) internal sphereXGuardInternal(0xbc836423) returns (uint256, uint256) {
    uint256 token0Value;
    uint256 token1Value;
    {
    (address token0, address token1) = steerVaultTokens();
    (uint256 amount0, uint256 amount1) = getTotalAmounts();
    (uint256 token0Price, uint256 token1Price) = calculateSteerVaultTokensPrices();
    token0Value = ((token0Price * amount0) / (10 ** uint256(IERC20(token0).decimals())));
    token1Value = ((token1Price * amount1) / (10 ** uint256(IERC20(token1).decimals())));
    }
    uint256 totalValue = token0Value + token1Value;
    uint256 token0Amount = (_amountIn * token0Value) / totalValue;
    uint256 token1Amount = _amountIn - token0Amount;
    return (token0Amount, token1Amount);
  }
}
