// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "../interfaces/staking-rewards.sol";

contract CallerContractForHopStrategy {

  // address public dai_rewards = 0xd4D28588ac1D9EF272aa29d4424e3E2A03789D1E;
  // address public HopDaiStrategy = 0x5A1d499f30114aCde6c3636D1a4df0fD8037D9cd;
  // address public lpHopDai = 0x68f5d998F00bB2460511021741D098c05721d8fF;

  function unStakeAndDepoistToVault(address _stakingRewards, address _hopStrategy, address _lpHop, address _hopVault) external {

    uint256 balance = IStakingRewards(_stakingRewards).balanceOf(_hopStrategy);
    IStakingRewards(_stakingRewards).withdraw(balance);
    IERC20(_lpHop).safeTransfer(_hopVault, balance);
  }

}
