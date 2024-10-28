// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../strategy-base-v3.sol";
import "../../../interfaces/peapods.sol";
import "../../../interfaces/camelot.sol";
import "hardhat/console.sol";


abstract contract StrategyPeapodsLPFarmBase is StrategyBaseV3 {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  address public constant indexUtils = 0x5c5c288f5EF3559Aaf961c5cCA0e77Ac3565f0C0;
  address public constant peas = 0x02f92800F57BCD74066F5709F1Daa1A4302Df875;

  address public tokenReward;

  address public stakingToken;

  address public apToken0;
  address public apToken1;
  address public token0;
  address public token1;
  address rewardToken;

  // How much tokens to keep?
  uint256 public keep = 1000;
  uint256 public keepReward = 1000;
  uint256 public constant keepMax = 10000;

  constructor(
    address _tokenReward,
    address _stakingToken,
    address _token0,
    address _token1,
    address _apToken0,
    address _apToken1,
    address _lp,
    address _governance,
    address _strategist,
    address _controller,
    address _timelock
  )
    StrategyBaseV3(_lp, _governance, _strategist, _controller, _timelock)
  {
    apToken0 = _apToken0;
    apToken1 = _apToken1;
    token0 = _token0;
    token1 = _token1;
    stakingToken = _stakingToken;
    tokenReward = _tokenReward;
  }

  function balanceOfPool() public view override returns (uint256) {
    (uint256 amount) = IStakingPoolToken(stakingToken).balanceOf(
        address(this)
    );
    return amount;
  }

  function getHarvestable() external view returns (uint256) {
    uint256 _pending = ITokenRewards(tokenReward).getUnpaid(
      peas,
      address(this)
    );
    return (_pending);
  }

  // **** Setters ****
  function deposit() public override {
    uint256 _want = IERC20(want).balanceOf(address(this));
    if (_want > 0) {
      IERC20(want).safeApprove(stakingToken, 0);
      IERC20(want).safeApprove(stakingToken, _want);
      IStakingPoolToken(stakingToken).stake(address(this), _want);
    }
  }

  function _withdrawSome(uint256 _amount) internal override returns (uint256){
    IStakingPoolToken(stakingToken).unstake(_amount);
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
    ITokenRewards(tokenReward).claimReward(address(this)); 
    uint256 _peas = IERC20(peas).balanceOf(address(this));
    console.log("peas reward balance is", _peas);
    if (_peas > 0) {
      // 10% is locked up for future gov
      uint256 _keepPEAS = _peas.mul(keep).div(keepMax);
      IERC20(peas).safeTransfer(
          IController(controller).treasury(),
          _keepPEAS
      );

      _peas = IERC20(peas).balanceOf(address(this));
    }

    // Swap half of PEAS for token0
    if (_peas > 0 && token0 != peas) {
      address[] memory path = new address[](3);

      path[0] = peas;
      path[1] = weth;
      path[2] = token0;

      _swapCamelotWithPath(path, _peas.div(2));
    }

    // Swap half PEAS for token1
    if (_peas > 0 && token1 != peas) {
      address[] memory path = new address[](3);

      path[0] = peas;
      path[1] = weth;
      path[2] = token1;

      _swapCamelotWithPath(path, _peas.div(2));
    }
    
    uint256 _amount0 = IERC20(token0).balanceOf(address(this));
    IERC20(token0).safeApprove(indexUtils, 0);
    IERC20(token0).safeApprove(indexUtils, _amount0);
    IDecentralizedIndex(indexUtils).bond(apToken0, token0, _amount0, 0);

    uint256 _amount1 = IERC20(token1).balanceOf(address(this));
    IERC20(token1).safeApprove(indexUtils, 0);
    IERC20(token1).safeApprove(indexUtils, _amount1);
    IDecentralizedIndex(indexUtils).bond(apToken1, token1, _amount1, 0);

    uint256 _amountApToken0 = IERC20(apToken0).balanceOf(address(this));
    uint256 _amountApToken1 = IERC20(apToken1).balanceOf(address(this));

    console.log("ap0 balance is", _amountApToken0);
    console.log("ap1 balance is", _amountApToken1);


    // approve each apToken on camelotRouter
    IERC20(apToken0).safeApprove(camelotRouter, 0);
    IERC20(apToken0).safeApprove(camelotRouter, _amountApToken0);

    IERC20(apToken1).safeApprove(camelotRouter, 0);
    IERC20(apToken1).safeApprove(camelotRouter, _amountApToken1);

    // Adds in liquidity for apToken0/apToken1
    ICamelotRouter(camelotRouter).addLiquidity(
      apToken0, 
      apToken1,
      _amountApToken0,
      _amountApToken1,
      0,
      0,
      address(this),
      block.timestamp.add(60)
    );

    // Donates DUST
    IERC20(token0).transfer(
      IController(controller).treasury(),
      IERC20(apToken0).balanceOf(address(this))
    );
    IERC20(token1).safeTransfer(
      IController(controller).treasury(),
      IERC20(apToken1).balanceOf(address(this))
    );

    IERC20(apToken0).transfer(
      IController(controller).treasury(),
      IERC20(apToken0).balanceOf(address(this))
    );
    IERC20(apToken1).safeTransfer(
      IController(controller).treasury(),
      IERC20(apToken1).balanceOf(address(this))
    );

    uint256 _want = IERC20(want).balanceOf(address(this));
    emit Harvest(block.timestamp, _want);

    // We want to get back SUSHI LP tokens
    _distributePerformanceFeesAndDeposit();
  
  }
}