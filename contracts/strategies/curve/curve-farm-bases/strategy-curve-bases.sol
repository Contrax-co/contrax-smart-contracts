// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../strategy-base.sol";
import "../../../interfaces/curve.sol";

abstract contract StrategyCurveFarmBase is StrategyBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // Token addresses
    address public constant curveStaking = 0x555766f3da968ecBefa690Ffd49A2Ac02f47aa5f;


    // Possible lp pair
    address public token0;
    address public token1;

    address rewardToken;

    // How much tokens to keep?
    uint256 public keep = 1000;
    uint256 public keepReward = 1000;
    uint256 public constant keepMax = 10000;

    uint256 public want_poolId;
    address public baseToken;

    uint256 poolId;

    constructor(
        uint256 _poolId,
        uint256 _want_poolId,
        address _baseToken,
        address _want,
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyBase(_want, _governance, _strategist, _controller, _timelock)
    {
        baseToken = _baseToken;
        want_poolId = _want_poolId;
        poolId = _poolId;
    }

    function balanceOfPool() public view override returns (uint256) {
        (uint256 amount) = ICurve(curveStaking).balanceOf(address(this));
        return amount;
    }

    function getHarvestable() external view returns (uint256) {
        uint256 _pendingStargate = ILPStaking(lpStaking).pendingStargate(poolId, address(this));
        return (_pendingStargate);
    }

    // **** Setters ****

    function deposit() public override {
        uint256 _want = IERC20(want).balanceOf(address(this));
        if(_want > 0) {
            IERC20(want).safeApprove(curveStaking, 0);
            IERC20(want).safeApprove(curveStaking, _want);

            ICurve(curveStaking).deposit(_want, address(this), false);
        }
    }

    function _withdrawSome(uint256 _amount)
        internal
        override
        returns (uint256)
    {
        ILPStaking(lpStaking).withdraw(poolId, _amount);
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
        // Collects Reward tokens
        ILPStaking(lpStaking).deposit(poolId, 0);

        uint256 _stargate = IERC20(stargate).balanceOf(address(this));
        if (_stargate > 0) {
            // 10% is locked up for future gov
            uint256 _keepStargate = _stargate.mul(keep).div(keepMax);
            IERC20(stargate).safeTransfer(
                IController(controller).treasury(),
                _keepStargate
            );

            _stargate = IERC20(stargate).balanceOf(address(this));
            _swapSushiswap(stargate, baseToken, _stargate);
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
                _swapSushiswap(rewardToken, baseToken, _reward);
            }
        }

        uint256 _wantBase = IERC20(baseToken).balanceOf(address(this));
        if (_wantBase > 0) {
            IERC20(baseToken).safeApprove(stargateRouter, 0);
            IERC20(baseToken).safeApprove(stargateRouter, _wantBase);
            IStargateRouter(stargateRouter).addLiquidity(want_poolId, _wantBase, address(this));
        }

        // We want to get back SUSHI LP tokens
        _distributePerformanceFeesAndDeposit();
    }
}