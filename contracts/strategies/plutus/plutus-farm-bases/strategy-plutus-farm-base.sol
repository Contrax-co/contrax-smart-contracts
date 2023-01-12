// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../strategy-base.sol";
import "../../../interfaces/plutus.sol";

import "hardhat/console.sol";

abstract contract StrategyPlutusFarmBase is StrategyBase {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;
  

  address public constant dpx = 0x6C2C06790b3E3E3c38e12Ee22F8183b37a13EE55;
  address public constant plsDPX = 0xF236ea74B515eF96a9898F5a4ed4Aa591f253Ce1;
  address public constant pls = 0x51318B7D00db7ACc4026C88c3952B66278B6A67F;

  address public constant dpxDeposit = 0x548C30b0af3CE6D96F1A63AfC05F0fb66495179F;

  address public constant plsDpxChef = 0x75c143460F6E3e22F439dFf947E25C9CcB72d2e8;

  // How much tokens to keep?
  uint256 public keep = 1000;
  uint256 public keepReward = 1000;
  uint256 public constant keepMax = 10000;

  address rewardToken;

  constructor(
        address _lp,
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
  )
    StrategyBase(_lp, _governance, _strategist, _controller, _timelock)
  {
  }

  function balanceOfPool() public view override returns (uint256) {
    (uint256 amount, , , , ) = IPlsDpxChef(plsDpxChef).userInfo(address(this)); 
    return amount;
  }

  function getHarvestable() external view returns (uint256, uint256, uint256, uint256) {
    (uint256 _pendingPls, 
    uint256 _pendingPlsDpx, 
    uint256 _pendingPlsJones,  
    uint256 _pendingDpx
    ) = IPlsDpxChef(plsDpxChef).pendingRewards(address(this));

    return (_pendingPls, _pendingPlsDpx, _pendingPlsJones, _pendingDpx);
  }

  function deposit() public override {
    uint256 _want = IERC20(want).balanceOf(address(this));

    console.log("The amount that we want to deposit is", _want);
    console.log("the msg.sender is", msg.sender);
    console.log("The tx origin is", tx.origin);

    if (_want > 0) {
        IERC20(want).safeApprove(plsDpxChef, 0);
        IERC20(want).safeApprove(plsDpxChef, _want);
        IPlsDpxChef(plsDpxChef).deposit(uint96(_want));
    }
  }

  function _withdrawSome(uint256 _amount) internal override returns (uint256) {
    IPlsDpxChef(plsDpxChef).withdraw(uint96(_amount));
    return _amount;
  }

  // **** Setters ****
  function setKeep(uint256 _keepSUSHI) external {
      require(msg.sender == timelock, "!timelock");
      keep = _keepSUSHI;
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

  function harvest() public override onlyBenevolent {
    IPlsDpxChef(plsDpxChef).harvest();

    uint256 _pls = IERC20(pls).balanceOf(address(this));
    _swapSushiswap(pls, dpx, _pls);

    uint256 _dpx = IERC20(dpx).balanceOf(address(this));
    if(_dpx > 0) {
      // 10% is locked up for future gov
      uint256 _keep = _dpx.mul(keep).div(keepMax);
      if (_keep > 0) {
          IERC20(dpx).safeTransfer(
                IController(controller).treasury(),
                _keep
          );
      }
      _dpx = IERC20(dpx).balanceOf(address(this));

      IERC20(dpx).safeApprove(dpxDeposit, 0);
      IERC20(dpx).safeApprove(dpxDeposit, _dpx);

      IDpxDepositor(dpxDeposit).deposit(_dpx);
    }

    uint256 _plsDPX = IERC20(plsDPX).balanceOf(address(this));
    if(_plsDPX > 0) {
    // 10% is locked up for future gov
      uint256 _keep = _plsDPX.mul(keep).div(keepMax);
      if (_keep > 0) {
          IERC20(plsDPX).safeTransfer(
                IController(controller).treasury(),
                _keep
          );
      }
      _plsDPX = IERC20(plsDPX).balanceOf(address(this));
    }

    _distributePerformanceFeesAndDeposit();

  }

  
}