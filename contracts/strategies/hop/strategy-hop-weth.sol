// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./hop-farm-bases/strategy-hop-farm-base.sol";

contract StrategyHopWeth is StrategyHopFarmBase {
    // Token/ETH pool id in MasterChef contract
    uint256 public sushi_dai_poolId = 14;
    // Token addresses
    address public hop_weth_lp = 0x59745774Ed5EfF903e615F5A2282Cae03484985a;
    address public heth = 0xDa7c0de432a9346bB6e96aC74e3B61A36d8a77eB;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyHopFarmBase(
            weth,
            heth,
            sushi_dai_poolId,
            hop_weth_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyHopWeth";
    }
}