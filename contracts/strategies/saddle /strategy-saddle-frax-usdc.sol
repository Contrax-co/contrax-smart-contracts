// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./saddle-farm-bases/strategy-saddle-farm-base.sol";

contract StrategySaddleFraxUsdc is StrategySaddleFarmBase {
    
    // Token addresses
    address public saddle_frax_usdc_lp = 0x896935B02D3cBEb152192774e4F1991bb1D2ED3f;
    address public frax = 0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F;
    address public usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategySaddleFarmBase(
            usdc,
            frax,
            saddle_frax_usdc_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategySaddleFraxUsdc";
    }
}