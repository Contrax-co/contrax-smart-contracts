// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../sushi-farm-bases/strategy-sushi-farm-base.sol";

contract StrategySushiAxlUsdcUsdc is StrategySushiFarmBase {
    uint256 public sushi_axlusdc_usdc_poolId = 16;

    address public sushi_axlusdc_usdc_lp = 0x863EeD6056918258626b653065588105C54FF2AC;

    address public axlusdc = 0xEB466342C4d449BC9f53A865D5Cb90586f405215;
    address public usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategySushiFarmBase(
            usdc,
            axlusdc,
            sushi_axlusdc_usdc_poolId,
            sushi_axlusdc_usdc_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategySushiAxlUsdcUsdc ";
    }
}