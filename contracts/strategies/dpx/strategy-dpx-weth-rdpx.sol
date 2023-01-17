// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./dpx-farm-bases/strategy-rdpx-farm-base.sol";

contract StrategyDpxWethRdpx is StrategyRdpxFarmBase {
    // Token addresses
    address public weth_rdpx_lp = 0x7418F5A2621E13c05d1EFBd71ec922070794b90a;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyRdpxFarmBase(
            weth,
            rdpx,
            weth_rdpx_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyDpxWethRdpx";
    }
}