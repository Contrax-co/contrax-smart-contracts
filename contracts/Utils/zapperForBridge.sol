// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/safe-math.sol";
import "../lib/erc20.sol";
import "../lib/square-root.sol";
import "../interfaces/weth.sol";
import "../interfaces/uniswapv3.sol";


contract ZapperBridge {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  address router; // V3 router
  address V3Factory;
  address USDC;
  address public governance;
  address weth;

  address USDT_CORE = 0x900101d06A7426441Ae63e9AB3B9b0F63Be145F1;

  uint24[] public poolsFee = [3000, 500, 100, 350, 80, 10000];
  // tokenIn => tokenOut => poolFee
  mapping(address => mapping(address => uint24)) public poolFees;

  constructor(address _governance, address _weth, address _usdc, address _router, address _V3Factory) {
    router = _router;
    V3Factory = _V3Factory;
    USDC = _usdc;
    weth = _weth;
    governance = _governance;

    // Safety checks to ensure WETH token address`
    WETH(weth).deposit{value: 0}();
    WETH(weth).withdraw(0);
    governance = _governance;
  }

  event EthTransferred(address indexed callingContract, uint256 amount);

  event UsdcTransferred(address indexed recipient, uint256 usdcAmount);

  receive() external payable {}

  // Modifier to restrict access to governance only
  modifier onlyGovernance() {
    require(msg.sender == governance, "Caller is not the governance");
    _;
  }

  function getPoolFee(address token0, address token1) public view returns (uint24) {
    uint24 fee = poolFees[token0][token1];
    require(fee > 0, "pool fee is not set");
    return fee;
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
          emit UsdcTransferred(msg.sender, balance);
        }
      }
    }
  }

  function multiPathSwapV3(address tokenIn, address tokenOut, uint256 amountIn) internal {
    address[] memory path = new address[](3);
    if (tokenIn != weth && tokenOut != weth) {
      path[0] = tokenIn;
      path[1] = tokenOut;
      path[2] = weth;

      if (poolFees[weth][tokenOut] == 0) fetchPool(weth, tokenOut, V3Factory);
    } else {
      path[0] = tokenIn;
      path[1] = tokenOut;
      path[2] = USDC;

      if (poolFees[USDC][tokenOut] == 0) fetchPool(USDC, tokenOut, V3Factory);
    }

    if (poolFees[tokenIn][tokenOut] == 0) fetchPool(tokenIn, tokenOut, V3Factory);

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

  function _swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOutMin) private {
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
      amountOutMinimum: amountOutMin,
      sqrtPriceLimitX96: 0
    });

    ISwapRouter(address(router)).exactInputSingle(params);
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

  function zapIn(
    address _callingContractAddress,
    bytes memory _data,
    uint256 _usdcAmountToZap,
    uint256 _ethAmountOut,
    uint256 _usdcAmountIn
  ) external payable returns (uint256) {
    if (msg.value > 0) {
      (bool _success, ) = payable(_callingContractAddress).call{value: msg.value}(_data);
      require(_success, "Call failed on calling contract");

      emit EthTransferred(_callingContractAddress, msg.value);

      return msg.value;
    }
    
    require(IERC20(USDC).allowance(msg.sender, address(this)) >= _usdcAmountIn, "Input token is not approved");

    require(_usdcAmountIn >= _usdcAmountToZap, "Input amount is not enough to zap");

    IERC20(USDC).safeTransferFrom(msg.sender, address(this), _usdcAmountIn + _usdcAmountToZap);

    multiPathSwapV3(USDC, USDT_CORE, _usdcAmountToZap);

    uint256 wethBal = IERC20(weth).balanceOf(address(this));

    if (wethBal > _ethAmountOut) {
      uint256 diffAmount = wethBal - _ethAmountOut;
      wethBal = wethBal - diffAmount;
    }

    WETH(weth).withdraw(wethBal);

    (bool success, ) = payable(_callingContractAddress).call{value: address(this).balance}(_data);

    require(success, "Call failed on calling contract");

    wethBal = IERC20(weth).balanceOf(address(this));

    multiPathSwapV3(weth, USDT_CORE, wethBal);

    address[] memory returnAssist = new address[](1);
    returnAssist[0] = USDC;

    _returnAssets(returnAssist);

    emit EthTransferred(_callingContractAddress, address(this).balance);

    return address(this).balance;
  }

  function approveToken(address token, address spender) external onlyGovernance {
    _approveTokenIfNeeded(token, spender);
  }

  function _approveTokenIfNeeded(address token, address spender) internal {
    if (IERC20(token).allowance(address(this), spender) == 0) {
      IERC20(token).safeApprove(spender, type(uint256).max);
    }
  }
}
