// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../strategy-base.sol";
import "../../../interfaces/peapods.sol";


abstract contract StrategyPeapodsFarmBase is StrategyBase {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  address public constant indexUtils = 0x5c5c288f5EF3559Aaf961c5cCA0e77Ac3565f0C0;

  address public apToken;
  address rewardToken;

  // How much tokens to keep?
  uint256 public keep = 1000;
  uint256 public keepReward = 1000;
  uint256 public constant keepMax = 10000;

  constructor(
    address _apToken,
    address _lp,
    address _governance,
    address _strategist,
    address _controller,
    address _timelock
  )
    StrategyBase(_lp, _governance, _strategist, _controller, _timelock)
  {
    apToken = _apToken;
  }

  function balanceOfPool() public view override returns (uint256) {
    (uint256 amount) = WeightedIndex(apToken).balanceOf(
      address(this)
    );
    return amount;
  }

  function getHarvestable() external view returns (uint256) {
   
  }

  // **** Setters ****
  function deposit() public override {
      uint256 _want = IERC20(want).balanceOf(address(this));
      if (_want > 0) {
        IERC20(want).safeApprove(indexUtils, 0);
        IERC20(want).safeApprove(indexUtils, _want);
        IDecentralizedIndex(indexUtils).bond(apToken ,want, _want, 0);
      }
  }

  function _withdrawSome(uint256 _amount)
    internal
    override
    returns (uint256)
  {
    address[] memory path;
    path = new address[](1);
    path[0] = want;

    uint8[] memory percent;
    percent = new uint8[](1);
    percent[0] = 100;

    WeightedIndex(apToken).debond(_amount, path, percent);
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
    require(
      msg.sender == timelock || msg.sender == strategist,
      "!timelock"
    );
    rewardToken = _rewardToken;
  }

  // **** State Mutations ****

  // Declare a Harvest Event
  event Harvest(uint _timestamp, uint _value); 

  function harvest() public override onlyBenevolent {
    
  }
}