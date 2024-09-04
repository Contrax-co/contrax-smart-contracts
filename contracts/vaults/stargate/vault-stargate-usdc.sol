// https://github.com/iearn-finance/vaults/blob/master/contracts/vaults/yVault.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../interfaces/controller.sol";

import "../../lib/erc20.sol";
import "../../lib/safe-math.sol"; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 

contract VaultStargateUsdc is ERC20 {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    IERC20 public token;

    uint256 public min = 9500;
    uint256 public constant max = 10000;

    address public governance;
    address public timelock;
    address public controller;

    constructor(
        address _token,
        address _governance,
        address _timelock,
        address _controller
    )
        ERC20(
            string(abi.encodePacked("freezing ", ERC20(_token).name())),
            string(abi.encodePacked("s", ERC20(_token).symbol()))
        )
    {
        _setupDecimals(ERC20(_token).decimals());
        token = IERC20(_token);
        governance = _governance;
        timelock = _timelock;
        controller = _controller;
    }

    function balance() public view returns (uint256) {
        return
            token.balanceOf(address(this)).add(
                IController(controller).balanceOf(address(token))
            );
    }

    function setMin(uint256 _min) external sphereXGuardExternal(0x7366fdcd) {
        require(msg.sender == governance, "!governance");
        require(_min <= max, "numerator cannot be greater than denominator");
        min = _min;
    }

    function setGovernance(address _governance) public sphereXGuardPublic(0x15d0014d, 0xab033ea9) {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    function setTimelock(address _timelock) public sphereXGuardPublic(0x86a1e858, 0xbdacb303) {
        require(msg.sender == timelock, "!timelock");
        timelock = _timelock;
    }

    function setController(address _controller) public sphereXGuardPublic(0x7b465183, 0x92eefe9b) {
        require(msg.sender == timelock, "!timelock");
        controller = _controller;
    }

    // Custom logic in here for how much the vault allows to be borrowed
    // Sets minimum required on-hand to keep small withdrawals cheap
    function available() public view returns (uint256) {
        return token.balanceOf(address(this)).mul(min).div(max);
    }

    function earn() public sphereXGuardPublic(0x1480700e, 0xd389800f) {
        uint256 _bal = available();
        token.safeTransfer(controller, _bal);
        IController(controller).earn(address(token), _bal);
    }

    function depositAll() external sphereXGuardExternal(0x36662f67) {
        deposit(token.balanceOf(msg.sender));
    }

    function deposit(uint256 _amount) public sphereXGuardPublic(0x24c4cfd4, 0xb6b55f25) {
        uint256 _pool = balance();
        uint256 _before = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _after = token.balanceOf(address(this));
        _amount = _after.sub(_before); // Additional check for deflationary tokens
        uint256 shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(totalSupply())).div(_pool);
        }
        _mint(msg.sender, shares);
    }

    function withdrawAll() external sphereXGuardExternal(0x273c3e6b) {
        withdraw(balanceOf(msg.sender));
    }

    // Used to swap any borrowed reserve over the debt limit to liquidate to 'token'
    function harvest(address reserve, uint256 amount) external sphereXGuardExternal(0x9426b1e0) {
        require(msg.sender == controller, "!controller");
        require(reserve != address(token), "token");
        IERC20(reserve).safeTransfer(controller, amount);
    }

    // No rebalance implementation for lower fees and faster swaps
    function withdraw(uint256 _shares) public sphereXGuardPublic(0xe524a453, 0x2e1a7d4d) {
        uint256 r = (balance().mul(_shares)).div(totalSupply());
        _burn(msg.sender, _shares);

        // Check balance
        uint256 b = token.balanceOf(address(this));
        if (b < r) {
            uint256 _withdraw = r.sub(b);
            IController(controller).withdraw(address(token), _withdraw);
            uint256 _after = token.balanceOf(address(this));
            uint256 _diff = _after.sub(b);
            if (_diff < _withdraw) {
                r = b.add(_diff);
            }
        }

        token.safeTransfer(msg.sender, r);
    }

    function getRatio() public view returns (uint256) {
        return balance().mul(1e18).div(totalSupply());
    }
}