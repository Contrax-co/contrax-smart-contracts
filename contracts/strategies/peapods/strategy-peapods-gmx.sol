// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./peapods-farm-bases/peapods-base.sol";

contract StrategyPeapodsGmx is StrategyPeapodsFarmBase {

  address public gmx = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
  address public apGmx = 0x8CB10B11Fad33cfE4758Dc9977d74CE7D2fB4609;

  constructor(
    address _governance,
    address _strategist,
    address _controller,
    address _timelock
  )
  StrategyPeapodsFarmBase(
      apGmx,
      gmx,
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