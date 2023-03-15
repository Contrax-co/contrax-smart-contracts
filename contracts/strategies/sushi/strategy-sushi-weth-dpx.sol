// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../sushi-farm-bases/strategy-sushi-farm-base.sol";

contract StrategySushiWethDpx is StrategySushiFarmBase {
    // Token/ETH pool id in MasterChef contract
    uint256 public sushi_weth_dpx_poolId = 17;
    // Token addresses
    address public sushi_weth_dpx_lp = 0x0C1Cf6883efA1B496B01f654E247B9b419873054;
    address public dpx = 0x6C2C06790b3E3E3c38e12Ee22F8183b37a13EE55;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategySushiFarmBase(
            weth,
            dpx,
            sushi_weth_dpx_poolId,
            sushi_weth_dpx_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategySushiWethDpx";
    }
}