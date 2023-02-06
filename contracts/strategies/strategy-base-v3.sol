// SPDX-License-Identifier: MIT	
pragma solidity 0.8.4;

import "../lib/erc20.sol";
import "../lib/safe-math.sol";

import "../interfaces/uniswapv2.sol";
import "../interfaces/staking-rewards.sol";
import "../interfaces/vault.sol";
import "../interfaces/controller.sol";

/**
 * The is the Strategy Base that implements the new UniswapV3 router
 */
abstract contract StrategyBaseV3 {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;


    // Dex
    address public uniRouterv3 = 0xE592427A0AEce92De3Edee1F18E0157C05861564; 

}