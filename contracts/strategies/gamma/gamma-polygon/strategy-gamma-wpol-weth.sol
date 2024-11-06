// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.4;

// import "../strategy-gamma.sol";

// contract StrategyGammaWpolWeth is StrategyGamma {
//   // Token/ETH pool id in MasterChef contract
//   uint256 public wpol_weth_poolId = 0;
//   // Token addresses
//   address public gamma_weth_wpol_lp = 0x02203f2351E7aC6aB5051205172D3f772db7D814;

//   // address public weth = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;

//   constructor(
//     address _governance,
//     address _strategist,
//     address _controller,
//     address _timelock,
//     address _masterChef
//   )
//     StrategyGamma(wpol_weth_poolId, gamma_weth_wpol_lp, _governance, _strategist, _controller, _timelock, _masterChef)
//   {}

//   // **** Views ****

//   function getName() external pure override returns (string memory) {
//     return "StrategySushiWethDai";
//   }
// }
