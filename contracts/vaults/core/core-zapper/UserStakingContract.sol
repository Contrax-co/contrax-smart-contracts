// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../interfaces/ICoreStaking.sol";
import "../../../lib/erc20.sol";
import "hardhat/console.sol";

contract UserStakingContract {
  using SafeERC20 for IERC20;
  address public zapper;
  address public user;
  address public constant CORE_STAKING = 0xf5fA1728bABc3f8D2a617397faC2696c958C3409;
  address public constant CORE_VALIDATOR = 0x1c151923Cf6C381C4aF6C3071a2773B3cDBBf704;

  constructor(address _zapper, address _user) {
    zapper = _zapper;
    user = _user;
  }

  modifier onlyZapperOrUser() {
    require(msg.sender == zapper || msg.sender == user, "Only zapper or user can call this function");
    _;
  }

  function redeem(uint256 _amount) external onlyZapperOrUser {
    ICoreStaking(CORE_STAKING).redeem(_amount);
  }

  function withdraw() external onlyZapperOrUser {
    ICoreStaking(CORE_STAKING).withdraw();
    // send core(eth) to zapper
    (bool sent, ) = payable(msg.sender).call{value: address(this).balance}("");
    require(sent, "Failed to send Ether");
  }

  receive() external payable {}
}
