// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import "../../interfaces/savvy.sol";
import "../../interfaces/uniswapv2.sol";
import "../../lib/TokenUtils.sol";
import "../../lib/Checker.sol";
import "../../interfaces/vault.sol";
import "../../base/Errors.sol";

contract ContraxSavvyAdapterForSteer is ITokenAdapter, Initializable, Ownable2StepUpgradeable {
  string public constant override version = "1.0.0";

  /// @notice Only SavvyPositionManager can call functions.
  mapping(address => bool) private isAllowlisted;

  address public override token;
  address public override baseToken;

  //Steer
  address public steerPeriphery = 0x806c2240793b3738000fcb62C66BF462764B903F;
  address public steerVault = 0x3eE813a6fCa2AaCAF0b7C72428fC5BC031B9BD65;

  uint256 private baseTokenDecimals;

  modifier onlyPositionManager() {
    require(isAllowlisted[msg.sender], "Only Position Manager");
    _;
  }

  function initialize(address _token, address _baseToken) public initializer {
    Checker.checkArgument(_token != address(0), "wrong token");
    token = _token;
    baseToken = _baseToken;
    baseTokenDecimals = TokenUtils.expectDecimals(token);
    __Ownable2Step_init();
  }

  //Get vault token price in usdc
  function price() external view override returns (uint256) {
    return IVault(token).getRatio() * calculateLpPriceInUsdc();
  }

  /// @inheritdoc ITokenAdapter
  function addAllowlist(address[] memory allowlistAddresses, bool status) external override onlyOwner {
    require(allowlistAddresses.length > 0, "invalid length");
    for (uint256 i = 0; i < allowlistAddresses.length; i++) {
      isAllowlisted[allowlistAddresses[i]] = status;
    }
  }

  /// @inheritdoc ITokenAdapter
  function wrap(uint256 amount, address recipient) external override onlyPositionManager returns (uint256) {
    amount = TokenUtils.safeTransferFrom(baseToken, msg.sender, address(this), amount);
    TokenUtils.safeApprove(baseToken, token, amount);

    return _deposit(amount, recipient);
  }

  function unwrap(uint256 amount, address recipient) external override onlyPositionManager returns (uint256) {
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

  function getTokensFromLpToken(
    uint256 lpTokenAmount,
    uint256 lpTokenSupply,
    uint256 vaultToken1Balance,
    uint256 vaultToken2Balance
  ) public view returns (uint256 token0Val, uint256 token1Val) {
    token0Val = lpTokenSupply > 0 ? (lpTokenAmount * vaultToken0Balance) / lpTokenSupply : 0;
    token1Val = lpTokenSupply > 0 ? (lpTokenAmount * vaultToken1Balance) / lpTokenSupply : 0;
  }

  function calculateLpPriceInUsdc() public view returns (uint256) {
    ISteerPeriphery(steerPeriphery).VaultDetails memory details= ISteerPeriphery(steerPeriphery).vaultDetailsByAddress(steerVault);
    (uint256 token0Val, uint256 token1Val ) = getTokensFromLpToken(
        
    )
  }
  
}
