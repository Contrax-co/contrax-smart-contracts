// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./gmx-zapper-base.sol";

contract VaultZapperGmx is GmxZapperBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IVault;

    address router2 = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506; 
    address gmx = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;

    constructor()
        GmxZapperBase(0xE592427A0AEce92De3Edee1F18E0157C05861564, 0xCb410A689A03E06de0a6247b13C13D14237DecC8){}

    function zapOutAndSwap(address vault_addr, uint256 withdrawAmount, address desiredToken, uint256 desiredTokenOutMin) public override onlyWhitelistedVaults(vault_addr){
        (IVault vault, address token) = _getVaultPair(vault_addr);

        vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
        vault.withdraw(withdrawAmount);

        if(desiredToken == token){
          address[] memory path = new address[](1);
          path[0] = desiredToken;

          _returnAssets(path);
        }else {
          address[] memory path = new address[](2);
          path[0] = token;
          path[1] = desiredToken;
      
          _approveTokenIfNeeded(path[0], address(router));
          ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: path[0],
            tokenOut: path[1],
            fee: poolFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: IERC20(path[0]).balanceOf(address(this)),
            amountOutMinimum: desiredTokenOutMin,
            sqrtPriceLimitX96: 0
          });

          // The call to `exactInputSingle` executes the swap.
          ISwapRouter(address(router)).exactInputSingle(params);

          address[] memory path2 = new address[](2);
          path2[0] = token;
          path2[1] = desiredToken;

          _returnAssets(path2);
        }
        
    }

    function zapOutAndSwapEth(address vault_addr, uint256 withdrawAmount, uint256 desiredTokenOutMin) public override onlyWhitelistedVaults(vault_addr){
        (IVault vault, address token) = _getVaultPair(vault_addr);

        vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
        vault.withdraw(withdrawAmount);

        if(token == weth){
          address[] memory path = new address[](1);
          path[0] = token;
    
          _returnAssets(path);
        }else {
          address[] memory path = new address[](2);
          path[0] = token;
          path[1] = weth;
      
          _approveTokenIfNeeded(path[0], address(router));
          ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: path[0],
            tokenOut: path[1],
            fee: poolFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: IERC20(path[0]).balanceOf(address(this)),
            amountOutMinimum: desiredTokenOutMin,
            sqrtPriceLimitX96: 0
          });

          // The call to `exactInputSingle` executes the swap.
          ISwapRouter(address(router)).exactInputSingle(params);
          _returnAssets(path);
        }
      
    }

    function _swapAndStake(address vault_addr, uint256 tokenAmountOutMin, address tokenIn) public override onlyWhitelistedVaults(vault_addr){
        (IVault vault, address token) = _getVaultPair(vault_addr);

        bool isInputA = token == tokenIn;
        require(isInputA, "Input token not present in liquidity pair");

        _approveTokenIfNeeded(address(vault.token()), address(vault));
        vault.deposit(IERC20(token).balanceOf(address(this)));

        //add to guage if possible instead of returning to user, and so no receipt token
        vault.safeTransfer(msg.sender, vault.balanceOf(address(this)));
        
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = weth;

        _returnAssets(path);
    }

    function estimateSwap(address vault_addr, address tokenIn, uint256 fullInvestmentIn) public view returns (uint256 swapAmountIn, uint256 swapAmountOut, address swapTokenOut){
        (, address token) = _getVaultPair(vault_addr);

        bool isInputA = token == tokenIn;

        if(isInputA){
          swapAmountOut = fullInvestmentIn; 
          swapAmountIn = fullInvestmentIn;

          swapTokenOut = gmx;


        }else{
            address[] memory path = new address[](2);
            path[0]= tokenIn;
            path[1] = gmx; 

            uint256[] memory amounts = UniswapRouterV2(router).getAmountsOut(
                fullInvestmentIn,
                path
            );

            swapAmountOut = amounts[1]; 
            swapAmountIn = amounts[0];

            swapTokenOut = gmx;

        }
    }
    
}