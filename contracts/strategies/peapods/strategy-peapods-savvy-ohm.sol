// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./peapods-farm-bases/peapods-farm-lp-base.sol";

contract StrategyPeapodsSavvyOhm is StrategyPeapodsLPFarmBase{

  address public ohm = 0xf0cb2dc0db5e6c66B9a70Ac27B06b878da017028;
  address public savvy = 0x43aB8f7d2A8Dd4102cCEA6b438F6d747b1B9F034;

  address public apOhm = 0xEb1A8f8Ea373536600082BA9aE2DB97327513F7d;
  address public apSavvy = 0x28656c22D22C82C4869578672D05E48F0cB7D611;

  address public savvy_ohm = 0x6F03F5019F2e48dD0853903b35e39CEe8f215b82;
  address public staked_savvy = 0xf88968a6Dc363D3DC2a552FBf10C51f6d61AE9dA;

  address public reward = 0x39b3ab609D58A183e639266Dd33b2Cb397ED99e3;

  constructor(
    address _governance,
    address _strategist,
    address _controller,
    address _timelock
  )
  StrategyPeapodsLPFarmBase(
      reward,
      staked_savvy,
      savvy,
      ohm,
      apSavvy,
      apOhm,
      savvy_ohm,
      _governance,
      _strategist,
      _controller,
      _timelock
  )
  {}

  function getName() external override pure returns (string memory) {
      return "StrategyPeapodsSavvyOhm";
  }

}