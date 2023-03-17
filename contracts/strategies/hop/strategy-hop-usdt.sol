// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./hop-farm-bases/strategy-hop-farm-base.sol";

contract StrategyHopUsdt is StrategyHopFarmBase {
    // Token addresses
    address public hop_usdt_lp = 0xCe3B19D820CB8B9ae370E423B0a329c4314335fE;
    address public usdt = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address public husdt = 0x12e59C59D282D2C00f3166915BED6DC2F5e2B5C7;

    // Pool and staking addresses
    address public usdt_pool = 0x18f7402B673Ba6Fb5EA4B95768aABb8aaD7ef18a;
    address public usdt_rewards = 0x9Dd8685463285aD5a94D2c128bda3c5e8a6173c8;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyHopFarmBase(
            usdt_rewards,
            usdt_pool,
            usdt,
            husdt,
            hop_usdt_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyHopUsdt";
    }
}