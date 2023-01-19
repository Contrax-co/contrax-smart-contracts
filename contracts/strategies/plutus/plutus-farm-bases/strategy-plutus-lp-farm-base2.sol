// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../strategy-base.sol";
import "../../../interfaces/plutus.sol";

abstract contract StrategyPlutusFarmBase is StrategyBase {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;
  
  address public constant pls = 0x51318B7D00db7ACc4026C88c3952B66278B6A67F;

  address public constant plutusMasterChef = 0x5593473e318F0314Eb2518239c474e183c4cBED5;

  // How much tokens to keep?
  uint256 public keep = 1000;
  uint256 public keepReward = 1000;
  uint256 public constant keepMax = 10000;

  address rewardToken;
  uint256 public poolId;

  constructor(
        uint256 _poolId,
        address _want,
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
  )
    StrategyBase(_want, _governance, _strategist, _controller, _timelock)
  {
    poolId = _poolId;
  }

  function balanceOfPool() public view override returns (uint256) {
    (uint256 amount, ) = IPlutusMasterChef(plutusMasterChef).userInfo(poolId, address(this)); 
    return amount;
  }

  function getHarvestable() external view returns (uint256) {
    uint256 _pendingPls = IPlutusMasterChef(plutusMasterChef).pendingPls(poolId, address(this));

    return (_pendingPls);
  }

  function deposit() public override {
    uint256 _want = IERC20(want).balanceOf(address(this));
    if (_want > 0) {
        IERC20(want).safeApprove(plutusMasterChef, 0);
        IERC20(want).safeApprove(plutusMasterChef, _want);
        IPlutusMasterChef(plutusMasterChef).deposit(poolId, _want);
    }
  }

  function _withdrawSome(uint256 _amount) internal override returns (uint256) {
    IPlutusMasterChef(plutusMasterChef).withdraw(poolId, _amount);
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
    IPlutusMasterChef(plutusMasterChef).deposit(poolId, 0);

    uint256 _pls = IERC20(pls).balanceOf(address(this));
    if(_pls > 0) {
        // 10% is locked up for future gov
        uint256 _keepPls = _pls.mul(keep).div(keepMax);
        IERC20(pls).safeTransfer(
            IController(controller).treasury(),
            _keepPls
        );
        
        _pls = IERC20(pls).balanceOf(address(this));
        _swapSushiswap(pls, weth, _pls.div(2));
    
    }
    
    uint256 _weth = IERC20(weth).balanceOf(address(this));
    _pls = IERC20(pls).balanceOf(address(this));
    
    // Adds in liquidity for token0/token1
    if (_pls > 0 && _weth > 0) {
        IERC20(pls).safeApprove(sushiRouter, 0);
        IERC20(pls).safeApprove(sushiRouter, _pls);
        IERC20(weth).safeApprove(sushiRouter, 0);
        IERC20(weth).safeApprove(sushiRouter, _weth);

        UniswapRouterV2(sushiRouter).addLiquidity(
            pls,
            weth,
            _pls,
            _weth,
            0,
            0,
            address(this),
            block.timestamp.add(60)
        );

        _pls = IERC20(pls).balanceOf(address(this));
        _weth = IERC20(weth).balanceOf(address(this));

        // Donates DUST
        if(_pls > 0) {
          IERC20(pls).transfer(
            IController(controller).treasury(),
            _pls
          );
        }
        
        if(_weth > 0) {
          IERC20(weth).safeTransfer(
              IController(controller).treasury(),
              _weth
          );
        }
    }

    _distributePerformanceFeesAndDeposit();

  }

}