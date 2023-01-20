// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../strategy-base.sol";
import "../../../interfaces/saddle.sol";

import "hardhat/console.sol";

abstract contract StrategySaddleFarmBase is StrategyBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // Token addresses
    address public constant sdl = 0x75C9bC761d88f70156DAf83aa010E84680baF131;
    address public constant saddleStaking = 0xBBcaeA4e732173C0De28397421c17A595372C9CF;

    // Possible lp pair
    address public token0;
    address public token1;

    address rewardToken;

    // How much tokens to keep?
    uint256 public keep = 1000;
    uint256 public keepReward = 1000;
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
        (uint256 amount) = ISaddleStaking(saddleStaking).balanceOf(
            address(this)
        );
        return amount;
    }

    function getHarvestable() external view returns (uint256) {
        uint256 _pendingSDL = ISaddleStaking(saddleStaking).claimable_reward(
            address(this),
            sdl
        );
        return (_pendingSDL);
    }

    // **** Setters ****

    function deposit() public override {
        uint256 _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            IERC20(want).safeApprove(saddleStaking, 0);
            IERC20(want).safeApprove(saddleStaking, _want);
            ISaddleStaking(saddleStaking).deposit(_want, address(this), true);
        }
    }

    function _withdrawSome(uint256 _amount)
        internal
        override
        returns (uint256)
    {
        ISaddleStaking(saddleStaking).withdraw(_amount, address(this), true);
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
        ISaddleStaking(saddleStaking).claim_rewards(address(this), address(this));

        uint256 _sdl = IERC20(sdl).balanceOf(address(this));
        console.log("the value of sdl is", _sdl);
        if (_sdl > 0) {
            // 10% is locked up for future gov
            uint256 _keepSDL = _sdl.mul(keep).div(keepMax);
            IERC20(sdl).safeTransfer(
                IController(controller).treasury(),
                _keepSDL
            );

            _sdl = IERC20(sdl).balanceOf(address(this));
            console.log("the value of sdl is", _sdl);
        }

        // We want to get back SUSHI LP tokens
        _distributePerformanceFeesAndDeposit();
    }
}