// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../lib/erc20.sol";

interface IVaultForSteer is IERC20 {

    
    function steerVaultTokens() external view returns (address,address);

    function deposit(uint256) external;

    function withdraw(uint256) external returns (uint256, uint256); 

}
