// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../../lib/safe-math.sol";
import "../../../lib/erc20.sol";
import "../../../lib/square-root.sol";
import "../../../interfaces/weth.sol";
import "../../../interfaces/vaultForSteer.sol";
import "../../../interfaces/uniswapv3.sol";

contract SteerZapperBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IVaultForSteer;

    address public router; //0xE592427A0AEce92De3Edee1F18E0157C05861564 Sushi V3 router
    address public constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public governance;

    // Define a mapping to store whether an address is whitelisted or not
    mapping(address => bool) public whitelistedVaults;

    // mapping to store steer vault to local vaults
    mapping(address => address) public steerVaultToLocalVault;

    uint256 public constant minimumAmount = 1000;

    // For this example, we will set the pool fee to 0.3%.
    uint24 public constant poolFee = 3000;

    constructor(address _router, address _governance) {
        // Safety checks to ensure WETH token address
        WETH(weth).deposit{value: 0}();
        WETH(weth).withdraw(0);
        governance = _governance;
        router = _router;
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

    // Function to add local vault against steer vault
    function addLocalVaultToSteerVault(
        address _vault,
        address _localVault
    ) external onlyGovernance {
        steerVaultToLocalVault[_vault] = _localVault;
    }

    // Function to add a vault to the whitelist
    function addToWhitelist(address _vault) external onlyGovernance {
        whitelistedVaults[_vault] = true;
    }

    // Function to remove a vault from the whitelist
    function removeFromWhitelist(address _vault) external onlyGovernance {
        whitelistedVaults[_vault] = false;
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

    function deposit(
        address vault,
        uint256 amount0,
        uint256 amount1
    ) public onlyWhitelistedVaults(vault) {
        address localVault = steerVaultToLocalVault[vault];
        require(
            localVault != address(0),
            "local vault not set against steer vault"
        );

        (address token0, address token1) = IVaultForSteer(vault)
            .steerVaultTokens();

        //transfer both tokens from zapper to local vault
        IERC20(token0).safeTransfer(
            localVault,
            IERC20(token0).balanceOf(address(this))
        );

        IERC20(token1).safeTransfer(
            localVault,
            IERC20(token1).balanceOf(address(this))
        );

        //depoist steer vault shares to local vault
        IVaultForSteer(localVault).deposit(vault, amount0, amount1);

        //return local vaults tokens to user
        IERC20(localVault).safeTransfer(
            msg.sender,
            IERC20(localVault).balanceOf(address(this))
        );
    }

    function _swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) private {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        _approveTokenIfNeeded(path[0], address(router));
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: path[0],
                tokenOut: path[1],
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        ISwapRouter(address(router)).exactInputSingle(params);
    }

    function zapInETH(
        address vault,
        uint256 tokenAmountOutMin,
        address tokenIn
    ) external payable onlyWhitelistedVaults(vault) {
        require(msg.value >= minimumAmount, "Insignificant input amount");
        require(
            steerVaultToLocalVault[vault] != address(0),
            "local vault not set against steer vault"
        );

        WETH(weth).deposit{value: msg.value}();

        (address token0, address token1) = IVaultForSteer(vault)
            .steerVaultTokens();
        uint256 _amount = IERC20(weth).balanceOf(address(this));

        if (tokenIn != token0 && tokenIn != token1) {
            _swap(weth, token0, _amount.div(2));
            _swap(weth, token1, _amount.sub(_amount.div(2)));
        } else {
            address tokenOut = tokenIn == token0 ? token1 : token0;
            _swap(weth, tokenOut, _amount.div(2));
        }

        deposit(
            vault,
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
    }

    function zapIn(
        address vault,
        uint256 tokenAmountOutMin,
        address tokenIn,
        uint256 tokenInAmount
    ) external onlyWhitelistedVaults(vault) {
        require(tokenInAmount >= minimumAmount, "Insignificant input amount");
        require(
            steerVaultToLocalVault[vault] != address(0),
            "local vault not set against steer vault"
        );
        require(
            IERC20(tokenIn).allowance(msg.sender, address(this)) >=
                tokenInAmount,
            "Input token is not approved"
        );

        // transfer token
        IERC20(tokenIn).safeTransferFrom(
            msg.sender,
            address(this),
            tokenInAmount
        );

        (address token0, address token1) = IVaultForSteer(vault)
            .steerVaultTokens();

        //Note : tokenIn pair must exist with both steerVaultTokens
        if (token0 != tokenIn && token1 != tokenIn) {
            _swap(tokenIn, token0, tokenInAmount.div(2));
            _swap(tokenIn, token1, tokenInAmount.sub(tokenInAmount.div(2)));
        } else {
            address tokenOut = tokenIn == token0 ? token1 : token0;
            _swap(weth, tokenOut, tokenInAmount.div(2));
        }

        deposit(
            vault,
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
    }

    function zapOutAndSwap(
        address vault,
        uint256 withdrawAmount,
        address desiredToken,
        uint256 desiredTokenOutMin
    ) public onlyWhitelistedVaults(vault) {
        require(
            steerVaultToLocalVault[vault] != address(0),
            "local vault not set against steer vault"
        );

        address localVault = steerVaultToLocalVault[vault];
        IERC20(localVault).safeTransferFrom(
            msg.sender,
            address(this),
            withdrawAmount
        );

        (uint256 amount0, uint256 amount1) = IVaultForSteer(localVault)
            .withdraw(withdrawAmount);
        (address token0, address token1) = IVaultForSteer(vault)
            .steerVaultTokens();

        // Swapping
        if (token0 != desiredToken) {
            _swap(token0, desiredToken, amount0);
        }

        if (token1 != desiredToken) {
            _swap(token1, desiredToken, amount1);
        }

        address[] memory path = new address[](3);
        path[0] = token0;
        path[1] = token1;
        path[2] = desiredToken;

        _returnAssets(path);
    }

    function zapOutAndSwapEth(
        address vault,
        uint256 withdrawAmount,
        uint256 desiredTokenOutMin
    ) public onlyWhitelistedVaults(vault) {
        require(
            steerVaultToLocalVault[vault] != address(0),
            "local vault not set against steer vault"
        );

        address localVault = steerVaultToLocalVault[vault];
        IERC20(localVault).safeTransferFrom(
            msg.sender,
            address(this),
            withdrawAmount
        );

        (uint256 amount0, uint256 amount1) = IVaultForSteer(localVault)
            .withdraw(withdrawAmount);
        (address token0, address token1) = IVaultForSteer(vault)
            .steerVaultTokens();

        // Swapping
        if (token0 != weth) {
            _swap(token0, weth, amount0);
        }

        if (token1 != weth) {
            _swap(token1, weth, amount1);
        }

        address[] memory path = new address[](3);
        path[0] = token0;
        path[1] = token1;
        path[2] = weth;

        _returnAssets(path);
    }

    function _approveTokenIfNeeded(address token, address spender) internal {
        if (IERC20(token).allowance(address(this), spender) == 0) {
            IERC20(token).safeApprove(spender, type(uint256).max);
        }
    }
}
