// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../vault-steer-base.sol";

// Vault address for steer base WETH-cbBTC vault
// 0xD5A49507197c243895972782C01700ca27090Ee1

contract VaultSteerBaseWethcbBTC is VaultSteerBase {
  constructor(
    address _governance,
    address _timelock,
    address _controller
  ) VaultSteerBase(0xD5A49507197c243895972782C01700ca27090Ee1, _governance, _timelock, _controller) {}
}
