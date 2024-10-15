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

  // Define a mapping to store whether an address is whitelisted or not
  mapping(address => bool) public whitelistedVaults;

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

  // Function to add a vault to the whitelist
  function addToWhitelist(address _vault) external onlyGovernance {
    whitelistedVaults[_vault] = true;
  }

  // Function to remove a vault from the whitelist
  function removeFromWhitelist(address _vault) external onlyGovernance {
    whitelistedVaults[_vault] = false;
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

    emit Redeem(msg.sender, amount);
  }

  function redeem(IVault vault, uint256 withdrawAmount) external {
    vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);

    uint256 stCoreBalBefore = IERC20(ST_CORE).balanceOf(address(this));

    vault.withdraw(withdrawAmount);

    uint256 stCoreBalAfter = IERC20(ST_CORE).balanceOf(address(this));

    uint256 stCoreRedeemed = stCoreBalAfter - stCoreBalBefore;

    _redeem(stCoreRedeemed);
  }

  function zapInETH(
    IVault vault,
    uint256 tokenAmountOutMin
  ) public payable onlyWhitelistedVaults(address(vault)) returns (uint256 vaultBalance) {
    //get tokenAmount
    uint256 _amountIn = msg.value;

    require(_amountIn >= minimumAmount, "Insignificant input amount");

    vaultBalance = deposit(vault, _amountIn, tokenAmountOutMin);
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

  function _approveTokenIfNeeded(address token, address spender) internal {
    if (IERC20(token).allowance(address(this), spender) == 0) {
      IERC20(token).safeApprove(spender, type(uint256).max);
    }
  }
}
