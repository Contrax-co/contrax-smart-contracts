// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

contract ICoreStaking {
  function mint(address _validator) external payable;
  function redeem(uint256 stCore) external;
  function withdraw() external;
}
