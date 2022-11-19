// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../gmx-farm-bases/strategy-gmx-single-sided-farm-base.sol";

contract StrategyGmx is StrategyGMXFarmBase {
    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyGMXFarmBase(
            gmx,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyGmx";
    }
}