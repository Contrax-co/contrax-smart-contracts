// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./strategy-steer.sol";
import "../../interfaces/ISteerPeriphery.sol";
import "../../interfaces/vault.sol";
// Vault address for steer sushi USDC-USDC.e pool
//0x3eE813a6fCa2AaCAF0b7C72428fC5BC031B9BD65

abstract contract StrategySteerBase is StrategySteer {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  using SafeERC20 for IVault;

  address public sushiFactory = 0xc35DADB65012eC5796536bD9864eD8773aBc74C4;
  uint256 public constant minimumAmount = 1000;

  constructor(
    address _want,
    address _governance,
    address _strategist,
    address _controller,
    address _timelock
  ) StrategySteer(_want, _governance, _strategist, _controller, _timelock) {}

  // Declare a Harvest Event
  event Harvest(uint _timestamp, uint _value);

  function _swap(address, address, uint256) internal virtual;

  function harvest() public override onlyBenevolent {
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

  function depositToSteerVault(uint256 _amount0, uint256 _amount1) public override {
    (address token0, address token1) = steerVaultTokens();

    //approve both tokens to Steer Periphery contract
    _approveTokenIfNeeded(token0, steerPeriphery);
    _approveTokenIfNeeded(token1, steerPeriphery);

    //deposit to Steer Periphery contract
    ISteerPeriphery(steerPeriphery).deposit(want, _amount0, _amount1, 0, 0, address(this));

    address[] memory tokens = new address[](2);
    tokens[0] = token0;
    tokens[1] = token1;

    _returnAssets(tokens);
  }

  function calculateSteerVaultTokensPrices() internal view returns (uint256 token0Price, uint256 token1Price) {
    (address token0, address token1) = steerVaultTokens();

    bool isToken0Stable = isStableToken(token0);
    bool isToken1Stable = isStableToken(token1);

    if (isToken0Stable) token0Price = 1 * PRECISION;
    if (isToken1Stable) token1Price = 1 * PRECISION;

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

  function getPrice(address token) internal view returns (uint256) {
    if (token == weth) {
      return calculateTokenPriceInUsdc(weth, weth_Usdc_Pair);
    } else {
      (address token0, address token1) = steerVaultTokens();
      // get pair address from factory contract
      address pair = IUniswapV2Factory(sushiFactory).getPair(token0, token1);

      if (token == token0) return calculateLpPriceInUsdc(token0, pair);

      return calculateLpPriceInUsdc(token1, pair);
    }
  }

  function calculateSteerVaultTokensRatio(uint256 _amountIn) internal view returns (uint256, uint256) {
    (address token0, address token1) = steerVaultTokens();
    (uint256 amount0, uint256 amount1) = getTotalAmounts();
    (uint256 token0Price, uint256 token1Price) = calculateSteerVaultTokensPrices();

    uint256 token0Value = ((token0Price * amount0) / (10 ** uint256(IERC20(token0).decimals()))) / PRECISION;
    uint256 token1Value = ((token1Price * amount1) / (10 ** uint256(IERC20(token1).decimals()))) / PRECISION;

    uint256 totalValue = token0Value + token1Value;
    uint256 token0Amount = (_amountIn * token0Value) / totalValue;
    uint256 token1Amount = _amountIn - token0Amount;

    return (token0Amount, token1Amount);
  }
}
