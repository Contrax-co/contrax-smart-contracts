// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./plutus-farm-bases/strategy-plutus-lp-farm-base.sol";

contract StrategyPlutusDpxPlsDpx is StrategyPlutusFarmBase {

    address public dpx_plsDpx = 0x16E818E279d7a12fF897e257b397172dCAab323b;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyPlutusFarmBase(
            dpx_plsDpx,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyPlutusDpxPlsDpx";
    }
}