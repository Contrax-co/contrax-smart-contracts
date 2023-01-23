// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./stargate-farm-bases/strategy-stargate-farm-base.sol";

contract StrategyStargateWeth is StrategyStargateFarmBase {
    uint256 public wethId = 13; 

    address public weth_lp = 0x915A55e36A01285A14f05dE6e81ED9cE89772f8e;
    uint256 public wethlp_Id = 2;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyStargateFarmBase(
          wethlp_Id,
          wethId, 
          weth,
          weth_lp,
          _governance,
          _strategist,
          _controller,
          _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyStargateUsdt";
    }
}