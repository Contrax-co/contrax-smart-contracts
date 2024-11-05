// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "../../../lib/safe-math.sol";
// import "../../../lib/erc20.sol";
// import "../../../lib/square-root.sol";
// import "../../../interfaces/weth.sol";
// import "../../../interfaces/vault.sol";
// import "../../../interfaces/uniswapv3.sol";
// import "../../../interfaces/IGamma.sol";
// import "hardhat/console.sol";

// contract GammaZapperBase {
//   using SafeERC20 for IERC20;
//   using Address for address;
//   using SafeMath for uint256;
//   using SafeERC20 for IVault;

//   address public router; // V3 router
//   address public V3Factory;
//   address public wPol;
//   address public GAMMA_UNIPROXY;
//   address public governance;

//   uint24[] public poolsFee = [3000, 500, 100, 350, 80, 10000];

//   // Define a mapping to store whether an address is whitelisted or not
//   mapping(address => bool) public whitelistedVaults;
//   // tokenIn => tokenOut => poolFee
//   mapping(address => mapping(address => uint24)) public poolFees;

//   uint256 public constant minimumAmount = 1000;

//   uint256[4] minInAmounts = [0, 0, 0, 0];

//   constructor(
//     address _governance,
//     address _weth,
//     address _router,
//     address _V3Factory,
//     address _gammaUniproxy,
//     address[] memory _vaults
//   ) {
//     router = _router;
//     V3Factory = _V3Factory;
//     GAMMA_UNIPROXY = _gammaUniproxy;
//     wPol = _weth;
//     governance = _governance;

//     // Safety checks to ensure WETH token address`

//     WETH(wPol).deposit{value: 0}();
//     WETH(wPol).withdraw(0);

//     for (uint i = 0; i < _vaults.length; i++) {
//       whitelistedVaults[_vaults[i]] = true;
//     }
//   }

//   event Deposit(address indexed recipient, uint256 amountIn);
//   event Withdraw(address indexed recipient, uint256 amountOut);

//   receive() external payable {
//     assert(msg.sender == wPol);
//   }

//   // Modifier to restrict access to governance only
//   modifier onlyGovernance() {
//     require(msg.sender == governance, "Caller is not the governance");
//     _;
//   }

//   // **** Modifiers **** //

//   // Modifier to restrict access to whitelisted vaults only
//   modifier onlyWhitelistedVaults(address vault) {
//     require(whitelistedVaults[vault], "Vault is not whitelisted");
//     _;
//   }

//   function getPoolFee(address token0, address token1) public view returns (uint24) {
//     uint24 fee = poolFees[token0][token1];
//     require(fee > 0, "pool fee is not set");
//     return fee;
//   }

//   function setSwapAddresses(address _weth, address _router, address _V3Factory) external onlyGovernance {
//     wPol = _weth;
//     router = _router;
//     V3Factory = _V3Factory;
//   }

//   // Function to add a vault to the whitelist
//   function addToWhitelist(address _vault) external onlyGovernance {
//     whitelistedVaults[_vault] = true;
//   }

//   function setPoolFees(address _token0, address _token1, uint24 _poolFee) external onlyGovernance {
//     require(_poolFee > 0, "pool fee must be greater than 0");
//     require(_token0 != address(0) && _token1 != address(0), "invalid address");

//     poolFees[_token0][_token1] = _poolFee;
//     // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
//     poolFees[_token1][_token0] = _poolFee;
//   }

//   // Function to remove a vault from the whitelist
//   function removeFromWhitelist(address _vault) external onlyGovernance {
//     whitelistedVaults[_vault] = false;
//   }

//   //returns DUST
//   function _returnAssets(address[] memory tokens) internal {
//     uint256 balance;
//     for (uint256 i; i < tokens.length; i++) {
//       balance = IERC20(tokens[i]).balanceOf(address(this));
//       if (balance > 0) {
//         if (tokens[i] == wPol) {
//           WETH(wPol).withdraw(balance);
//           (bool success, ) = msg.sender.call{value: balance}(new bytes(0));
//           require(success, "ETH transfer failed");
//         } else {
//           IERC20(tokens[i]).safeTransfer(msg.sender, balance);
//         }
//       }
//     }
//   }

//   function getGammaVaultDepoistAmount(
//     address gammaVault,
//     address token,
//     uint256 _depositAmount
//   ) public view returns (uint256 minAmount, uint256 maxAmount) {
//     (minAmount, maxAmount) = IUniProxy(GAMMA_UNIPROXY).getDepositAmount(gammaVault, token, _depositAmount);
//   }

//   function deposit(
//     IVault vault,
//     uint256 amount0,
//     uint256 amount1,
//     uint256 amountOutMin
//   ) public onlyWhitelistedVaults(address(vault)) returns (uint256) {
//     (address token0, address token1) = gammaVaultTokens(vault);

//     //Deposit tokens to steer vault tokens

//     //get gamma vault from local vault
//     address _gammaVault = vault.token();

//     _approveTokenIfNeeded(token0, _gammaVault);
//     _approveTokenIfNeeded(token1, _gammaVault);

//     //get tokenO amount to deposit into Gamma UniProxy contract
//     (, uint256 token1AmountMax) = getGammaVaultDepoistAmount(_gammaVault, token0, amount0);

//     require(token1AmountMax < amount1, "token1 amount is less then predicted deposit amount");
//     //deposit into Gamma UniProxy contract
//     uint256 shares = IUniProxy(GAMMA_UNIPROXY).deposit(
//       amount0,
//       token1AmountMax,
//       address(this),
//       _gammaVault,
//       minInAmounts
//     );

//     //depoist gamma vault shares to local vault
//     _approveTokenIfNeeded(_gammaVault, address(vault));

//     vault.deposit(shares);

//     uint256 vaultBalance = vault.balanceOf(address(this));

//     require(vaultBalance >= amountOutMin, "Insignificant amountOutMin");

//     //return vault tokens to user
//     IERC20(address(vault)).safeTransfer(msg.sender, vaultBalance);

//     address[] memory tokens = new address[](2);
//     tokens[0] = token0;
//     tokens[1] = token1;

//     _returnAssets(tokens);

//     emit Deposit(msg.sender, vaultBalance);

//     return vaultBalance;
//   }

//   function _swap(address tokenIn, address tokenOut, uint256 amountIn) private {
//     address[] memory path = new address[](2);
//     path[0] = tokenIn;
//     path[1] = tokenOut;

//     if (poolFees[tokenIn][tokenOut] == 0) fetchPool(tokenIn, tokenOut, V3Factory);

//     _approveTokenIfNeeded(path[0], address(router));
//     ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
//       tokenIn: path[0],
//       tokenOut: path[1],
//       fee: getPoolFee(tokenIn, tokenOut),
//       recipient: address(this),
//       deadline: block.timestamp,
//       amountIn: amountIn,
//       amountOutMinimum: 0,
//       sqrtPriceLimitX96: 0
//     });

//     ISwapRouter(address(router)).exactInputSingle(params);
//   }

//   function fetchPool(address token0, address token1, address _uniV3Factory) internal returns (address) {
//     address pairWithMaxLiquidity = address(0);
//     uint256 maxLiquidity = 0;

//     for (uint256 i = 0; i < poolsFee.length; i++) {
//       address currentPair = IUniswapV3Factory(_uniV3Factory).getPool(token0, token1, poolsFee[i]);
//       if (currentPair != address(0)) {
//         uint256 currentLiquidity = IUniswapV3Pool(currentPair).liquidity();
//         if (currentLiquidity > maxLiquidity) {
//           maxLiquidity = currentLiquidity;
//           pairWithMaxLiquidity = currentPair;
//           poolFees[token0][token1] = poolsFee[i];
//           // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
//           poolFees[token1][token0] = poolsFee[i];
//         }
//       }
//     }
//     require(pairWithMaxLiquidity != address(0), "No pool found with sufficient liquidity");
//     return pairWithMaxLiquidity;
//   }

//   function calculateGammaVaultTokensAmount(
//     uint256 amount
//   ) internal pure returns (uint256 token0Amount, uint256 token1Amount) {
//     // split amount into half for token0 and half for token1
//     token0Amount = amount / 2;
//     token1Amount = amount - token0Amount;
//   }

//   function zapInETH(
//     IVault vault,
//     uint256 tokenAmountOutMin,
//     address tokenIn
//   ) external payable onlyWhitelistedVaults(address(vault)) returns (uint256 vaultBalance) {
//     //get tokenAmount

//     WETH(wPol).deposit{value: msg.value}();
//     uint256 _amountIn = IERC20(wPol).balanceOf(address(this));
//     (address token0, address token1) = gammaVaultTokens(vault);
//     require(_amountIn >= minimumAmount, "Insignificant input amount");

//     (uint256 tokenInAmount0, uint256 tokenInAmount1) = calculateGammaVaultTokensAmount(_amountIn);

//     if (tokenIn != token0 && tokenIn != token1) {
//       _swap(wPol, token0, tokenInAmount0);
//       _swap(wPol, token1, tokenInAmount1);
//     } else {
//       address tokenOut = token0;
//       uint256 amountToSwap = tokenInAmount0;
//       if (tokenIn == token0) {
//         tokenOut = token1;
//         amountToSwap = tokenInAmount1;
//       }
//       _swap(wPol, tokenOut, amountToSwap);
//     }

//     vaultBalance = deposit(
//       vault,
//       IERC20(token0).balanceOf(address(this)),
//       IERC20(token1).balanceOf(address(this)),
//       tokenAmountOutMin
//     );
//   }

//   function zapIn(
//     IVault vault,
//     uint256 tokenAmountOutMin,
//     address tokenIn,
//     uint256 tokenInAmount
//   ) external onlyWhitelistedVaults(address(vault)) returns (uint256 vaultBalance) {
//     require(tokenInAmount >= minimumAmount, "Insignificant input amount");
//     require(IERC20(tokenIn).allowance(msg.sender, address(this)) >= tokenInAmount, "Input token is not approved");

//     (address token0, address token1) = gammaVaultTokens(vault);
//     // transfer token
//     IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), tokenInAmount);

//     (uint256 tokenInAmount0, uint256 tokenInAmount1) = calculateGammaVaultTokensAmount(tokenInAmount);

//     //Note : tokenIn pair must exist withsteerVaultTokens
//     if (token0 != tokenIn && token1 != tokenIn) {
//       _swap(tokenIn, token0, tokenInAmount0);
//       _swap(tokenIn, token1, tokenInAmount1);
//     } else {
//       address tokenOut = token0;
//       uint256 amountToSwap = tokenInAmount0;
//       if (tokenIn == token0) {
//         tokenOut = token1;
//         amountToSwap = tokenInAmount1;
//       }
//       _swap(tokenIn, tokenOut, amountToSwap);
//     }

//     vaultBalance = deposit(
//       vault,
//       IERC20(token0).balanceOf(address(this)),
//       IERC20(token1).balanceOf(address(this)),
//       tokenAmountOutMin
//     );
//   }

//   function zapOutAndSwap(
//     IVault vault,
//     uint256 withdrawAmount,
//     address desiredToken,
//     uint256 desiredTokenOutMin
//   ) public onlyWhitelistedVaults(address(vault)) returns (uint256 tokenBalance) {
//     vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);

//     IHypervisor gammaVault = IHypervisor(vault.token());

//     vault.withdraw(withdrawAmount);
//     //get gamma vault tokens
//     uint256 gammaVaultTokenBal = gammaVault.balanceOf(address(this));

//     (uint256 amount0, uint256 amount1) = gammaVault.withdraw(
//       gammaVaultTokenBal,
//       address(this),
//       address(this),
//       minInAmounts
//     );
//     (address token0, address token1) = gammaVaultTokens(vault);

//     // Swapping
//     if (token0 != desiredToken) {
//       _swap(token0, desiredToken, amount0);
//     }

//     if (token1 != desiredToken) {
//       _swap(token1, desiredToken, amount1);
//     }

//     address[] memory path = new address[](3);
//     path[0] = token0;
//     path[1] = token1;
//     path[2] = desiredToken;

//     tokenBalance = IERC20(desiredToken).balanceOf(address(this));

//     require(tokenBalance >= desiredTokenOutMin, "Insignificant desiredTokenOutMin");

//     _returnAssets(path);

//     emit Withdraw(msg.sender, tokenBalance);
//   }

//   function zapOutAndSwapEth(
//     IVault vault,
//     uint256 withdrawAmount,
//     uint256 desiredTokenOutMin
//   ) public onlyWhitelistedVaults(address(vault)) returns (uint256 ethBalance) {
//     vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);

//     IHypervisor gammaVault = IHypervisor(vault.token());

//     vault.withdraw(withdrawAmount);

//     //get gamma vault tokens
//     uint256 gammaVaultTokenBal = gammaVault.balanceOf(address(this));

//     (uint256 amount0, uint256 amount1) = gammaVault.withdraw(
//       gammaVaultTokenBal,
//       address(this),
//       address(this),
//       minInAmounts
//     );

//     (address token0, address token1) = gammaVaultTokens(vault);

//     // Swapping
//     if (token0 != wPol) {
//       _swap(token0, wPol, amount0);
//     }

//     if (token1 != wPol) {
//       _swap(token1, wPol, amount1);
//     }

//     address[] memory path = new address[](3);
//     path[0] = token0;
//     path[1] = token1;
//     path[2] = wPol;

//     ethBalance = IERC20(wPol).balanceOf(address(this));

//     require(ethBalance >= desiredTokenOutMin, "Insignificant desiredTokenOutMin");

//     _returnAssets(path);

//     emit Withdraw(msg.sender, ethBalance);
//   }

//   function gammaVaultTokens(IVault _localVault) public view returns (address, address) {
//     return (IHypervisor(_localVault.token()).token0(), IHypervisor(_localVault.token()).token1());
//   }

//   function _approveTokenIfNeeded(address token, address spender) internal {
//     if (IERC20(token).allowance(address(this), spender) == 0) {
//       IERC20(token).safeApprove(spender, type(uint256).max);
//     }
//   }
// }
