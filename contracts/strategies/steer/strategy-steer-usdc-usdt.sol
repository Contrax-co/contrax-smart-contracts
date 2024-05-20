// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./strategy-steer-base.sol";
import "../../interfaces/ISteerPeriphery.sol";

import "hardhat/console.sol";

// Vault address for steer sushi USDT-USDC pool
//0x5DbAD371890C3A89f634e377c1e8Df987F61fB64

contract StrategySteerUsdcUsdt is StrategySteerBase {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  constructor(
    address _governance,
    address _strategist,
    address _controller,
    address _timelock
  ) StrategySteerBase(0x5DbAD371890C3A89f634e377c1e8Df987F61fB64, _governance, _strategist, _controller, _timelock) {}

  // Declare a Harvest Event
  event Harvest(uint _timestamp, uint _value);

  function harvest() public override onlyBenevolent {
    require(rewardToken != address(0), "!rewardToken");
    uint256 _reward = IERC20(rewardToken).balanceOf(address(this));
    require(_reward > 0, "!reward");
    uint256 _keepReward = _reward.mul(keepReward).div(keepMax);
    IERC20(rewardToken).safeTransfer(IController(controller).treasury(), _keepReward);

    _reward = IERC20(rewardToken).balanceOf(address(this));

    //get strategy steer vault tokens before balances
    uint256 beforeBal = IERC20(want).balanceOf(address(this));

    (address Usdt, address Usdce) = steerVaultTokens();

    console.log("Usdt: ", Usdt, " Usdce: ", Usdce);

    (uint256 UsdtAmount, uint256 UsdceAmount) = getTotalAmounts();

    // Get token decimals
    uint8 usdtDecimals = IERC20(Usdt).decimals();
    uint8 usdceDecimals = IERC20(Usdce).decimals();

    //For Usdt and Usdce price will be 1$ so we don't consider the price
    uint256 totalUsdtStaked = UsdtAmount.div(10 ** usdtDecimals);
    uint256 totalUsdcStaked = UsdceAmount.div(10 ** usdceDecimals);

    uint256 usdtAmounttoDeposit = ((_reward *
      ((((totalUsdtStaked * PRECISION) / (totalUsdtStaked + totalUsdcStaked)) * 10 ** 12))) / 10 ** 12) / PRECISION;

    uint256 usdcAmounttoDeposit = _reward.sub(usdtAmounttoDeposit);

    if (rewardToken != Usdt && rewardToken != Usdce) {
      _swap(rewardToken, Usdt, usdtAmounttoDeposit);
      _swap(rewardToken, Usdce, usdcAmounttoDeposit);
    } else {
      address tokenOut = Usdt;
      uint256 amountToSwap = usdtAmounttoDeposit;
      if (rewardToken == Usdt) {
        tokenOut = Usdce;
        amountToSwap = usdcAmounttoDeposit;
      }
      _swap(rewardToken, tokenOut, amountToSwap);
    }

    depositToSteerVault(IERC20(Usdt).balanceOf(address(this)), IERC20(Usdce).balanceOf(address(this)));

    address[] memory tokens = new address[](2);
    tokens[0] = Usdt;
    tokens[1] = Usdce;

    _returnAssets(tokens);

    //get strategy steer vault tokens after balances
    uint256 afterBal = IERC20(want).balanceOf(address(this));

    emit Harvest(block.timestamp, afterBal.sub(beforeBal));
  }

  function depositToSteerVault(uint256 _amount0, uint256 _amount1) public override {
    (address usdt, address usdc) = steerVaultTokens();

    //approve both tokens to Steer Periphery contract
    _approveTokenIfNeeded(usdt, steerPeriphery);
    _approveTokenIfNeeded(usdc, steerPeriphery);

    //deposit to Steer Periphery contract
    ISteerPeriphery(steerPeriphery).deposit(want, _amount0, _amount1, 0, 0, address(this));
  }
}
