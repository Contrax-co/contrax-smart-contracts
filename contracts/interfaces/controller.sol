// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IController {
    function vaults(address) external view returns (address);

    function rewards() external view returns (address);

    function devfund() external view returns (address);

    function treasury() external view returns (address);

    function balanceOf(address) external view returns (uint256);

    function withdraw(address, uint256) external;

    function earn(address, uint256) external;

    // For Big Green Button:

    function setVault(address _token, address _vault) external;

    function approveStrategy(address _token, address _strategy) external;

    function revokeStrategy(address _token, address _strategy) external;

    function setStrategy(address _token, address _strategy) external;

    function setStrategist(address _strategist) external;

    function setGovernance(address _governance) external;

    function setTimelock(address _timelock) external;
}