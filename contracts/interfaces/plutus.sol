// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IDpxDepositor {
  function deposit(uint256 _amount) external;
}


interface IPlsDpxChef {
  function userInfo(address) external view returns (
    uint96 amount,
    int128 plsRewardDebt,
    int128 plsDpxRewardDebt,
    int128 plsJonesRewardDebt,
    int128 dpxRewardDebt
  );

  function deposit(uint96 _amount) external;

  function withdraw(uint96 _amount) external;

  function harvest() external;

  function pendingRewards(address _user)
    external
    view
    returns (
      uint256 _pendingPls,
      uint256 _pendingPlsDpx,
      uint256 _pendingPlsJones,
      uint256 _pendingDpx
    );

  
}

interface IPlutusChef {
  function userInfo(address) external view returns (
    uint96 amount,
    int128 plsRewardDebt
  );

  function pendingRewards(address _user) external view returns (uint256 _pendingPls);

  function deposit(uint96 _amount) external;

  function harvest() external;

  function withdraw(uint96 _amount) external;
}

interface IPlutusMasterChef {
  function deposit(uint256 _pid, uint256 _amount) external;

  function userInfo(uint256, address) external view returns (
    uint256 amount, 
    uint256 rewardDebt
  );

  function pendingPls(uint256 _pid, address _user) external view returns (uint256);

  function withdraw(uint256 _pid, uint256 _amount) external; 

}