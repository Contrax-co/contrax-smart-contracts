// SPDX-License-Identifier: Apache2.0
pragma solidity 0.8.4;

import {ISTCoreErrors} from "./interface/IErrors.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract STCore is ERC20, Ownable2Step {
    address public earn;

    bool private setEarnCalled = false;

    event SetEarnAddress(address indexed operator, address earn);

    constructor() ERC20("Liquid staked CORE", "stCORE") {}

    modifier onlyEarn() {
        require(msg.sender == earn, "Not Earn contract");
        _;
    }

    modifier calledOnce() {
        require(!setEarnCalled, "Set earn address can only be called once");
        _;
    }

    function mint(address account, uint256 amount) external onlyEarn {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external onlyEarn {
        _burn(account, amount);
    } 

    function setEarnAddress(address _earn) external onlyOwner calledOnce {
        if (_earn == address(0)) {
            revert ISTCoreErrors.STCoreZeroEarn(_earn);
        }
        earn = _earn;
        setEarnCalled = true;
        emit SetEarnAddress(msg.sender, _earn);
    }
}