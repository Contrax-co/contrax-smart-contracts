// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./peapods-farm-bases/peapods-farm-base.sol";

contract StrategyPeapodsPeas is StrategyPeapodsFarmBase {

  address public apPeas = 0x6a02F704890F507f13d002F2785ca7Ba5BFcc8F7;

  constructor(
    address _governance,
    address _strategist,
    address _controller,
    address _timelock
  )
  StrategyPeapodsFarmBase(
      apPeas,
      _governance,
      _strategist,
      _controller,
      _timelock
  )
  {}

  function getName() external override pure returns (string memory) {
      return "StrategyPeapodsPeas";
  }

}