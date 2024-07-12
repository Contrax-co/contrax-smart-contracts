// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../lib/safe-math.sol";
import "../../../lib/erc20.sol";
import "../../../lib/square-root.sol";
import "../../../interfaces/weth.sol";
import "../../../interfaces/vault.sol";
import "../../../interfaces/Clipper.sol";
import "../../../interfaces/uniswapv3.sol";

contract SteerZapperBase {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;
  using SafeERC20 for IVault;

  address public governance;

  address public constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

  address public constant CLIPPER = 0x769728b5298445BA2828c0f3F5384227fbF590C5;
  address public constant uniV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
  address public constant router = 0xE592427A0AEce92De3Edee1F18E0157C05861564; // uniswap V3 router

  uint24[] public poolsFee = [3000, 500, 100, 10000];

  address[] public ClipperTokens = [
    weth,
    0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9, //USDT
    0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1, //DAI
    0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f, //WBTC
    0xaf88d065e77c8cC2239327C5EDb3A432268e5831, //USDC
    0x912CE59144191C1204E64559FE8253a0e49E6548 //ARB
  ];

  // Define a mapping to store whether an address is whitelisted or not
  mapping(address => bool) public whitelistedVaults;

  // tokenIn => tokenOut => poolFee
  mapping(address => mapping(address => uint24)) public poolFees;

  uint256 public constant minimumAmount = 1000;

  constructor(address _governance, address[] memory _vaults) {
    // Safety checks to ensure WETH token address`
    WETH(weth).deposit{value: 0}();
    WETH(weth).withdraw(0);
    governance = _governance;

    for (uint i = 0; i < _vaults.length; i++) {
      whitelistedVaults[_vaults[i]] = true;
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

  modifier onlyGovernance() {
    require(msg.sender == governance, "Caller is not the governance");
    _;
  }

  function getPoolFee(address token0, address token1) public view returns (uint24) {
    uint24 fee = poolFees[token0][token1];
    require(fee > 0, "pool fee is not set");
    return fee;
  }

  function setClipperTokens(address _token) external onlyGovernance {
    require(_token != address(0), "Invalid address");
    ClipperTokens.push(_token);
  }

  // Function to add a vault to the whitelist
  function addToWhitelist(address _vault) external onlyGovernance {
    whitelistedVaults[_vault] = true;
  }

  // Function to remove a vault from the whitelist
  function removeFromWhitelist(address _vault) external onlyGovernance {
    whitelistedVaults[_vault] = false;
  }

  function _returnClipperTokens() internal {
    uint256 balance;
    for (uint256 i; i < ClipperTokens.length; i++) {
      balance = IERC20(ClipperTokens[i]).balanceOf(address(this));
      if (balance > 0) {
        IERC20(ClipperTokens[i]).safeTransfer(msg.sender, balance);
      }
    }
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

  function unpack(uint256 amountAndAddress) internal pure returns (uint256 amount, address contractAddress) {
    // uint256 -> uint160 automatically takes just last 40 hexchars
    contractAddress = address(uint160(amountAndAddress));
    // shift over the 40 hexchars to capture the amount
    amount = amountAndAddress >> 160;
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

  function _swap(address tokenIn, address tokenOut, uint256 amountIn) private {
    address[] memory path = new address[](2);
    path[0] = tokenIn;
    path[1] = tokenOut;

    if (poolFees[tokenIn][tokenOut] == 0) fetchPool(tokenIn, tokenOut, uniV3Factory);

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

  function deposit(
    IVault vault,
    uint256 packedInput,
    uint256 packedConfig,
    bytes32 r,
    bytes32 s,
    uint256 amountOutMin
  ) public onlyWhitelistedVaults(address(vault)) {
    (, address tokenIn) = unpack(packedInput);

    _approveTokenIfNeeded(tokenIn, CLIPPER);

    IClipper(CLIPPER).packedTransmitAndDepositOneAsset(packedInput, packedConfig, r, s);

    //get steer vault balance
    uint256 clipperBal = IERC20(CLIPPER).balanceOf(address(this));
    //depoist steer vault shares to local vault

    _approveTokenIfNeeded(CLIPPER, address(vault));

    vault.deposit(clipperBal);

    uint256 vaultBalance = vault.balanceOf(address(this));

    require(vaultBalance >= amountOutMin, "Insignificant amountOutMin");

    //return vault tokens to user
    IERC20(address(vault)).safeTransfer(msg.sender, vaultBalance);

    address[] memory tokens = new address[](2);
    tokens[0] = tokenIn;
    tokens[1] = CLIPPER;

    _returnAssets(tokens);
  }

  function zapInETH(
    IVault vault,
    uint256 tokenAmountOutMin,
    uint256 packedInput,
    uint256 packedConfig,
    bytes32 r,
    bytes32 s
  ) external payable onlyWhitelistedVaults(address(vault)) {
    //get tokenAmount

    WETH(weth).deposit{value: msg.value}();
    uint256 _amountIn = IERC20(weth).balanceOf(address(this));

    require(_amountIn >= minimumAmount, "Insignificant input amount");

    deposit(vault, packedInput, packedConfig, r, s, tokenAmountOutMin);
  }

  function zapIn(
    IVault vault,
    uint256 tokenAmountOutMin,
    uint256 packedInput,
    uint256 packedConfig,
    bytes32 r,
    bytes32 s
  ) external onlyWhitelistedVaults(address(vault)) {
    (uint256 tokenInAmount, address tokenIn) = unpack(packedInput);
    require(tokenInAmount >= minimumAmount, "Insignificant input amount");
    require(IERC20(tokenIn).allowance(msg.sender, address(this)) >= tokenInAmount, "Input token is not approved");

    // transfer token
    IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), tokenInAmount);

    deposit(vault, packedInput, packedConfig, r, s, tokenAmountOutMin);
  }


  function zapOutAndSwap(
    IVault vault,
    uint256 withdrawAmount,
    address desiredToken,
    uint256 desiredTokenOutMin
  ) public onlyWhitelistedVaults(address(vault)) {
    vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);

    vault.withdraw(withdrawAmount);

    //get clipper vault balance
    uint256 clipperBal = IERC20(CLIPPER).balanceOf(address(this));

    IClipper(CLIPPER).burnToWithdraw(clipperBal);

    for (uint256 i = 0; i < ClipperTokens.length; i++) {
      uint256 _amount = IERC20(ClipperTokens[i]).balanceOf(address(this));
      if (_amount > 0 && ClipperTokens[i] != desiredToken) {
        _swap(ClipperTokens[i], desiredToken, _amount);
      }
    }
    require(IERC20(desiredToken).balanceOf(address(this)) >= desiredTokenOutMin, "Insignificant desiredTokenOutMin");

    _returnClipperTokens();
  }

  function zapOutAndSwapEth(
    IVault vault,
    uint256 withdrawAmount,
    uint256 desiredTokenOutMin
  ) public onlyWhitelistedVaults(address(vault)) {
    vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);

    vault.withdraw(withdrawAmount);

    //get clipper vault balance
    uint256 clipperBal = IERC20(CLIPPER).balanceOf(address(this));

    IClipper(CLIPPER).burnToWithdraw(clipperBal);

    for (uint256 i = 0; i < ClipperTokens.length; i++) {
      uint256 _amount = IERC20(ClipperTokens[i]).balanceOf(address(this));
      if (_amount > 0 && ClipperTokens[i] != weth) {
        _swap(ClipperTokens[i], weth, _amount);
      }
    }

    require(IERC20(weth).balanceOf(address(this)) >= desiredTokenOutMin, "Insignificant desiredTokenOutMin");

    _returnClipperTokens();
  }

  function _approveTokenIfNeeded(address token, address spender) internal {
    if (IERC20(token).allowance(address(this), spender) == 0) {
      IERC20(token).safeApprove(spender, type(uint256).max);
    }
  }
}
