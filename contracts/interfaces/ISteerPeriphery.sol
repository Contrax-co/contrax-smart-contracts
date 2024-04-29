// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IMultiPositionManager.sol";

interface ISteerPeriphery is IMultiPositionManager {
  /**
    @param _vaultAddress	address	The address of the vault to deposit to
    @param amount0Desired	uint256	Max amount of token0 to deposit
    @param amount1Desired	uint256	Max amount of token1 to deposit
    @param amount0Min	    uint256	Revert if resulting amount0 is less than this
    @param amount1Min	    uint256	Revert if resulting amount1 is less than this
    @param to	            address	Recipient of shares
    */

  function deposit(
    address _vaultAddress,
    uint256 amount0Desired,
    uint256 amount1Desired,
    uint256 amount0Min,
    uint256 amount1Min,
    address to
  ) external;

  
  function vaultDetailsByAddress(address vault) external view returns (struct IMultiPositionManager.VaultDetails details)
}
