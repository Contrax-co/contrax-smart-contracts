// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../strategy-base.sol";
import "../../interfaces/gmx-reward-router.sol";
import "../../interfaces/IRewarder.sol";

abstract contract StrategyGMXFarmBase is StrategyBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // Token addresses
    address public constant gmx = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
    address public constant esGMX = 0xf42Ae1D54fd613C9bb14810b0588FaAa09a426cA; 
    address public constant rewardRouter = 0xA906F338CB21815cBc4Bc87ace9e68c87eF8d8F1;

    address public constant rewardTracker = 0x908C4D94D34924765f1eDc22A1DD098397c59dD4;

    
    address rewardToken;

    // How much tokens to keep?
    uint256 public keep = 2000;
    uint256 public keepReward = 2000;
    uint256 public constant keepMax = 10000;

    constructor(
        address _lp,
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyBase(_lp, _governance, _strategist, _controller, _timelock)
    {
    }

    // BUILT 
    function balanceOfPool() public view override returns (uint256) {
        uint256 amount = IRewardTracker(rewardTracker).stakedAmounts(address(this)); 
        return amount;
    }

    // BUILT
    function getHarvestable() external view returns (uint256) {
        uint256 _pendingesGMX = IRewardTracker(rewardTracker).claimable(address(this));
        return (_pendingesGMX);
    }

    // **** Setters ****
    //BUILT
    function deposit() public override {
        uint256 _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            IERC20(want).safeApprove(rewardTracker, 0);
            IERC20(want).safeApprove(rewardTracker, _want);
            IRewardRouterV2(rewardRouter).stakeGmx(_want);
        }
    }

    function _withdrawSome(uint256 _amount)
        internal
        override
        returns (uint256)
    {
        IRewardRouterV2(rewardRouter).unstakeGmx(_amount);
        return _amount;
    }

    // **** Setters ****

    function setKeep(uint256 _keepSUSHI) external {
        require(msg.sender == timelock, "!timelock");
        keep = _keepSUSHI;
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
        //  Collects rewards 
        IRewardRouterV2(rewardRouter).handleRewards(
            true, 
            true, 
            false, 
            false, 
            true, 
            true, 
            false
        );

        uint256 _weth = IERC20(weth).balanceOf(address(this));
        if (_weth > 0) {
            // 10% is locked up for future gov
            uint256 _keepWETH = _weth.mul(keep).div(keepMax);
            IERC20(weth).safeTransfer(
                IController(controller).treasury(),
                _keepWETH
            );
            _swapSushiswap(weth, gmx, _weth.sub(_keepWETH));
        }

        // We want to get back GMX tokens
        _distributePerformanceFeesAndDeposit();
    }
}