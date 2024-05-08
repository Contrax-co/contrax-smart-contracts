// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../../lib/safe-math.sol";
import "../../../lib/erc20.sol";
import "../../../lib/square-root.sol";
import "../../../interfaces/weth.sol";
import "../../../interfaces/IVaultSteerBase.sol";
import "../../../interfaces/uniswapv2.sol";

contract SteerSushiZapperBase {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;
  using SafeERC20 for IVaultSteerBase;

  address public router = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506; // sushi v2 router
  address public constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
  address public constant sushi = 0xd4d42F0b6DEF4CE0383636770eF773390d85c61A;
  address public governance;

  // Define a mapping to store whether an address is whitelisted or not
  mapping(address => bool) public whitelistedVaults;
  // tokenIn => tokenOut => poolFee
  mapping(address => mapping(address => uint24)) public poolFees;

  uint256 public constant minimumAmount = 1000;

  constructor(address _governance, address[] memory _vaults) {
    // Safety checks to ensure WETH token address`
    WETH(weth).deposit{value: 0}();
    WETH(weth).withdraw(0);
    governance = _governance;

    for (uint i = 0; i < _vaults.length; i++) {
      whitelistedVaults[_vaults[i]] = true;
    }
  }

  receive() external payable {
    assert(msg.sender == weth);
  }

  // **** Modifiers **** //

  // Modifier to restrict access to whitelisted vaults only
  modifier onlyWhitelistedVaults(address vault) {
    require(whitelistedVaults[vault], "Vault is not whitelisted");
    _;
  }

  // Modifier to restrict access to governance only
  modifier onlyGovernance() {
    require(msg.sender == governance, "Caller is not the governance");
    _;
  }

  // Function to add a vault to the whitelist
  function addToWhitelist(address _vault) external onlyGovernance {
    whitelistedVaults[_vault] = true;
  }

  // Function to remove a vault from the whitelist
  function removeFromWhitelist(address _vault) external onlyGovernance {
    whitelistedVaults[_vault] = false;
  }

  //returns DUST
  function _returnAssets(address[] memory tokens) internal {
    uint256 balance;
    for (uint256 i; i < tokens.length; i++) {
      balance = IERC20(tokens[i]).balanceOf(address(this));
      if (balance > 0) {
        if (tokens[i] == weth) {
          WETH(weth).withdraw(balance);
          (bool success, ) = msg.sender.call{value: balance}(new bytes(0));
          require(success, "ETH transfer failed");
        } else {
          IERC20(tokens[i]).safeTransfer(msg.sender, balance);
        }
      }
    }
  }

  function deposit(
    IVaultSteerBase vault,
    uint256 amount0,
    uint256 amount1,
    uint256 amountOutMin
  ) public onlyWhitelistedVaults(address(vault)) {
    (address token0, address token1) = vault.steerVaultTokens();

    //transfer both tokens from zapper to our vault
    IERC20(token0).safeTransfer(address(vault), IERC20(token0).balanceOf(address(this)));

    IERC20(token1).safeTransfer(address(vault), IERC20(token1).balanceOf(address(this)));

    //depoist steer vault shares to local vault
    vault.deposit(amount0, amount1);

    uint256 vaultBalance = vault.balanceOf(address(this));

    require(vaultBalance >= amountOutMin, "Insignificant amountOutMin");

    //return vault tokens to user
    IERC20(address(vault)).safeTransfer(msg.sender, vaultBalance);

    address[] memory tokens = new address[](2);
    tokens[0] = token0;
    tokens[1] = token1;

    _returnAssets(tokens);
  }

  function _swap(address tokenIn, address tokenOut, uint256 amountIn) private {
    address[] memory path;

    // sushi only has liquidity with eth, so always route with weth to swap sushi
    if (tokenIn != weth && tokenOut != weth && (tokenIn == sushi || tokenOut == sushi)) {
      path = new address[](3);
      path[0] = tokenIn;
      path[1] = weth;
      path[2] = tokenOut;

      _approveTokenIfNeeded(weth, address(router));
    } else {
      path = new address[](2);
      path[0] = tokenIn;
      path[1] = tokenOut;
    }

    _approveTokenIfNeeded(path[0], address(router));

    UniswapRouterV2(router).swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp);
  }

  function zapInETH(
    IVaultSteerBase vault,
    uint256 tokenAmountOutMin,
    address tokenIn,
    uint256 tokenInAmount0,
    uint256 tokenInAmount1
  ) external payable onlyWhitelistedVaults(address(vault)) {
    uint256 tokenInAmount = tokenInAmount0 + tokenInAmount1;
    require(msg.value >= minimumAmount, "Insignificant input amount");
    require(msg.value >= tokenInAmount, "Insignificant token in amounts");

    WETH(weth).deposit{value: msg.value}();

    (address token0, address token1) = vault.steerVaultTokens();

    if (tokenIn != token0 && tokenIn != token1) {
      _swap(weth, token0, tokenInAmount0);
      _swap(weth, token1, tokenInAmount1);
    } else {
      address tokenOut = token0;
      uint256 amountToSwap = tokenInAmount0;
      if (tokenIn == token0) {
        tokenOut = token1;
        amountToSwap = tokenInAmount1;
      }
      _swap(weth, tokenOut, amountToSwap);
    }

    deposit(vault, IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), tokenAmountOutMin);
  }

  function zapIn(
    IVaultSteerBase vault,
    uint256 tokenAmountOutMin,
    address tokenIn,
    uint256 tokenInAmount0,
    uint256 tokenInAmount1
  ) external onlyWhitelistedVaults(address(vault)) {
    uint256 tokenInAmount = tokenInAmount0 + tokenInAmount1;
    require(tokenInAmount >= minimumAmount, "Insignificant input amount");
    require(IERC20(tokenIn).allowance(msg.sender, address(this)) >= tokenInAmount, "Input token is not approved");

    // transfer token
    IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), tokenInAmount);

    (address token0, address token1) = vault.steerVaultTokens();

    //Note : tokenIn pair must exist with both steerVaultTokens
    if (token0 != tokenIn && token1 != tokenIn) {
      _swap(tokenIn, token0, tokenInAmount0);
      _swap(tokenIn, token1, tokenInAmount1);
    } else {
      address tokenOut = token0;
      uint256 amountToSwap = tokenInAmount0;
      if (tokenIn == token0) {
        tokenOut = token1;
        amountToSwap = tokenInAmount1;
      }
      _swap(tokenIn, tokenOut, amountToSwap);
    }

    deposit(vault, IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), tokenAmountOutMin);
  }

  function zapOutAndSwap(
    IVaultSteerBase vault,
    uint256 withdrawAmount,
    address desiredToken,
    uint256 desiredTokenOutMin
  ) public onlyWhitelistedVaults(address(vault)) {
    vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);

    (uint256 amount0, uint256 amount1) = vault.withdraw(withdrawAmount);
    (address token0, address token1) = vault.steerVaultTokens();

    // Swapping
    if (token0 != desiredToken) {
      _swap(token0, desiredToken, amount0);
    }

    if (token1 != desiredToken) {
      _swap(token1, desiredToken, amount1);
    }

    address[] memory path = new address[](3);
    path[0] = token0;
    path[1] = token1;
    path[2] = desiredToken;

    require(IERC20(desiredToken).balanceOf(address(this)) >= desiredTokenOutMin, "Insignificant desiredTokenOutMin");

    _returnAssets(path);
  }

  function zapOutAndSwapEth(
    IVaultSteerBase vault,
    uint256 withdrawAmount,
    uint256 desiredTokenOutMin
  ) public onlyWhitelistedVaults(address(vault)) {
    vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);

    (uint256 amount0, uint256 amount1) = vault.withdraw(withdrawAmount);
    (address token0, address token1) = vault.steerVaultTokens();

    // Swapping
    if (token0 != weth) {
      _swap(token0, weth, amount0);
    }

    if (token1 != weth) {
      _swap(token1, weth, amount1);
    }

    address[] memory path = new address[](3);
    path[0] = token0;
    path[1] = token1;
    path[2] = weth;

    require(IERC20(weth).balanceOf(address(this)) >= desiredTokenOutMin, "Insignificant desiredTokenOutMin");

    _returnAssets(path);
  }

  function _approveTokenIfNeeded(address token, address spender) internal {
    if (IERC20(token).allowance(address(this), spender) == 0) {
      IERC20(token).safeApprove(spender, type(uint256).max);
    }
  }
}
