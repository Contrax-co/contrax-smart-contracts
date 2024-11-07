// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../lib/erc20.sol";

interface IUniProxy {
  /// @notice Get the amount of token to deposit for the given amount of pair token
  /// @param pos Hypervisor Address
  /// @param token Address of token to deposit
  /// @param _deposit Amount of token to deposit
  /// @return amountStart Minimum amounts of the pair token to deposit
  /// @return amountEnd Maximum amounts of the pair token to deposit
  function getDepositAmount(
    address pos,
    address token,
    uint256 _deposit
  ) external view returns (uint256 amountStart, uint256 amountEnd);

  /// @notice Deposit into the given position
  /// @param deposit0 Amount of token0 to deposit
  /// @param deposit1 Amount of token1 to deposit
  /// @param to Address to receive liquidity tokens
  /// @param pos Hypervisor Address (Gamma Vault address)
  /// @param minIn min assets to expect in position during a direct deposit
  /// @return shares Amount of liquidity tokens received
  function deposit(
    uint256 deposit0,
    uint256 deposit1,
    address to,
    address pos,
    uint256[4] memory minIn
  ) external returns (uint256 shares);
}

interface IHypervisor is IERC20 {
  /// @param shares Number of liquidity tokens to redeem as pool assets
  /// @param to Address to which redeemed pool assets are sent
  /// @param from Address from which liquidity tokens are sent
  /// @param minAmounts min amount0,1 returned for shares of liq
  /// @return amount0 Amount of token0 redeemed by the submitted liquidity tokens
  /// @return amount1 Amount of token1 redeemed by the submitted liquidity tokens
  function withdraw(
    uint256 shares,
    address to,
    address from,
    uint256[4] memory minAmounts
  ) external returns (uint256 amount0, uint256 amount1);

  function token0() external view returns (address);

  function token1() external view returns (address);

  function getTotalAmounts() external view returns (uint256 total0, uint256 total1);
}
