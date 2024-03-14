// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import "../../interfaces/savvy.sol";
import "../../lib/TokenUtils.sol";
import "../../lib/Checker.sol";
import "../../interfaces/vault.sol";
import "../../base/Errors.sol";


contract ContraxSavvyAdapter is ITokenAdapter, Initializable, Ownable2StepUpgradeable {
  string public constant override version = "1.0.0";

  /// @notice Only SavvyPositionManager can call functions.
  mapping(address => bool) private isAllowlisted;

  address public override token;
  address public override baseToken;

  uint256 private baseTokenDecimals;

  modifier onlyPositionManager {
    require (isAllowlisted[msg.sender], "Only Position Manager");
    _;
  }

  function initialize(
      address _token, 
      address _baseToken
  ) public initializer {
      Checker.checkArgument(_token != address(0), "wrong token");
      token = _token;
      baseToken = _baseToken;
      baseTokenDecimals = TokenUtils.expectDecimals(token);
      __Ownable2Step_init();
  }

  /// @inheritdoc ITokenAdapter
  function addAllowlist(address[] memory allowlistAddresses, bool status) external onlyOwner override {
      require (allowlistAddresses.length > 0, "invalid length");
      for (uint256 i = 0; i < allowlistAddresses.length; i ++) {
          isAllowlisted[allowlistAddresses[i]] = status;
      }
  }

  /// @inheritdoc ITokenAdapter
  function wrap(uint256 amount, address recipient) external onlyPositionManager override returns (uint256) {
    amount = TokenUtils.safeTransferFrom(baseToken, msg.sender, address(this), amount);
    TokenUtils.safeApprove(baseToken, token, amount);

    return _deposit(amount, recipient);
  }

  function unwrap(uint256 amount, address recipient) external onlyPositionManager override returns (uint256) {
    amount = TokenUtils.safeTransferFrom(token, msg.sender, address(this), amount);
    uint256 balanceBefore = TokenUtils.safeBalanceOf(token, address(this));

    uint256 amountWithdrawn = _withdraw(amount, recipient);
    uint256 balanceAfter = TokenUtils.safeBalanceOf(token, address(this));

    Checker.checkState(balanceBefore - balanceAfter == amount, "unwrap failed");

    return amountWithdrawn;
  }

  function _deposit(uint256 amount, address recipient) internal returns (uint256) {
    uint256 balanceBefore = IERC20(token).balanceOf(address(this));
    IVault(token).deposit(amount);
    uint256 balanceAfter = IERC20(token).balanceOf(address(this));
    uint256 receivedVaultTokens = balanceAfter - balanceBefore;
    TokenUtils.safeTransfer(token, recipient, receivedVaultTokens);

    return receivedVaultTokens;
  }

  function _withdraw(uint256 amount, address recipient) internal returns (uint256) {
    uint256 balanceBefore = IERC20(baseToken).balanceOf(address(this));
    IVault(token).withdraw(amount);
    uint256 balanceAfter = IERC20(baseToken).balanceOf(address(this));
    uint256 receivedBaseTokens = balanceAfter - balanceBefore;
    TokenUtils.safeTransfer(baseToken, recipient, receivedBaseTokens);

    return receivedBaseTokens;
  }



}