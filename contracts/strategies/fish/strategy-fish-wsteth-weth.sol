// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./fish-farm-bases/strategy-fish-farm-base.sol";

contract StrategyFishWstEthWeth is StrategyFishFarmBase {

    uint256 public fish_poolId = 2;

    // Token addresses
    address public fish_wsteth_weth_lp = 0xe263353986a4638144c41E44cEBAc9d0A76ECab3;
    address public wsteth = 0x5979D7b546E38E414F7E9822514be443A4800529; 

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyFishFarmBase(
            wsteth,
            weth,
            fish_poolId,
            fish_wsteth_weth_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyFishWstEthWeth";
    }
}