// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

struct RewardData {
  address token;
  uint256 amount;
}

struct LockedBalance {
  uint256 amount;
  uint256 unlockTime;
}

interface IFastChef{
  function userInfo(uint256 _pid, address _user) external view returns (uint256, int256);

  function pendingReward(uint256 _pid, address _user) external view returns (uint256 pending);

  function deposit(
    uint256 pid,
    uint256 amount,
    address to
  ) external; 

  function withdraw(
    uint256 pid,
    uint256 amount,
    address to
  ) external;

  function harvest(uint256 pid, address to) external;

}

interface IFastStaking {
  function withdrawableBalance(address user) external view returns (uint256 amount, uint256 penaltyAmount);
  function withdraw(uint256 amount) external;

  function totalBalance(address user) external view returns (uint256 amount);

  function claimableRewards(address account) external view returns ( address token, uint256 amount); 

  function lockedBalances(address user)
    external
    view
    returns (
      uint256 total,
      uint256 unlockable,
      uint256 locked,
      LockedBalance[] memory lockData
  );

   function getReward() external;

}