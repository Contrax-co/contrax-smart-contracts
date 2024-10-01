// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../vault-steer-base.sol";

// Vault address for steer sushi WETH-SNSY vault
// 0x3C88c76783a9f2975C6d58F2aa1437f1E8229335

contract VaultSteerSushiWethSnsy is VaultSteerBase {
  constructor(
    address _governance,
    address _timelock,
    address _controller
  ) VaultSteerBase(0x3C88c76783a9f2975C6d58F2aa1437f1E8229335, _governance, _timelock, _controller) {}
}