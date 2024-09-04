// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./sushi-zapper-base.sol"; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 

contract VaultZapperSushi is SushiZapperBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IVault;

    constructor()
      SushiZapperBase(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506){}

    function zapOutAndSwap(address vault_addr, uint256 withdrawAmount, address desiredToken, uint256 desiredTokenOutMin) public override sphereXGuardPublic(0xee43f8c6, 0xf3cc669a) {
        (IVault vault, IUniswapV2Pair pair) = _getVaultPair(vault_addr);
        address token0 = pair.token0();
        address token1 = pair.token1();

        vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
        vault.withdraw(withdrawAmount);
        _removeLiquidity(address(pair), address(this));

        if(token0 != desiredToken){

          if(token0 != weth && desiredToken != weth){
              address[] memory path = new address[](3);
              path[0] = token0;
              path[1] = weth;
              path[2] = desiredToken;

              _approveTokenIfNeeded(path[0], address(router));
              UniswapRouterV2(router).swapExactTokensForTokens(
                  IERC20(token0).balanceOf(address(this)),
                  desiredTokenOutMin,
                  path,
                  address(this),
                  block.timestamp
              );

          } else {
              address[] memory path = new address[](2);
              path[0] = token0;
              path[1] = desiredToken;

              _approveTokenIfNeeded(path[0], address(router));
              UniswapRouterV2(router).swapExactTokensForTokens(
                  IERC20(token0).balanceOf(address(this)),
                  desiredTokenOutMin,
                  path,
                  address(this),
                  block.timestamp
              );
          }
         
        }

        if(token1 != desiredToken){
          if(token1 != weth && desiredToken != weth){
              address[] memory path = new address[](3);
              path[0] = token1;
              path[1] = weth;
              path[2] = desiredToken;

              _approveTokenIfNeeded(path[1], address(router));
              UniswapRouterV2(router).swapExactTokensForTokens(
                  IERC20(token1).balanceOf(address(this)),
                  desiredTokenOutMin,
                  path,
                  address(this),
                  block.timestamp
              );

          } else {
              address[] memory path = new address[](2);
              path[0] = token1;
              path[1] = desiredToken;

              _approveTokenIfNeeded(path[1], address(router));
              UniswapRouterV2(router).swapExactTokensForTokens(
                  IERC20(token1).balanceOf(address(this)),
                  desiredTokenOutMin,
                  path,
                  address(this),
                  block.timestamp
              );
          }
        
        }

          address[] memory path2 = new address[](4);
          path2[0] = token0; 
          path2[1] = token1;
          path2[2] = weth; 
          path2[3] = desiredToken;

        _returnAssets(path2);
    }

    function zapOutAndSwapEth(address vault_addr, uint256 withdrawAmount, uint256 desiredTokenOutMin) public override sphereXGuardPublic(0xd4af6a4a, 0x02006da0) {
        (IVault vault, IUniswapV2Pair pair) = _getVaultPair(vault_addr);

        address token0 = pair.token0();
        address token1 = pair.token1();

        vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
        vault.withdraw(withdrawAmount);
        _removeLiquidity(address(pair), address(this));

        if(token0 != weth){
          address[] memory path = new address[](2);
          path[0] = token0;
          path[1] = weth;
      
          _approveTokenIfNeeded(path[0], address(router));
          UniswapRouterV2(router).swapExactTokensForTokens(
              IERC20(token0).balanceOf(address(this)),
              desiredTokenOutMin,
              path,
              address(this),
              block.timestamp
          );
        }

        if(token1 != weth){
          address[] memory path = new address[](2);
          path[0] = token1;
          path[1] = weth;
      
          _approveTokenIfNeeded(path[1], address(router));
          UniswapRouterV2(router).swapExactTokensForTokens(
              IERC20(token1).balanceOf(address(this)),
              desiredTokenOutMin,
              path,
              address(this),
              block.timestamp
          );

        }

        address[] memory path2 = new address[](3);
        path2[0] = token0;
        path2[1] = token1;
        path2[2] = weth; 

        _returnAssets(path2);

    }

    function _swapAndStake(address vault_addr, uint256 tokenAmountOutMin, address tokenIn) public override sphereXGuardPublic(0xb5478cf3, 0xb384bcbc) {
        (IVault vault, IUniswapV2Pair pair) = _getVaultPair(vault_addr);

        (uint256 reserveA, uint256 reserveB, ) = pair.getReserves();
        require(reserveA > minimumAmount && reserveB > minimumAmount, "Liquidity pair reserves too low");

        bool isInputA = pair.token0() == tokenIn;
        require(isInputA || pair.token1() == tokenIn, "Input token not present in liquidity pair");

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = isInputA ? pair.token1() : pair.token0();

        uint256 fullInvestment = IERC20(tokenIn).balanceOf(address(this));

        if(tokenIn != weth && path[1] != weth){
            address[] memory path1 = new address[](3);
            path1[0] = tokenIn;
            path1[1] = weth;
            path1[2] = isInputA ? pair.token1() : pair.token0();
            _approveTokenIfNeeded(path1[0], address(router));
            UniswapRouterV2(router).swapExactTokensForTokens(
                fullInvestment.div(2),
                tokenAmountOutMin,
                path1,
                address(this),
                block.timestamp
            );

        } else{
            _approveTokenIfNeeded(path[0], address(router));
            UniswapRouterV2(router).swapExactTokensForTokens(
                fullInvestment.div(2),
                tokenAmountOutMin,
                path,
                address(this),
                block.timestamp
            );

        }
      
        _approveTokenIfNeeded(path[1], address(router));
        (, , uint256 amountLiquidity) = UniswapRouterV2(router).addLiquidity(
            path[0],
            path[1],
            IERC20(path[0]).balanceOf(address(this)),
            IERC20(path[1]).balanceOf(address(this)),
            1,
            1,
            address(this),
            block.timestamp
        );

        _approveTokenIfNeeded(address(pair), address(vault));
        vault.deposit(amountLiquidity);

        //add to guage if possible instead of returning to user, and so no receipt token
        vault.safeTransfer(msg.sender, vault.balanceOf(address(this)));

        //taking receipt token and sending back to user
        vault.safeTransfer(msg.sender, vault.balanceOf(address(this)));

        _returnAssets(path);
    }

    function _getSwapAmount(uint256 investmentA, uint256 reserveA, uint256 reserveB) public view override returns (uint256 swapAmount) {
        uint256 halfInvestment = investmentA.div(2);
        uint256 nominator = UniswapRouterV2(router).getAmountOut(
            halfInvestment,
            reserveA,
            reserveB
        );
        uint256 denominator = UniswapRouterV2(router).quote(
            halfInvestment,
            reserveA.add(halfInvestment),
            reserveB.sub(nominator)
        );
        swapAmount = investmentA.sub(
            Babylonian.sqrt(
                (halfInvestment * halfInvestment * nominator) / denominator
            )
        );
    }

    function estimateSwap(address vault_addr, address tokenIn, uint256 fullInvestmentIn) public view returns (uint256 swapAmountIn, uint256 swapAmountOut, address swapTokenOut){
        (, IUniswapV2Pair pair) = _getVaultPair(vault_addr);

        bool isInputA = pair.token0() == tokenIn;
        require(isInputA || pair.token1() == tokenIn, "Input token not present in liquidity pair");

        (uint256 reserveA, uint256 reserveB, ) = pair.getReserves();
        (reserveA, reserveB) = isInputA ? (reserveA, reserveB) : (reserveB, reserveA);

        swapAmountIn = _getSwapAmount(fullInvestmentIn, reserveA, reserveB);
        swapAmountOut = UniswapRouterV2(router).getAmountOut(
            swapAmountIn,
            reserveA,
            reserveB
        );
        swapTokenOut = isInputA ? pair.token1() : pair.token0();
    }
}