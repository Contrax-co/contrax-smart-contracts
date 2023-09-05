// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./hop-farm-bases/strategy-hop-farm-base.sol";

contract StrategyHoprEth is StrategyHopFarmBase {
    // Token addresses
    address public hop_reth_lp = 0xbBA837dFFB3eCf4638D200F11B8c691eA641AdCb;
    address public reth = 0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8;
    address public hreth = 0x588Bae9C85a605a7F14E551d144279984469423B;

    // Pool and staking addresses
    address public reth_pool = 0x0Ded0d521AC7B0d312871D18EA4FDE79f03Ee7CA;
    address public reth_rewards = 0x3D4cAD734B464Ed6EdCF6254C2A3e5fA5D449b32;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyHopFarmBase(
            reth_rewards,
            reth_pool,
            reth,
            hreth,
            hop_reth_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyHoprEth";
    }
}