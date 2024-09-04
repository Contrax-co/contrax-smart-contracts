// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./fish-zapper-base.sol"; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 


contract FishVaultZapper is FishZapperBaseArbitrum {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IVault;

    constructor()
        FishZapperBaseArbitrum(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506, 0xcDAeC65495Fa5c0545c5a405224214e3594f30d8){}

    function zapOutAndSwap(address vault_addr, uint256 withdrawAmount, address desiredToken, uint256 desiredTokenOutMin) public override sphereXGuardPublic(0x84664a87, 0xf3cc669a) {
        (IVault vault, IUniswapV2Pair pair) = _getVaultPair(vault_addr);
        address token0 = pair.token0();
        address token1 = pair.token1();
        require(token0 == desiredToken || token1 == desiredToken, "desired token not present in liquidity pair");

        vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
        vault.withdraw(withdrawAmount);
        _removeLiquidity(address(pair), address(this));

        address swapToken = token1 == desiredToken ? token0 : token1;
        address[] memory path = new address[](2);
        path[0] = swapToken;
        path[1] = desiredToken;

        _approveTokenIfNeeded(path[0], address(router));
        UniswapRouterV2(router).swapExactTokensForTokens(
            IERC20(swapToken).balanceOf(address(this)),
            desiredTokenOutMin,
            path,
            address(this),
            block.timestamp
        );

        _returnAssets(path);
    }

    struct SwapAndStakeData{
        IVault vault;
        IUniswapV2Pair pair;
        uint256 reserveA;
        uint256 reserveB;
    }

    function _swapAndStake(address vault_addr, uint256 tokenAmountOutMin, address tokenIn) public override sphereXGuardPublic(0xbdec7477, 0xb384bcbc) {
        SwapAndStakeData memory swapStakeData;

        (swapStakeData.vault, swapStakeData.pair) = _getVaultPair(vault_addr);

        (swapStakeData.reserveA, swapStakeData.reserveB, ) = swapStakeData.pair.getReserves();
        require(swapStakeData.reserveA > minimumAmount && swapStakeData.reserveB > minimumAmount, "Liquidity pair reserves too low");

        bool isInputA = swapStakeData.pair.token0() == tokenIn;
        require(isInputA || swapStakeData.pair.token1() == tokenIn, "Input token not present in liquidity pair");

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = isInputA ? swapStakeData.pair.token1() : swapStakeData.pair.token0();

        uint256 fullInvestment = IERC20(tokenIn).balanceOf(address(this));
        uint256 swapAmountIn;
        if (isInputA) {
            swapAmountIn = _getSwapAmount(fullInvestment, swapStakeData.reserveA, swapStakeData.reserveB);
        } else {
            swapAmountIn = _getSwapAmount(fullInvestment, swapStakeData.reserveB, swapStakeData.reserveA);
        }

        _approveTokenIfNeeded(path[0], address(router));
        uint256[] memory swappedAmounts = UniswapRouterV2(router)
            .swapExactTokensForTokens(
                swapAmountIn,
                tokenAmountOutMin,
                path,
                address(this),
                block.timestamp
            );

        _approveTokenIfNeeded(path[1], address(router));
        (, , uint256 amountLiquidity) = UniswapRouterV2(router).addLiquidity(
            path[0],
            path[1],
            fullInvestment.sub(swappedAmounts[0]),
            swappedAmounts[1],
            1,
            1,
            address(this),
            block.timestamp
        );

        _approveTokenIfNeeded(address(swapStakeData.pair), address(swapStakeData.vault));
        swapStakeData.vault.deposit(amountLiquidity);

        //add to guage if possible instead of returning to user, and so no receipt token
        swapStakeData.vault.safeTransfer(msg.sender, swapStakeData.vault.balanceOf(address(this)));

        //taking receipt token and sending back to user
        swapStakeData.vault.safeTransfer(msg.sender, swapStakeData.vault.balanceOf(address(this)));

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