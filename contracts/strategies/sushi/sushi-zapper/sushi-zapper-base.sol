// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../../lib/safe-math.sol";
import "../../../lib/erc20.sol";
import "../../../interfaces/uniswapv2.sol";
import "../../../lib/square-root.sol";
import "../../../interfaces/weth.sol";
import "../../../interfaces/vault.sol"; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 

abstract contract SushiZapperBase is SphereXProtected {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IVault;

    address public router;

    address public constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    uint256 public constant minimumAmount = 1000;

    constructor(address _router) {
        // Safety checks to ensure WETH token address
        WETH(weth).deposit{value: 0}();
        WETH(weth).withdraw(0);
        router = _router;
    }

    receive() external payable {
        assert(msg.sender == weth);
    }

    function _getSwapAmount(uint256 investmentA, uint256 reserveA, uint256 reserveB) public view virtual returns (uint256 swapAmount);

    //returns DUST
    function _returnAssets(address[] memory tokens) internal sphereXGuardInternal(0x84cf7e33) {
        uint256 balance;
        for (uint256 i; i < tokens.length; i++) {
            balance = IERC20(tokens[i]).balanceOf(address(this));
            if (balance > 0) {
                if (tokens[i] == weth) {
                    WETH(weth).withdraw(balance);
                    (bool success, ) = msg.sender.call{value: balance}(
                        new bytes(0)
                    );
                    require(success, "ETH transfer failed");
                } else {
                    IERC20(tokens[i]).safeTransfer(msg.sender, balance);
                }
            }
        }
    }

    function _swapAndStake(address vault_addr, uint256 tokenAmountOutMin, address tokenIn) public virtual;

    function zapInETH(address vault_addr, uint256 tokenAmountOutMin, address tokenIn) external payable sphereXGuardExternal(0x2f5804f3) {
        require(msg.value >= minimumAmount, "Insignificant input amount");

        WETH(weth).deposit{value: msg.value}();

        // allows us to zapIn if eth isn't part of the original pair
        if (tokenIn != weth){
            uint256 _amount = IERC20(weth).balanceOf(address(this));

            (, IUniswapV2Pair pair) = _getVaultPair(vault_addr);

            (uint256 reserveA, uint256 reserveB, ) = pair.getReserves();
            require(reserveA > minimumAmount && reserveB > minimumAmount, "Liquidity pair reserves too low");

            bool isInputA = pair.token0() == tokenIn;
            require(isInputA || pair.token1() == tokenIn, "Input token not present in liquidity pair");

            address[] memory path = new address[](2);
            path[0] = weth;
            path[1] = tokenIn;

            _approveTokenIfNeeded(path[0], address(router));
            UniswapRouterV2(router).swapExactTokensForTokens(
                _amount,
                tokenAmountOutMin,
                path,
                address(this),
                block.timestamp
            );
            
            _swapAndStake(vault_addr, tokenAmountOutMin, tokenIn);
        }else{
            _swapAndStake(vault_addr, tokenAmountOutMin, tokenIn);
        }
    }

    // transfers tokens from msg.sender to this contract 
    function zapIn(address vault_addr, uint256 tokenAmountOutMin, address tokenIn, uint256 tokenInAmount) external sphereXGuardExternal(0x916251e6) {
        require(tokenInAmount >= minimumAmount, "Insignificant input amount");
        require(IERC20(tokenIn).allowance(msg.sender, address(this)) >= tokenInAmount, "Input token is not approved");

        // transfer token 
        IERC20(tokenIn).safeTransferFrom(
            msg.sender,
            address(this),
            tokenInAmount
        );

        (, IUniswapV2Pair pair) = _getVaultPair(vault_addr);

        if(tokenIn != pair.token0() && tokenIn != pair.token1()){
            (address desiredToken) = pair.token0();

            if(tokenIn != weth && desiredToken != weth){
                // execute swap from tokenin to desired token
                uint256 _amount = IERC20(tokenIn).balanceOf(address(this));

                address[] memory path = new address[](3);
                path[0] = tokenIn;
                path[1] = weth;
                path[2] = desiredToken;
        
                _approveTokenIfNeeded(path[0], address(router));
                UniswapRouterV2(router).swapExactTokensForTokens(
                    _amount,
                    tokenAmountOutMin,
                    path,
                    address(this),
                    block.timestamp
                );
            }else {
                // execute swap from tokenin to desired token
                uint256 _amount = IERC20(tokenIn).balanceOf(address(this));

                address[] memory path = new address[](2);
                path[0] = tokenIn;
                path[1] = desiredToken;
        
                _approveTokenIfNeeded(path[0], address(router));
                UniswapRouterV2(router).swapExactTokensForTokens(
                    _amount,
                    tokenAmountOutMin,
                    path,
                    address(this),
                    block.timestamp
                );
            }
            _swapAndStake(vault_addr, tokenAmountOutMin, desiredToken);
        }else{
            _swapAndStake(vault_addr, tokenAmountOutMin, tokenIn);
        }
   
    }

    function zapOutAndSwap(address vault_addr, uint256 withdrawAmount, address desiredToken, uint256 desiredTokenOutMin) public virtual;

    function zapOutAndSwapEth(address vault, uint256 withdrawAmount, uint256 desiredTokenOutMin) public virtual;

    function _removeLiquidity(address pair, address to) internal sphereXGuardInternal(0x570acd76) {
        IERC20(pair).safeTransfer(pair, IERC20(pair).balanceOf(address(this)));
        (uint256 amount0, uint256 amount1) = IUniswapV2Pair(pair).burn(to);

        require(amount0 >= minimumAmount, "Router: INSUFFICIENT_A_AMOUNT");
        require(amount1 >= minimumAmount, "Router: INSUFFICIENT_B_AMOUNT");
    }

    function _getVaultPair(address vault_addr) internal view returns (IVault vault, IUniswapV2Pair pair){
        vault = IVault(vault_addr);
        pair = IUniswapV2Pair(vault.token());

        require(pair.factory() == IUniswapV2Pair(router).factory(), "Incompatible liquidity pair factory");
    }

    function _approveTokenIfNeeded(address token, address spender) internal sphereXGuardInternal(0x5aded1dc) {
        if (IERC20(token).allowance(address(this), spender) == 0) {
            IERC20(token).safeApprove(spender, type(uint256).max);
        }
    }

    function zapOut(address vault_addr, uint256 withdrawAmount) external sphereXGuardExternal(0x421eac04) {
        (IVault vault, IUniswapV2Pair pair) = _getVaultPair(vault_addr);

        IERC20(vault_addr).safeTransferFrom(msg.sender, address(this), withdrawAmount);
        vault.withdraw(withdrawAmount);

        if (pair.token0() != weth && pair.token1() != weth) {
            return _removeLiquidity(address(pair), msg.sender);
        }


        _removeLiquidity(address(pair), address(this));

        address[] memory tokens = new address[](2);
        tokens[0] = pair.token0();
        tokens[1] = pair.token1();

        _returnAssets(tokens);
    }
}