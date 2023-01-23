// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./camelot-farm-bases/strategy-camelot-farm-base.sol"; 

contract StrategyCamelotGmxUsdc is StrategyCamelotFarmBase {

    uint256 public gmxtokenId = 465;

    address public gmx_usdc = 0x913398d79438e8D709211cFC3DC8566F6C67e1A8;
    address public gmx = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
    address public usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyCamelotFarmBase(
            usdc,
            gmx,
            gmxtokenId,
            gmx_usdc,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyCamelotGmxUsdc";
    }
}