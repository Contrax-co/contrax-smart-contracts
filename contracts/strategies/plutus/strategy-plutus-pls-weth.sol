// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./plutus-farm-bases/strategy-plutus-lp-farm-base2.sol";

contract StrategyPlutusPlsWeth is StrategyPlutusFarmBase {
    address public pls_weth = 0x6CC0D643C7b8709F468f58F363d73Af6e4971515;
    uint256 pls_weth_poolId = 0; 

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategyPlutusFarmBase(
            pls_weth_poolId,
            pls_weth,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyPlutusPlsWeth";
    }
}