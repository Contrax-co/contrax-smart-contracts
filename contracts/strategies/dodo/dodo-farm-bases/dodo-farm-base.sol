// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../strategy-base.sol";
import "../../../interfaces/dodoproxy.sol";

abstract contract StrategyDodoBase is StrategyBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public dodo_approve = 0xA867241cDC8d3b0C07C85cC06F25a0cD3b5474d8; 
    address public dodo_proxy = 0x88CBf433471A0CD8240D2a12354362988b4593E5;
    address dodo_mine = 0xE3C10989dDc5Df5B1b9c0E6229c2E4e0862fDe3e;

    // Token addresses 
    address public usdc_usdt = 0xe4B2Dfc82977dd2DCE7E8d37895a6A8F50CbB4fB; 
    address public dodo = 0x69Eb4FA4a2fbd498C257C57Ea8b7655a2559A581;

    address public usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public usdt = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; 

    address rewardToken;
    address wantBase;

    // How much tokens to keep?
    uint256 public keep = 1000;
    uint256 public keepReward = 1000;
    uint256 public constant keepMax = 10000;

    constructor(
        address _wantBase,
        address _want,
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyBase(_want, _governance, _strategist, _controller, _timelock)
    {
        wantBase = _wantBase; 
    }

    function balanceOfPool() public view override returns (uint256) {
        uint256 amount = IDodoMining(dodo_mine).getUserLpBalance(wantBase, address(this)); 
        return amount;
    }

    function getHarvestable() external view returns (uint256) {
        uint256 _pending = IDodoMining(dodo_mine).getPendingReward(wantBase, address(this));
        return (_pending);
    }

    // **** Setters ****
    function deposit() public override{
        uint256 _want = IERC20(want).balanceOf(address(this));

        IERC20(want).safeApprove(dodo_approve, 0);
        IERC20(want).safeApprove(dodo_approve, _want);

        if(want == usdt) {
            IDodoProxy(dodo_proxy).addLiquidityToV1(usdc_usdt, _want, 0, 0, 0, 0, block.timestamp.add(60));
        }else if (want == usdc) {
            IDodoProxy(dodo_proxy).addLiquidityToV1(usdc_usdt, 0, _want, 0, 0, 0, block.timestamp.add(60));
        }

        uint256 _wantBase = IERC20(wantBase).balanceOf(address(this));
    
        if (_wantBase > 0) {
            IERC20(wantBase).safeApprove(dodo_mine, 0); 
            IERC20(wantBase).safeApprove(dodo_mine, _wantBase); 

            IDodoMining(dodo_mine).deposit(wantBase, _wantBase); 
        }
    }

    function _withdrawSome(uint256 _amount)
        internal
        override
        returns (uint256)
    {
        IDodoMining(dodo_mine).withdraw(wantBase, _amount);
       
        uint256 _withdraw;

        if(want == usdt){
            _withdraw = IDodo(usdc_usdt).getLpBaseBalance(address(this));
            IDodo(usdc_usdt).withdrawBase(_withdraw);
        }else if (want == usdc){
            _withdraw = IDodo(usdc_usdt).getLpQuoteBalance(address(this));
            IDodo(usdc_usdt).withdrawQuote(_withdraw);
        }
    
        return _withdraw;
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
        // Collects Reward tokens
        IDodoMining(dodo_mine).claim(wantBase);
        uint256 _dodo = IERC20(dodo).balanceOf(address(this));
        if (_dodo > 0) {
            // 10% is locked up for future gov
            uint256 _keepDODO = _dodo.mul(keep).div(keepMax);
            IERC20(dodo).safeTransfer(
                IController(controller).treasury(),
                _keepDODO
            );
            _dodo = IERC20(dodo).balanceOf(address(this));

            // swap dodo for base token
            _swapSushiswap(dodo, want, _dodo);
        }
            
        _distributePerformanceFeesAndDeposit();
    }
}
