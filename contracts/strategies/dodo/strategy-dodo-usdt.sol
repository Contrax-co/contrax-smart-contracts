// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./dodo-farm-bases/dodo-farm-base.sol"; 

contract StrategyDodoUsdt is StrategyDodoBase {

    address public usdt_dodo = 0x82B423848CDd98740fB57f961Fa692739F991633;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyDodoBase(
            usdt,
            usdt_dodo,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyDodoUsdt";
    }
}