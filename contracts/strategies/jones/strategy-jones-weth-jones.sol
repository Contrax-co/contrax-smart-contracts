// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./jones-farm-bases/strategy-jones-farm-base.sol";

contract StrategyJonesWethJones is StrategyJonesFarmBase {
    address public weth_jones = 0xe8EE01aE5959D3231506FcDeF2d5F3E85987a39c;
    uint256 weth_jones_poolID = 1;


    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyJonesFarmBase(
          weth,
          jones,
          weth_jones_poolID,
          weth_jones,
          _governance,
          _strategist,
          _controller,
          _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyJonesWethJones";
    }
}