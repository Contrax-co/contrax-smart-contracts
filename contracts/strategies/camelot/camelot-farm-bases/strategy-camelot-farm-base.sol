// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../strategy-base.sol";
import "../../../interfaces/camelotRouter.sol";

abstract contract StrategyCamelotFarmBase is StrategyBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // Token addresses
    address public constant camelotRouter = 0xc873fEcbd354f5A56E00E710B90EF4201db2448d;
    address public constant camelotPool = 0x978E469E8242cd18af5926A1b60B8D93A550a391;

    address public constant grail = 0x3d9907F9a368ad0a51Be60f7Da3b97cf940982D8;
    address public constant xgrail = 0x3CAaE25Ee616f2C8E13C74dA0813402eae3F496b;

    // Possible lp pair
    address public token0;
    address public token1;

    address rewardToken;

    // How much tokens to keep?
    uint256 public keep = 1000;
    uint256 public keepReward = 1000;
    uint256 public constant keepMax = 10000;

    uint256 public tokenId;

    constructor(
        address _token0,
        address _token1,
        uint256 _tokenId,
        address _lp,
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyBase(_lp, _governance, _strategist, _controller, _timelock)
    {
        tokenId = _tokenId;
        token0 = _token0;
        token1 = _token1;
    }

    function balanceOfPool() public view override returns (uint256) {
        (uint256 amount, , , , , , , ) = ICamelotPool(camelotPool).getStakingPosition(tokenId);
        return amount;
    }

    function getHarvestable() external view returns (uint256) {
        uint256 _pending = ICamelotPool(camelotPool).pendingRewards(tokenId);
        
        return _pending;
    }

    // **** Setters ****

    function deposit() public override {
        uint256 _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            IERC20(want).safeApprove(camelotPool, 0);
            IERC20(want).safeApprove(camelotPool, _want);
            ICamelotPool(camelotPool).createPosition(_want, 0);
        }
    }

    function _withdrawSome(uint256 _amount)
        internal
        override
        returns (uint256)
    {
        ICamelotPool(camelotPool).withdrawFromPosition(tokenId, _amount);
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
        ICamelotPool(camelotPool).harvestPosition(tokenId);

        uint256 _grail = IERC20(grail).balanceOf(address(this));
        uint256 _xgrail = IERC20(xgrail).balanceOf(address(this));
        if (_grail > 0) {
            // 10% is locked up for future gov
            uint256 _keepGrail = _grail.mul(keep).div(keepMax);
            IERC20(grail).safeTransfer(
                IController(controller).treasury(),
                _keepGrail
            );

            _grail = IERC20(grail).balanceOf(address(this));
            _swapSushiswap(grail, weth, _grail);
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
            IERC20(token0).safeApprove(camelotRouter, 0);
            IERC20(token0).safeApprove(camelotRouter, _token0);
            IERC20(token1).safeApprove(camelotRouter, 0);
            IERC20(token1).safeApprove(camelotRouter, _token1);

            ICamelotRouter(camelotRouter).addLiquidity(
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