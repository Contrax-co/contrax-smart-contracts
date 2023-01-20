// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IMilliner{
  function userInfo(uint256, address) external view returns (
    uint256 amount, 
    int256 rewardDebt
  );

  function pendingJones(uint256 _pid, address _user)
  external
  view
  returns (uint256);

  function deposit(uint256 _pid, uint256 _amount) external;

  function harvest(uint256 _pid) external;

  function withdraw(uint256 _pid, uint256 _amount) external;
}