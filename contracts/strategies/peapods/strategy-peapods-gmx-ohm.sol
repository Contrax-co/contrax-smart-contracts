// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./peapods-farm-bases/peapods-farm-lp-base.sol";

contract StrategyPeapodsGmxOhm is StrategyPeapodsLPFarmBase{

  address public ohm = 0xf0cb2dc0db5e6c66B9a70Ac27B06b878da017028;
  address public gmx = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;

  address public apOhm = 0xEb1A8f8Ea373536600082BA9aE2DB97327513F7d;
  address public apGmx = 0x8CB10B11Fad33cfE4758Dc9977d74CE7D2fB4609;

  address public gmx_ohm = 0x91aDF4a1A94A1a9E8a9d4b5B53DD7D8EFF816892;
  address public staked_gmx = 0xbF2E9d6B3c2d60E31D31fa52E67dF26bA7ca701c;

  address public reward = 0x5841b48419DB90E2179d28f4D4e1601DF8009691;
  

  constructor(
    address _governance,
    address _strategist,
    address _controller,
    address _timelock
  )
  StrategyPeapodsLPFarmBase(
      reward,
      staked_gmx,
      gmx,
      ohm,
      apGmx,
      apOhm,
      gmx_ohm,
      _governance,
      _strategist,
      _controller,
      _timelock
  )
  {}

  function getName() external override pure returns (string memory) {
      return "StrategyPeapodsGmxOhm";
  }

}