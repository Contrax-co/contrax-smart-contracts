 // SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IRewardRouterV2 {
    function stakeGmx(uint256 _amount) external; 
    function handleRewards(
        bool _shouldClaimGmx,
        bool _shouldStakeGmx,
        bool _shouldClaimEsGmx,
        bool _shouldStakeEsGmx,
        bool _shouldStakeMultiplierPoints,
        bool _shouldClaimWeth,
        bool _shouldConvertWethToEth
    ) external; 

    function unstakeGmx(uint256 _amount) external;

}

interface IRewardTracker {
    function stakedAmounts(address) external view returns (uint256);
    function claimable(address _account) external view returns (uint256);
}