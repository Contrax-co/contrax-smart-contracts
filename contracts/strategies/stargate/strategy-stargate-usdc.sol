// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./stargate-farm-bases/strategy-stargate-farm-base.sol";

contract StrategyStargateUsdc is StrategyStargateFarmBase {

    uint256 _usdcId = 1;
    uint256 _usdclpId = 0;

    address public usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public usdc_lp = 0x892785f33CdeE22A30AEF750F285E18c18040c3e;
    


    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyStargateFarmBase(
          _usdclpId,
          _usdcId,
          usdc,
          usdc_lp,
          _governance,
          _strategist,
          _controller,
          _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyStargateUsdc";
    }
}