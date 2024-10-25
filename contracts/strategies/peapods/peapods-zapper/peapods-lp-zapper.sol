// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../peapods-zapper/peapods-lp-zapper-base.sol";
import "../../../lib/square-root.sol";

contract VaultLPZapperPeapods is PeapodsLPZapperBase {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;
  using SafeERC20 for IVault;
  using SafeERC20 for ICamelotPair;

  constructor()
    PeapodsLPZapperBase(0xc873fEcbd354f5A56E00E710B90EF4201db2448d, 0xCb410A689A03E06de0a6247b13C13D14237DecC8)
  {}

  function zapOutAndSwap(
    address vault_addr,
    uint256 withdrawAmount,
    address desiredToken,
    uint256 desiredTokenOutMin
  ) public override onlyWhitelistedVaults(vault_addr) returns (uint256 tokenBalance) {
    (IVault vault, ICamelotPair pair) = _getVaultPair(vault_addr);
    address token0 = pair.token0();
    address token1 = pair.token1();

    vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
    vault.withdraw(withdrawAmount);
    _removeLiquidity(address(pair), address(this));

    address tokenA = baseToken[token0];
    address tokenB = baseToken[token1];

    if (tokenA != desiredToken) {
      // unbond from apToken get base token
      address[] memory path;
      path = new address[](1);
      path[0] = tokenA;

      uint8[] memory percent;
      percent = new uint8[](1);
      percent[0] = 100;

      WeightedIndex(token0).debond(IERC20(token0).balanceOf(address(this)), path, percent);

      uint256 _tokenA = IERC20(tokenA).balanceOf(address(this));
      if (_tokenA > 0 && tokenA == ohm) {
        address[] memory path2 = new address[](3);
        path2[0] = tokenA;
        path2[1] = weth;
        path2[2] = desiredToken;

        address[] memory adapters = new address[](2);
        adapters[0] = weth_ohm_adapter;
        adapters[1] = usdc_usdcE_adapter;

        address[] memory recipients = new address[](2);
        recipients[0] = weth_ohm;
        recipients[1] = usdc_usdcE_adapter;

        _swapCamelotYak(tokenA, path2, adapters, recipients, _tokenA);
      }

      if (_tokenA > 0 && tokenA == peas) {
        address[] memory path2 = new address[](2);
        path2[0] = tokenA;
        path2[1] = desiredToken;

        address[] memory adapters = new address[](1);
        adapters[0] = usdc_usdcE_adapter;

        _swapCamelotYak(tokenA, path2, adapters, adapters, _tokenA);
      }

      if (_tokenA > 0 && tokenA == gmx) {
        _swapCamelot(tokenA, weth, _tokenA);
        _swapCamelot(weth, desiredToken, IERC20(weth).balanceOf(address(this)));
      }
    }

    if (tokenB != desiredToken) {
      // unbond from apToken get base token
      address[] memory path;
      path = new address[](1);
      path[0] = baseToken[token1];

      uint8[] memory percent;
      percent = new uint8[](1);
      percent[0] = 100;

      WeightedIndex(token1).debond(IERC20(token1).balanceOf(address(this)), path, percent);

      uint256 _tokenB = IERC20(tokenB).balanceOf(address(this));

      if (_tokenB > 0 && tokenB == ohm) {
        address[] memory path2 = new address[](3);
        path2[0] = tokenB;
        path2[1] = weth;
        path2[2] = desiredToken;

        address[] memory adapters = new address[](2);
        adapters[0] = weth_ohm_adapter;
        adapters[1] = usdc_usdcE_adapter;

        address[] memory recipients = new address[](2);
        recipients[0] = weth_ohm;
        recipients[1] = usdc_usdcE_adapter;

        _swapCamelotYak(tokenB, path2, adapters, recipients, _tokenB);
      }

      if (_tokenB > 0 && tokenB == peas) {
        address[] memory path2 = new address[](2);
        path2[0] = tokenB;
        path2[1] = desiredToken;

        address[] memory adapters = new address[](1);
        adapters[0] = usdc_usdcE_adapter;

        _swapCamelotYak(tokenB, path2, adapters, adapters, IERC20(tokenB).balanceOf(address(this)));
      }
      if (_tokenB > 0 && tokenB == gmx) {
        _swapCamelot(tokenB, weth, _tokenB);
        _swapCamelot(weth, desiredToken, IERC20(weth).balanceOf(address(this)));
      }
    }

    address[] memory returnTokens = new address[](6);
    returnTokens[0] = token0;
    returnTokens[1] = token1;
    returnTokens[2] = weth;
    returnTokens[3] = desiredToken;
    returnTokens[4] = tokenA;
    returnTokens[5] = tokenB;

    tokenBalance = IERC20(desiredToken).balanceOf(address(this));

    _returnAssets(returnTokens);

    emit Withdraw(msg.sender, tokenBalance);
  }

  function zapOutAndSwapEth(
    address vault_addr,
    uint256 withdrawAmount,
    uint256 desiredTokenOutMin
  ) public override onlyWhitelistedVaults(vault_addr) returns (uint256 ethBalance) {
    (IVault vault, ICamelotPair pair) = _getVaultPair(vault_addr);
    address token0 = pair.token0();
    address token1 = pair.token1();

    vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
    vault.withdraw(withdrawAmount);
    _removeLiquidity(address(pair), address(this));

    address tokenA = baseToken[token0];
    address tokenB = baseToken[token1];

    if (tokenA != weth) {
      // unbond from apToken get base token
      address[] memory path;
      path = new address[](1);
      path[0] = tokenA;

      uint8[] memory percent;
      percent = new uint8[](1);
      percent[0] = 100;

      WeightedIndex(token0).debond(IERC20(token0).balanceOf(address(this)), path, percent);

      uint256 _tokenA = IERC20(tokenA).balanceOf(address(this));

      if (_tokenA > 0 && tokenA == ohm) {
        address[] memory path2 = new address[](2);
        path2[0] = tokenA;
        path2[1] = weth;

        address[] memory adapters = new address[](1);
        adapters[0] = weth_ohm_adapter;

        address[] memory recipients = new address[](1);
        recipients[0] = weth_ohm;

        _swapCamelotYak(tokenA, path2, adapters, recipients, _tokenA);
      }

      if (_tokenA > 0 && tokenA == peas) {
        address[] memory path2 = new address[](2);
        path2[0] = tokenA;
        path2[1] = weth;

        address[] memory adapters = new address[](1);
        adapters[0] = usdc_usdcE_adapter;

        _swapCamelotYak(tokenA, path2, adapters, adapters, _tokenA);
      }
      if (_tokenA > 0 && tokenA == gmx) {
        _swapCamelot(tokenA, weth, _tokenA);
      }
    }

    if (tokenB != weth) {
      // unbond from apToken get base token
      address[] memory path;
      path = new address[](1);
      path[0] = tokenB;

      uint8[] memory percent;
      percent = new uint8[](1);
      percent[0] = 100;

      WeightedIndex(token1).debond(IERC20(token1).balanceOf(address(this)), path, percent);

      uint256 _tokenB = IERC20(tokenB).balanceOf(address(this));

      if (_tokenB > 0 && tokenB == ohm) {
        address[] memory path2 = new address[](2);
        path2[0] = tokenB;
        path2[1] = weth;

        address[] memory adapters = new address[](1);
        adapters[0] = weth_ohm_adapter;

        address[] memory recipients = new address[](1);
        recipients[0] = weth_ohm;

        _swapCamelotYak(tokenB, path2, adapters, recipients, _tokenB);
      }

      if (_tokenB > 0 && tokenB == peas) {
        address[] memory path2 = new address[](2);
        path2[0] = tokenB;
        path2[1] = weth;

        address[] memory adapters = new address[](1);
        adapters[0] = usdc_usdcE_adapter;

        _swapCamelotYak(tokenB, path2, adapters, adapters, _tokenB);
      }
      if (_tokenB > 0 && tokenB == gmx) {
        _swapCamelot(tokenB, weth, _tokenB);
      }
    }

    address[] memory returnTokens = new address[](5);
    returnTokens[0] = token0;
    returnTokens[1] = token1;
    returnTokens[2] = weth;
    returnTokens[3] = tokenA;
    returnTokens[4] = tokenB;

    ethBalance = IERC20(weth).balanceOf(address(this));

    _returnAssets(returnTokens);

    emit Withdraw(msg.sender, ethBalance);
  }

  function _swapAndStake(
    address vault_addr,
    uint256 tokenAmountOutMin,
    address tokenIn
  ) public override onlyWhitelistedVaults(vault_addr) returns (uint256 vaultBalance) {
    (IVault vault, ICamelotPair pair) = _getVaultPair(vault_addr);

    bool isInputA = pair.token0() == apToken[tokenIn];
    require(isInputA || pair.token1() == apToken[tokenIn], "Input token not present in liquidity pair");

    address tokenOut = isInputA ? baseToken[pair.token1()] : baseToken[pair.token0()];

    // Swap for apToken version and approve
    _bondTokenToIndex(tokenIn, indexUtils);
    _bondTokenToIndex(tokenOut, indexUtils);

    // Add liquidity
    _approveTokenIfNeeded(apToken[tokenIn], address(router));
    _approveTokenIfNeeded(apToken[tokenOut], address(router));
    ICamelotRouter(router).addLiquidity(
      apToken[tokenIn],
      apToken[tokenOut],
      IERC20(apToken[tokenIn]).balanceOf(address(this)),
      IERC20(apToken[tokenOut]).balanceOf(address(this)),
      tokenAmountOutMin,
      tokenAmountOutMin,
      address(this),
      block.timestamp
    );

    // Deposit and transfer balance
    _approveTokenIfNeeded(address(pair), address(vault));
    vault.deposit(IERC20(address(pair)).balanceOf(address(this)));
    vault.safeTransfer(msg.sender, vault.balanceOf(address(this)));

    // Update balance and return assets
    vaultBalance = vault.balanceOf(msg.sender);

    _returnAssets(tokenIn, tokenOut);

    emit Deposit(msg.sender, vaultBalance);
  }

  // Helper function to return assets
  function _returnAssets(address tokenIn, address tokenOut) internal {
    IERC20(tokenIn).safeTransfer(msg.sender, IERC20(tokenIn).balanceOf(address(this)));
    IERC20(tokenOut).safeTransfer(msg.sender, IERC20(tokenOut).balanceOf(address(this)));
  }

  // Helper function to bond token to index
  function _bondTokenToIndex(address token, address index) internal {
    uint256 balance = IERC20(token).balanceOf(address(this));
    IERC20(token).safeApprove(index, 0);
    IERC20(token).safeApprove(index, balance);
    IDecentralizedIndex(index).bond(apToken[token], token, balance, 0);
  }

  function _getSwapAmount(
    uint256 investmentA,
    uint256 reserveA,
    uint256 reserveB
  ) public view override returns (uint256 swapAmount) {
    uint256 halfInvestment = investmentA.div(2);
    uint256 nominator = UniswapRouterV2(router).getAmountOut(halfInvestment, reserveA, reserveB);
    uint256 denominator = ICamelotRouter(router).quote(
      halfInvestment,
      reserveA.add(halfInvestment),
      reserveB.sub(nominator)
    );
    swapAmount = investmentA.sub(Babylonian.sqrt((halfInvestment * halfInvestment * nominator) / denominator));
  }

  function estimateSwap(
    address vault_addr,
    address tokenIn,
    uint256 fullInvestmentIn
  ) public view returns (uint256 swapAmountIn, uint256 swapAmountOut, address swapTokenOut) {
    (, ICamelotPair pair) = _getVaultPair(vault_addr);

    bool isInputA = pair.token0() == apToken[tokenIn];
    require(isInputA || pair.token1() == apToken[tokenIn], "Input token not present in liquidity pair");

    (uint256 reserveA, uint256 reserveB, , ) = pair.getReserves();
    (reserveA, reserveB) = isInputA ? (reserveA, reserveB) : (reserveB, reserveA);

    swapAmountIn = _getSwapAmount(fullInvestmentIn, reserveA, reserveB);
    swapAmountOut = ICamelotPair(address(pair)).getAmountOut(swapAmountIn, apToken[tokenIn]);
    swapTokenOut = isInputA ? pair.token1() : pair.token0();
  }
}
