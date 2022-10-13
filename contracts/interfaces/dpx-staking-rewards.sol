 // SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IStakingRewardsV3{ 
    function claim() external;
    function unstake(uint256 amount) external; 
    function balanceOf(address account) external view returns (uint256);
    function earned(address account) external view returns (uint256 tokensEarned);
    function stake(uint256 amount) external;
}