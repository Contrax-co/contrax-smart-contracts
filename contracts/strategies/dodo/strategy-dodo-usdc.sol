// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./dodo-farm-bases/dodo-farm-base.sol"; 

contract StrategyDodoUsdc is StrategyDodoBase {

    address public usdc_dodo = 0x7eBd8a1803cE082d4dE609C0aA0813DD842BD4DB;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyDodoBase(
            usdc,
            usdc_dodo,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyDodoUsdc";
    }
}