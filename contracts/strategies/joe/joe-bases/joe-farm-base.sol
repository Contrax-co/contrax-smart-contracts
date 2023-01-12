// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../strategy-base.sol";
import "../../../interfaces/joeRouter.sol";

abstract contract StrategyJoeFarmBase is StrategyBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public lbRouter = 0x7BFd7192E76D950832c77BB412aaE841049D8D9B;

    address public token0;
    address public token1;
    
    constructor(
        address _token0,
        address _token1,
        address _want,
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyBase(_want, _governance, _strategist, _controller, _timelock)
    {
        token0 = _token0;
        token1 = _token1; 
    }

    function harvest() public override onlyBenevolent {

        uint256 _token0 = IERC20(token0).balanceOf(address(this));
        uint256 _token1 = IERC20(token1).balanceOf(address(this));

        if(_token0 > 0 && _token1 > 0) {
            IERC20(token0).safeApprove(lbRouter, 0);
            IERC20(token0).safeApprove(lbRouter, _token0);
            IERC20(token1).safeApprove(lbRouter, 0);
            IERC20(token1).safeApprove(lbRouter, _token1);
        }


    }
}