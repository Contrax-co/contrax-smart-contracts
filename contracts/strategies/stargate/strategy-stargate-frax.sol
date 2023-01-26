// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./stargate-farm-bases/strategy-stargate-farm-base.sol";

contract StrategyStargateFrax is StrategyStargateFarmBase {
    address public frax = 0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F;
    uint256 public fraxId = 7; 


    address public frax_lp = 0xaa4BF442F024820B2C28Cd0FD72b82c63e66F56C;
    uint256 public fraxlp_Id = 3;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyStargateFarmBase(
          fraxlp_Id,
          fraxId, 
          frax,
          frax_lp,
          _governance,
          _strategist,
          _controller,
          _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyStargateFrax";
    }
}