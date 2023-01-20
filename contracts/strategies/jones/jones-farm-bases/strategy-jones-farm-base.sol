// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../strategy-base.sol";
import "../../../interfaces/jones.sol";

import "hardhat/console.sol";

abstract contract StrategyJonesFarmBase is StrategyBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // Token addresses
    address public constant jones = 0x10393c20975cF177a3513071bC110f7962CD67da;
    address public constant milliner = 0xb94d1959084081c5a11C460012Ab522F5a0FD756;

    // Possible lp pair
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
        StrategyBase(_lp, _governance, _strategist, _controller, _timelock)
    {
        poolId = _poolId;
        token0 = _token0;
        token1 = _token1;
    }

    function balanceOfPool() public view override returns (uint256) {
        (uint256 amount, ) = IMilliner(milliner).userInfo(
            poolId,
            address(this)
        );
        return amount;
    }

    function getHarvestable() external view returns (uint256) {
        uint256 _pendingJones = IMilliner(milliner).pendingJones(
            poolId,
            address(this)
        );
        return (_pendingJones);
    }

    // **** Setters ****

    function deposit() public override {
        uint256 _want = IERC20(want).balanceOf(address(this));
        console.log("the msg.sender is", msg.sender);
        if (_want > 0) {
            IERC20(want).safeApprove(milliner, 0);
            IERC20(want).safeApprove(milliner, _want);
            IMilliner(milliner).deposit(poolId, _want);
        }
    }

    function _withdrawSome(uint256 _amount)
        internal
        override
        returns (uint256)
    {
        IMilliner(milliner).withdraw(poolId, _amount);
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
        IMilliner(milliner).harvest(poolId);

        uint256 _jones = IERC20(jones).balanceOf(address(this));
        if (_jones > 0) {
            // 10% is locked up for future gov
            uint256 _keepJones = _jones.mul(keep).div(keepMax);
            IERC20(jones).safeTransfer(
                IController(controller).treasury(),
                _keepJones
            );

            _jones = IERC20(jones).balanceOf(address(this));
            _swapSushiswap(jones, weth, _jones);
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
                _swapSushiswap(rewardToken, weth, _reward.sub(_keepReward));
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

        // We want to get back SUSHI LP tokens
        _distributePerformanceFeesAndDeposit();
    }
}