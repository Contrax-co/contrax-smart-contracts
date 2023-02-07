// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IMasterChefWoo {
  function deposit(uint256 _pid, uint256 _amount) external;

  function pendingXWoo(uint256 _pid, address _user)
    external
    view
    returns (uint256 pendingXWooAmount, uint256 pendingWooAmount);

  function userInfo(uint256, address) external view returns(uint256 amount, uint256 rewardDebt); 

  function harvest(uint256 _pid) external;

  function withdraw(uint256 _pid, uint256 _amount) external;
}