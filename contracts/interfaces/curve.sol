// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface ICurve {
  function balanceOf(address) external view returns (uint256);
  function deposit(uint256 _value, address _user, bool _claim_rewards) external;
}