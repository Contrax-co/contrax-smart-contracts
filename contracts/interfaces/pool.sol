// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IPool {
  function deposit(uint256 amount) external; 
  function getBalance(address account) external view returns(uint256);
  function withdraw(uint256 currencyAmount) external;
  function getCurrencyBalance(address account) external view returns(uint256);
}

interface IRewards {
  function getClaimableReward() external view returns(uint256);
  function collectReward() external;
  function updateRewards(address account) external;
}

interface ICapRewards {
  function getClaimableReward() external view returns(uint256);
  function collectReward() external;
  function updateRewards(address account) external;
}