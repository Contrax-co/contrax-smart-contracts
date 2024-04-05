// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../lib/erc20.sol";
import "../../lib/safe-math.sol";
import "../../interfaces/ISteerVault.sol";

// Vault address for Usdc/Usdc.e
//0x3eE813a6fCa2AaCAF0b7C72428fC5BC031B9BD65

contract VaultSteerSushiUsdcUsdce is ERC20 {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Address for address;

    address public steerVault = 0x3eE813a6fCa2AaCAF0b7C72428fC5BC031B9BD65;
    
    address public governance;
    address public timelock;

    // Declare a Deposit Event
    event Deposit(
        address indexed _from,
        uint _timestamp,
        uint _value,
        uint _shares
    );

    
    // Declare a Withdraw Event
    event Withdraw(address indexed _from, uint _timestamp, uint _value, uint _shares); 

    constructor(
        address _token,
        address _governance,
        address _timelock
    )
        ERC20(
            string(abi.encodePacked("freezing ", ERC20(_token).name())),
            string(abi.encodePacked("s", ERC20(_token).symbol()))
        )
    {
        _setupDecimals(ERC20(_token).decimals());
        governance = _governance;
        timelock = _timelock;
    }

    function steerVaultTokens() external view returns (address, address) {
        return (ISteerVault(steerVault).token0(), ISteerVault(steerVault).token1());
    }

   

    function balance() public view returns (uint256) {
        return IERC20(steerVault).balanceOf(address(this));
    }

    function setGovernance(address _governance) public {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    function setTimelock(address _timelock) public {
        require(msg.sender == timelock, "!timelock");
        timelock = _timelock;
    }

    function deposit(uint256 _amount) external {
        //Transfer steerVault token to vault
        IERC20(steerVault).safeTransferFrom(msg.sender, address(this), _amount);

        _mint(msg.sender, _amount);

        emit Deposit(tx.origin, block.timestamp, _amount, _amount);
    }

    function withdraw(uint256 _shares) external returns (uint256 amount0, uint256 amount1) {
        //Check if caller has enough shares
        require(balanceOf(msg.sender) >= _shares,"Not enough shares");

        //Withdraw lp token from steer vault
        (amount0,amount1) = ISteerVault(steerVault).withdraw(_shares, 0, 0, msg.sender);

        //burn user shares
        _burn(msg.sender, _shares);

        emit Withdraw(tx.origin, block.timestamp, _shares, _shares);
    }
}
