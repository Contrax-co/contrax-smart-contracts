// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./hop-zapper-base.sol";

contract VaultZapperHop is HopZapperBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IVault;

    constructor()
        HopZapperBase(0xE592427A0AEce92De3Edee1F18E0157C05861564){}

    function zapOutAndSwap(address vault_addr, uint256 withdrawAmount, address desiredToken, uint256 desiredTokenOutMin) public override {
        (IVault vault, IHopSwap pair) = _getVaultPair(vault_addr);
        (address token0) = pair.getToken(0);
        (address token1) = pair.getToken(1); 

        vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
        vault.withdraw(withdrawAmount);
        _removeLiquidity(address(vault.token()), IHopSwap(pair));

        _approveTokenIfNeeded(token1, address(pair));
        IHopSwap(pair).swap(
          1,
          0,
          IERC20(token1).balanceOf(address(this)),
          desiredTokenOutMin,
          block.timestamp
        );

        if(desiredToken == token0){
          address[] memory path = new address[](2);
          path[0] = token0;
          path[1] = token1;

          _returnAssets(path);
        }else {
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

          _returnAssets(path2);
        }
        
    }

    function zapOutAndSwapEth(address vault_addr, uint256 withdrawAmount, uint256 desiredTokenOutMin) public override {
        (IVault vault, IHopSwap pair) = _getVaultPair(vault_addr);

        (address token0) = pair.getToken(0);
        (address token1) = pair.getToken(1); 

        vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
        vault.withdraw(withdrawAmount);
        _removeLiquidity(address(vault.token()), IHopSwap(pair));

        _approveTokenIfNeeded(token1, address(pair));
        IHopSwap(pair).swap(
          1,
          0,
          IERC20(token1).balanceOf(address(this)),
          desiredTokenOutMin,
          block.timestamp
        );

        if(token0 == weth){
          address[] memory path = new address[](2);
          path[0] = token0;
          path[1] = token1;

          _returnAssets(path);
        }else {

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

          _returnAssets(path);
        }
      
    }

    function _swapAndStake(address vault_addr, uint256 tokenAmountOutMin, address tokenIn) public override {
        (IVault vault, IHopSwap pair) = _getVaultPair(vault_addr);

        (address token0) = pair.getToken(0);
        (address token1) = pair.getToken(1); 

        bool isInputA = token0 == tokenIn;
        require(isInputA || token1 == tokenIn, "Input token not present in liquidity pair");

        (uint256 _tokenBalance0) = IHopSwap(pair).getTokenBalance(0);
        (uint256 _tokenBalance1) = IHopSwap(pair).getTokenBalance(1);

        if(_tokenBalance0 > _tokenBalance1){
          uint256 fullInvestment = IERC20(tokenIn).balanceOf(address(this));
          _approveTokenIfNeeded(token0, address(pair)); 

          IHopSwap(pair).swap(
              0, 
              1, 
              fullInvestment, 
              tokenAmountOutMin, 
              block.timestamp
          ); 
        }

        // Adds in liquidity for token0/token1
        uint256 _token0 = IERC20(token0).balanceOf(address(this));
        uint256 _token1 = IERC20(token1).balanceOf(address(this));

        uint256[] memory amounts;
        amounts = new uint256[](2);
        amounts[0] = _token0;
        amounts[1] = _token1;
        
        _approveTokenIfNeeded(token0, address(pair));
        _approveTokenIfNeeded(token1, address(pair));

        uint256 amountLiquidity = IHopSwap(pair).addLiquidity(
            amounts, 
            0, 
            block.timestamp
        );

        _approveTokenIfNeeded(address(vault.token()), address(vault));
        vault.deposit(amountLiquidity);

        //add to guage if possible instead of returning to user, and so no receipt token
        vault.safeTransfer(msg.sender, vault.balanceOf(address(this)));

        //taking receipt token and sending back to user
        vault.safeTransfer(msg.sender, vault.balanceOf(address(this)));

        address[] memory path = new address[](2);
        path[0] = token0;
        path[1] = token1;

        _returnAssets(path);
    }

    function estimateSwap(address vault_addr, address tokenIn, uint256 fullInvestmentIn) public view returns (uint256 swapAmountIn, uint256 swapAmountOut, address swapTokenOut){
        (IVault vault, IHopSwap pair) = _getVaultPair(vault_addr);

        bool isInputA = pair.getToken(0) == tokenIn;
        require(isInputA || pair.getToken(1) == tokenIn, "Input token not present in liquidity pair");

        (uint256 reserveA) = pair.getTokenBalance(0);
        (uint256 reserveB) = pair.getTokenBalance(1);

        if(isInputA){
          if(reserveA >= reserveB){
            uint256 _tokenOut = pair.calculateSwap(0, 1, fullInvestmentIn); 

            uint256[] memory amounts;
            amounts = new uint256[](2);
            amounts[0] = 0;
            amounts[1] = _tokenOut;

            swapAmountOut = pair.calculateTokenAmount(address(this), amounts, true); 
          }
        }else {
          if(reserveB >= reserveA){
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