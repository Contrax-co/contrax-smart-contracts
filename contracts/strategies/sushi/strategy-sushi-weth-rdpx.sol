// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../sushi-farm-bases/strategy-sushi-farm-base.sol";

contract StrategySushiWethRdpx is StrategySushiFarmBase {
    // Token/ETH pool id in MasterChef contract
    uint256 public sushi_weth_rdpx_poolId = 23;
    // Token addresses
    address public sushi_weth_rdpx_lp = 0x7418F5A2621E13c05d1EFBd71ec922070794b90a;
    address public rdpx = 0x32Eb7902D4134bf98A28b963D26de779AF92A212;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategySushiFarmBase(
            weth,
            rdpx,
            sushi_weth_rdpx_poolId,
            sushi_weth_rdpx_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategySushiWethRdpx";
    }
}