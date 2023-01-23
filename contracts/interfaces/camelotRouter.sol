// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface ICamelotRouter {
    function addLiquidity(
      address tokenA,
      address tokenB,
      uint amountADesired,
      uint amountBDesired,
      uint amountAMin,
      uint amountBMin,
      address to,
      uint deadline
  ) external returns (uint amountA, uint amountB, uint liquidity);
}

interface ICamelotPool {
  function createPosition(uint256 amount, uint256 lockDuration) external;

  function pendingRewards(uint256 tokenId) external view returns (uint256);

  function harvestPosition(uint256 tokenId) external;

  function withdrawFromPosition(uint256 tokenId, uint256 amountToWithdraw) external;

  function getStakingPosition(uint256 tokenId) external view returns (
    uint256 amount, uint256 amountWithMultiplier, uint256 startLockTime,
    uint256 lockDuration, uint256 lockMultiplier, uint256 rewardDebt,
    uint256 boostPoints, uint256 totalMultiplier
  );
}