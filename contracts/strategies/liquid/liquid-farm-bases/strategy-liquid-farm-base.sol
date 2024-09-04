// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../strategy-base.sol";
import "../../../interfaces/liquidChef.sol";

import "hardhat/console.sol"; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 

abstract contract StrategyLiquidFarmBase is StrategyBase {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  uint256 public poolId; 

  address public token0;
  address public token1;

  address public constant lqd = 0x93C15cd7DE26f07265f0272E0b831C5D7fAb174f;
  address public constant fastChef = 0x2582fFEa547509472B3F12d94a558bB83A48c007;

  address public constant fastStaking = 0xA1A988A22a03CbE0cF089e3E7d2e6Fcf9BD585A9;

  address rewardToken;

  // How much tokens to keep?
  uint256 public keep = 1000;
  uint256 public keepReward = 1000;
  uint256 public constant keepMax = 10000;

  constructor(
      uint256 _pid,
      address _token0, 
      address _token1,
      address _want,
      address _governance,
      address _strategist,
      address _controller,
      address _timelock
  )
      StrategyBase(_want, _governance, _strategist, _controller, _timelock)
  {
    poolId = _pid;
    token0 = _token0;
    token1 = _token1;
  }

  function balanceOfPool() public view override returns (uint256) {
    (uint256 amount, ) = IFastChef(fastChef).userInfo(
      poolId,
      address(this)
    );
    return amount;
  }

  function getHarvestable() external view returns (uint256) {
    uint256 _pending = IFastChef(fastChef).pendingReward(
      poolId,
      address(this)
    );
    return _pending;
  }

  function deposit() public override sphereXGuardPublic(0x39abdd6a, 0xd0e30db0) {
      uint256 _want = IERC20(want).balanceOf(address(this));

      if (_want > 0) {
          IERC20(want).safeApprove(fastChef, 0); 
          IERC20(want).safeApprove(fastChef, _want); 

          IFastChef(fastChef).deposit(poolId, _want, address(this)); 
      }
  }

  function _withdrawSome(uint256 _amount)
    internal
    override
    sphereXGuardInternal(0x4064e67c) returns (uint256)
  {
      IFastChef(fastChef).withdraw(poolId, _amount, address(this));
      return _amount;
  }

  // **** Setters ****
  function setKeep(uint256 _keep) external sphereXGuardExternal(0xe0f13cb6) {
    require(msg.sender == timelock, "!timelock");
    keep = _keep;
  }

  function setKeepReward(uint256 _keepReward) external sphereXGuardExternal(0xf8cfd0e6) {
    require(msg.sender == timelock, "!timelock");
    keepReward = _keepReward;
  }

  function setRewardToken(address _rewardToken) external sphereXGuardExternal(0xd4b65fbc) {
    require(
        msg.sender == timelock || msg.sender == strategist,
        "!timelock"
    );
    rewardToken = _rewardToken;
  }

  function harvest() public override onlyBenevolent sphereXGuardPublic(0xc72eff5a, 0x4641257d) {
    IFastChef(fastChef).harvest(poolId, address(this)); 

    IFastStaking(fastStaking).getReward();
  
    (uint256 total, uint256 unlocked, uint256 locked, ) = IFastStaking(fastStaking).lockedBalances(address(this));

    console.log("the total balance is", total);
    console.log("the total unlicked balance is", unlocked);
    console.log("the total licked balance is", locked);

    (, uint256 _amount) = IFastStaking(fastStaking).withdrawableBalance(address(this));

    if(_amount > 0) {
      IFastStaking(fastStaking).withdraw(_amount); 
    }
    

    uint256 _lqd = IERC20(lqd).balanceOf(address(this));
    uint256 _weth = IERC20(weth).balanceOf(address(this));

    console.log("bal of weth is", _weth);
    console.log("bal from harvest is", _lqd);

    if (_lqd > 0) {
      // 10% is locked up for future gov
      uint256 _keep = _lqd.mul(keep).div(keepMax);
      IERC20(lqd).safeTransfer(
          IController(controller).treasury(),
          _keep
      );

      _lqd = IERC20(lqd).balanceOf(address(this));
      _swapSushiswap(lqd, weth, _lqd);
    }

    // Swap half WETH for token0
    _weth = IERC20(weth).balanceOf(address(this));
    if (_weth > 0 && token0 != weth) {
        _swapSushiswap(weth, token0, _weth.div(2));
    }

    // Swap half WETH for token1
    if (_weth > 0 && token1 != weth) {
        _swapSushiswap(weth, token1, _weth.div(2));
    }

    // Adds in liquidity for token0/token1
    uint256 _token0 = IERC20(token0).balanceOf(address(this));
    uint256 _token1 = IERC20(token1).balanceOf(address(this));
    if (_token0 > 0 && _token1 > 0) {
      IERC20(token0).safeApprove(sushiRouter, 0);
      IERC20(token0).safeApprove(sushiRouter, _token0);
      IERC20(token1).safeApprove(sushiRouter, 0);
      IERC20(token1).safeApprove(sushiRouter, _token1);

      UniswapRouterV2(sushiRouter).addLiquidity(
        token0,
        token1,
        _token0,
        _token1,
        0,
        0,
        address(this),
        block.timestamp.add(60)
      );

      // Donates DUST
      IERC20(token0).transfer(
          IController(controller).treasury(),
          IERC20(token0).balanceOf(address(this))
      );
      IERC20(token1).safeTransfer(
          IController(controller).treasury(),
          IERC20(token1).balanceOf(address(this))
      );
    }

    _distributePerformanceFeesAndDeposit();

  }

}