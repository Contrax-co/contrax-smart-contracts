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

  function getTokenBalance(uint8 index) external view returns (uint256);

  function getToken(uint8 index) external view returns (address);

  function removeLiquidity(
        uint256 amount,
        uint256[] calldata minAmounts,
        uint256 deadline
  ) external returns (uint256[] memory);

  function calculateSwap(
      uint8 tokenIndexFrom,
      uint8 tokenIndexTo,
      uint256 dx
  ) external view returns (uint256);

  function calculateTokenAmount(
      address account,
      uint256[] calldata amounts,
      bool deposit
  ) external view returns (uint256); 
}

interface ILPToken {
  function swap() external view returns (address);

}