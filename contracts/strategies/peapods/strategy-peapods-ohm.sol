// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./peapods-farm-bases/peapods-farm-base.sol";

contract StrategyPeapodsOhm is StrategyPeapodsFarmBase {

  address public apOhm = 0xEb1A8f8Ea373536600082BA9aE2DB97327513F7d;

  constructor(
    address _governance,
    address _strategist,
    address _controller,
    address _timelock
  )
  StrategyPeapodsFarmBase(
      apOhm,
      _governance,
      _strategist,
      _controller,
      _timelock
  )
  {}

  function getName() external override pure returns (string memory) {
      return "StrategyPeapodsOhm";
  }

}