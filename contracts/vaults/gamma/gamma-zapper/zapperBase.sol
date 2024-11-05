// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IERC20, SafeERC20, Address} from "../../../lib/erc20.sol";
import {WETH} from "../../../interfaces/weth.sol";
import {ISwapRouter} from "../../../interfaces/ISwapRouter.sol";
import {IVault} from "../../../interfaces/vault.sol";
import {IZapper} from "../../../interfaces/IZapper.sol";

abstract contract ZapperBase is IZapper {
  using Address for address;
  using SafeERC20 for IERC20;
  using SafeERC20 for IVault;

  address public governance;
  ISwapRouter public swapRouter;
  WETH public wrappedNative;
  IERC20 public usdcToken;
  uint256 public constant minimumAmount = 1000;
  mapping(address => bool) public whitelistedVaults;

  constructor(address _wrappedNative, address _usdcToken, address _swapRouter, address[] memory _vaultsToWhitelist) {
    // Safety checks to ensure wrappedNative token address
    wrappedNative = WETH(_wrappedNative);
    wrappedNative.deposit{value: 0}();
    wrappedNative.withdraw(0);
    usdcToken = IERC20(_usdcToken);
    swapRouter = ISwapRouter(_swapRouter);

    for (uint i = 0; i < _vaultsToWhitelist.length; i++) {
      _setWhitelistVault(_vaultsToWhitelist[i], true);
    }
  }

  modifier onlyGovernance() {
    require(msg.sender == governance, "Caller is not the governance");
    _;
  }

  modifier onlyWhitelistedVaults(address vault) {
    require(whitelistedVaults[vault], "Vault is not whitelisted");
    _;
  }

  function _setWhitelistVault(address _vault, bool _whitelisted) internal virtual {
    whitelistedVaults[_vault] = _whitelisted;
    emit WhitelistVault(_vault, _whitelisted);
  }

  function setWhitelistVault(address _vault, bool _whitelisted) external onlyGovernance {
    _setWhitelistVault(_vault, _whitelisted);
  }

  function setSwapRouter(address _swapRouter) external onlyGovernance {
    emit SetSwapRouter(_swapRouter, address(swapRouter));
    swapRouter = ISwapRouter(_swapRouter);
  }

  receive() external payable {
    assert(msg.sender == address(wrappedNative));
  }

  //returns DUST
  function _returnAssets(address[] memory tokens) internal returns (ReturnedAsset[] memory returnedAssets) {
    uint256 balance;
    for (uint256 i; i < tokens.length; i++) {
      balance = IERC20(tokens[i]).balanceOf(address(this));
      if (balance > 0) {
        if (tokens[i] == address(wrappedNative)) {
          wrappedNative.withdraw(balance);
          (bool success, ) = msg.sender.call{value: balance}(new bytes(0));
          require(success, "ETH transfer failed");
        } else {
          IERC20(tokens[i]).safeTransfer(msg.sender, balance);
        }
        returnedAssets[i] = ReturnedAsset({tokens: tokens[i], amounts: balance});
      }
    }
  }

  // for zapIn, converts the tokenIn balance of address(this) to the desired token of the vault
  // must return the left over amount of any token back to the caller
  function _beforeDeposit(
    IVault vault,
    IERC20 tokenIn
  ) public virtual returns (uint256 tokenOutAmount, ReturnedAsset[] memory returnedAssets);

  // for zapOut, converts the desired token of the vault to the desired token of the caller
  // must return the left over amount of any token back to the caller
  function _afterWithdraw(
    IVault vault,
    IERC20 tokenIn
  ) public virtual returns (uint256 tokenOutAmount, ReturnedAsset[] memory returnedAssets);

  function _zapIn(
    IVault vault,
    uint256 tokenAmountOutMin,
    IERC20 tokenIn,
    uint256 tokenInAmount
  ) internal returns (uint256 shares, ReturnedAsset[] memory returnedAssets) {
    uint256 amountToDeposit;
    (amountToDeposit, returnedAssets) = _beforeDeposit(vault, tokenIn);

    //depoist gamma vault shares to local vault
    _approveTokenIfNeeded(vault.token(), address(vault));

    // deposit the converted token to the vault
    vault.deposit(amountToDeposit);

    // return any remaining vault shares to the caller
    shares = vault.balanceOf(address(this));
    require(shares >= tokenAmountOutMin, "zapIn: Insufficient output vault shares");
    IERC20(vault).safeTransfer(msg.sender, shares);
    emit ZapIn(msg.sender, address(vault), address(tokenIn), tokenInAmount, shares);
  }

  // TODO: combine zapInETH and zapIn
  function zapInETH(
    IVault vault,
    uint256 tokenAmountOutMin,
    address // unnecessary param for backwards compatibility
  )
    external
    payable
    override
    onlyWhitelistedVaults(address(vault))
    returns (uint256 shares, ReturnedAsset[] memory returnedAssets)
  {
    require(msg.value >= minimumAmount, "Insignificant input amount");
    wrappedNative.deposit{value: msg.value}();
    return _zapIn(vault, tokenAmountOutMin, IERC20(address(wrappedNative)), msg.value);
  }

  // TODO: also return the amount of tokenIn that was used or in case it was converted,
  // all the converted amounts that are left in the contract (dust)
  function zapIn(
    IVault vault,
    uint256 tokenAmountOutMin,
    IERC20 tokenIn,
    uint256 tokenInAmount
  )
    external
    override
    onlyWhitelistedVaults(address(vault))
    returns (uint256 shares, ReturnedAsset[] memory returnedAssets)
  {
    require(tokenInAmount >= minimumAmount, "Insignificant input amount");
    require(IERC20(tokenIn).allowance(msg.sender, address(this)) >= tokenInAmount, "Input token is not approved");
    IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), tokenInAmount);
    return _zapIn(vault, tokenAmountOutMin, tokenIn, tokenInAmount);
  }

  function zapOutAndSwap(
    IVault vault,
    uint256 withdrawAmount,
    IERC20 desiredToken,
    uint256 desiredTokenOutMin
  )
    public
    virtual
    override
    onlyWhitelistedVaults(address(vault))
    returns (uint256 tokenOutAmount, ReturnedAsset[] memory returnedAssets)
  {
    IVault(vault).safeTransferFrom(msg.sender, address(this), withdrawAmount);
    IVault(vault).withdraw(withdrawAmount);
    (tokenOutAmount, returnedAssets) = _afterWithdraw(vault, desiredToken);
    require(tokenOutAmount >= desiredTokenOutMin, "zapOut: Insufficient output amount");
  }

  function zapOutAndSwapEth(
    IVault vault,
    uint256 withdrawAmount,
    uint256 desiredTokenOutMin
  )
    public
    virtual
    override
    onlyWhitelistedVaults(address(vault))
    returns (uint256 tokenOutAmount, ReturnedAsset[] memory returnedAssets)
  {
    return zapOutAndSwap(vault, withdrawAmount, IERC20(address(0)), desiredTokenOutMin);
  }

  function _approveTokenIfNeeded(address token, address spender) internal {
    if (IERC20(token).allowance(address(this), spender) == 0) {
      IERC20(token).safeApprove(spender, type(uint256).max);
    }
  }
}
