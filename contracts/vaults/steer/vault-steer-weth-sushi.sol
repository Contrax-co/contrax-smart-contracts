// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./vault-steer-base.sol";

// Vault address for steer sushi WETH-Sushi pool
// 0x6723b8E1B28E924857C02F96f7B23041758AfA98

contract VaultSteerSushiWethSushi is VaultSteerBase {
  constructor(
    address _governance,
    address _timelock
  ) VaultSteerBase(0x6723b8E1B28E924857C02F96f7B23041758AfA98, _governance, _timelock) {}
}
