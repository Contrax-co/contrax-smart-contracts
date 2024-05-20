// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../lib/erc20.sol";
import "../../lib/safe-math.sol";
import "../../interfaces/controller.sol";
import "../../interfaces/ISushiMultiPositionLiquidityManager.sol";
import "../../interfaces/ISteerPeriphery.sol";
import "../../interfaces/vault.sol";

contract VaultSteerBase is ERC20 {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;
  using Address for address;

  IERC20 public token;

  uint256 public min = 9500;
  uint256 public constant max = 10000;

  address public governance;
  address public timelock;
  address public controller;

  // Declare a Deposit Event
  event Deposit(address indexed _from, uint _timestamp, uint _value, uint _shares);

  // Declare a Withdraw Event
  event Withdraw(address indexed _from, uint _timestamp, uint _value, uint _shares);

  constructor(
    address _steerVault,
    address _governance,
    address _timelock,
    address _controller
  )
    ERC20(
      string(abi.encodePacked("freezing ", ERC20(_steerVault).name())),
      string(abi.encodePacked("s", ERC20(_steerVault).symbol()))
    )
  {
    _setupDecimals(ERC20(_steerVault).decimals());
    governance = _governance;
    timelock = _timelock;
    token = IERC20(_steerVault);
    controller = _controller;
  }

  function setMin(uint256 _min) external {
    require(msg.sender == governance, "!governance");
    require(_min <= max, "numerator cannot be greater than denominator");
    min = _min;
  }

  function balance() public view returns (uint256) {
    return token.balanceOf(address(this)).add(IController(controller).balanceOf(address(token)));
  }

  function setGovernance(address _governance) public {
    require(msg.sender == governance, "!governance");
    governance = _governance;
  }

  function setController(address _controller) public {
    require(msg.sender == timelock, "!timelock");
    controller = _controller;
  }

  function setTimelock(address _timelock) public {
    require(msg.sender == timelock, "!timelock");
    timelock = _timelock;
  }

  function available() public view returns (uint256) {
    return token.balanceOf(address(this)).mul(min).div(max);
  }

  function earn() public {
    uint256 _bal = available();
    token.safeTransfer(controller, _bal);
    IController(controller).earn(address(token), _bal);
  }

  function depositAll() external {
    deposit(token.balanceOf(msg.sender));
  }
 
  function deposit(uint256 _amount) public {
    // extract before deposit balance of token
    uint256 beforeBal = token.balanceOf(address(this));

    token.safeTransferFrom(msg.sender, address(this), _amount);
    // extract after deposit balance of token
    uint256 afterBal = token.balanceOf(address(this));

    // calculate shares to mint
    _amount = afterBal.sub(beforeBal);

    uint256 shares = 0;
    if (totalSupply() == 0) {
      shares = _amount;
    } else {
      shares = (_amount.mul(totalSupply())).div(balance());
    }

    // mint local vault shares to msg.sender
    _mint(msg.sender, shares);

    emit Deposit(tx.origin, block.timestamp, _amount, shares);
  }

  function withdraw(uint256 _shares) public {
    uint256 ratio = (balance().mul(_shares)).div(totalSupply());

    //burn user shares
    _burn(msg.sender, _shares);

    // Check vault balance
    uint256 bal = token.balanceOf(address(this));

    if (bal < ratio) {
      uint256 _withdraw = ratio.sub(bal);
      IController(controller).withdraw(address(token), _withdraw);
      uint256 _after = token.balanceOf(address(this));
      uint256 _diff = _after.sub(bal);
      if (_diff < _withdraw) {
        ratio = bal.add(_diff);
      }
    }

    token.safeTransfer(msg.sender, ratio);
    emit Withdraw(tx.origin, block.timestamp, ratio, _shares);
  }

  function withdrawAll() external {
    withdraw(balanceOf(msg.sender));
  }

  // Used to swap any borrowed reserve over the debt limit to liquidate to 'token'
  function harvest(address reserve, uint256 amount) external {
    require(msg.sender == controller, "!controller");
    require(reserve != address(token), "token");
    IERC20(reserve).safeTransfer(controller, amount);
  }

  function getRatio() public view returns (uint256) {
    return balance().mul(1e18).div(totalSupply());
  }
}
