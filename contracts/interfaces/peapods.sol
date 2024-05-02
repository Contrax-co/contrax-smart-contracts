// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IDecentralizedIndex {
  function bond(
    address _indexFund,
    address _token,
    uint256 _amount,
    uint256 _amountMintMin
  ) external;

  function unstakeAndRemoveLP(
    address _indexFund,
    uint256 _amountStakedTokens,
    uint256 _minLPTokens,
    uint256 _minPairedLpToken,
    uint256 _deadline
  ) external;

   function addLiquidityV2(
    uint256 _idxLPTokens,
    uint256 _pairedLPTokens,
    uint256 _slippage,
    uint256 _deadline
  ) external;
}

interface WeightedIndex {
  function balanceOf(address account) external view returns (uint256);

  function debond(
    uint256 amount,
    address[] memory token,
    uint8[] memory percentage
  ) external;
}

interface IStakingPoolToken {
  function balanceOf(address account) external view returns (uint256); 
  function claimReward(address _wallet) external; 
  function getUnpaid(
    address _token,
    address _wallet
  ) external view returns (uint256);

  function stake(address user, uint256 amount) external;
  function unstake(uint256 amount) external;
}

interface ITokenRewards {
   function getUnpaid(
    address _token,
    address _wallet
  ) external view returns (uint256);

  function claimReward(address wallet) external;
}