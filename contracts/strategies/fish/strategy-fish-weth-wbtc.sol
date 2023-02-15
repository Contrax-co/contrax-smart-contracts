// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./fish-farm-bases/strategy-fish-farm-base.sol";

contract StrategyFishWethWbtc is StrategyFishFarmBase {

    uint256 public fish_poolId = 3;

    // Token addresses
    address public fish_wbtc_weth_lp = 0xf7C6FFA90E8f240481234fb3fe9E8F60df74ED87;
    address public wbtc = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f; 

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyFishFarmBase(
            wbtc,
            weth,
            fish_poolId,
            fish_wbtc_weth_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyFishWethWbtc";
    }
}