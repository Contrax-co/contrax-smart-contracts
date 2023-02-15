// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./fish-farm-bases/strategy-fish-farm-base.sol";

contract StrategyFishTusdUsdc is StrategyFishFarmBase {

    uint256 public fish_poolId = 35;

    // Token addresses
    address public fish_tusd_usdc_lp = 0xFc0F4F60F6BcF32a6c5847C2dc1E590e39A45993;
    address public tusd = 0x4D15a3A2286D883AF0AA1B3f21367843FAc63E07; 

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyFishFarmBase(
            tusd,
            usdc,
            fish_poolId,
            fish_tusd_usdc_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyFishTusdUsdc";
    }
}