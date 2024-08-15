// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../vault-steer-base.sol";

// Vault address for steer sushi USDC-USDC.e pool
//0x3eE813a6fCa2AaCAF0b7C72428fC5BC031B9BD65

contract VaultSteerSushiUsdcUsdce is VaultSteerBase {
  constructor(
    address _governance,
    address _timelock,
    address _controller
  ) VaultSteerBase(0x3eE813a6fCa2AaCAF0b7C72428fC5BC031B9BD65, _governance, _timelock, _controller) {}
}
