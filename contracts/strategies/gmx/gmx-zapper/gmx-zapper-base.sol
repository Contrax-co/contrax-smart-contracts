// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../../lib/safe-math.sol";
import "../../../lib/erc20.sol";
import "../../../lib/square-root.sol";
import "../../../interfaces/weth.sol";
import "../../../interfaces/vault.sol";
import "../../../interfaces/uniswapv3.sol";
import "../../../interfaces/uniswapv2.sol"; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 

abstract contract GmxZapperBase is SphereXProtected {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IVault;

    address public router;

    address public constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public governance;

    // Define a mapping to store whether an address is whitelisted or not
    mapping(address => bool) public whitelistedVaults;

    uint256 public constant minimumAmount = 1000;

    // For this example, we will set the pool fee to 0.3%.
    uint24 public constant poolFee = 3000;

    constructor(
        address _router,
        address _governance
    ) {
        // Safety checks to ensure WETH token address
        WETH(weth).deposit{value: 0}();
        WETH(weth).withdraw(0);
        router = _router;
        governance = _governance;
    }

    receive() external payable {
        assert(msg.sender == weth);
    }

    // **** Modifiers **** //

    // Modifier to restrict access to whitelisted vaults only
    modifier onlyWhitelistedVaults(address vault) {
        require(whitelistedVaults[vault], "Vault is not whitelisted");
        _;
    }

    // Modifier to restrict access to governance only
    modifier onlyGovernance() {
        require(msg.sender == governance, "Caller is not the governance");
        _;
    }
    
    // Function to add a vault to the whitelist
    function addToWhitelist(address _vault) external onlyGovernance sphereXGuardExternal(0xf383c3c5) {
        whitelistedVaults[_vault] = true;
    }

    // Function to remove a vault from the whitelist
    function removeFromWhitelist(address _vault) external onlyGovernance sphereXGuardExternal(0x9f0c1616) {
        whitelistedVaults[_vault] = false;
    }

    //returns DUST
    function _returnAssets(address[] memory tokens) internal sphereXGuardInternal(0xfbd7b6a7) {
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

    function zapInETH(address vault, uint256 tokenAmountOutMin, address tokenIn) external payable onlyWhitelistedVaults(vault) sphereXGuardExternal(0x2a0d9871) {
        require(msg.value >= minimumAmount, "Insignificant input amount");

        WETH(weth).deposit{value: msg.value}();

        (, address token) = _getVaultPair(vault);

        // allows us to zapIn if eth isn't part of the original pair
        if (tokenIn != token){
            uint256 _amount = IERC20(weth).balanceOf(address(this));

            address[] memory path = new address[](2);
            path[0] = weth;
            path[1] = token;
       
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
            
            _swapAndStake(vault, tokenAmountOutMin, token);
        }else{
            _swapAndStake(vault, tokenAmountOutMin, tokenIn);
        }
    }


    // transfers tokens from msg.sender to this contract 
    function zapIn(address vault, uint256 tokenAmountOutMin, address tokenIn, uint256 tokenInAmount) external onlyWhitelistedVaults(vault) sphereXGuardExternal(0xd2645df7) {
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

    function _approveTokenIfNeeded(address token, address spender) internal sphereXGuardInternal(0x33fd16e6) {
        if (IERC20(token).allowance(address(this), spender) == 0) {
            IERC20(token).safeApprove(spender, type(uint256).max);
        }
    }

    function zapOut(address vault_addr, uint256 withdrawAmount) external onlyWhitelistedVaults(vault_addr) sphereXGuardExternal(0xc8ee3aeb) {
        (IVault vault, address token) = _getVaultPair(vault_addr);

        IERC20(vault_addr).safeTransferFrom(msg.sender, address(this), withdrawAmount);
        vault.withdraw(withdrawAmount);

        address[] memory tokens = new address[](2);
        tokens[0] = token;
        tokens[1] = address(vault.token());

        _returnAssets(tokens);
    }
}