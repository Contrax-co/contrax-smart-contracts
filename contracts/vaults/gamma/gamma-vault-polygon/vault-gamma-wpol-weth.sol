// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../vault-gamma-base.sol";

// Vault address for Gamma quickswap wPol-wEth vault
//0x02203f2351E7aC6aB5051205172D3f772db7D814

contract VaultGammaWpolWeth is VaultGammaBase {
  constructor(
    address _governance,
    address _timelock,
    address _controller
  ) VaultGammaBase(0x02203f2351E7aC6aB5051205172D3f772db7D814, _governance, _timelock, _controller) {}
}
