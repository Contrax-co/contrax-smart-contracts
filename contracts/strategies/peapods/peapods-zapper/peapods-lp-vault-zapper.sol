// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./peapods-lp-zapper-base.sol";

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
  ) public override onlyWhitelistedVaults(vault_addr) {
    (IVault vault, ICamelotPair pair) = _getVaultPair(vault_addr);
    address token0 = pair.token0();
    address token1 = pair.token1();

    vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
    vault.withdraw(withdrawAmount);
    _removeLiquidity(address(pair), address(this));

    if (baseToken[token0] != desiredToken) {
      // unbond from apToken get base token
      address[] memory path;
      path = new address[](1);
      path[0] = baseToken[token0];

      uint8[] memory percent;
      percent = new uint8[](1);
      percent[0] = 100;

      WeightedIndex(token0).debond(IERC20(token0).balanceOf(address(this)), path, percent);

      if (baseToken[token0] != weth && desiredToken != weth) {
        // convert baseToken to desiredToken
        address[] memory tokens = new address[](3);
        tokens[0] = baseToken[token0];
        tokens[1] = weth;
        tokens[2] = desiredToken;

        if (tokens[0] == ohm) {
          _swapCamelotWithPathV2(tokens[0], tokens[1], IERC20(tokens[0]).balanceOf(address(this)));

          _swapCamelot(tokens[1], tokens[2], IERC20(weth).balanceOf(address(this)));
        } else {
          _swapCamelotWithPath(tokens, IERC20(tokens[0]).balanceOf(address(this)));
        }
      } else {
        address[] memory tokens = new address[](2);
        tokens[0] = baseToken[token0];
        tokens[1] = desiredToken;

        _swapCamelot(tokens[0], tokens[1], IERC20(tokens[0]).balanceOf(address(this)));
      }
    }

    if (baseToken[token1] != desiredToken) {
      // unbond from apToken get base token
      address[] memory path;
      path = new address[](1);
      path[0] = baseToken[token1];

      uint8[] memory percent;
      percent = new uint8[](1);
      percent[0] = 100;

      WeightedIndex(token1).debond(IERC20(token1).balanceOf(address(this)), path, percent);

      if (baseToken[token1] != weth && desiredToken != weth) {
        address[] memory tokens = new address[](3);
        tokens[0] = baseToken[token1];
        tokens[1] = weth;
        tokens[2] = desiredToken;

        _swapCamelotWithPath(tokens, IERC20(tokens[0]).balanceOf(address(this)));
      } else {
        address[] memory tokens = new address[](2);
        tokens[0] = baseToken[token1];
        tokens[1] = desiredToken;

        _swapCamelot(tokens[0], tokens[1], IERC20(tokens[0]).balanceOf(address(this)));
      }
    }

    address[] memory returnTokens = new address[](6);
    returnTokens[0] = token0;
    returnTokens[1] = token1;
    returnTokens[2] = weth;
    returnTokens[3] = desiredToken;
    returnTokens[4] = baseToken[token0];
    returnTokens[5] = baseToken[token1];

    uint256 desiredTokenBalance = IERC20(desiredToken).balanceOf(address(this));
    require(desiredTokenBalance >= desiredTokenOutMin, "Insignificant desiredTokenOutMin");

    _returnAssets(returnTokens);
  }

  function zapOutAndSwapEth(
    address vault_addr,
    uint256 withdrawAmount,
    uint256 desiredTokenOutMin
  ) public override onlyWhitelistedVaults(vault_addr) {
    (IVault vault, ICamelotPair pair) = _getVaultPair(vault_addr);
    address token0 = pair.token0();
    address token1 = pair.token1();

    vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
    vault.withdraw(withdrawAmount);
    _removeLiquidity(address(pair), address(this));

    if (baseToken[token0] != weth) {
      // unbond from apToken get base token
      address[] memory path;
      path = new address[](1);
      path[0] = baseToken[token0];

      uint8[] memory percent;
      percent = new uint8[](1);
      percent[0] = 100;

      WeightedIndex(token0).debond(IERC20(token0).balanceOf(address(this)), path, percent);

      address[] memory tokens = new address[](2);
      tokens[0] = baseToken[token0];
      tokens[1] = weth;

      if (tokens[0] == ohm) {
        _swapCamelotWithPathV2(tokens[0], tokens[1], IERC20(tokens[0]).balanceOf(address(this)));
      } else {
        _swapCamelot(tokens[0], tokens[1], IERC20(tokens[0]).balanceOf(address(this)));
      }
    }

    if (baseToken[token1] != weth) {
      // unbond from apToken get base token
      address[] memory path;
      path = new address[](1);
      path[0] = baseToken[token1];

      uint8[] memory percent;
      percent = new uint8[](1);
      percent[0] = 100;

      WeightedIndex(token1).debond(IERC20(token1).balanceOf(address(this)), path, percent);

      address[] memory tokens = new address[](2);
      tokens[0] = baseToken[token1];
      tokens[1] = weth;

      if (tokens[0] == ohm) {
        _swapCamelotWithPathV2(tokens[0], tokens[1], IERC20(tokens[0]).balanceOf(address(this)));
      } else {
        _swapCamelot(tokens[0], tokens[1], IERC20(tokens[0]).balanceOf(address(this)));
      }
    }

    address[] memory returnTokens = new address[](5);
    returnTokens[0] = token0;
    returnTokens[1] = token1;
    returnTokens[2] = weth;
    returnTokens[3] = baseToken[token0];
    returnTokens[4] = baseToken[token1];

    uint256 desiredTokenBalance = IERC20(weth).balanceOf(address(this));
    require(desiredTokenBalance >= desiredTokenOutMin, "Insignificant desiredTokenOutMin");

    _returnAssets(returnTokens);
  }

  function _swapAndStake(
    address vault_addr,
    uint256 tokenAmountOutMin,
    address tokenIn
  ) public override onlyWhitelistedVaults(vault_addr) {
    (IVault vault, ICamelotPair pair) = _getVaultPair(vault_addr);

    (uint256 reserveA, uint256 reserveB, , ) = pair.getReserves();
    require(reserveA > minimumAmount && reserveB > minimumAmount, "Liquidity pair reserves too low");

    bool isInputA = pair.token0() == apToken[tokenIn];
    require(isInputA || pair.token1() == apToken[tokenIn], "Input token not present in liquidity pair");

    address[] memory tokens = new address[](2);
    tokens[0] = tokenIn;
    tokens[1] = isInputA ? baseToken[pair.token1()] : baseToken[pair.token0()];

    uint256 fullInvestment = IERC20(tokens[0]).balanceOf(address(this));

    if (tokenIn != weth && tokens[1] != weth) {
      address[] memory path = new address[](3);
      path[0] = tokens[0];
      path[1] = weth;
      path[2] = tokens[1];

      _swapCamelot(path[0], path[1], fullInvestment.div(2));
      _swapCamelot(path[1], path[2], IERC20(tokens[1]).balanceOf(address(this)));
    } else {
      if (tokens[0] == weth && tokens[1] == ohm) {
        _swapCamelotWithPathV2(tokens[0], tokens[1], fullInvestment.div(2));
      } else {
        _swapCamelot(tokens[0], tokens[1], fullInvestment.div(2));
      }
    }

    // swap for apToken version
    uint256 _want0 = IERC20(tokens[0]).balanceOf(address(this));
    uint256 _want1 = IERC20(tokens[1]).balanceOf(address(this));

    IERC20(tokens[0]).safeApprove(indexUtils, 0);
    IERC20(tokens[0]).safeApprove(indexUtils, _want0);
    IDecentralizedIndex(indexUtils).bond(apToken[tokens[0]], tokens[0], _want0, 0);

    IERC20(tokens[1]).safeApprove(indexUtils, 0);
    IERC20(tokens[1]).safeApprove(indexUtils, _want1);
    IDecentralizedIndex(indexUtils).bond(apToken[tokens[1]], tokens[1], _want1, 0);

    _approveTokenIfNeeded(apToken[tokens[0]], address(router));
    _approveTokenIfNeeded(apToken[tokens[1]], address(router));
    ICamelotRouter(router).addLiquidity(
      apToken[tokens[0]],
      apToken[tokens[1]],
      IERC20(apToken[tokens[0]]).balanceOf(address(this)),
      IERC20(apToken[tokens[1]]).balanceOf(address(this)),
      1,
      1,
      address(this),
      block.timestamp
    );

    _approveTokenIfNeeded(address(pair), address(vault));
    vault.deposit(IERC20(address(pair)).balanceOf(address(this)));

    //add to guage if possible instead of returning to user, and so no receipt token
    uint256 vaultBalance = vault.balanceOf(address(this));
    require(vaultBalance >= tokenAmountOutMin, "Insignificant amountOutMin");

    vault.safeTransfer(msg.sender, vaultBalance);
    _returnAssets(tokens);
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
