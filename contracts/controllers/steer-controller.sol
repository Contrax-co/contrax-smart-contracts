// https://github.com/iearn-finance/vaults/blob/master/contracts/controllers/StrategyControllerV1.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
pragma experimental ABIEncoderV2;

import "../interfaces/controller.sol";

import "../lib/erc20.sol";
import "../lib/safe-math.sol";

import "../interfaces/vault.sol";
import "../interfaces/vault-converter.sol";
import "../interfaces/onesplit.sol";
import "../interfaces/strategy.sol";
import "../interfaces/converter.sol";

contract SteerController {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  address public constant burn = 0x000000000000000000000000000000000000dEaD;

  address public governance;
  address public strategist;
  address public devfund;
  address public treasury;
  address public timelock;

  mapping(address => address) public vaults; // takes lp address and returns associated vault
  mapping(address => address) public strategies; // takes lp and returns associated strategy
  mapping(address => mapping(address => address)) public converters;
  mapping(address => mapping(address => bool)) public approvedStrategies;
  mapping(address => bool) public approvedVaultConverters;

  modifier onlyGovernance() {
    require(msg.sender == strategist || msg.sender == governance, "!strategist");
    _;
  }

  constructor(address _governance, address _strategist, address _timelock, address _devfund, address _treasury) {
    require(_governance != address(0));
    require(_strategist != address(0));
    require(_devfund != address(0));
    require(_treasury != address(0));
    require(_timelock != address(0));

    governance = _governance;
    strategist = _strategist;
    timelock = _timelock;
    devfund = _devfund;
    treasury = _treasury;
  }

  function setDevFund(address _devfund) public onlyGovernance {
    devfund = _devfund;
  }

  function setTreasury(address _treasury) public onlyGovernance {
    treasury = _treasury;
  }

  function setStrategist(address _strategist) public onlyGovernance {
    strategist = _strategist;
  }

  function setGovernance(address _governance) public onlyGovernance {
    governance = _governance;
  }

  function setTimelock(address _timelock) public onlyGovernance {
    require(msg.sender == timelock, "!timelock");
    timelock = _timelock;
  }

  function setVault(address _token, address _vault) public onlyGovernance {
    require(vaults[_token] == address(0), "vault");
    vaults[_token] = _vault;
  }

  function approveVaultConverter(address _converter) public onlyGovernance {
    approvedVaultConverters[_converter] = true;
  }

  function revokeVaultConverter(address _converter) public onlyGovernance {
    approvedVaultConverters[_converter] = false;
  }

  function approveStrategy(address _token, address _strategy) public {
    require(msg.sender == timelock, "!timelock");
    approvedStrategies[_token][_strategy] = true;
  }

  function revokeStrategy(address _token, address _strategy) public onlyGovernance {
    require(strategies[_token] != _strategy, "cannot revoke active strategy");
    approvedStrategies[_token][_strategy] = false;
  }

  function setStrategy(address _token, address _strategy) public onlyGovernance {
    require(approvedStrategies[_token][_strategy], "!approved");

    address _current = strategies[_token];
    if (_current != address(0)) {
      IStrategy(_current).withdrawAll();
    }
    strategies[_token] = _strategy;
  }

  function balanceOf(address _token) external view returns (uint256) {
    return IStrategy(strategies[_token]).balanceOf();
  }

  function earn(address _token, uint256 _amount) public {
    address _strategy = strategies[_token];
    require(_strategy != address(0), "invalid strategy");
    IERC20(_token).safeTransfer(_strategy, _amount);
  }

  function withdrawAll(address _token) public {
    IStrategy(strategies[_token]).withdrawAll();
  }

  function inCaseTokensGetStuck(address _token, uint256 _amount) public onlyGovernance {
    IERC20(_token).safeTransfer(msg.sender, _amount);
  }

  function inCaseStrategyTokenGetStuck(address _strategy, address _token) public onlyGovernance {
    IStrategy(_strategy).withdraw(_token);
  }

  function withdraw(address _token, uint256 _amount) public {
    require(msg.sender == vaults[_token], "!vault");
    IStrategy(strategies[_token]).withdraw(_amount);
  }
}
