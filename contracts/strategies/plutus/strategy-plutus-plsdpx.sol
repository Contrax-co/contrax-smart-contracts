// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./plutus-farm-bases/strategy-plutus-farm-base.sol";

contract StrategyPlutusPlsDpx is StrategyPlutusPlsDpxFarmBase {

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyPlutusPlsDpxFarmBase(
            plsDPX,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyPlutusPlsDpx";
    }
}