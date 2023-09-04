// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./hop-farm-bases/strategy-hop-farm-base.sol";

contract StrategyHopMagic is StrategyHopFarmBase {
    // Token addresses
    address public hop_magic_lp = 0x163A9E12787dBFa2836caa549aE02ed67F73e7C2;
    address public magic = 0x539bdE0d7Dbd336b79148AA742883198BBF60342;
    address public hmagic = 0xB76e673EBC922b1E8f10303D0d513a9E710f5c4c;

    // Pool and staking addresses
    address public magic_pool = 0xFFe42d3Ba79Ee5Ee74a999CAd0c60EF1153F0b82;
    address public magic_rewards = 0x4e9840f3C1ff368a10731D15c11516b9Fe7E1898;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyHopFarmBase(
            magic_rewards,
            magic_pool,
            magic,
            hmagic,
            hop_magic_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyHopMagic";
    }
}