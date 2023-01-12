// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../strategy-base.sol";
import "../../../interfaces/pool.sol";

import "hardhat/console.sol";

abstract contract StrategyCapBase is StrategyBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // Token addresses
    address public constant pool = 0x958cc92297e6F087f41A86125BA8E121F0FbEcF2;
    address public constant rewards = 0x10f2f3B550d98b6E51461a83AD3FE27123391029;
    address public constant capRewards = 0xCEFFAc2522b837012B576770b6F5DD75a3F75C38;

    address rewardToken;

    // How much tokens to keep?
    uint256 public keep = 1000;
    uint256 public keepReward = 1000;
    uint256 public constant keepMax = 10000;

    uint256 public constant UNIT = 10**18;
    uint public constant decimals = 6; 

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
        uint256 amount = IPool(pool).getCurrencyBalance(address(this));
        uint256 amount1 = IPool(pool).getBalance(address(this));
        console.log("The balance of first call is", amount);
        console.log("The balance of the second call is", amount1);

        uint256 _returnAmt = (amount * 10**decimals)/UNIT; 
        return _returnAmt ;
    }

    function getHarvestable() external view returns (uint256) {   
        uint256 _pending = IRewards(rewards).getClaimableReward();
        uint256 _pending1 = ICapRewards(capRewards).getClaimableReward();
        console.log("The claimable reward is", _pending);
        console.log("The claimable reward 2 is", _pending1); 

        console.log("the msg sender is", msg.sender); 
        return (_pending);
    }

    // **** Setters ****
    function deposit() public override {
        uint256 _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            IERC20(want).safeApprove(pool, 0);
            IERC20(want).safeApprove(pool, (_want * UNIT)/10**decimals);
            IPool(pool).deposit((_want * UNIT)/10**decimals);
        }

        _want = IERC20(want).balanceOf(address(this));
    }

    function _withdrawSome(uint256 _amount)
        internal
        override
        returns (uint256)
    {
        IPool(pool).withdraw((_amount * UNIT)/10**decimals);
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
}