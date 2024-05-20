// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../../lib/safe-math.sol";
import "../../../lib/erc20.sol";
import "../../../lib/square-root.sol";
import "../../../interfaces/weth.sol";
import "../../../interfaces/vault.sol";
import "../../../interfaces/uniswapv3.sol";
import "../../../interfaces/ISteerPeriphery.sol";
import "../../../interfaces/ISushiMultiPositionLiquidityManager.sol";
import "../../../Utils/PriceCalculator.sol";

contract SteerZapperBase is PriceCalculator {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;
  using SafeERC20 for IVault;

  address public router = 0xE592427A0AEce92De3Edee1F18E0157C05861564; // uniswap V3 router
  address public steerPeriphery = 0x806c2240793b3738000fcb62C66BF462764B903F;

  // Define a mapping to store whether an address is whitelisted or not
  mapping(address => bool) public whitelistedVaults;
  // tokenIn => tokenOut => poolFee
  mapping(address => mapping(address => uint24)) public poolFees;

  //hold steer vault address againts our local vault
  mapping(address => address) public steerVaults;

  uint256 public constant minimumAmount = 1000;

  constructor(
    address _governance,
    address[] memory _vaults,
    address[] memory _token0,
    address[] memory _token1,
    uint24[] memory _poolFee
  ) PriceCalculator(_governance) {
    // Safety checks to ensure WETH token address`
    WETH(weth).deposit{value: 0}();
    WETH(weth).withdraw(0);
    governance = _governance;

    require(
      _token0.length == _poolFee.length && _token1.length == _poolFee.length,
      "token and pool fee length must be equal"
    );

    for (uint i = 0; i < _vaults.length; i++) {
      whitelistedVaults[_vaults[i]] = true;
    }

    for (uint i = 0; i < _poolFee.length; i++) {
      poolFees[_token0[i]][_token1[i]] = _poolFee[i];
      // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
      poolFees[_token1[i]][_token0[i]] = _poolFee[i];
    }
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


  function getPoolFee(address token0, address token1) public view returns (uint24) {
    uint24 fee = poolFees[token0][token1];
    require(fee > 0, "pool fee is not set");
    return fee;
  }

  function setSteerVaults(address _localVault, address _steerVault) external onlyGovernance {
    require(_steerVault != address(0), "invalid address");
    require(_localVault != address(0), "invalid address");
    steerVaults[_localVault] = _steerVault;
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
  ) public onlyWhitelistedVaults(address(vault)) {
    (address token0, address token1) = steerVaultTokens(address(vault));

    //Deposit tokens to steer vault tokens
    //approve both tokens to Steer Periphery contract
    _approveTokenIfNeeded(token0, steerPeriphery);
    _approveTokenIfNeeded(token1, steerPeriphery);

    //get steer vault from local vault
    address _steerVault = steerVaults[address(vault)];
    //deposit to Steer Periphery contract
    ISteerPeriphery(steerPeriphery).deposit(_steerVault, amount0, amount1, 0, 0, address(this));

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
  }

  function _swap(address tokenIn, address tokenOut, uint256 amountIn) private {
    address[] memory path = new address[](2);
    path[0] = tokenIn;
    path[1] = tokenOut;

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

  function zapInETH(
    IVault vault,
    uint256 tokenAmountOutMin,
    address tokenIn,
    uint256 tokenInAmount0,
    uint256 tokenInAmount1
  ) external payable onlyWhitelistedVaults(address(vault)) {
    //get tokenAmount

    ISushiMultiPositionLiquidityManager steerVault = ISushiMultiPositionLiquidityManager(steerVaults[address(vault)]);

    (address token0, address token1) = steerVaultTokens(address(vault));

    (uint256 amount0, uint256 amount1) = getTotalAmounts(address(vault));

    uint8 token0Decimals = IERC20(token0).decimals();
    uint8 token1Decimals = IERC20(token1).decimals();

    uint256 token0Price;
    uint256 token1Price;

    //check if token0 and token1 are stableTokens
    //check if token1 is in stable tokens array
    for (uint256 i = 0; i < stableTokens.length; i++) {
      if (stableTokens[i] == token0 && stableTokens[i] == token1) {
        token0Price = 1;
        token1Price = 1;
      } else if (stableTokens[i] == token0) {
        token0Price = 1;
        //Needed to fetch token1 price
      } else if (stableTokens[i] == token1) {
        token1Price = 1;
        //Needed to fetch token0 price
      } else if (stableTokens[i] != token0 && stableTokens[i] != token1) {
        //Needed to fetch both tokens prices
      }
    }

    uint256 token0Stacked = token0Price * amount0.div(10 ** token0Decimals);
    uint256 token1Stacked = token1Price * amount1.div(10 ** token1Decimals);

    uint256 tokenInAmount = tokenInAmount0 + tokenInAmount1;
    require(msg.value >= minimumAmount, "Insignificant input amount");
    require(msg.value >= tokenInAmount, "Insignificant token in amounts");

    WETH(weth).deposit{value: msg.value}();

    if (tokenIn != token0 && tokenIn != token1) {
      _swap(weth, token0, tokenInAmount0);
      _swap(weth, token1, tokenInAmount1);
    } else {
      address tokenOut = token0;
      uint256 amountToSwap = tokenInAmount0;
      if (tokenIn == token0) {
        tokenOut = token1;
        amountToSwap = tokenInAmount1;
      }
      _swap(weth, tokenOut, amountToSwap);
    }

    deposit(vault, IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), tokenAmountOutMin);
  }

  function zapIn(
    IVault vault,
    uint256 tokenAmountOutMin,
    address tokenIn,
    uint256 tokenInAmount0,
    uint256 tokenInAmount1
  ) external onlyWhitelistedVaults(address(vault)) {
    uint256 tokenInAmount = tokenInAmount0 + tokenInAmount1;
    require(tokenInAmount >= minimumAmount, "Insignificant input amount");
    require(IERC20(tokenIn).allowance(msg.sender, address(this)) >= tokenInAmount, "Input token is not approved");

    // transfer token
    IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), tokenInAmount);

    (address token0, address token1) = steerVaultTokens(address(vault));

    //Note : tokenIn pair must exist withsteerVaultTokens
    if (token0 != tokenIn && token1 != tokenIn) {
      _swap(tokenIn, token0, tokenInAmount0);
      _swap(tokenIn, token1, tokenInAmount1);
    } else {
      address tokenOut = token0;
      uint256 amountToSwap = tokenInAmount0;
      if (tokenIn == token0) {
        tokenOut = token1;
        amountToSwap = tokenInAmount1;
      }
      _swap(tokenIn, tokenOut, amountToSwap);
    }

    deposit(vault, IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), tokenAmountOutMin);
  }

  function zapOutAndSwap(
    IVault vault,
    uint256 withdrawAmount,
    address desiredToken,
    uint256 desiredTokenOutMin
  ) public onlyWhitelistedVaults(address(vault)) {
    vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);

    ISushiMultiPositionLiquidityManager steerVault = ISushiMultiPositionLiquidityManager(steerVaults[address(vault)]);

    vault.withdraw(withdrawAmount);
    //get steer vault tokens
    uint256 steerVaultTokenBal = steerVault.balanceOf(address(this));

    (uint256 amount0, uint256 amount1) = steerVault.withdraw(steerVaultTokenBal, 0, 0, address(this));
    (address token0, address token1) = steerVaultTokens(address(vault));

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

    require(IERC20(desiredToken).balanceOf(address(this)) >= desiredTokenOutMin, "Insignificant desiredTokenOutMin");

    _returnAssets(path);
  }

  function zapOutAndSwapEth(
    IVault vault,
    uint256 withdrawAmount,
    uint256 desiredTokenOutMin
  ) public onlyWhitelistedVaults(address(vault)) {
    vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);

    ISushiMultiPositionLiquidityManager steerVault = ISushiMultiPositionLiquidityManager(steerVaults[address(vault)]);

    vault.withdraw(withdrawAmount);
    //get steer vault tokens
    uint256 steerVaultTokenBal = steerVault.balanceOf(address(this));

    (uint256 amount0, uint256 amount1) = steerVault.withdraw(steerVaultTokenBal, 0, 0, address(this));

    (address token0, address token1) = steerVaultTokens(address(vault));

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

    require(IERC20(weth).balanceOf(address(this)) >= desiredTokenOutMin, "Insignificant desiredTokenOutMin");

    _returnAssets(path);
  }

  function getTotalAmounts(address _localVaultAdd) public view returns (uint256, uint256) {
    return ISushiMultiPositionLiquidityManager(steerVaults[_localVaultAdd]).getTotalAmounts();
  }

  function steerVaultTokens(address _localVaultAdd) public view returns (address, address) {
    return (
      ISushiMultiPositionLiquidityManager(steerVaults[_localVaultAdd]).token0(),
      ISushiMultiPositionLiquidityManager(steerVaults[_localVaultAdd]).token1()
    );
  }

  function _approveTokenIfNeeded(address token, address spender) internal {
    if (IERC20(token).allowance(address(this), spender) == 0) {
      IERC20(token).safeApprove(spender, type(uint256).max);
    }
  }
}
