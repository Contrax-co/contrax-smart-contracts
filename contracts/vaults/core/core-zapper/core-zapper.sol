// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../lib/safe-math.sol";
import "../../../lib/erc20.sol";
import "../../../lib/square-root.sol";
import "../../../interfaces/weth.sol";
import "../../../interfaces/vault.sol";
import "../../../interfaces/uniswapv3.sol";
import "../../../interfaces/ICoreStaking.sol";
import "./UserStakingContract.sol";

contract CoreZapperBase {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;
  using SafeERC20 for IVault;

  address public governance;

  address public constant wCore = 0x40375C92d9FAf44d2f9db9Bd9ba41a3317a2404f; // wCore
  address public constant CORE_STAKING = 0xf5fA1728bABc3f8D2a617397faC2696c958C3409; // CORE_STAKING
  address public constant CORE_VALIDATOR = 0x1c151923Cf6C381C4aF6C3071a2773B3cDBBf704; // CORE_VALIDATOR
  address public constant ST_CORE = 0xb3A8F0f0da9ffC65318aA39E55079796093029AD; // ST_CORE

  address public constant coreXFactory = 0x526190295AFB6b8736B14E4b42744FBd95203A3a;
  address public constant coreXRouter = 0xcc85A7870902f5e3dCef57E4d44F42b613c87a2E; // uniswap V3 coreXRouter

  address constant USDT = 0x900101d06A7426441Ae63e9AB3B9b0F63Be145F1;
  address constant USDC = 0xa4151B2B3e269645181dCcF2D426cE75fcbDeca9;

  // Define a mapping to store whether an address is whitelisted or not
  mapping(address => bool) public whitelistedVaults;

  uint24[] public poolsFee = [3000, 500, 100, 10000];
  // tokenIn => tokenOut => poolFee
  mapping(address => mapping(address => uint24)) public poolFees;

  uint256 public constant minimumAmount = 1000;

  // Add this mapping to store user staking contracts
  mapping(address => address) public userStakingContracts;

  constructor(address _governance, address[] memory _vaults) {
    // Safety checks to ensure WETH token address`
    WETH(wCore).deposit{value: 0}();
    WETH(wCore).withdraw(0);
    governance = _governance;

    for (uint i = 0; i < _vaults.length; i++) {
      whitelistedVaults[_vaults[i]] = true;
    }
  }

  event Deposit(address indexed recipient, uint256 amountIn);
  event Redeem(address indexed recipient, uint256 amountOut);
  event Withdraw(address indexed recipient, uint256 amountOut);

  receive() external payable {}

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

  //returns DUST
  function _returnAssets(address[] memory tokens) internal {
    uint256 balance;
    for (uint256 i; i < tokens.length; i++) {
      balance = IERC20(tokens[i]).balanceOf(address(this));
      if (balance > 0) {
        if (tokens[i] == wCore) {
          WETH(wCore).withdraw(balance);
          (bool success, ) = msg.sender.call{value: balance}(new bytes(0));
          require(success, "ETH transfer failed");
        } else {
          IERC20(tokens[i]).safeTransfer(msg.sender, balance);
        }
      }
    }
  }

  // Function to add a vault to the whitelist
  function addToWhitelist(address _vault) external onlyGovernance {
    whitelistedVaults[_vault] = true;
  }

  // Function to remove a vault from the whitelist
  function removeFromWhitelist(address _vault) external onlyGovernance {
    whitelistedVaults[_vault] = false;
  }

  function multiPathSwapV3(address tokenIn, address tokenOut, uint256 amountIn) internal {
    address[] memory path = new address[](3);
    if (tokenIn != wCore && tokenOut != wCore) {
      path[0] = tokenIn;
      path[1] = tokenOut;
      path[2] = wCore;

      if (poolFees[wCore][tokenOut] == 0) fetchPool(wCore, tokenOut, coreXFactory);
    } else {
      path[0] = tokenIn;
      path[1] = tokenOut;
      path[2] = USDC;

      if (poolFees[USDC][tokenOut] == 0) fetchPool(USDC, tokenOut, coreXFactory);
    }

    if (poolFees[tokenIn][tokenOut] == 0) fetchPool(tokenIn, tokenOut, coreXFactory);

    _approveTokenIfNeeded(path[0], address(coreXRouter));

    ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
      path: abi.encodePacked(path[0], getPoolFee(path[0], path[1]), path[1], getPoolFee(path[1], path[2]), path[2]),
      recipient: address(this),
      deadline: block.timestamp,
      amountIn: amountIn,
      amountOutMinimum: 0
    });

    // Executes the swap
    ISwapRouter(coreXRouter).exactInput(params);
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

  function deposit(
    IVault vault,
    uint256 amountIn,
    uint256 amountOutMin
  ) public payable onlyWhitelistedVaults(address(vault)) returns (uint256) {
    // depoist Core to coreStaking
    ICoreStaking(CORE_STAKING).mint{value: amountIn}(CORE_VALIDATOR);

    //get clipper vault balance
    uint256 stCoreBal = IERC20(ST_CORE).balanceOf(address(this));

    //depoist clipper vault shares to local vault
    _approveTokenIfNeeded(ST_CORE, address(vault));

    vault.deposit(stCoreBal);

    uint256 vaultBalance = vault.balanceOf(address(this));

    require(vaultBalance >= amountOutMin, "Insignificant amountOutMin");

    //return vault tokens to user
    IERC20(address(vault)).safeTransfer(msg.sender, vaultBalance);

    emit Deposit(msg.sender, vaultBalance);

    return vaultBalance;
  }

  function _redeem(uint256 amount) internal {
    // Check if the user already has a staking contract
    if (userStakingContracts[msg.sender] == address(0)) {
      // If not, create a new UserStakingContract
      UserStakingContract newContract = new UserStakingContract(address(this));
      userStakingContracts[msg.sender] = address(newContract);
    }

    // Get the user's staking contract
    address userContract = userStakingContracts[msg.sender];

    //sending stCore tokens to user's staking contract
    IERC20(ST_CORE).safeTransfer(userContract, amount);

    // Call redeem on the user's staking contract
    require(amount > 1e18, "Insufficient stCore balance, core staking won't allow to redeem");
    UserStakingContract(payable(userContract)).redeem(amount);
  }

  function redeem(IVault vault, uint256 withdrawAmount) external returns (uint256 stCoreRedeemed) {
    vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);

    uint256 stCoreBalBefore = IERC20(ST_CORE).balanceOf(address(this));

    vault.withdraw(withdrawAmount);

    uint256 stCoreBalAfter = IERC20(ST_CORE).balanceOf(address(this));

    stCoreRedeemed = stCoreBalAfter - stCoreBalBefore;

    _redeem(stCoreRedeemed);

    emit Redeem(msg.sender, stCoreRedeemed);
  }

  function zapInETH(
    IVault vault,
    uint256 tokenAmountOutMin,
    address tokenIn
  ) public payable onlyWhitelistedVaults(address(vault)) returns (uint256 vaultBalance) {
    //get tokenAmount
    uint256 _amountIn = msg.value;

    require(tokenIn == wCore, "Invalid tokenIn address");
    require(_amountIn >= minimumAmount, "Insignificant input amount");

    vaultBalance = deposit(vault, _amountIn, tokenAmountOutMin);
  }

  function zapIn(
    IVault vault,
    uint256 tokenAmountOutMin,
    address tokenIn,
    uint256 tokenInAmount
  ) public onlyWhitelistedVaults(address(vault)) returns (uint256 vaultBalance) {
    require(tokenInAmount >= minimumAmount, "Insignificant input amount");

    require(IERC20(tokenIn).allowance(msg.sender, address(this)) >= tokenInAmount, "Input token is not approved");
    // transfer token
    IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), tokenInAmount);

    multiPathSwapV3(tokenIn, USDT, tokenInAmount);

    uint256 wCoreBal = IERC20(wCore).balanceOf(address(this));

    WETH(wCore).withdraw(wCoreBal);

    vaultBalance = deposit(vault, address(this).balance, tokenAmountOutMin);
  }

  function zapOutAndSwapEth(IVault vault) public onlyWhitelistedVaults(address(vault)) returns (uint256 ethBalance) {
    // Get the user's staking contract
    address userContract = userStakingContracts[msg.sender];
    require(userContract != address(0), "User has no staking contract");

    //call withdraw on zapper
    UserStakingContract(payable(userContract)).withdraw();

    ethBalance = address(this).balance;
    // send core(eth) to msg.sender
    (bool sent, ) = payable(msg.sender).call{value: address(this).balance}("");
    require(sent, "Failed to send Ether");

    emit Withdraw(msg.sender, ethBalance);
  }

  function zapOutAndSwap(IVault vault) public onlyWhitelistedVaults(address(vault)) returns (uint256 tokenBalance) {
    // Get the user's staking contract
    address userContract = userStakingContracts[msg.sender];
    require(userContract != address(0), "User has no staking contract");

    //call withdraw on zapper
    UserStakingContract(payable(userContract)).withdraw();

    uint256 ethBalance = address(this).balance;

    WETH(wCore).deposit{value: ethBalance}();

    uint256 wCoreBal = IERC20(wCore).balanceOf(address(this));

    multiPathSwapV3(wCore, USDT, wCoreBal);

    address[] memory returnAssist = new address[](1);
    returnAssist[0] = USDC;

    _returnAssets(returnAssist);

    tokenBalance = IERC20(USDC).balanceOf(msg.sender);

    emit Withdraw(msg.sender, tokenBalance);
  }

  function _approveTokenIfNeeded(address token, address spender) internal {
    if (IERC20(token).allowance(address(this), spender) == 0) {
      IERC20(token).safeApprove(spender, type(uint256).max);
    }
  }
}
