// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./vault-steer-base.sol";

// Vault address for steer sushi USDC-USDC.e pool
//0x5DbAD371890C3A89f634e377c1e8Df987F61fB64

contract VaultSteerSushiWethUsdc is VaultSteerBase {
  constructor(
    address _governance,
    address _timelock
  ) VaultSteerBase(0x5DbAD371890C3A89f634e377c1e8Df987F61fB64, _governance, _timelock) {}
}
