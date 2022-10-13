// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../sushi-farm-bases/strategy-sushi-farm-base.sol";

contract StrategySushiWethWbtc is StrategySushiFarmBase {
    // Token/ETH pool id in MasterChef contract
    uint256 public sushi_weth_wbtc_poolId = 3;
    // Token addresses
    address public sushi_weth_wbtc_lp = 0x515e252b2b5c22b4b2b6Df66c2eBeeA871AA4d69;
    address public wbtc = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategySushiFarmBase(
            weth,
            wbtc,
            sushi_weth_wbtc_poolId,
            sushi_weth_wbtc_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategySushiWethWbtc";
    }
}