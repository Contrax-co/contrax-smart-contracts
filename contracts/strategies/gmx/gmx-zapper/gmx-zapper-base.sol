// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../../lib/safe-math.sol";
import "../../../lib/erc20.sol";
import "../../../lib/square-root.sol";
import "../../../interfaces/weth.sol";
import "../../../interfaces/vault.sol";
import "../../../interfaces/uniswapv3.sol";

abstract contract GmxZapperBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IVault;

    address public router;

    address public constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    uint256 public constant minimumAmount = 1000;

    // For this example, we will set the pool fee to 0.3%.
    uint24 public constant poolFee = 3000;

    constructor(address _router) {
        // Safety checks to ensure WETH token address
        WETH(weth).deposit{value: 0}();
        WETH(weth).withdraw(0);
        router = _router;
    }

    receive() external payable {
        assert(msg.sender == weth);
    }

    //returns DUST
    function _returnAssets(address[] memory tokens) internal {
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

    function _swapAndStake(address vault, uint256 tokenAmountOutMin, address tokenIn) public virtual;

    function zapInETH(address vault, uint256 tokenAmountOutMin, address tokenIn) external payable{
        require(msg.value >= minimumAmount, "Insignificant input amount");

        WETH(weth).deposit{value: msg.value}();

        // allows us to zapIn if eth isn't part of the original pair
        if (tokenIn != weth){
            uint256 _amount = IERC20(weth).balanceOf(address(this));

            (, address token) = _getVaultPair(vault);

            bool isInputA = token == tokenIn;
            require(isInputA, "Input token not present in liquidity pair");

            address[] memory path = new address[](2);
            path[0] = weth;
            path[1] = tokenIn;
       
            _approveTokenIfNeeded(path[0], address(router));
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
              tokenIn: path[0],
              tokenOut: path[1],
              fee: poolFee,
              recipient: address(this),
              deadline: block.timestamp,
              amountIn: _amount,
              amountOutMinimum: 0,
              sqrtPriceLimitX96: 0
            });

            // The call to `exactInputSingle` executes the swap.
            ISwapRouter(address(router)).exactInputSingle(params);
            
            _swapAndStake(vault, tokenAmountOutMin, tokenIn);
        }else{
            _swapAndStake(vault, tokenAmountOutMin, tokenIn);
        }
    }


    // transfers tokens from msg.sender to this contract 
    function zapIn(address vault, uint256 tokenAmountOutMin, address tokenIn, uint256 tokenInAmount) external {
        require(tokenInAmount >= minimumAmount, "Insignificant input amount");
        require(IERC20(tokenIn).allowance(msg.sender, address(this)) >= tokenInAmount, "Input token is not approved");

        // transfer token 
        IERC20(tokenIn).safeTransferFrom(
            msg.sender,
            address(this),
            tokenInAmount
        );

        (, address token) = _getVaultPair(vault);

        if(token != tokenIn){
            address[] memory path = new address[](2);
            path[0] = tokenIn;
            path[1] = token;

            _approveTokenIfNeeded(path[0], address(router));
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
                tokenIn: path[0],
                tokenOut: path[1],
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: tokenInAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

            // The call to `exactInputSingle` executes the swap.
            ISwapRouter(address(router)).exactInputSingle(params);
            _swapAndStake(vault, tokenAmountOutMin, token);

        }else {
            _swapAndStake(vault, tokenAmountOutMin, tokenIn);
        }
        
    }

    function zapOutAndSwap(address vault, uint256 withdrawAmount, address desiredToken, uint256 desiredTokenOutMin) public virtual;

    function zapOutAndSwapEth(address vault, uint256 withdrawAmount, uint256 desiredTokenOutMin) public virtual;

    function _getVaultPair(address vault_addr) internal view returns (IVault vault, address token){
        vault = IVault(vault_addr);
        token = vault.token();

        require(token != address(0), "Liquidity pool address cannot be the zero address");
    }

    function _approveTokenIfNeeded(address token, address spender) internal {
        if (IERC20(token).allowance(address(this), spender) == 0) {
            IERC20(token).safeApprove(spender, type(uint256).max);
        }
    }

    function zapOut(address vault_addr, uint256 withdrawAmount) external {
        (IVault vault, address token) = _getVaultPair(vault_addr);

        IERC20(vault_addr).safeTransferFrom(msg.sender, address(this), withdrawAmount);
        vault.withdraw(withdrawAmount);

        address[] memory tokens = new address[](2);
        tokens[0] = token;
        tokens[1] = address(vault.token());

        _returnAssets(tokens);
    }
}