// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import "../../interfaces/savvy.sol";
import "../../lib/TokenUtils.sol";
import "../../lib/Checker.sol";
import "../../interfaces/vault.sol";
import "../../base/Errors.sol";
import "../../interfaces/ISteerPeriphery.sol";
import "../../Utils/PriceCalculator.sol";

contract ContraxSavvyAdapterForSteer is ITokenAdapter, Initializable, Ownable2StepUpgradeable {
  string public constant override version = "1.0.0";

  /// @notice Only SavvyPositionManager can call functions.
  mapping(address => bool) private isAllowlisted;

  address public override token;
  address public override baseToken;

  address public steerPeriphery = 0x806c2240793b3738000fcb62C66BF462764B903F;
  //Steer vault for USDC
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
    return calculateLpPriceInUsdc();
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

  // Helper function to adjust token amounts to a common decimal place
  function adjustForDecimals(uint256 amount, uint8 decimals) public pure returns (uint256) {
    if (decimals < 18) {
      return amount * 10 ** (18 - decimals);
    } else if (decimals > 18) {
      return amount / 10 ** (decimals - 18);
    }
    return amount;
  }

  function getTokensFromLpToken(
    uint256 lpTokenAmount,
    uint256 lpTokenSupply,
    uint256 vaultToken0Balance,
    uint256 vaultToken1Balance,
    uint8 token0Decimals,
    uint8 token1Decimals
  ) public pure returns (uint256 token0Val, uint256 token1Val) {
    uint256 adjustedToken0Balance = adjustForDecimals(vaultToken0Balance, token0Decimals);
    uint256 adjustedToken1Balance = adjustForDecimals(vaultToken1Balance, token1Decimals);

    token0Val = lpTokenSupply > 0 ? (lpTokenAmount * adjustedToken0Balance) / lpTokenSupply : 0;
    token1Val = lpTokenSupply > 0 ? (lpTokenAmount * adjustedToken1Balance) / lpTokenSupply : 0;
  }

  function calculateLpPriceInUsdc() public pure returns (uint256) {
    VaultDetails memory details = ISteerPeriphery(steerPeriphery).vaultDetailsByAddress(steerVault);

    (uint256 token0Val, uint256 token1Val) = getTokensFromLpToken(
      1, // Amount of LP tokens to calculate price for
      details.totalLPTokensIssued,
      details.token0Balance,
      details.token1Balance,
      details.token0Decimals,
      details.token1Decimals
    );
    // Not considering token0 and token1 price as both tokens are priced at 1 USDC
    return token0Val + token1Val;
  }

  function steerVaultTokens() public view override returns (address, address) {
    return (steerVault.token0(), steerVault.token1());
  }

  function TokenSpliterSteer(uint256 amount) internal returns (uint256 token0, uint256 token1) {
    (address token0, address token1) = steerVaultTokens();
    (uint256 token0Amount, uint256 token1Amount) = steerVault.getTotalAmounts(); 
  }
}
