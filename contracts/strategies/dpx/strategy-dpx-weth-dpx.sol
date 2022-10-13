// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../dpx-farm-bases/strategy-dpx-farm-base.sol";

contract StrategyDpxWethDpx is StrategyDpxFarmBase {
    // Token addresses
    address public weth_dpx_lp = 0x0C1Cf6883efA1B496B01f654E247B9b419873054;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyDpxFarmBase(
            weth,
            dpx,
            weth_dpx_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyDpxWethDpx";
    }
}