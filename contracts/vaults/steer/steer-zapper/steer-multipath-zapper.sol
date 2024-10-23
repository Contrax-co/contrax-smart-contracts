// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../lib/safe-math.sol";
import "../../../lib/erc20.sol";
import "../../../lib/square-root.sol";
import "../../../interfaces/weth.sol";
import "../../../interfaces/vault.sol";
import "../../../interfaces/uniswapv3.sol";
import "../../../interfaces/ISteerPeriphery.sol";
import "../../../interfaces/ISushiMultiPositionLiquidityManager.sol";
import "../../../Utils/PriceCalculatorV3.sol";

import "hardhat/console.sol";

contract SteerZapperMultiPath is PriceCalculatorV3 {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;
  using SafeERC20 for IVault;

  address router; // uniswap V3 router
  address STEER_PERIPHERY;
  address V3Factory;

  // Define a mapping to store whether an address is whitelisted or not
  mapping(address => bool) public whitelistedVaults;
  // tokenIn => tokenOut => poolFee
  mapping(address => mapping(address => uint24)) public poolFees;

  uint256 public constant minimumAmount = 1000;

  constructor(
    address _governance,
    address _weth,
    address _router,
    address _V3Factory,
    address _steerPeriphery,
    address _weth_usdc_pool,
    address[] memory _vaults
  ) PriceCalculatorV3(_governance, _weth_usdc_pool, _weth) {
    router = _router;
    V3Factory = _V3Factory;
    STEER_PERIPHERY = _steerPeriphery;
    // Safety checks to ensure WETH token address`
    WETH(weth).deposit{value: 0}();
    WETH(weth).withdraw(0);
    governance = _governance;

    for (uint i = 0; i < _vaults.length; i++) {
      whitelistedVaults[_vaults[i]] = true;
    }
  }

  event Deposit(address indexed recipient, uint256 amountIn);
  event Withdraw(address indexed recipient, uint256 amountOut);

  receive() external payable {
    assert(msg.sender == weth);
  }

  // **** Modifiers **** //

  // Modifier to restrict access to whitelisted vaults only
  modifier onlyWhitelistedVaults(address vault) {
    require(whitelistedVaults[vault], "Vault is not whitelisted");
    _;
  }

  function getPoolFee(address token0, address token1) public view returns (uint24) {
    uint24 fee = poolFees[token0][token1];
    require(fee > 0, "pool fee is not set");
    return fee;
  }

  function setSwapAddresses(address _weth, address _router, address _V3Factory) external onlyGovernance {
    weth = _weth;
    router = _router;
    V3Factory = _V3Factory;
  }

  // Function to add a vault to the whitelist
  function addToWhitelist(address _vault) external onlyGovernance {
    whitelistedVaults[_vault] = true;
  }

  function setPoolFees(address _token0, address _token1, uint24 _poolFee) external onlyGovernance {
    require(_poolFee > 0, "pool fee must be greater than 0");
    require(_token0 != address(0) && _token1 != address(0), "invalid address");

    poolFees[_token0][_token1] = _poolFee;
    // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
    poolFees[_token1][_token0] = _poolFee;
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
          (bool success, ) = msg.sender.call{value: balance}(new bytes(0));
          require(success, "ETH transfer failed");
        } else {
          IERC20(tokens[i]).safeTransfer(msg.sender, balance);
        }
      }
    }
  }

  function deposit(
    IVault vault,
    uint256 amount0,
    uint256 amount1,
    uint256 amountOutMin
  ) public onlyWhitelistedVaults(address(vault)) returns (uint256) {
    (address token0, address token1) = steerVaultTokens(vault);

    //Deposit tokens to steer vault tokens
    //approve both tokens to Steer Periphery contract
    _approveTokenIfNeeded(token0, STEER_PERIPHERY);
    _approveTokenIfNeeded(token1, STEER_PERIPHERY);

    //get steer vault from local vault
    address _steerVault = vault.token();
    //deposit to Steer Periphery contract
    ISteerPeriphery(STEER_PERIPHERY).deposit(_steerVault, amount0, amount1, 0, 0, address(this));

    //get steer vault balance
    uint256 balance = IERC20(_steerVault).balanceOf(address(this));
    //depoist steer vault shares to local vault

    _approveTokenIfNeeded(_steerVault, address(vault));

    vault.deposit(balance);

    uint256 vaultBalance = vault.balanceOf(address(this));

    require(vaultBalance >= amountOutMin, "Insignificant amountOutMin");

    //return vault tokens to user
    IERC20(address(vault)).safeTransfer(msg.sender, vaultBalance);

    address[] memory tokens = new address[](2);
    tokens[0] = token0;
    tokens[1] = token1;

    _returnAssets(tokens);

    emit Deposit(msg.sender, vaultBalance);

    return vaultBalance;
  }

  function multiPathSwapV3(address tokenIn, address tokenOut, uint256 amountIn) internal {
    if (tokenIn == weth || tokenOut == weth) {
      _swap(tokenIn, tokenOut, amountIn);
      return;
    }

    address[] memory path = new address[](3);
    path[0] = tokenIn;
    path[1] = weth;
    path[2] = tokenOut;

    if (poolFees[weth][tokenOut] == 0) fetchPool(weth, tokenOut, V3Factory);
    if (poolFees[tokenIn][weth] == 0) fetchPool(tokenIn, weth, V3Factory);

    _approveTokenIfNeeded(path[0], address(router));

    ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
      path: abi.encodePacked(path[0], getPoolFee(path[0], path[1]), path[1], getPoolFee(path[1], path[2]), path[2]),
      recipient: address(this),
      deadline: block.timestamp,
      amountIn: amountIn,
      amountOutMinimum: 0
    });

    // Executes the swap
    ISwapRouter(router).exactInput(params);
  }

  function _swap(address tokenIn, address tokenOut, uint256 amountIn) private {
    address[] memory path = new address[](2);
    path[0] = tokenIn;
    path[1] = tokenOut;

    if (poolFees[tokenIn][tokenOut] == 0) fetchPool(tokenIn, tokenOut, V3Factory);

    _approveTokenIfNeeded(path[0], address(router));
    ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
      tokenIn: path[0],
      tokenOut: path[1],
      fee: getPoolFee(tokenIn, tokenOut),
      recipient: address(this),
      deadline: block.timestamp,
      amountIn: amountIn,
      amountOutMinimum: 0,
      sqrtPriceLimitX96: 0
    });

    ISwapRouter(address(router)).exactInputSingle(params);
  }

  function calculateSteerVaultTokensPrices(IVault vault) internal returns (uint256 token0Price, uint256 token1Price) {
    (address token0, address token1) = steerVaultTokens(vault);

    bool isToken0Stable = isStableToken(token0);
    bool isToken1Stable = isStableToken(token1);

    if (isToken0Stable) token0Price = 1 * PRECISION;
    if (isToken1Stable) token1Price = 1 * PRECISION;

    if (!isToken0Stable) {
      token0Price = getPrice(token0, vault);
    }

    if (!isToken1Stable) {
      token1Price = getPrice(token1, vault);
    }

    return (token0Price, token1Price);
  }

  function isStableToken(address token) internal view returns (bool) {
    for (uint256 i = 0; i < stableTokens.length; i++) {
      if (stableTokens[i] == token) return true;
    }
    return false;
  }

  function getPrice(address token, IVault vault) internal returns (uint256) {
    if (token == weth) {
      return calculateEthPriceInUsdc();
    } else {
      (address token0, address token1) = steerVaultTokens(vault);
      // get pair address from factory contract for weth and desired token
      address pair;
      if (token == token0) {
        pair = fetchPool(token0, weth, V3Factory);

        return calculateTokenPriceInUsd(token0, pair);
      }

      pair = fetchPool(token1, weth, V3Factory);

      return calculateTokenPriceInUsd(token1, pair);
    }
  }

  function fetchPool(address token0, address token1, address _uniV3Factory) internal returns (address) {
    address pairWithMaxLiquidity = address(0);
    uint256 maxLiquidity = 0;

    for (uint256 i = 0; i < poolsFee.length; i++) {
      address currentPair = IUniswapV3Factory(_uniV3Factory).getPool(token0, token1, poolsFee[i]);
      if (currentPair != address(0)) {
        uint256 currentLiquidity = IUniswapV3Pool(currentPair).liquidity();
        if (currentLiquidity > maxLiquidity) {
          maxLiquidity = currentLiquidity;
          pairWithMaxLiquidity = currentPair;
          poolFees[token0][token1] = poolsFee[i];
          // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
          poolFees[token1][token0] = poolsFee[i];
        }
      }
    }
    require(pairWithMaxLiquidity != address(0), "No pool found with sufficient liquidity");
    return pairWithMaxLiquidity;
  }

  function zapInETH(
    IVault vault,
    uint256 tokenAmountOutMin,
    address tokenIn
  ) external payable onlyWhitelistedVaults(address(vault)) returns (uint256 vaultBalance) {
    //get tokenAmount

    WETH(weth).deposit{value: msg.value}();
    uint256 _amountIn = IERC20(weth).balanceOf(address(this));
    (address token0, address token1) = steerVaultTokens(vault);

    (uint256 tokenInAmount0, uint256 tokenInAmount1) = calculateSteerVaultTokensRatio(vault, _amountIn);

    uint256 tokenInAmount = tokenInAmount0 + tokenInAmount1;
    require(_amountIn >= minimumAmount, "Insignificant input amount");
    require(_amountIn >= tokenInAmount, "Insignificant token in amounts");

    if (tokenIn != token0 && tokenIn != token1) {
      multiPathSwapV3(weth, token0, tokenInAmount0);
      multiPathSwapV3(weth, token1, tokenInAmount1);
    } else {
      address tokenOut = token0;
      uint256 amountToSwap = tokenInAmount0;
      if (tokenIn == token0) {
        tokenOut = token1;
        amountToSwap = tokenInAmount1;
      }
      multiPathSwapV3(weth, tokenOut, amountToSwap);
    }

    vaultBalance = deposit(
      vault,
      IERC20(token0).balanceOf(address(this)),
      IERC20(token1).balanceOf(address(this)),
      tokenAmountOutMin
    );
  }

  function zapIn(
    IVault vault,
    uint256 tokenAmountOutMin,
    address tokenIn,
    uint256 tokenInAmount
  ) external onlyWhitelistedVaults(address(vault)) returns (uint256 vaultBalance) {
    require(tokenInAmount >= minimumAmount, "Insignificant input amount");
    require(IERC20(tokenIn).allowance(msg.sender, address(this)) >= tokenInAmount, "Input token is not approved");

    (uint256 tokenInAmount0, uint256 tokenInAmount1) = calculateSteerVaultTokensRatio(vault, tokenInAmount);

    // transfer token
    IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), tokenInAmount);

    (address token0, address token1) = steerVaultTokens(vault);

    //Note : tokenIn pair must exist withsteerVaultTokens
    if (token0 != tokenIn && token1 != tokenIn) {
      multiPathSwapV3(tokenIn, token0, tokenInAmount0);
      multiPathSwapV3(tokenIn, token1, tokenInAmount1);
    } else {
      address tokenOut = token0;
      uint256 amountToSwap = tokenInAmount0;
      if (tokenIn == token0) {
        tokenOut = token1;
        amountToSwap = tokenInAmount1;
      }
      multiPathSwapV3(tokenIn, tokenOut, amountToSwap);
    }

    vaultBalance = deposit(
      vault,
      IERC20(token0).balanceOf(address(this)),
      IERC20(token1).balanceOf(address(this)),
      tokenAmountOutMin
    );
  }

  function zapOutAndSwap(
    IVault vault,
    uint256 withdrawAmount,
    address desiredToken,
    uint256 desiredTokenOutMin
  ) public onlyWhitelistedVaults(address(vault)) returns (uint256 tokenBalance) {
    vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);

    ISushiMultiPositionLiquidityManager steerVault = ISushiMultiPositionLiquidityManager(vault.token());

    vault.withdraw(withdrawAmount);
    //get steer vault tokens
    uint256 steerVaultTokenBal = steerVault.balanceOf(address(this));

    (uint256 amount0, uint256 amount1) = steerVault.withdraw(steerVaultTokenBal, 0, 0, address(this));
    (address token0, address token1) = steerVaultTokens(vault);

    // Swapping
    if (token0 != desiredToken) {
      multiPathSwapV3(token0, desiredToken, amount0);
    }

    if (token1 != desiredToken) {
      multiPathSwapV3(token1, desiredToken, amount1);
    }

    address[] memory path = new address[](3);
    path[0] = token0;
    path[1] = token1;
    path[2] = desiredToken;

    tokenBalance = IERC20(desiredToken).balanceOf(address(this));
    require(tokenBalance >= desiredTokenOutMin, "Insignificant desiredTokenOutMin");

    _returnAssets(path);

    emit Withdraw(msg.sender, tokenBalance);
  }

  function zapOutAndSwapEth(
    IVault vault,
    uint256 withdrawAmount,
    uint256 desiredTokenOutMin
  ) public onlyWhitelistedVaults(address(vault)) returns (uint256 ethBalance) {
    vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);

    ISushiMultiPositionLiquidityManager steerVault = ISushiMultiPositionLiquidityManager(vault.token());

    vault.withdraw(withdrawAmount);
    //get steer vault tokens
    uint256 steerVaultTokenBal = steerVault.balanceOf(address(this));

    (uint256 amount0, uint256 amount1) = steerVault.withdraw(steerVaultTokenBal, 0, 0, address(this));

    (address token0, address token1) = steerVaultTokens(vault);

    // Swapping
    if (token0 != weth) {
      multiPathSwapV3(token0, weth, amount0);
    }

    if (token1 != weth) {
      multiPathSwapV3(token1, weth, amount1);
    }

    address[] memory path = new address[](3);
    path[0] = token0;
    path[1] = token1;
    path[2] = weth;

    ethBalance = IERC20(weth).balanceOf(address(this));
    require(ethBalance >= desiredTokenOutMin, "Insignificant desiredTokenOutMin");

    _returnAssets(path);

    emit Withdraw(msg.sender, ethBalance);
  }

  function calculateSteerVaultTokensRatio(IVault vault, uint256 _amountIn) internal returns (uint256, uint256) {
    (address token0, address token1) = steerVaultTokens(vault);
    (uint256 amount0, uint256 amount1) = getTotalAmounts(vault);
    (uint256 token0Price, uint256 token1Price) = calculateSteerVaultTokensPrices(vault);

    uint256 token0Value = ((token0Price * amount0) / (10 ** uint256(IERC20(token0).decimals())));
    uint256 token1Value = ((token1Price * amount1) / (10 ** uint256(IERC20(token1).decimals())));

    uint256 totalValue = token0Value + token1Value;
    uint256 token0Amount = (_amountIn * token0Value) / totalValue;
    uint256 token1Amount = _amountIn - token0Amount;

    return (token0Amount, token1Amount);
  }

  function getTotalAmounts(IVault _localVault) public view returns (uint256, uint256) {
    return ISushiMultiPositionLiquidityManager(_localVault.token()).getTotalAmounts();
  }

  function steerVaultTokens(IVault _localVault) public view returns (address, address) {
    return (
      ISushiMultiPositionLiquidityManager(_localVault.token()).token0(),
      ISushiMultiPositionLiquidityManager(_localVault.token()).token1()
    );
  }

  function _approveTokenIfNeeded(address token, address spender) internal {
    if (IERC20(token).allowance(address(this), spender) == 0) {
      IERC20(token).safeApprove(spender, type(uint256).max);
    }
  }
}
