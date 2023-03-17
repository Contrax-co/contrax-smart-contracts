// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./hop-farm-bases/strategy-hop-farm-base.sol";

contract StrategyHopWeth is StrategyHopFarmBase {
    // Token addresses
    address public hop_weth_lp = 0x59745774Ed5EfF903e615F5A2282Cae03484985a;
    address public heth = 0xDa7c0de432a9346bB6e96aC74e3B61A36d8a77eB;

    // Pool and staking addresses
    address public weth_pool = 0x652d27c0F72771Ce5C76fd400edD61B406Ac6D97;
    address public wethRewards = 0x755569159598f3702bdD7DFF6233A317C156d3Dd;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyHopFarmBase(
            wethRewards,
            weth_pool,
            weth,
            heth,
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