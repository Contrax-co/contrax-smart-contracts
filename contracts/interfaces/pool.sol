// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IPool {
  function deposit(uint256 amount) external payable; 
  function getBalance(address account) external view returns(uint256);
  function withdraw(uint256 currencyAmount) external;
}

interface IRewards {
  function getClaimableReward() external view returns(uint256);
  function collectReward() external;
}