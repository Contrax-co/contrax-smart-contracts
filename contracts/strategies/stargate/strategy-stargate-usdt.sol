// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./stargate-farm-bases/strategy-stargate-farm-base.sol";

contract StrategyStargateUsdt is StrategyStargateFarmBase {
    address public usdt = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    uint256 public usdtId = 2; 


    address public usdt_lp = 0xB6CfcF89a7B22988bfC96632aC2A9D6daB60d641;
    uint256 public usdtlp_Id = 1;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyStargateFarmBase(
          usdtlp_Id,
          usdtId, 
          usdt,
          usdt_lp,
          _governance,
          _strategist,
          _controller,
          _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyStargateUsdt";
    }
}