// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../../lib/erc20.sol";
import "../../../interfaces/weth.sol";
import "../../../interfaces/vault.sol";
import "../../../interfaces/uniswapv3.sol";
import "../../../interfaces/uniswapv2.sol";
import "../../../interfaces/camelot.sol";
import "../../../interfaces/peapods.sol";

abstract contract PeapodsLPZapperBase {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;
  using SafeERC20 for IVault;
  using SafeERC20 for ICamelotPair;

  address public router;
  address public governance;

  address public camelotRouterV3 = 0x1F721E2E82F6676FCE4eA07A5958cF098D339e18;
  address public camelotYakRouter = 0x99D4e80DB0C023EFF8D25d8155E0dCFb5aDDeC5E;

  // TOKENS
  address public constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
  address public constant gmx = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;

  address public constant ohm = 0xf0cb2dc0db5e6c66B9a70Ac27B06b878da017028;
  address public constant peas = 0x02f92800F57BCD74066F5709F1Daa1A4302Df875;
  address public constant savvy = 0x43aB8f7d2A8Dd4102cCEA6b438F6d747b1B9F034;
  address public constant usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
  address public constant usdcE = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
  address public constant indexUtils = 0x5c5c288f5EF3559Aaf961c5cCA0e77Ac3565f0C0;

  address public constant weth_ohm = 0x8aCd42e4B5A5750B44A28C5fb50906eBfF145359;
  address public constant weth_usdcE = 0x84652bb2539513BAf36e225c930Fdd8eaa63CE27;
  address public constant weth_ohm_adapter = 0x610934FEBC44BE225ADEcD888eAF7DFf3B0bc050;
  address public constant usdc_usdcE_adapter = 0x83Bb6048D55Ea0a84795A939531Fdc1314c0d3e3;

  address public constant zero = 0x0000000000000000000000000000000000000000;

  // Define a mapping to store whether an address is whitelisted or not
  mapping(address => bool) public whitelistedVaults;
  mapping(address => address) public apToken;
  mapping(address => address) public baseToken;

  uint256 public constant minimumAmount = 1000;

  // For this example, we will set the pool fee to 0.3%.
  uint24 public constant poolFee = 5000;

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

  event Deposit(address indexed recipient, uint256 amountIn);
  event Withdraw(address indexed recipient, uint256 amountOut);

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

  function setApTokens(address _apToken, address _baseToken) external onlyGovernance {
    apToken[_baseToken] = _apToken;
  }

  function setBaseTokens(address _apToken, address _baseToken) external onlyGovernance {
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

  function _swapCamelotYak(
    address _from,
    address[] memory path,
    address[] memory adapters,
    address[] memory recipients,
    uint256 _amount
  ) internal {
    IERC20(_from).safeApprove(camelotYakRouter, 0);
    IERC20(_from).safeApprove(camelotYakRouter, _amount);

    CamelotYakRouter.Trade memory params = CamelotYakRouter.Trade({
      amountIn: _amount,
      amountOut: 0,
      path: path,
      adapters: adapters,
      recipients: recipients
    });

    CamelotYakRouter(camelotYakRouter).swapNoSplit(params, 0, address(this));
  }

  function _swapCamelot(address _from, address _to, uint256 _amount) internal returns (uint256 amountOut) {
    IERC20(_from).safeApprove(camelotRouterV3, 0);
    IERC20(_from).safeApprove(camelotRouterV3, _amount);

    ICamelotRouterV3.ExactInputSingleParams memory params = ICamelotRouterV3.ExactInputSingleParams({
      tokenIn: _from,
      tokenOut: _to,
      recipient: address(this),
      deadline: block.timestamp,
      amountIn: _amount,
      amountOutMinimum: 0,
      limitSqrtPrice: 0
    });

    // The call to `exactInputSingle` executes the swap.
    amountOut = ICamelotRouterV3(camelotRouterV3).exactInputSingle(params);
  }

  function _swapCamelotWithPath(address[] memory path, uint256 _amount) internal returns (uint256 amountOut) {
    IERC20(path[0]).safeApprove(camelotRouterV3, 0);
    IERC20(path[0]).safeApprove(camelotRouterV3, _amount);

    ICamelotRouterV3.ExactInputParams memory params = ICamelotRouterV3.ExactInputParams({
      path: abi.encodePacked(path[0], poolFee, path[1], poolFee, path[2]),
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
          (bool success, ) = msg.sender.call{value: balance}(new bytes(0));
          require(success, "ETH transfer failed");
        } else {
          IERC20(tokens[i]).safeTransfer(msg.sender, balance);
        }
      }
    }
  }

  function _swapAndStake(address vault, uint256 tokenAmountOutMin, address tokenIn) public virtual returns (uint256);

  function zapInETH(
    address vault,
    uint256 tokenAmountOutMin,
    address tokenIn
  ) external payable onlyWhitelistedVaults(vault) returns (uint256 vaultBalance) {
    require(msg.value >= minimumAmount, "Insignificant input amount");

    WETH(weth).deposit{value: msg.value}();

    (, ICamelotPair pair) = _getVaultPair(vault);
    (uint256 reserveA, uint256 reserveB, , ) = pair.getReserves();
    require(reserveA > minimumAmount && reserveB > minimumAmount, "Liquidity pair reserves too low");

    bool isInputA = pair.token0() == apToken[tokenIn];
    require(isInputA || pair.token1() == apToken[tokenIn], "Input token not present in liquidity pair");

    address tokenIn2 = isInputA ? baseToken[pair.token1()] : tokenIn;

    uint256 _amount = IERC20(weth).balanceOf(address(this));

    // allows us to zapIn if eth isn't part of the original pair
    if (tokenIn != weth) {
      if (_amount > 0 && tokenIn == ohm) {
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = tokenIn;

        address[] memory adapters = new address[](1);
        adapters[0] = weth_ohm_adapter;

        address[] memory recipients = new address[](1);
        recipients[0] = weth_ohm;

        _swapCamelotYak(weth, path, adapters, recipients, _amount.div(2));
      }

      if (_amount > 0 && tokenIn == peas) {
        //swap with camelot router but use usdc as intermediary
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = tokenIn;

        address[] memory adapters = new address[](1);
        adapters[0] = usdc_usdcE_adapter;

        _swapCamelotYak(weth, path, adapters, adapters, _amount.div(2));
      }

      if (_amount > 0 && tokenIn == gmx) {
        _swapCamelot(weth, tokenIn, _amount.div(2));
      }
    }

    if (tokenIn2 != weth) {
      if (_amount > 0 && tokenIn2 == ohm) {
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = tokenIn2;

        address[] memory adapters = new address[](1);
        adapters[0] = weth_ohm_adapter;

        address[] memory recipients = new address[](1);
        recipients[0] = weth_ohm;

        _swapCamelotYak(weth, path, adapters, recipients, _amount.div(2));
      }

      if (_amount > 0 && tokenIn2 == peas) {
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = tokenIn2;

        address[] memory adapters = new address[](1);
        adapters[0] = usdc_usdcE_adapter;

        _swapCamelotYak(weth, path, adapters, adapters, _amount.div(2));
      }

      if (_amount > 0 && tokenIn2 == gmx) {
        _swapCamelot(weth, tokenIn2, _amount.div(2));
      }
    }

    vaultBalance = _swapAndStake(vault, tokenAmountOutMin, tokenIn);
  }

  function zapOutAndSwap(
    address vault,
    uint256 withdrawAmount,
    address desiredToken,
    uint256 desiredTokenOutMin
  ) public virtual returns (uint256 tokenBalance);

  function zapOutAndSwapEth(address vault, uint256 withdrawAmount, uint256 desiredTokenOutMin) public virtual returns (uint256 ethBalance);

  function _removeLiquidity(address pair, address to) internal {
    IERC20(pair).safeTransfer(pair, IERC20(pair).balanceOf(address(this)));
    (uint256 amount0, uint256 amount1) = ICamelotPair(pair).burn(to);

    require(amount0 >= minimumAmount, "Router: INSUFFICIENT_A_AMOUNT");
    require(amount1 >= minimumAmount, "Router: INSUFFICIENT_B_AMOUNT");
  }

  function _getVaultPair(address vault_addr) internal view returns (IVault vault, ICamelotPair pair) {
    vault = IVault(vault_addr);
    pair = ICamelotPair(vault.token());

    require(pair.factory() == ICamelotPair(router).factory(), "Incompatible liquidity pair factory");
  }

  function _approveTokenIfNeeded(address token, address spender) internal {
    if (IERC20(token).allowance(address(this), spender) == 0) {
      IERC20(token).safeApprove(spender, type(uint256).max);
    }
  }

  function zapOut(address vault_addr, uint256 withdrawAmount) external onlyWhitelistedVaults(vault_addr) {
    (IVault vault, ICamelotPair token) = _getVaultPair(vault_addr);

    IERC20(vault_addr).safeTransferFrom(msg.sender, address(this), withdrawAmount);
    vault.withdraw(withdrawAmount);

    address[] memory tokens = new address[](2);
    tokens[0] = address(token);
    tokens[1] = address(vault.token());

    _returnAssets(tokens);
  }
}
