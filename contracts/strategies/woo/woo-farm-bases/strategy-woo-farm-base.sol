// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../strategy-base.sol";
import "../../../interfaces/woo.sol";

abstract contract StrategyWooFarmBase is StrategyBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // Token addresses
    address public constant xwoo = 0x9321785D257b3f0eF7Ff75436a87141C683DC99d;

    address public constant masterchefWoo = 0xc0f8C29e3a9A7650a3F642e467d70087819926d6;

    address rewardToken;

    // How much tokens to keep?
    uint256 public keep = 1000;
    uint256 public keepReward = 1000;
    uint256 public constant keepMax = 10000;

    uint256 public poolId;

    constructor(
        uint256 _poolId,
        address _lp,
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyBase(_lp, _governance, _strategist, _controller, _timelock)
    {
        poolId = _poolId;
    }

    function balanceOfPool() public view override returns (uint256) {
        (uint256 amount, ) = IMasterChefWoo(masterchefWoo).userInfo(
            poolId,
            address(this)
        );
        return amount;
    }

    function getHarvestable() external view returns (uint256) {
        uint256 _pendingXWoo = IMasterChefWoo(masterchefWoo).pendingXWoo(poolId, address(this));
        return (_pendingXWoo);
    }

    // **** Setters ****

    function deposit() public override {
        uint256 _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            IERC20(want).safeApprove(masterchefWoo, 0);
            IERC20(want).safeApprove(masterchefWoo, _want);
            IMasterChefWoo(masterchefWoo).deposit(poolId, _want);
        }
    }

    function _withdrawSome(uint256 _amount)
        internal
        override
        returns (uint256)
    {
        IMasterChefWoo(masterchefWoo).withdrawSome(poolId, _amount);
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
        // Collects Reward Tokens
        IMasterChefWoo(masterchefWoo).harvest(poolId);

        uint256 _xwoo = IERC20(xwoo).balanceOf(address(this));
        if (_xwoo > 0) {
            // 10% is locked up for future gov
            uint256 _keep = _xwoo.mul(keep).div(keepMax);
            IERC20(xwoo).safeTransfer(
                IController(controller).treasury(),
                _keep
            );
            
            //swap xwoo for weth and redeposit
            _xwoo = IERC20(xwoo).balanceOf(address(this));
            _swapSushiswap(sushi, weth, _sushi);
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

      

        // We want to get back LP tokens
        _distributePerformanceFeesAndDeposit();
    }
}