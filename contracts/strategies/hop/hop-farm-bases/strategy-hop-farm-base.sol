// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../strategy-base-v3.sol";
import "../../../interfaces/hop.sol"; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 

abstract contract StrategyHopFarmBase is StrategyBaseV3 {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // Token addresses
    address public hop = 0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC;

    // Staking addresses and pools
    address public stakingRewards;
    address public liquidityPool;
 
    // <token0>/<token1> pair
    address public token0;
    address public token1;
    address rewardToken;

    // How much tokens to keep?
    uint256 public keep = 1000;
    uint256 public keepReward = 1000;
    uint256 public constant keepMax = 10000;

    constructor(
        address _stakingRewards,
        address _liquidityPool,
        address _token0,
        address _token1,
        address _lp,
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyBaseV3(_lp, _governance, _strategist, _controller, _timelock)
    {
        token0 = _token0;
        token1 = _token1;
        liquidityPool = _liquidityPool; 
        stakingRewards = _stakingRewards;
    }

    function balanceOfPool() public view override returns (uint256) {
        uint256 amount = IHopStakingRewards(stakingRewards).balanceOf(address(this));
    
        return amount;
    }

    function getHarvestable() external view returns (uint256) {
        uint256 _pendingHop = IHopStakingRewards(stakingRewards).earned(address(this));
        return _pendingHop;
    }

    // **** Setters ****
    function deposit() public override sphereXGuardPublic(0xdcda2df5, 0xd0e30db0) {
        uint256 _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            IERC20(want).safeApprove(stakingRewards, 0);
            IERC20(want).safeApprove(stakingRewards, _want);
            IHopStakingRewards(stakingRewards).stake(_want);
        }
    }

    function _withdrawSome(uint256 _amount)
        internal
        override
        sphereXGuardInternal(0x1996a763) returns (uint256)
    {
        IHopStakingRewards(stakingRewards).withdraw(_amount);

        return _amount;
    }

    // **** Setters ****

    function setKeep(uint256 _keep) external sphereXGuardExternal(0x9346d788) {
        require(msg.sender == timelock, "!timelock");
        keep = _keep;
    }

    function setKeepReward(uint256 _keepReward) external sphereXGuardExternal(0x2608e64e) {
        require(msg.sender == timelock, "!timelock");
        keepReward = _keepReward;
    }

    function setRewardToken(address _rewardToken) external sphereXGuardExternal(0xa4ab9138) {
        require(
            msg.sender == timelock || msg.sender == strategist,
            "!timelock"
        );
        rewardToken = _rewardToken;
    }


    // **** State Mutations ****

    // Declare a Harvest Event
    event Harvest(uint _timestamp, uint _value); 

    function harvest() public override onlyBenevolent sphereXGuardPublic(0x31755086, 0x4641257d) {
        // Collects REWARD token(s)
        IHopStakingRewards(stakingRewards).getReward();

        uint256 _hop = IERC20(hop).balanceOf(address(this));
        if (_hop > 0) {
            // 10% is locked up for future gov
            uint256 _keepHOP = _hop.mul(keep).div(keepMax);
            IERC20(hop).safeTransfer(
                IController(controller).treasury(),
                _keepHOP
            );

            _hop = IERC20(hop).balanceOf(address(this));
            _swapUniswap(hop, weth, _hop);
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
                _swapUniswap(rewardToken, weth, _reward);
            }
        }

        // Checks token0 vs token1 and swap if necessary
        if(token0 != weth){
            uint256 _weth = IERC20(weth).balanceOf(address(this));
            _swapUniswap(weth, token0, _weth);
        }

        uint256 _token0 = IERC20(token0).balanceOf(address(this));

        uint256 _tokenBalance0 = IHopSwap(liquidityPool).getTokenBalance(0);
        uint256 _tokenBalance1 = IHopSwap(liquidityPool).getTokenBalance(1);
        if(_tokenBalance0 >= _tokenBalance1){
            IERC20(token0).safeApprove(liquidityPool, 0);
            IERC20(token0).safeApprove(liquidityPool, _token0);
            IHopSwap(liquidityPool).swap(
                0, 
                1, 
                _token0, 
                0, 
                block.timestamp
            ); 
        }
        
        // Adds in liquidity for token0/token1
        _token0 = IERC20(token0).balanceOf(address(this));
        uint256 _token1 = IERC20(token1).balanceOf(address(this));

        uint256[] memory amounts;
        amounts = new uint256[](2);
        amounts[0] = _token0;
        amounts[1] = _token1;

        if (_token0 > 0 || _token1 > 0) {
            IERC20(token0).safeApprove(liquidityPool, 0);
            IERC20(token0).safeApprove(liquidityPool, _token0);
            IERC20(token1).safeApprove(liquidityPool, 0);
            IERC20(token1).safeApprove(liquidityPool, _token1);

            IHopSwap(liquidityPool).addLiquidity(
                amounts, 
                0, 
                block.timestamp
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

        uint256 _want = IERC20(want).balanceOf(address(this));
    
        emit Harvest(block.timestamp, _want);

        // We want to get back SUSHI LP tokens
        _distributePerformanceFeesAndDeposit();
    }
}