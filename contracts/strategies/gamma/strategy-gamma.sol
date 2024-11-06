// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./strategy-gamma-base.sol";
import "../../interfaces/minichefv2.sol";
import "../../interfaces/IRewarder.sol";

contract StrategyGamma is StrategyGammaBase {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  // Token addresses
  address public constant ACCT = 0x012c399Cf299ba26C9c379e17e90e3535b4318D6;
  address public MASTER_CHEF;

  // WETH/<token1> pair
  address public token0;
  address public token1;
  address rewardToken;

  // How much tokens to keep?
  uint256 public keep = 1000;
  uint256 public keepReward = 1000;
  uint256 public constant keepMax = 10000;

  uint256 public poolId;

  constructor(
    uint256 _poolId,
    address _lp,
    address _governance,
    address _strategist,
    address _controller,
    address _timelock,
    address _masterChef
  ) StrategyGammaBase(_lp, _governance, _strategist, _controller, _timelock) {
    poolId = _poolId;
    MASTER_CHEF = _masterChef;
  }

  function balanceOfPool() public view override returns (uint256) {
    (uint256 amount, ) = IMiniChefV2(MASTER_CHEF).userInfo(poolId, address(this));
    return amount;
  }

  function getHarvestable() external view returns (uint256) {
    uint256 _pendingSushi = IMiniChefV2(MASTER_CHEF).pendingSushi(poolId, address(this));
    return (_pendingSushi);
  }

  // **** Setters ****
  function deposit() public override {
    uint256 _want = IERC20(want).balanceOf(address(this));
    if (_want > 0) {
      IERC20(want).safeApprove(MASTER_CHEF, 0);
      IERC20(want).safeApprove(MASTER_CHEF, _want);
      IMiniChefV2(MASTER_CHEF).deposit(poolId, _want, address(this));
    }
  }

  function _withdrawSome(uint256 _amount) internal override returns (uint256) {
    IMiniChefV2(MASTER_CHEF).withdraw(poolId, _amount, address(this));
    return _amount;
  }

  // **** Setters ****

  function setKeep(uint256 _keep) external {
    require(msg.sender == timelock, "!timelock");
    keep = _keep;
  }

  function setKeepReward(uint256 _keepReward) external {
    require(msg.sender == timelock, "!timelock");
    keepReward = _keepReward;
  }

  function setRewardToken(address _rewardToken) external {
    require(msg.sender == timelock || msg.sender == strategist, "!timelock");
    rewardToken = _rewardToken;
  }

  // **** State Mutations ****

  // Declare a Harvest Event
  event Harvest(uint _timestamp, uint _value);

  function harvest() public override onlyBenevolent {
    // Collects SUSHI tokens
    IMiniChefV2(MASTER_CHEF).harvest(poolId, address(this));
    uint256 _Acct = IERC20(ACCT).balanceOf(address(this));
    if (_Acct > 0) {
      // 10% is locked up for future gov
      uint256 _keepAcct = _Acct.mul(keep).div(keepMax);
      IERC20(ACCT).safeTransfer(IController(controller).treasury(), _keepAcct);
    }

    // Collect reward tokens
    if (rewardToken != address(0)) {
      uint256 _reward = IERC20(rewardToken).balanceOf(address(this));
      if (_reward > 0) {
        uint256 _keepReward = _reward.mul(keepReward).div(keepMax);
        IERC20(rewardToken).safeTransfer(IController(controller).treasury(), _keepReward);
        _reward = IERC20(rewardToken).balanceOf(address(this));
      }
    }
    uint256 _want = IERC20(want).balanceOf(address(this));
    emit Harvest(block.timestamp, _want);

    // We want to get back SUSHI LP tokens
    _distributePerformanceFeesAndDeposit();
  }
}
