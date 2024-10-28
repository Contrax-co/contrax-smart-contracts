// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../../lib/safe-math.sol";
import "../../../lib/erc20.sol";
import "../../../lib/square-root.sol";
import "../../../interfaces/weth.sol";
import "../../../interfaces/vault.sol";
import "../../../interfaces/uniswapv3.sol";
import "../../../interfaces/uniswapv2.sol";
import "../../../interfaces/camelot.sol";
import "../../../interfaces/peapods.sol";
import "../../strategy-base-v3.sol";
import "hardhat/console.sol";

abstract contract PeapodsLPZapperBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IVault;
    using SafeERC20 for ICamelotPair;

    address public router;

    address public camelotRouterV3 = 0x1F721E2E82F6676FCE4eA07A5958cF098D339e18;
    address constant CAMELOT_ROUTER_V2 =
        0xc873fEcbd354f5A56E00E710B90EF4201db2448d;

    address public constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public governance;
    address constant ohm = 0xf0cb2dc0db5e6c66B9a70Ac27B06b878da017028;
    address constant peas = 0x02f92800F57BCD74066F5709F1Daa1A4302Df875;
    address constant gmx = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
    address public constant indexUtils =
        0x5c5c288f5EF3559Aaf961c5cCA0e77Ac3565f0C0;

    address public constant zero = 0x0000000000000000000000000000000000000000;

    // Define a mapping to store whether an address is whitelisted or not
    mapping(address => bool) public whitelistedVaults;
    mapping(address => address) public apToken;
    mapping(address => address) public baseToken;

    uint256 public constant minimumAmount = 1000;

    // For this example, we will set the pool fee to 0.3%.
    uint24 public constant poolFee = 3000;

    constructor(address _router, address _governance) {
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

    function setApTokens(
        address _apToken,
        address _baseToken
    ) external onlyGovernance {
        apToken[_baseToken] = _apToken;
    }

    function setBaseTokens(
        address _apToken,
        address _baseToken
    ) external onlyGovernance {
        baseToken[_apToken] = _baseToken;
    }

    function _getSwapAmount(
        uint256 investmentA,
        uint256 reserveA,
        uint256 reserveB
    ) public view virtual returns (uint256 swapAmount);

    // Function to add a vault to the whitelist
    function addToWhitelist(address _vault) external onlyGovernance {
        whitelistedVaults[_vault] = true;
    }

    // Function to remove a vault from the whitelist
    function removeFromWhitelist(address _vault) external onlyGovernance {
        whitelistedVaults[_vault] = false;
    }

    function _swapCamelot(
        address _from,
        address _to,
        uint256 _amount
    ) internal returns (uint256 amountOut) {
        IERC20(_from).safeApprove(camelotRouterV3, 0);
        IERC20(_from).safeApprove(camelotRouterV3, _amount);

        ICamelotRouterV3.ExactInputSingleParams memory params = ICamelotRouterV3
            .ExactInputSingleParams({
                tokenIn: _from,
                tokenOut: _to,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: _amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        amountOut = ICamelotRouterV3(camelotRouterV3).exactInputSingle(params);
    }

    function _swapCamelotWithPathV2(
        address tokenIn,
        address tokenOut,
        uint256 _amount
    ) internal {
        address[] memory path;

        // ohm only has liquidity with eth, so always route with weth to swap ohm
        if (
            tokenIn != weth &&
            tokenOut != weth &&
            (tokenIn == ohm || tokenOut == ohm)
        ) {
            path = new address[](3);
            path[0] = tokenIn;
            path[1] = weth;
            path[2] = tokenOut;

            _approveTokenIfNeeded(weth, address(CAMELOT_ROUTER_V2));
        } else {
            path = new address[](2);
            path[0] = tokenIn;
            path[1] = tokenOut;
        }

        _approveTokenIfNeeded(path[0], address(CAMELOT_ROUTER_V2));

        UniswapRouterV2(CAMELOT_ROUTER_V2).swapExactTokensForTokens(
            _amount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function _swapCamelotWithPath(
        address[] memory path,
        uint256 _amount
    ) internal returns (uint256 amountOut) {
        IERC20(path[0]).safeApprove(camelotRouterV3, 0);
        IERC20(path[0]).safeApprove(camelotRouterV3, _amount);

        ICamelotRouterV3.ExactInputParams memory params = ICamelotRouterV3
            .ExactInputParams({
                path: abi.encodePacked(
                    path[0],
                    poolFee,
                    path[1],
                    poolFee,
                    path[2]
                ),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: _amount,
                amountOutMinimum: 0
            });

        // Executes the swap
        amountOut = ICamelotRouterV3(camelotRouterV3).exactInput(params);
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

    function _swapAndStake(
        address vault,
        uint256 tokenAmountOutMin,
        address tokenIn
    ) public virtual;

    function zapInETH(
        address vault,
        uint256 tokenAmountOutMin,
        address tokenIn
    ) external payable onlyWhitelistedVaults(vault) {
        require(msg.value >= minimumAmount, "Insignificant input amount");

        WETH(weth).deposit{value: msg.value}();

        // allows us to zapIn if eth isn't part of the original pair
        if (tokenIn != weth) {
            uint256 _amount = IERC20(weth).balanceOf(address(this));

            (, ICamelotPair pair) = _getVaultPair(vault);

            (uint256 reserveA, uint256 reserveB, , ) = pair.getReserves();
            require(
                reserveA > minimumAmount && reserveB > minimumAmount,
                "Liquidity pair reserves too low"
            );

            bool isInputA = pair.token0() == apToken[tokenIn];
            require(
                isInputA || pair.token1() == apToken[tokenIn],
                "Input token not present in liquidity pair"
            );

            address[] memory path = new address[](2);
            path[0] = weth;
            path[1] = tokenIn;

            uint256 _passing = IERC20(path[1]).balanceOf(address(this));
            console.log("the amount of token in BEFORE", _passing);

            _swapCamelot(path[0], path[1], _amount);

            _passing = IERC20(path[1]).balanceOf(address(this));
            console.log("the amount of token in", _passing);

            _swapAndStake(vault, tokenAmountOutMin, tokenIn);
        } else {
            _swapAndStake(vault, tokenAmountOutMin, tokenIn);
        }
    }

    // transfers tokens from msg.sender to this contract
    function zapIn(
        address vault,
        uint256 tokenAmountOutMin,
        address tokenIn,
        uint256 tokenInAmount
    ) external onlyWhitelistedVaults(vault) {
        require(tokenInAmount >= minimumAmount, "Insignificant input amount");
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

        (, ICamelotPair pair) = _getVaultPair(vault);
        if (
            apToken[tokenIn] != pair.token0() &&
            apToken[tokenIn] != pair.token1()
        ) {
            address desiredToken = baseToken[pair.token0()];

            if (
                tokenIn != weth &&
                desiredToken != weth &&
                tokenIn != ohm &&
                tokenIn != peas &&
                tokenIn != gmx
            ) {
                // execute swap from tokenin to desired token
                uint256 _amount = IERC20(tokenIn).balanceOf(address(this));

                address[] memory path = new address[](3);
                path[0] = tokenIn;
                path[1] = weth;
                path[2] = desiredToken;

                if (desiredToken == ohm) {
                    _swapCamelot(tokenIn, weth, _amount);
                    _swapCamelotWithPathV2(
                        weth,
                        desiredToken,
                        IERC20(weth).balanceOf(address(this))
                    );
                } else {
                    _swapCamelotWithPath(path, _amount);
                }
            }
            
            _swapAndStake(vault, tokenAmountOutMin, desiredToken);
        } else {
            _swapAndStake(vault, tokenAmountOutMin, tokenIn);
        }
    }

    function zapOutAndSwap(
        address vault,
        uint256 withdrawAmount,
        address desiredToken,
        uint256 desiredTokenOutMin
    ) public virtual;

    function zapOutAndSwapEth(
        address vault,
        uint256 withdrawAmount,
        uint256 desiredTokenOutMin
    ) public virtual;

    function _removeLiquidity(address pair, address to) internal {
        IERC20(pair).safeTransfer(pair, IERC20(pair).balanceOf(address(this)));
        (uint256 amount0, uint256 amount1) = ICamelotPair(pair).burn(to);

        require(amount0 >= minimumAmount, "Router: INSUFFICIENT_A_AMOUNT");
        require(amount1 >= minimumAmount, "Router: INSUFFICIENT_B_AMOUNT");
    }

    function _getVaultPair(
        address vault_addr
    ) internal view returns (IVault vault, ICamelotPair pair) {
        vault = IVault(vault_addr);
        pair = ICamelotPair(vault.token());

        require(
            pair.factory() == ICamelotPair(router).factory(),
            "Incompatible liquidity pair factory"
        );
    }

    function _approveTokenIfNeeded(address token, address spender) internal {
        if (IERC20(token).allowance(address(this), spender) == 0) {
            IERC20(token).safeApprove(spender, type(uint256).max);
        }
    }

    function zapOut(
        address vault_addr,
        uint256 withdrawAmount
    ) external onlyWhitelistedVaults(vault_addr) {
        (IVault vault, ICamelotPair token) = _getVaultPair(vault_addr);

        IERC20(vault_addr).safeTransferFrom(
            msg.sender,
            address(this),
            withdrawAmount
        );
        vault.withdraw(withdrawAmount);

        address[] memory tokens = new address[](2);
        tokens[0] = address(token);
        tokens[1] = address(vault.token());

        _returnAssets(tokens);
    }
}
