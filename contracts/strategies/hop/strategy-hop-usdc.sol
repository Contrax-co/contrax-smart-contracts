// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./hop-farm-bases/strategy-hop-farm-base.sol";

contract StrategyHopUsdc is StrategyHopFarmBase {
    // Token addresses
    address public hop_usdc_lp = 0xB67c014FA700E69681a673876eb8BAFAA36BFf71;
    address public usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public husdc = 0x0ce6c85cF43553DE10FC56cecA0aef6Ff0DD444d;

    // Pool and staking addresses
    address public usdc_pool = 0x10541b07d8Ad2647Dc6cD67abd4c03575dade261;
    address public usdc_rewards = 0xb0CabFE930642AD3E7DECdc741884d8C3F7EbC70;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyHopFarmBase(
            usdc_rewards,
            usdc_pool,
            usdc,
            husdc,
            hop_usdc_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyHopUsdc";
    }
}