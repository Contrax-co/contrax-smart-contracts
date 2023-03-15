// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../sushi-farm-bases/strategy-sushi-farm-base.sol";

contract StrategySushiWethSushi is StrategySushiFarmBase {
    // Token/ETH pool id in MasterChef contract
    uint256 public sushi_weth_sushi_poolId = 2;
    // Token addresses
    address public sushi_weth_sushi_lp = 0x3221022e37029923aCe4235D812273C5A42C322d;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategySushiFarmBase(
            weth,
            sushi,
            sushi_weth_sushi_poolId,
            sushi_weth_sushi_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategySushiWethSushi";
    }
}