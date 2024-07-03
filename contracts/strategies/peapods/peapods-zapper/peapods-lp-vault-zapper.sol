// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./peapods-lp-zapper-base.sol";

contract VaultZapperPeapods is PeapodsZapperBase {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;
  using SafeERC20 for IVault;

  constructor()
    PeapodsZapperBase(0x1F721E2E82F6676FCE4eA07A5958cF098D339e18, 0xCb410A689A03E06de0a6247b13C13D14237DecC8)
  {}

  function zapOutAndSwap(
    address vault_addr,
    uint256 withdrawAmount,
    address desiredToken,
    uint256 desiredTokenOutMin
  ) public override onlyWhitelistedVaults(vault_addr) {
    (IVault vault, address apToken) = _getVaultPair(vault_addr);

    vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
    vault.withdraw(withdrawAmount);

    if (desiredToken == apToken) {
      address[] memory path = new address[](1);
      path[0] = desiredToken;

      _returnAssets(path);
    } else {
      //unbond from apToken get base token
      address[] memory path;
      path = new address[](1);
      path[0] = baseToken[apToken];

      uint8[] memory percent;
      percent = new uint8[](1);
      percent[0] = 100;

      WeightedIndex(apToken).debond(withdrawAmount, path, percent);

      // convert baseToken to desiredToken
      address[] memory path3 = new address[](3);
      path3[0] = baseToken[apToken];
      path3[1] = weth;
      path3[2] = desiredToken;

      if (path3[0] == ohm) {
        _swapCamelotWithPathV2(path3[0], path3[1], IERC20(path3[0]).balanceOf(address(this)));

        _swapCamelot(path3[1], path3[2], IERC20(path3[1]).balanceOf(address(this)));
      } else {
        _swapCamelot(path3[0], path3[1], IERC20(baseToken[apToken]).balanceOf(address(this)));

        _swapCamelot(path3[1], path3[2], IERC20(path3[1]).balanceOf(address(this)));
      }

      address[] memory path4 = new address[](2);
      path4[0] = baseToken[apToken];
      path4[1] = desiredToken;

      _returnAssets(path4);
    }
  }

  function zapOutAndSwapEth(
    address vault_addr,
    uint256 withdrawAmount,
    uint256 desiredTokenOutMin
  ) public override onlyWhitelistedVaults(vault_addr) {
    (IVault vault, address apToken) = _getVaultPair(vault_addr);

    vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
    vault.withdraw(withdrawAmount);

    if (apToken == weth) {
      address[] memory path = new address[](1);
      path[0] = apToken;

      _returnAssets(path);
    } else {
      //unbond from apToken get base token
      address[] memory path;
      path = new address[](1);
      path[0] = baseToken[apToken];

      uint8[] memory percent;
      percent = new uint8[](1);
      percent[0] = 100;

      WeightedIndex(apToken).debond(withdrawAmount, path, percent);

      // convert baseToken to desiredToken
      address[] memory path1 = new address[](2);
      path1[0] = baseToken[apToken];
      path1[1] = weth;

      if (path1[0] == ohm) {
        _swapCamelotWithPathV2(path1[0], path1[1], IERC20(path1[0]).balanceOf(address(this)));
      } else {
        _swapCamelot(path1[0], path1[1], IERC20(path1[0]).balanceOf(address(this)));
      }

      address[] memory path2 = new address[](2);
      path2[0] = baseToken[apToken];
      path2[1] = weth;

      _returnAssets(path2);
    }
  }

  function _swapAndStake(
    address vault_addr,
    uint256 tokenAmountOutMin,
    address tokenIn
  ) public override onlyWhitelistedVaults(vault_addr) {
    (IVault vault, address apToken) = _getVaultPair(vault_addr);

    bool isInputA = apToken == tokenIn;
    require(isInputA, "Input token not present in liquidity pair");

    _approveTokenIfNeeded(address(vault.token()), address(vault));
    vault.deposit(IERC20(apToken).balanceOf(address(this)));

    //add to guage if possible instead of returning to user, and so no receipt token
    vault.safeTransfer(msg.sender, vault.balanceOf(address(this)));

    address[] memory path = new address[](2);
    path[0] = apToken;
    path[1] = weth;

    _returnAssets(path);
  }

  // function estimateSwap(address vault_addr, address tokenIn, uint256 fullInvestmentIn) public view returns (uint256 swapAmountIn, uint256 swapAmountOut, address swapTokenOut){
  //     (, address token) = _getVaultPair(vault_addr);

  //     bool isInputA = token == tokenIn;

  //     if(isInputA){
  //       swapAmountOut = fullInvestmentIn;
  //       swapAmountIn = fullInvestmentIn;

  //       swapTokenOut = gmx;

  //     }else{
  //         address[] memory path = new address[](2);
  //         path[0]= tokenIn;
  //         path[1] = gmx;

  //         uint256[] memory amounts = UniswapRouterV2(router).getAmountsOut(
  //             fullInvestmentIn,
  //             path
  //         );

  //         swapAmountOut = amounts[1];
  //         swapAmountIn = amounts[0];

  //         swapTokenOut = gmx;

  //     }
  // }
}
