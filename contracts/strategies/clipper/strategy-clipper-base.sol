// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../lib/erc20.sol";
import "./strategy-clipper.sol";
import "../../lib/safe-math.sol";
import "../../interfaces/Clipper.sol";
import "../../interfaces/uniswapv3.sol";
import "../../interfaces/vault.sol";

contract StrategyClipperBase is StrategyClipper {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  address public constant UNIV3FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
  address public constant router = 0xE592427A0AEce92De3Edee1F18E0157C05861564; // uniswap V3 router
  uint24[] public poolsFee = [3000, 500, 100, 10000];
  address public constant CLIPPER = 0x769728b5298445BA2828c0f3F5384227fbF590C5;

  constructor(
    address _want,
    address _governance,
    address _strategist,
    address _controller,
    address _timelock
  ) StrategyClipper(_want, _governance, _strategist, _controller, _timelock) {}

  // Declare a Harvest Event
  event Harvest(uint _timestamp, uint _value);

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

  function unpack(uint256 amountAndAddress) internal pure returns (uint256 amount, address contractAddress) {
    // uint256 -> uint160 automatically takes just last 40 hexchars
    contractAddress = address(uint160(amountAndAddress));
    // shift over the 40 hexchars to capture the amount
    amount = amountAndAddress >> 160;
  }

  function _swap(address tokenIn, address tokenOut, uint256 amountIn) internal override {
    address[] memory path = new address[](2);
    path[0] = tokenIn;
    path[1] = tokenOut;

    if (poolFees[tokenIn][tokenOut] == 0) fetchPool(tokenIn, tokenOut, UNIV3FACTORY);

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

  function deposit(uint256 packedInput, uint256 packedConfig, bytes32 r, bytes32 s) internal {
    (, address tokenIn) = unpack(packedInput);

    _approveTokenIfNeeded(tokenIn, CLIPPER);

    IClipper(CLIPPER).packedTransmitAndDepositOneAsset(packedInput, packedConfig, r, s);

    address[] memory tokens = new address[](2);
    tokens[0] = tokenIn;
    tokens[1] = CLIPPER;

    _returnAssets(tokens);
  }

  function harvest(uint256 packedInput, uint256 packedConfig, bytes32 r, bytes32 s) public override onlyBenevolent {
    require(rewardToken != address(0), "!rewardToken");
    uint256 _reward = IERC20(rewardToken).balanceOf(address(this));
    require(_reward > 0, "!reward");
    uint256 _keepReward = _reward.mul(keepReward).div(keepMax);
    IERC20(rewardToken).safeTransfer(IController(controller).treasury(), _keepReward);

    //get strategy clipper vault tokens before balances
    uint256 beforeBal = IERC20(want).balanceOf(address(this));

    //get strategy clipper vault tokens after balances
    uint256 afterBal = IERC20(want).balanceOf(address(this));

    deposit(packedInput, packedConfig, r, s);

    emit Harvest(block.timestamp, afterBal.sub(beforeBal));
  }
}
