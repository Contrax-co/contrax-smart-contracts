// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./liquid-farm-bases/strategy-liquid-farm-base.sol";

contract StrategyLiquidLqdEthEth is StrategyLiquidFarmBase {
    uint256 public lqeth_eth_poolId = 0;
    // Token addresses
    address public lqeth_eth_lp = 0xB6a0ad0f714352830467725e619ea23E2C488f37;

    address public lqeth = 0x73700aeCfC4621E112304B6eDC5BA9e36D7743D3;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyLiquidFarmBase(
            lqeth_eth_poolId,
            lqeth,
            weth,
            lqeth_eth_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyLiquidLqEthEth";
    }
}