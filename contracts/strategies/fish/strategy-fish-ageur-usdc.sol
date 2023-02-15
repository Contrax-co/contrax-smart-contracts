// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./fish-farm-bases/strategy-fish-farm-base.sol";

contract StrategyFishAgEurUsdc is StrategyFishFarmBase {

    uint256 public fish_poolId = 23;

    // Token addresses
    address public fish_ageur_usdc_lp = 0x78d9B037Fb873AfCf4e3E466aDfAfa8A5258CdaD;
    address public ageur = 0xFA5Ed56A203466CbBC2430a43c66b9D8723528E7; 

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyFishFarmBase(
            ageur,
            usdc,
            fish_poolId,
            fish_ageur_usdc_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyFishAgEurUsdc";
    }
}