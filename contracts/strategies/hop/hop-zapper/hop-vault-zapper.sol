// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./hop-zapper-base.sol";

contract VaultZapperHop is HopZapperBase {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;
  using SafeERC20 for IVault;

  constructor(
    address _governance,
    address[] memory _vaults
  ) HopZapperBase(0xE592427A0AEce92De3Edee1F18E0157C05861564, _governance, _vaults) {}

  function zapOutAndSwap(
    address vault_addr,
    uint256 withdrawAmount,
    address desiredToken,
    uint256 desiredTokenOutMin
  ) public override onlyWhitelistedVaults(vault_addr) returns (uint256 tokenBalance) {
    (IVault vault, IHopSwap pair) = _getVaultPair(vault_addr);
    address token0 = pair.getToken(0);
    address token1 = pair.getToken(1);

    vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
    vault.withdraw(withdrawAmount);
    _removeLiquidity(address(vault.token()), IHopSwap(pair));

    _approveTokenIfNeeded(token1, address(pair));
    IHopSwap(pair).swap(1, 0, IERC20(token1).balanceOf(address(this)), desiredTokenOutMin, block.timestamp);

    if (desiredToken == token0) {
      address[] memory path = new address[](2);
      path[0] = token0;
      path[1] = token1;

      _returnAssets(path);
    } else {
      address[] memory path = new address[](2);
      path[0] = token0;
      path[1] = desiredToken;

      _approveTokenIfNeeded(path[0], address(router));
      ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
        tokenIn: path[0],
        tokenOut: path[1],
        fee: poolFee,
        recipient: address(this),
        deadline: block.timestamp,
        amountIn: IERC20(path[0]).balanceOf(address(this)),
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0
      });

      // The call to `exactInputSingle` executes the swap.
      ISwapRouter(address(router)).exactInputSingle(params);

      address[] memory path2 = new address[](3);
      path2[0] = token0;
      path2[1] = token1;
      path2[2] = desiredToken;

      tokenBalance = IERC20(desiredToken).balanceOf(address(this));

      _returnAssets(path2);

      emit Withdraw(msg.sender, tokenBalance);
    }
  }

  function zapOutAndSwapEth(
    address vault_addr,
    uint256 withdrawAmount,
    uint256 desiredTokenOutMin
  ) public override onlyWhitelistedVaults(vault_addr) returns (uint256 ethBalance) {
    (IVault vault, IHopSwap pair) = _getVaultPair(vault_addr);

    address token0 = pair.getToken(0);
    address token1 = pair.getToken(1);

    vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
    vault.withdraw(withdrawAmount);
    _removeLiquidity(address(vault.token()), IHopSwap(pair));

    _approveTokenIfNeeded(token1, address(pair));
    IHopSwap(pair).swap(1, 0, IERC20(token1).balanceOf(address(this)), desiredTokenOutMin, block.timestamp);

    if (token0 == weth) {
      address[] memory path = new address[](2);
      path[0] = token0;
      path[1] = token1;

      _returnAssets(path);
    } else {
      address[] memory path = new address[](2);
      path[0] = token0;
      path[1] = weth;

      _approveTokenIfNeeded(path[0], address(router));
      ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
        tokenIn: path[0],
        tokenOut: path[1],
        fee: poolFee,
        recipient: address(this),
        deadline: block.timestamp,
        amountIn: IERC20(path[0]).balanceOf(address(this)),
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0
      });

      // The call to `exactInputSingle` executes the swap.
      ISwapRouter(address(router)).exactInputSingle(params);

      ethBalance = IERC20(weth).balanceOf(address(this));

      _returnAssets(path);

      emit Withdraw(msg.sender, ethBalance);
    }
  }

  // function _swapAndStake(
  //   address vault_addr,
  //   uint256 tokenAmountOutMin,
  //   address tokenIn
  // ) public override onlyWhitelistedVaults(vault_addr) returns (uint256 vaultBalance) {
  //   (IVault vault, IHopSwap pair) = _getVaultPair(vault_addr);

  //   address token0 = pair.getToken(0);
  //   address token1 = pair.getToken(1);

  //   bool isInputA = token0 == tokenIn;
  //   require(isInputA || token1 == tokenIn, "Input token not present in liquidity pair");

  //   uint256 _tokenBalance0 = IHopSwap(pair).getTokenBalance(0);
  //   uint256 _tokenBalance1 = IHopSwap(pair).getTokenBalance(1);

  //   if (_tokenBalance0 > _tokenBalance1) {
  //     uint256 fullInvestment = IERC20(tokenIn).balanceOf(address(this));
  //     _approveTokenIfNeeded(token0, address(pair));

  //     IHopSwap(pair).swap(0, 1, fullInvestment, tokenAmountOutMin, block.timestamp);
  //   }

  //   // Adds in liquidity for token0/token1
  //   uint256 _token0 = IERC20(token0).balanceOf(address(this));
  //   uint256 _token1 = IERC20(token1).balanceOf(address(this));

  //   uint256[] memory amounts;
  //   amounts = new uint256[](2);
  //   amounts[0] = _token0;
  //   amounts[1] = _token1;

  //   _approveTokenIfNeeded(token0, address(pair));
  //   _approveTokenIfNeeded(token1, address(pair));

  //   uint256 amountLiquidity = IHopSwap(pair).addLiquidity(amounts, 0, block.timestamp);

  //   _approveTokenIfNeeded(address(vault.token()), address(vault));
  //   vault.deposit(amountLiquidity);

  //   vaultBalance = vault.balanceOf(address(this));
  //   //add to guage if possible instead of returning to user, and so no receipt token
  //   vault.safeTransfer(msg.sender, vaultBalance);

  //   address[] memory path = new address[](2);
  //   path[0] = token0;
  //   path[1] = token1;

  //   _returnAssets(path);

  //   emit Deposit(msg.sender, vaultBalance);
  // }

  function _swapAndStake(
    address vault_addr,
    uint256 tokenAmountOutMin,
    address tokenIn
  ) public override onlyWhitelistedVaults(vault_addr) returns (uint256 vaultBalance) {
    (IVault vault, IHopSwap pair) = _getVaultPair(vault_addr);

    _validateTokenInPair(pair, tokenIn);

    (uint256 _tokenBalance0, uint256 _tokenBalance1) = _getTokenBalances(pair);

    if (_tokenBalance0 > _tokenBalance1) {
      uint256 fullInvestment = IERC20(tokenIn).balanceOf(address(this));
      _approveAndSwap(pair, tokenIn, fullInvestment, tokenAmountOutMin);
    }

    (uint256 _token0, uint256 _token1) = _getUpdatedTokenBalances(pair);
    uint256 amountLiquidity = _addLiquidity(pair, _token0, _token1);
    _handleVaultOperations(vault, amountLiquidity);

    vaultBalance = vault.balanceOf(address(this));
    vault.safeTransfer(msg.sender, vaultBalance);

    _returnAssets(pair);

    emit Deposit(msg.sender, vaultBalance);
  }

  function _validateTokenInPair(IHopSwap pair, address tokenIn) internal view {
    address token0 = pair.getToken(0);
    address token1 = pair.getToken(1);
    require(token0 == tokenIn || token1 == tokenIn, "Input token not present in liquidity pair");
  }

  function _getTokenBalances(IHopSwap pair) internal view returns (uint256, uint256) {
    uint256 _tokenBalance0 = IHopSwap(pair).getTokenBalance(0);
    uint256 _tokenBalance1 = IHopSwap(pair).getTokenBalance(1);
    return (_tokenBalance0, _tokenBalance1);
  }

  function _approveAndSwap(IHopSwap pair, address tokenIn, uint256 fullInvestment, uint256 tokenAmountOutMin) internal {
    _approveTokenIfNeeded(tokenIn, address(pair));
    IHopSwap(pair).swap(0, 1, fullInvestment, tokenAmountOutMin, block.timestamp);
  }

  function _getUpdatedTokenBalances(IHopSwap pair) internal view returns (uint256, uint256) {
    uint256 _token0 = IERC20(pair.getToken(0)).balanceOf(address(this));
    uint256 _token1 = IERC20(pair.getToken(1)).balanceOf(address(this));
    return (_token0, _token1);
  }

  function _addLiquidity(IHopSwap pair, uint256 _token0, uint256 _token1) internal returns (uint256) {
    uint256[] memory amounts = new uint256[](2);
    amounts[0] = _token0;
    amounts[1] = _token1;

    _approveTokenIfNeeded(pair.getToken(0), address(pair));
    _approveTokenIfNeeded(pair.getToken(1), address(pair));

    return IHopSwap(pair).addLiquidity(amounts, 0, block.timestamp);
  }

  function _handleVaultOperations(IVault vault, uint256 amountLiquidity) internal {
    _approveTokenIfNeeded(address(vault.token()), address(vault));
    vault.deposit(amountLiquidity);
  }

  function _returnAssets(IHopSwap pair) internal {
    address[] memory path = new address[](2);
    path[0] = pair.getToken(0);
    path[1] = pair.getToken(1);
    _returnAssets(path);
  }

  function estimateSwap(
    address vault_addr,
    address tokenIn,
    uint256 fullInvestmentIn
  ) public view returns (uint256 swapAmountIn, uint256 swapAmountOut, address swapTokenOut) {
    (IVault vault, IHopSwap pair) = _getVaultPair(vault_addr);

    bool isInputA = pair.getToken(0) == tokenIn;
    require(isInputA || pair.getToken(1) == tokenIn, "Input token not present in liquidity pair");

    uint256 reserveA = pair.getTokenBalance(0);
    uint256 reserveB = pair.getTokenBalance(1);

    if (isInputA) {
      if (reserveA >= reserveB) {
        uint256 _tokenOut = pair.calculateSwap(0, 1, fullInvestmentIn);

        uint256[] memory amounts;
        amounts = new uint256[](2);
        amounts[0] = 0;
        amounts[1] = _tokenOut;

        swapAmountOut = pair.calculateTokenAmount(address(this), amounts, true);
      }
    } else {
      if (reserveB >= reserveA) {
        uint256 _tokenOut = pair.calculateSwap(1, 0, fullInvestmentIn);

        uint256[] memory amounts;
        amounts = new uint256[](2);
        amounts[0] = 0;
        amounts[1] = _tokenOut;

        swapAmountOut = pair.calculateTokenAmount(address(this), amounts, true);
      }
    }

    swapAmountIn = fullInvestmentIn;
    swapTokenOut = vault.token();
  }
}
