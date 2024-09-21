// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../vault-steer-base.sol";

// Vault address for steer sushi WETH-USDBC pool
// 0x571A582064a07E0FA1d62Cb1cE4d1B7fcf9095d3

contract VaultSteerSushiWethUsdbc is VaultSteerBase {
  constructor(
    address _governance,
    address _timelock,
    address _controller
  ) VaultSteerBase(0x571A582064a07E0FA1d62Cb1cE4d1B7fcf9095d3, _governance, _timelock, _controller) {}
}
