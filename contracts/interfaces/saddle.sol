// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface ISaddleStaking {
  function deposit(uint256 _value, address _user, bool _claim_rewards) external; 

  function claimable_reward(address _user, address _reward_token) external view returns(uint256);

  function balanceOf(address) external view returns(uint256);

  function withdraw(uint256 _value, address _user, bool _claim_rewards) external;

  function claim_rewards(address _addr, address _receiver) external;

}