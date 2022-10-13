// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../sushi-farm-bases/strategy-sushi-farm-base.sol";

contract StrategySushiWethDai is StrategySushiFarmBase {
    // Token/ETH pool id in MasterChef contract
    uint256 public sushi_dai_poolId = 14;
    // Token addresses
    address public sushi_weth_dai_lp = 0x692a0B300366D1042679397e40f3d2cb4b8F7D30;
    address public dai = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategySushiFarmBase(
            weth,
            dai,
            sushi_dai_poolId,
            sushi_weth_dai_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategySushiWethDai";
    }
}