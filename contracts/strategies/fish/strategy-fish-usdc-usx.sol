// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./fish-farm-bases/strategy-fish-farm-base.sol";

contract StrategyFishUsdcUsx is StrategyFishFarmBase {

    uint256 public fish_poolId = 22;

    // Token addresses
    address public fish_usdc_usx_lp = 0x53001d6FaA0B6be4f1F27e0272EAb3A35090E6d0;
    address public usx = 0x641441c631e2F909700d2f41FD87F0aA6A6b4EDb; 

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyFishFarmBase(
            usx,
            usdc,
            fish_poolId,
            fish_usdc_usx_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyFishUsdcUsx";
    }
}