// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../sushi-farm-bases/strategy-sushi-farm-base.sol";

contract StrategySushiWethUsdt is StrategySushiFarmBase {
    uint256 public sushi_weth_usdt_poolId = 4;
    // Token addresses
    address public sushi_weth_usdt_lp = 0xCB0E5bFa72bBb4d16AB5aA0c60601c438F04b4ad;
    address public usdt = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategySushiFarmBase(
            weth,
            usdt,
            sushi_weth_usdt_poolId,
            sushi_weth_usdt_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategySushiWethUsdt";
    }
}