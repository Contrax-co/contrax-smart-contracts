// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./strategy-steer-base.sol";
import "../../interfaces/ISteerPeriphery.sol";


contract StrategySteerUsdcUsdce is StrategySteerBase {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  constructor(
    address _want,
    address _governance,
    address _strategist,
    address _controller,
    address _timelock
  ) StrategySteerBase(_want, _governance, _strategist, _controller, _timelock) {}

  event Harvested(address indexed user, uint256 amount);

  function harvest() public override onlyBenevolent {
    require(rewardToken != address(0), "!rewardToken");
    uint256 _reward = IERC20(rewardToken).balanceOf(address(this));
    require(_reward > 0, "!reward");
    uint256 _keepReward = _reward.mul(keepReward).div(keepMax);
    IERC20(rewardToken).safeTransfer(IController(controller).treasury(), _keepReward);

    _reward = IERC20(rewardToken).balanceOf(address(this));

    //get strategy steer vault tokens before balances
    uint256 beforeBal = IERC20(steerVaultAddress).balanceOf(address(this));

    (address Usdc, address Usdce) = steerVaultTokens();

    (uint256 UsdcAmount, uint256 UsdceAmount) = getTotalAmounts();

    // Get token decimals
    uint8 usdcDecimals = IERC20(Usdc).decimals();
    uint8 usdceDecimals = IERC20(Usdce).decimals();

    //For Usdc and Usdce price will be 1$ so we don't consider the price
    uint256 totalUsdcStaked = UsdcAmount.div(10 ** usdcDecimals);
    uint256 totalUsdceStaked = UsdceAmount.div(10 ** usdceDecimals);

    uint256 usdcAmounttoDeposit = ((_reward *
      ((((totalUsdcStaked * PRECISION) / (totalUsdcStaked + totalUsdceStaked)) * 10 ** 12))) / 10 ** 12) / PRECISION;

    uint256 usdceAmounttoDeposit = _reward.sub(usdcAmounttoDeposit);


    if (rewardToken != Usdc && rewardToken != Usdce) {
      _swap(rewardToken, Usdc, usdcAmounttoDeposit);
      _swap(rewardToken, Usdce, usdceAmounttoDeposit);
    } else {
      address tokenOut = Usdc;
      uint256 amountToSwap = usdcAmounttoDeposit;
      if (rewardToken == Usdc) {
        tokenOut = Usdce;
        amountToSwap = usdceAmounttoDeposit;
      }
      _swap(rewardToken, tokenOut, amountToSwap);
    }

    depositToSteerVault(IERC20(Usdc).balanceOf(address(this)), IERC20(Usdce).balanceOf(address(this)));

    address[] memory tokens = new address[](2);
    tokens[0] = Usdc;
    tokens[1] = Usdce;

    _returnAssets(tokens);

    //get strategy steer vault tokens after balances
    uint256 afterBal = IERC20(steerVaultAddress).balanceOf(address(this));

    emit Harvested(msg.sender, afterBal.sub(beforeBal));
  }

  function depositToSteerVault(uint256 _amount0, uint256 _amount1) public override {
    (address usdc, address usdce) = steerVaultTokens();

    //approve both tokens to Steer Periphery contract
    _approveTokenIfNeeded(usdc, steerPeriphery);
    _approveTokenIfNeeded(usdce, steerPeriphery);

    //deposit to Steer Periphery contract
    ISteerPeriphery(steerPeriphery).deposit(steerVaultAddress, _amount0, _amount1, 0, 0, address(this));
  }
}
