// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../strategy-base.sol";
import "../../../interfaces/hop.sol";

import "../../../interfaces/uniswapv3.sol";
import "hardhat/console.sol";


abstract contract StrategyHopFarmBase is StrategyBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // Token addresses
    address public hop = 0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC;

    address public stakingRewards = 0x755569159598f3702bdD7DFF6233A317C156d3Dd;
    address public wethSwap = 0x652d27c0F72771Ce5C76fd400edD61B406Ac6D97;
 
    // WETH/<token1> pair
    address public token0;
    address public token1;
    address rewardToken;

    // How much tokens to keep?
    uint256 public keep = 1000;
    uint256 public keepReward = 1000;
    uint256 public constant keepMax = 10000;

    uint256 public poolId;

    uint24 public constant poolFee = 3000;

    // DEX 
    address public swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564; 

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
        uint256 amount = IHopStakingRewards(stakingRewards).balanceOf(address(this));
    
        return amount;
    }

    function getHarvestable() external view returns (uint256) {
        uint256 _pendingHop = IHopStakingRewards(stakingRewards).earned(address(this));
        return _pendingHop;
    }

    // **** Setters ****
    function deposit() public override {
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
        returns (uint256)
    {
        IHopStakingRewards(stakingRewards).withdraw(_amount);

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

    function _swapHopToWeth(
        uint256 _amount
    ) internal {

        IERC20(hop).safeApprove(swapRouter, 0);
        IERC20(hop).safeApprove(swapRouter, _amount);

        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: hop,
                tokenOut: weth,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: _amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        ISwapRouter(swapRouter).exactInputSingle(params);

    }

    // **** State Mutations ****

    // Declare a Harvest Event
    event Harvest(uint _timestamp, uint _value); 

    function harvest() public override onlyBenevolent {
        // Collects REWARD token(s)
        IHopStakingRewards(stakingRewards).getReward();

        uint256 _hop = IERC20(hop).balanceOf(address(this));
        console.log("The amount of hop tokens is", _hop);
        if (_hop > 0) {
            // 10% is locked up for future gov
            uint256 _keepHOP = _hop.mul(keep).div(keepMax);
            IERC20(hop).safeTransfer(
                IController(controller).treasury(),
                _keepHOP
            );

            _hop = IERC20(hop).balanceOf(address(this));
            _swapHopToWeth(_hop);
        }

        _hop = IERC20(hop).balanceOf(address(this));
        console.log("The amount of hop after swapping for weth", _hop);



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
        console.log("The amount of weth is", _weth);

        IHopSwap(wethSwap).swap(0, 1, _weth.div(2), 0, block.timestamp);
        

        // Adds in liquidity for token0/token1
        uint256 _token0 = IERC20(token0).balanceOf(address(this));
        uint256 _token1 = IERC20(token1).balanceOf(address(this));

        uint256[] memory amounts;
        amounts = new uint256[](2);
        amounts[0] = _token0;
        amounts[1] = _token1;

        if (_token0 > 0 && _token1 > 0) {
            IERC20(token0).safeApprove(wethSwap, 0);
            IERC20(token0).safeApprove(wethSwap, _token0);
            IERC20(token1).safeApprove(wethSwap, 0);
            IERC20(token1).safeApprove(wethSwap, _token1);

            IHopSwap(wethSwap).addLiquidity(
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