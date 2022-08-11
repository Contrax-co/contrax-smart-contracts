// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../strategy-sushi-farm-base.sol";

contract StrategySushiWethUsdc is StrategySushiFarmBase {
    uint256 public sushi_weth_usdc_poolId = 0;
    // Token addresses
    address public sushi_weth_usdc_lp = 0x905dfCD5649217c42684f23958568e533C711Aa3;
    address public usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategySushiFarmBase(
            weth,
            usdc,
            sushi_weth_usdc_poolId,
            sushi_weth_usdc_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategySushiWethUsdc";
    }
}