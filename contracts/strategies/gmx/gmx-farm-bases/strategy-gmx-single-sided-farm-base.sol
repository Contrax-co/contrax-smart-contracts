// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../strategy-base.sol";
import "../../../interfaces/gmx-reward-router.sol";
import "../../../interfaces/IRewarder.sol"; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 

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
    uint256 public keep = 1000;
    uint256 public keepReward = 1000;
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

    function balanceOfPool() public view override returns (uint256) {
        uint256 amount = IRewardTracker(rewardTracker).depositBalances(address(this), gmx); 
        return amount;
    }

    function getHarvestable() external view returns (uint256) {
        uint256 _pendingesGMX = IRewardTracker(rewardTracker).claimable(address(this));
        return (_pendingesGMX);
    }

    // **** Setters ****
    function deposit() public override sphereXGuardPublic(0xf17c7dd1, 0xd0e30db0) {
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
        sphereXGuardInternal(0xd590a4cf) returns (uint256)
    {
        IRewardRouterV2(rewardRouter).unstakeGmx(_amount);
        return _amount;
    }

    // **** Setters ****

    function setKeep(uint256 _keep) external sphereXGuardExternal(0xc8cb0b2d) {
        require(msg.sender == timelock, "!timelock");
        keep = _keep;
    }

    function setKeepReward(uint256 _keepReward) external sphereXGuardExternal(0xc17aaabb) {
        require(msg.sender == timelock, "!timelock");
        keepReward = _keepReward;
    }

    function setRewardToken(address _rewardToken) external sphereXGuardExternal(0xda1d4798) {
        require(
            msg.sender == timelock || msg.sender == strategist,
            "!timelock"
        );
        rewardToken = _rewardToken;
    }

    // **** State Mutations ****

    // Declare a Harvest Event
    event Harvest(uint _timestamp, uint _value); 

    function harvest() public override onlyBenevolent sphereXGuardPublic(0x815c0123, 0x4641257d) {
        //  Collects rewards 
        IRewardRouterV2(rewardRouter).handleRewards(
            true, 
            true, 
            true, 
            true, 
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

        uint256 _want = IERC20(want).balanceOf(address(this));
    
        emit Harvest(block.timestamp, _want);

        // We want to get back GMX tokens
        _distributePerformanceFeesAndDeposit();
    }
}