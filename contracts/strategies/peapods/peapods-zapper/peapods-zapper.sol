// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./peapods-zapper-base.sol";

contract PeapodsZapper is PeapodsZapperBase {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;
  using SafeERC20 for IVault;

  constructor(
    address _governance,
    address[] memory _vaults
  ) PeapodsZapperBase(0x1F721E2E82F6676FCE4eA07A5958cF098D339e18, _governance) {
    WETH(weth).deposit{value: 0}();
    WETH(weth).withdraw(0);

    for (uint i = 0; i < _vaults.length; i++) {
      whitelistedVaults[_vaults[i]] = true;
    }

    baseToken[0x6a02F704890F507f13d002F2785ca7Ba5BFcc8F7] = 0x02f92800F57BCD74066F5709F1Daa1A4302Df875; // apPEAS / PEAS
    baseToken[0xEb1A8f8Ea373536600082BA9aE2DB97327513F7d] = 0xf0cb2dc0db5e6c66B9a70Ac27B06b878da017028; // apOHM / OHM
    baseToken[0x8CB10B11Fad33cfE4758Dc9977d74CE7D2fB4609] = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a; // apGMX / GMX
  }

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

      require(IERC20(desiredToken).balanceOf(address(this)) >= desiredTokenOutMin, "Insignificant desiredTokenOutMin");

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

      require(IERC20(desiredToken).balanceOf(address(this)) >= desiredTokenOutMin, "Insignificant desiredTokenOutMin");

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

      require(IERC20(weth).balanceOf(address(this)) >= desiredTokenOutMin, "Insignificant desiredTokenOutMin");

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

      require(IERC20(weth).balanceOf(address(this)) >= desiredTokenOutMin, "Insignificant desiredTokenOutMin");

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

    uint256 vaultBalance = vault.balanceOf(address(this));

    require(vaultBalance >= tokenAmountOutMin, "Insignificant tokenAmountOutMin");

    //add to guage if possible instead of returning to user, and so no receipt token
    vault.safeTransfer(msg.sender, vaultBalance);

    address[] memory path = new address[](2);
    path[0] = apToken;
    path[1] = weth;

    _returnAssets(path);
  }
}
