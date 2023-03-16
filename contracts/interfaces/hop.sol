// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IHopStakingRewards {
  function balanceOf(address account) external view returns (uint256);

  function earned(address account) external view returns (uint256);

  function stake(uint256 amount) external; 

  function getReward() external;

  function withdraw(uint256 amount) external;

}

interface IHopSwap {
  function swap(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline) external returns (uint256);

  function addLiquidity(uint256[] calldata amounts, uint256 minToMint, uint256 deadline) external returns (uint256);
}