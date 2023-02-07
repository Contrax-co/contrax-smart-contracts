// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./woo-farm-bases/strategy-woo-farm-base.sol";

contract StrategyWooWeth is StrategyWooFarmBase {

    address public weWeth = 0xba452bCc4BC52AF2fe1190e7e1dBE267ad1C2d08;

    uint256 public weth_poolId = 2;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyWooFarmBase(
            weth_poolId,
            weWeth,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyWooWeth";
    }
}