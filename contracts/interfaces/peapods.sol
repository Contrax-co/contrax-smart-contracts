// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IDecentralizedIndex {
  function bond(
    address _indexFund,
    address _token,
    uint256 _amount,
    uint256 _amountMintMin
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