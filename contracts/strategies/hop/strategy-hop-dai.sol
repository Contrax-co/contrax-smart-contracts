// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./hop-farm-bases/strategy-hop-farm-base.sol";

contract StrategyHopDai is StrategyHopFarmBase {
    // Token addresses
    address public hop_dai_lp = 0x68f5d998F00bB2460511021741D098c05721d8fF;
    address public dai = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address public hdai = 0x46ae9BaB8CEA96610807a275EBD36f8e916b5C61;

    // Pool and staking addresses
    address public dai_pool = 0xa5A33aB9063395A90CCbEa2D86a62EcCf27B5742;
    address public dai_rewards = 0xd4D28588ac1D9EF272aa29d4424e3E2A03789D1E;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyHopFarmBase(
            dai_rewards,
            dai_pool,
            dai,
            hdai,
            hop_dai_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyHopDai";
    }
}