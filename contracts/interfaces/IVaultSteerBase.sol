// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../lib/erc20.sol";

interface IVaultSteerBase is IERC20 {
  function steerVaultTokens() external view returns (address, address);

  function getTotalAmounts() external view returns (uint256, uint256);

  function deposit(uint256 amount0, uint256 amount1) external;

  function withdraw(uint256 _shares) external returns (uint256 amount0, uint256 amount1);
}
