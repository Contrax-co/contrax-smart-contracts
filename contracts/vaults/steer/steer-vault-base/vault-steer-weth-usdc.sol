// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../vault-steer-base.sol";

// Vault address for steer sushi WETH-cbBTC vault
// 0xd5a49507197c243895972782c01700ca27090ee1

contract VaultSteerBaseWethcbBTC is VaultSteerBase {
  constructor(
    address _governance,
    address _timelock,
    address _controller
  ) VaultSteerBase(0xd5a49507197c243895972782c01700ca27090ee1, _governance, _timelock, _controller) {}
}
