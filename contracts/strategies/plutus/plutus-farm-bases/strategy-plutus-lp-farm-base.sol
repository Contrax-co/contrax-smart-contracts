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
  address public constant plutusChef = 0xA61f0d1d831BA4Be2ae253c13ff906d9463299c2;

  // How much tokens to keep?
  uint256 public keep = 1000;
  uint256 public keepReward = 1000;
  uint256 public constant keepMax = 10000;

  address rewardToken;

  constructor(
        address _want,
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
  )
    StrategyBase(_want, _governance, _strategist, _controller, _timelock)
  {
  }

  function balanceOfPool() public view override returns (uint256) {
    (uint256 amount, ) = IPlutusChef(plutusChef).userInfo(address(this)); 
    return amount;
  }

  function getHarvestable() external view returns (uint256) {
    uint256 _pendingPls = IPlutusChef(plutusChef).pendingRewards(address(this));

    return (_pendingPls);
  }

  function deposit() public override {
    uint256 _want = IERC20(want).balanceOf(address(this));
    console.log("before deposit", _want);
    if (_want > 0) {
        IERC20(want).safeApprove(plutusChef, 0);
        IERC20(want).safeApprove(plutusChef, _want);
        IPlutusChef(plutusChef).deposit(uint96(_want));
    }

    _want = IERC20(want).balanceOf(address(this));
    console.log("after deposit", _want);
  }

  function _withdrawSome(uint256 _amount) internal override returns (uint256) {
    IPlutusChef(plutusChef).withdraw(uint96(_amount));
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

  function harvest() public override onlyBenevolent {
    IPlutusChef(plutusChef).harvest();

    uint256 _pls = IERC20(pls).balanceOf(address(this));
    if(_pls > 0) {
      // 10% is locked up for future gov
      uint256 _keep = _pls.mul(keep).div(keepMax);
      if (_keep > 0) {
          IERC20(pls).safeTransfer(
                IController(controller).treasury(),
                _keep
          );
      }
      _pls = IERC20(pls).balanceOf(address(this));
      _swapSushiswap(pls, dpx, _pls);
    
    }

    uint256 _dpx = IERC20(dpx).balanceOf(address(this));
    
    IERC20(dpx).safeApprove(dpxDeposit, 0);
    IERC20(dpx).safeApprove(dpxDeposit, _dpx.div(2));

    IDpxDepositor(dpxDeposit).deposit(_dpx.div(2));

    // Adds in liquidity for token0/token1
    _dpx = IERC20(dpx).balanceOf(address(this));
    uint256 _plsDPX = IERC20(plsDPX).balanceOf(address(this));
    if (_dpx > 0 && _plsDPX > 0) {
        IERC20(dpx).safeApprove(sushiRouter, 0);
        IERC20(dpx).safeApprove(sushiRouter, _dpx);
        IERC20(plsDPX).safeApprove(sushiRouter, 0);
        IERC20(plsDPX).safeApprove(sushiRouter, _plsDPX);

        UniswapRouterV2(sushiRouter).addLiquidity(
            dpx,
            plsDPX,
            _dpx,
            _plsDPX,
            0,
            0,
            address(this),
            block.timestamp.add(60)
        );

        // Donates DUST
        IERC20(dpx).transfer(
            IController(controller).treasury(),
            IERC20(dpx).balanceOf(address(this))
        );
        IERC20(plsDPX).safeTransfer(
            IController(controller).treasury(),
            IERC20(plsDPX).balanceOf(address(this))
        );
    }

    _distributePerformanceFeesAndDeposit();

  }

}