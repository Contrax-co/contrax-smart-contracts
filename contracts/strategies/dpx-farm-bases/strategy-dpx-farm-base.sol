// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../strategy-base.sol";
import "../../interfaces/dpx-staking-rewards.sol";


abstract contract StrategyDpxFarmBase is StrategyBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // Token addresses
    address public constant dpx = 0x6C2C06790b3E3E3c38e12Ee22F8183b37a13EE55;
    address public constant stakingRewards = 0x1f80C96ca521d7247a818A09b0b15C38E3e58a28;

    // WETH/<token1> pair
    address public token0;
    address public token1;
    address rewardToken;

    // How much tokens to keep?
    uint256 public keep = 2000;
    uint256 public keepReward = 2000;
    uint256 public constant keepMax = 10000;

    constructor(
        address _token0,
        address _token1,
        address _lp,
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyBase(_lp, _governance, _strategist, _controller, _timelock)
    {
        token0 = _token0;
        token1 = _token1;
    }

    function balanceOfPool() public view override returns (uint256) {
        (uint256 amount) = IStakingRewardsV3(stakingRewards).balanceOf(
            address(this)
        );
        return amount;
    }

    function getHarvestable() external view returns (uint256) {
        uint256 _pending = IStakingRewardsV3(stakingRewards).earned(
            address(this)
        );
        return (_pending);
    }

    // **** Setters ****
    function deposit() public override {
        uint256 _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            IERC20(want).safeApprove(stakingRewards, 0);
            IERC20(want).safeApprove(stakingRewards, _want);
            IStakingRewardsV3(stakingRewards).stake(_want);
        }
    }

    function _withdrawSome(uint256 _amount)
        internal
        override
        returns (uint256)
    {
        IStakingRewardsV3(stakingRewards).unstake(_amount);
        return _amount;
    }

    // **** Setters ****

    function setKeep(uint256 _keepDPX) external {
        require(msg.sender == timelock, "!timelock");
        keep = _keepDPX;
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
        // Collects Reward tokens
        IStakingRewardsV3(stakingRewards).claim();
        uint256 _dpx = IERC20(dpx).balanceOf(address(this));
        if (_dpx > 0) {
            // 10% is locked up for future gov
            uint256 _keepDPX = _dpx.mul(keep).div(keepMax);
            IERC20(dpx).safeTransfer(
                IController(controller).treasury(),
                _keepDPX
            );
            _dpx = IERC20(dpx).balanceOf(address(this));
            _swapSushiswap(dpx, weth, _dpx);
        }

        // Collect reward tokens
        if (rewardToken != address(0)) {
            uint256 _reward = IERC20(rewardToken).balanceOf(address(this));
            if (_reward > 0) {
                uint256 _keepReward = _reward.mul(keepReward).div(keepMax);
                IERC20(rewardToken).safeTransfer(
                    IController(controller).treasury(),
                    _keepReward
                );
                _reward = IERC20(rewardToken).balanceOf(address(this));
                _swapSushiswap(rewardToken, weth, _reward);
            }
        }

        // Swap half WETH for token0
        uint256 _weth = IERC20(weth).balanceOf(address(this));
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

        // We want to get back LP tokens
        _distributePerformanceFeesAndDeposit();
    }
}