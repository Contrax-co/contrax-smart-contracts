// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../lib/erc20.sol";
import "../../lib/safe-math.sol";
import "../../interfaces/ISushiMultiPositionLiquidityManager.sol";
import "../../interfaces/ISteerPeriphery.sol";
import "../../interfaces/IVaultSteerBase.sol";

contract VaultSteerBase is ERC20, IVaultSteerBase {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;
  using Address for address;

  ISushiMultiPositionLiquidityManager public steerVault;
  address public steerPeriphery = 0x806c2240793b3738000fcb62C66BF462764B903F;

  address public governance;
  address public timelock;

  // Declare a Deposit Event
  event Deposit(address indexed _from, uint _timestamp, uint _value, uint _shares);

  // Declare a Withdraw Event
  event Withdraw(address indexed _from, uint _timestamp, uint _value, uint _shares);

  constructor(
    address _steerVault,
    address _governance,
    address _timelock
  )
    ERC20(
      string(abi.encodePacked("freezing ", ERC20(_steerVault).name())),
      string(abi.encodePacked("s", ERC20(_steerVault).symbol()))
    )
  {
    _setupDecimals(ERC20(_steerVault).decimals());
    governance = _governance;
    timelock = _timelock;
    steerVault = ISushiMultiPositionLiquidityManager(_steerVault);
  }

  function steerVaultTokens() public view override returns (address, address) {
    return (steerVault.token0(), steerVault.token1());
  }

  function balance() public view returns (uint256) {
    return steerVault.balanceOf(address(this));
  }

  function setGovernance(address _governance) public {
    require(msg.sender == governance, "!governance");
    governance = _governance;
  }

  function setTimelock(address _timelock) public {
    require(msg.sender == timelock, "!timelock");
    timelock = _timelock;
  }

  function _returnAssets(address[] memory tokens) internal {
    for (uint256 i; i < tokens.length; i++) {
      uint256 _balance = IERC20(tokens[i]).balanceOf(address(this));
      if (_balance > 0) {
        IERC20(tokens[i]).safeTransfer(msg.sender, _balance);
      }
    }
  }

  function deposit(uint256 amount0, uint256 amount1) external override {
    (address token0, address token1) = steerVaultTokens();

    //approve both tokens to Steer Periphery contract
    _approveTokenIfNeeded(token0, steerPeriphery);
    _approveTokenIfNeeded(token1, steerPeriphery);

    // extract before deposit balance of steerVault
    uint256 beforeBal = steerVault.balanceOf(address(this));

    //deposit to Steer Periphery contract
    ISteerPeriphery(steerPeriphery).deposit(address(steerVault), amount0, amount1, 0, 0, address(this));

    // extract after deposit balance of steerVault
    uint256 afterBal = steerVault.balanceOf(address(this));

    // calculate shares to mint
    uint256 shares = afterBal.sub(beforeBal);

    // mint local vault shares to msg.sender
    _mint(msg.sender, shares);

    address[] memory tokens = new address[](2);
    tokens[0] = token0;
    tokens[1] = token1;
    _returnAssets(tokens);

    emit Deposit(tx.origin, block.timestamp, amount0, amount1);
  }

  function withdraw(uint256 _shares) external override returns (uint256 amount0, uint256 amount1) {
    //Check if caller has enough shares
    require(balanceOf(msg.sender) >= _shares, "Not enough shares");

    //Withdraw lp token from steer vault
    (amount0, amount1) = steerVault.withdraw(_shares, 0, 0, msg.sender);

    //burn user shares
    _burn(msg.sender, _shares);

    emit Withdraw(tx.origin, block.timestamp, _shares, _shares);
  }

  function _approveTokenIfNeeded(address token, address spender) internal {
    if (IERC20(token).allowance(address(this), spender) == 0) {
      IERC20(token).safeApprove(spender, type(uint256).max);
    }
  }

  function getTotalAmounts() public view override returns (uint256, uint256) {
    return steerVault.getTotalAmounts();
  }
}
