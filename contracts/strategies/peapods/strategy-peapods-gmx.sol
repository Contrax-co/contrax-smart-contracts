// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./peapods-farm-bases/peapods-farm-base.sol";

contract StrategyPeapodsGmx is StrategyPeapodsFarmBase {

  address public apGmx = 0x8CB10B11Fad33cfE4758Dc9977d74CE7D2fB4609;

  constructor(
    address _governance,
    address _strategist,
    address _controller,
    address _timelock
  )
  StrategyPeapodsFarmBase(
      apGmx,
      _governance,
      _strategist,
      _controller,
      _timelock
  )
  {}

  function getName() external override pure returns (string memory) {
      return "StrategyPeapodsGmx";
  }

}