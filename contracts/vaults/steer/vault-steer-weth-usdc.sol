// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./vault-steer-base.sol";

// Vault address for steer sushi WETH-USDC pool
// 0x01476fcCa94502267008119B83Cea234dc3fA7D7

contract VaultSteerSushiWethUsdc is VaultSteerBase {
  constructor(
    address _governance,
    address _timelock
  ) VaultSteerBase(0x01476fcCa94502267008119B83Cea234dc3fA7D7, _governance, _timelock) {}
}
