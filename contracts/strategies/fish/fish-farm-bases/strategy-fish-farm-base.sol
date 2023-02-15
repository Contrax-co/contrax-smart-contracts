// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../strategy-uni-base.sol";
import "../../../interfaces/swapfish.sol";

abstract contract StrategyFishFarmBase is StrategyUniBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // Token addresses
    address public constant fish = 0xb348B87b23D5977E2948E6f36ca07E1EC94d7328;
    address public constant masterChef = 0x33141e87ad2DFae5FBd12Ed6e61Fa2374aAeD029;

    address public constant usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;


    // <token0>/<token1> pair
    address public token0;
    address public token1;
    address rewardToken;

    // How much tokens to keep?
    uint256 public keep = 1000;
    uint256 public keepReward = 1000;
    uint256 public constant keepMax = 10000;

    uint256 public poolId;

    constructor(
        address _token0,
        address _token1,
        uint256 _poolId,
        address _lp,
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyUniBase(_lp, _governance, _strategist, _controller, _timelock)
    {
        poolId = _poolId;
        token0 = _token0;
        token1 = _token1;
    }

    function balanceOfPool() public view override returns (uint256) {
      (uint256 amount, ) = IMasterChef(masterChef).userInfo(
        poolId, 
        address(this)
      ); 

      return amount;
    }

    function getHarvestable() external view returns (uint256) {
      uint256 _pendingFish = IMasterChef(masterChef).pendingCake(
        poolId, 
        address(this)
      );
   
      return _pendingFish;
    }

    // **** Setters ****

    function deposit() public override {
        uint256 _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            IERC20(want).safeApprove(masterChef, 0);
            IERC20(want).safeApprove(masterChef, _want);
            IMasterChef(masterChef).deposit(poolId, _want);
        }
    }

    function _withdrawSome(uint256 _amount)
        internal
        override
        returns (uint256)
    {
        IMasterChef(masterChef).withdraw(poolId, _amount);
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

    function harvest() public override onlyBenevolent {
        
        IMasterChef(masterChef).deposit(poolId, 0); 

        uint256 _fish = IERC20(fish).balanceOf(address(this));
        _swapUniswap(fish, usdc, _fish);

        uint256 _usdc = IERC20(usdc).balanceOf(address(this));
        if (_usdc > 0) {
            // 10% is locked up for future gov
            uint256 _keep = _usdc.mul(keep).div(keepMax);
            IERC20(usdc).safeTransfer(
                IController(controller).treasury(),
                _keep
            );
        }

        // Swap half for token0
        _usdc = IERC20(usdc).balanceOf(address(this));
        if (_usdc > 0 && token0 != usdc) {
            _swapUniswap(usdc, token0, _usdc.div(2));
        }

        // Swap half for token1
        if (_usdc > 0 && token1 != usdc) {
            _swapUniswap(usdc, token1, _usdc.div(2));
        }

        // Adds in liquidity for token0/token1
        uint256 _token0 = IERC20(token0).balanceOf(address(this));
        uint256 _token1 = IERC20(token1).balanceOf(address(this));
        if (_token0 > 0 && _token1 > 0) {
            IERC20(token0).safeApprove(uniswapRouterV2, 0);
            IERC20(token0).safeApprove(uniswapRouterV2, _token0);
            IERC20(token1).safeApprove(uniswapRouterV2, 0);
            IERC20(token1).safeApprove(uniswapRouterV2, _token1);

            UniswapRouterV2(uniswapRouterV2).addLiquidity(
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

        // We want to get back SUSHI LP tokens
        _distributePerformanceFeesAndDeposit();
    }
}