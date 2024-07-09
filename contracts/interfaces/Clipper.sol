// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IClipper {
  /*
    packedTransmitAndDepositOneAsset: deposit a single asset in a calldata-efficient way
    Input arguments:
      packedInput: Amount and contract address of asset to deposit
      packedConfig: First 32 hexchars are poolTokens, next 24 are goodUntil, next 6 are nDays, final 2 are v
      r, s: Signature values
  */
  function packedTransmitAndDepositOneAsset(
    uint256 packedInput,
    uint256 packedConfig,
    bytes32 r,
    bytes32 s
  ) external payable;
}
