// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IMasterChef {
  function userInfo(uint256, address) external view returns(uint256 amount, uint256 rewardDebt);

  function deposit(uint256 _pid, uint256 _amount) external;

  function pendingCake(uint256 _pid, address _user) external view returns (uint256);

  function withdraw(uint256 _pid, uint256 _amount) external;
}