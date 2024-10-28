// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./peapods-farm-bases/peapods-farm-lp-base.sol";

contract StrategyPeapodsPeasOhm is StrategyPeapodsLPFarmBase{

  address public ohm = 0xf0cb2dc0db5e6c66B9a70Ac27B06b878da017028;

  address public apOhm = 0xEb1A8f8Ea373536600082BA9aE2DB97327513F7d;
  address public apPeas = 0x6a02F704890F507f13d002F2785ca7Ba5BFcc8F7;

  address public peas_ohm = 0x04d30065D2E6B1D83A163076935aefdA4599c586;
  address public staked_peas = 0x6B0BB4d3a2B86150CeE5B4E071EDEf65918deA33;
  
  address public reward = 0x93f186AC7D0E76A26Cc2de93Bb282F548C284FD5;

  constructor(
    address _governance,
    address _strategist,
    address _controller,
    address _timelock
  )
  StrategyPeapodsLPFarmBase(
      reward,
      staked_peas,
      peas,
      ohm,
      apPeas,
      apOhm,
      peas_ohm,
      _governance,
      _strategist,
      _controller,
      _timelock
  )
  {}

  function getName() external override pure returns (string memory) {
      return "StrategyPeapodsPeasOhm";
  }

}