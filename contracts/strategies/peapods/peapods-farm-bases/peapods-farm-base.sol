// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../strategy-base.sol";
import "../../../interfaces/peapods.sol";


abstract contract StrategyPeapodsFarmBase is StrategyBase {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  address public constant indexUtils = 0x5c5c288f5EF3559Aaf961c5cCA0e77Ac3565f0C0;

  address rewardToken;

  // How much tokens to keep?
  uint256 public keep = 1000;
  uint256 public keepReward = 1000;
  uint256 public constant keepMax = 10000;

  constructor(
    address _apToken,
    address _governance,
    address _strategist,
    address _controller,
    address _timelock
  )
    StrategyBase(_apToken, _governance, _strategist, _controller, _timelock)
  {
  }

  function balanceOfPool() public view override returns (uint256) {
    (uint256 amount) = WeightedIndex(want).balanceOf(
      address(this)
    );
    return amount;
  }

  function getHarvestable() external view returns (uint256) {
   
  }

  // **** Setters ****
  function deposit() public override {
  }

  function _withdrawSome(uint256 _amount)
    internal
    pure
    override
    returns (uint256)
  {
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