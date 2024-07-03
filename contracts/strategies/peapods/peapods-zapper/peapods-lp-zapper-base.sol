// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../../lib/erc20.sol";
import "../../../interfaces/weth.sol";
import "../../../interfaces/vault.sol";
import "../../../interfaces/uniswapv3.sol";
import "../../../interfaces/uniswapv2.sol";
import "../../../interfaces/camelot.sol";
import "../../../interfaces/peapods.sol";


abstract contract PeapodsZapperBase {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;
  using SafeERC20 for IVault;

  address public camelotRouterV3;
  address public camelotRouterV2 = 0xc873fEcbd354f5A56E00E710B90EF4201db2448d;

  address public constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
  address public governance;
  address constant ohm = 0xf0cb2dc0db5e6c66B9a70Ac27B06b878da017028;
  address constant peas = 0x02f92800F57BCD74066F5709F1Daa1A4302Df875;
  address constant gmx = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;

  address public constant indexUtils = 0x5c5c288f5EF3559Aaf961c5cCA0e77Ac3565f0C0;
  address public constant zero = 0x0000000000000000000000000000000000000000;

  // Define a mapping to store whether an address is whitelisted or not
  mapping(address => bool) public whitelistedVaults;
  mapping(address => address) public baseToken;

  uint256 public constant minimumAmount = 1000;

  // For this example, we will set the pool fee to 0.3%.
  uint24 public constant poolFee = 3000;

  constructor(address _router, address _governance) {
    // Safety checks to ensure WETH token address
    WETH(weth).deposit{value: 0}();
    WETH(weth).withdraw(0);
    camelotRouterV3 = _router;
    governance = _governance;
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

  function setBaseTokens(address _apToken, address _baseToken) external onlyGovernance {
    baseToken[_apToken] = _baseToken;
  }

  // Function to remove a vault from the whitelist
  function removeFromWhitelist(address _vault) external onlyGovernance {
    whitelistedVaults[_vault] = false;
  }

  function _swapCamelotWithPathV2(address tokenIn, address tokenOut, uint256 _amount) internal {
    address[] memory path;

    // ohm only has liquidity with eth, so always route with weth to swap ohm
    if (tokenIn != weth && tokenOut != weth && (tokenIn == ohm || tokenOut == ohm)) {
      path = new address[](3);
      path[0] = tokenIn;
      path[1] = weth;
      path[2] = tokenOut;

      _approveTokenIfNeeded(weth, address(camelotRouterV2));
    } else {
      path = new address[](2);
      path[0] = tokenIn;
      path[1] = tokenOut;
    }

    _approveTokenIfNeeded(path[0], address(camelotRouterV2));

    UniswapRouterV2(camelotRouterV2).swapExactTokensForTokens(_amount, 0, path, address(this), block.timestamp);
  }

  function _swapCamelot(address _from, address _to, uint256 _amount) internal returns (uint256 amountOut) {
    _approveTokenIfNeeded(_from, address(camelotRouterV3));

    ICamelotRouterV3.ExactInputSingleParams memory params = ICamelotRouterV3.ExactInputSingleParams({
      tokenIn: _from,
      tokenOut: _to,
      recipient: address(this),
      deadline: block.timestamp,
      amountIn: _amount,
      amountOutMinimum: 0,
      sqrtPriceLimitX96: 0
    });

    // The call to `exactInputSingle` executes the swap.
    amountOut = ICamelotRouterV3(camelotRouterV3).exactInputSingle(params);
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

  function _swapAndStake(address vault, uint256 tokenAmountOutMin, address tokenIn) public virtual;

  function zapInETH(
    address vault,
    uint256 tokenAmountOutMin,
    address tokenIn
  ) external payable onlyWhitelistedVaults(vault) {
    require(msg.value >= minimumAmount, "Insignificant input amount");

    WETH(weth).deposit{value: msg.value}();

    (, address apToken) = _getVaultPair(vault);

    // allows us to zapIn if eth isn't part of the original pair
    if (tokenIn != apToken) {
      uint256 _amount = IERC20(weth).balanceOf(address(this));

      address[] memory path = new address[](2);
      path[0] = weth;
      path[1] = baseToken[apToken];

      if (baseToken[apToken] == ohm) {
        _swapCamelotWithPathV2(weth, baseToken[apToken], _amount);

      } else {
        _swapCamelot(weth, baseToken[apToken], _amount);
      }

      uint256 _want = IERC20(baseToken[apToken]).balanceOf(address(this));

      IERC20(baseToken[apToken]).safeApprove(indexUtils, 0);
      IERC20(baseToken[apToken]).safeApprove(indexUtils, _want);
      IDecentralizedIndex(indexUtils).bond(apToken, baseToken[apToken], _want, 0);

      _swapAndStake(vault, tokenAmountOutMin, apToken);
    } else {
      _swapAndStake(vault, tokenAmountOutMin, tokenIn);
    }
  }

  // transfers tokens from msg.sender to this contract
  function zapIn(
    address vault,
    uint256 tokenAmountOutMin,
    address tokenIn,
    uint256 tokenInAmount
  ) external onlyWhitelistedVaults(vault) {
    require(tokenInAmount >= minimumAmount, "Insignificant input amount");
    require(IERC20(tokenIn).allowance(msg.sender, address(this)) >= tokenInAmount, "Input token is not approved");

    // transfer token
    IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), tokenInAmount);

    (, address apToken) = _getVaultPair(vault);

    if (apToken != tokenIn && tokenIn != ohm && tokenIn != peas && tokenIn != gmx) {
      address[] memory path = new address[](3);
      path[0] = tokenIn;
      path[1] = weth;
      path[2] = baseToken[apToken];

      if (baseToken[apToken] == ohm) {
        _swapCamelot(tokenIn, weth, tokenInAmount);
        _swapCamelotWithPathV2(weth, ohm, IERC20(weth).balanceOf(address(this)));
      } else {
        _swapCamelot(path[0], path[1], tokenInAmount);
        _swapCamelot(path[1], path[2], IERC20(path[1]).balanceOf(address(this)));
      }

      uint256 _want = IERC20(baseToken[apToken]).balanceOf(address(this));

      IERC20(baseToken[apToken]).safeApprove(indexUtils, 0);
      IERC20(baseToken[apToken]).safeApprove(indexUtils, _want);
      IDecentralizedIndex(indexUtils).bond(apToken, baseToken[apToken], _want, 0);

      _swapAndStake(vault, tokenAmountOutMin, apToken);
    } else {
      uint256 _want = IERC20(baseToken[apToken]).balanceOf(address(this));

      IERC20(baseToken[apToken]).safeApprove(indexUtils, 0);
      IERC20(baseToken[apToken]).safeApprove(indexUtils, _want);
      IDecentralizedIndex(indexUtils).bond(apToken, baseToken[apToken], _want, 0);

      _swapAndStake(vault, tokenAmountOutMin, apToken);
    }
  }

  function zapOutAndSwap(
    address vault,
    uint256 withdrawAmount,
    address desiredToken,
    uint256 desiredTokenOutMin
  ) public virtual;

  function zapOutAndSwapEth(address vault, uint256 withdrawAmount, uint256 desiredTokenOutMin) public virtual;

  function _getVaultPair(address vault_addr) internal view returns (IVault vault, address token) {
    vault = IVault(vault_addr);
    token = vault.token();

    require(token != address(0), "Liquidity pool address cannot be the zero address");
  }

  function _approveTokenIfNeeded(address token, address spender) internal {
    if (IERC20(token).allowance(address(this), spender) == 0) {
      IERC20(token).safeApprove(spender, type(uint256).max);
    }
  }

  function zapOut(address vault_addr, uint256 withdrawAmount) external onlyWhitelistedVaults(vault_addr) {
    (IVault vault, address apToken) = _getVaultPair(vault_addr);

    IERC20(vault_addr).safeTransferFrom(msg.sender, address(this), withdrawAmount);
    vault.withdraw(withdrawAmount);

    address[] memory tokens = new address[](2);
    tokens[0] = apToken;
    tokens[1] = address(vault.token());

    _returnAssets(tokens);
  }
}
