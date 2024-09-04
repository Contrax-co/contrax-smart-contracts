// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../../lib/safe-math.sol";
import "../../../lib/erc20.sol";
import "../../../interfaces/hop.sol";
import "../../../lib/square-root.sol";
import "../../../interfaces/weth.sol";
import "../../../interfaces/vault.sol";
import "../../../interfaces/uniswapv3.sol"; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 

abstract contract HopZapperBase is SphereXProtected {
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
    function addToWhitelist(address _vault) external onlyGovernance sphereXGuardExternal(0x2dc7019b) {
        whitelistedVaults[_vault] = true;
    }

    // Function to remove a vault from the whitelist
    function removeFromWhitelist(address _vault) external onlyGovernance sphereXGuardExternal(0xf3f1986d) {
        whitelistedVaults[_vault] = false;
    }

    //returns DUST
    function _returnAssets(address[] memory tokens) internal sphereXGuardInternal(0x5ec368d0) {
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

    function zapInETH(address vault, uint256 tokenAmountOutMin, address tokenIn) external payable onlyWhitelistedVaults(vault) sphereXGuardExternal(0x734cdde6) {
        require(msg.value >= minimumAmount, "Insignificant input amount");

        WETH(weth).deposit{value: msg.value}();

        // allows us to zapIn if eth isn't part of the original pair
        if (tokenIn != weth){
            uint256 _amount = IERC20(weth).balanceOf(address(this));

            (, IHopSwap pair) = _getVaultPair(vault);

            (address token0) = pair.getToken(0);
            (address token1) = pair.getToken(1); 

            bool isInputA = token0 == tokenIn;
            require(isInputA || token1 == tokenIn, "Input token not present in liquidity pair");

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
    function zapIn(address vault, uint256 tokenAmountOutMin, address tokenIn, uint256 tokenInAmount) external onlyWhitelistedVaults(vault) sphereXGuardExternal(0x18cbbf6b) {
        require(tokenInAmount >= minimumAmount, "Insignificant input amount");
        require(IERC20(tokenIn).allowance(msg.sender, address(this)) >= tokenInAmount, "Input token is not approved");

        // transfer token 
        IERC20(tokenIn).safeTransferFrom(
            msg.sender,
            address(this),
            tokenInAmount
        );

        (, IHopSwap pair) = _getVaultPair(vault);
        (address desiredToken) = pair.getToken(0);

        if(desiredToken != tokenIn){
            address[] memory path = new address[](2);
            path[0] = tokenIn;
            path[1] = desiredToken;

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
            _swapAndStake(vault, tokenAmountOutMin, desiredToken);

        }else {
            _swapAndStake(vault, tokenAmountOutMin, tokenIn);
        }
        
    }

    function zapOutAndSwap(address vault, uint256 withdrawAmount, address desiredToken, uint256 desiredTokenOutMin) public virtual;

    function zapOutAndSwapEth(address vault, uint256 withdrawAmount, uint256 desiredTokenOutMin) public virtual;

    function _removeLiquidity(address token, IHopSwap pair) internal sphereXGuardInternal(0xcf2e6bd6) {
        _approveTokenIfNeeded(token, address(pair));

        uint256[] memory amounts;
        amounts = new uint256[](2);
        amounts[0] = 0;
        amounts[1] = 0;
        IHopSwap(pair).removeLiquidity(IERC20(token).balanceOf(address(this)), amounts, block.timestamp); 

    }

    function _getVaultPair(address vault_addr) internal view returns (IVault vault, IHopSwap pair){
        vault = IVault(vault_addr);
        pair = IHopSwap(ILPToken(vault.token()).swap());

        require(ILPToken(vault.token()).swap() != address(0), "Liquidity pool address cannot be the zero address");
    }

    function _approveTokenIfNeeded(address token, address spender) internal sphereXGuardInternal(0x2c208429) {
        if (IERC20(token).allowance(address(this), spender) == 0) {
            IERC20(token).safeApprove(spender, type(uint256).max);
        }
    }

    function zapOut(address vault_addr, uint256 withdrawAmount) external onlyWhitelistedVaults(vault_addr) sphereXGuardExternal(0x9c3b0ddf) {
        (IVault vault, IHopSwap pair) = _getVaultPair(vault_addr);

        IERC20(vault_addr).safeTransferFrom(msg.sender, address(this), withdrawAmount);
        vault.withdraw(withdrawAmount);

        _removeLiquidity(address(vault.token()), IHopSwap(pair));

        address[] memory tokens = new address[](2);
        tokens[0] = pair.getToken(0);
        tokens[1] = pair.getToken(1);

        _returnAssets(tokens);
    }
}