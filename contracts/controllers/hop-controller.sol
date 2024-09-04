// https://github.com/iearn-finance/vaults/blob/master/contracts/controllers/StrategyControllerV1.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
pragma experimental ABIEncoderV2;

import "../interfaces/controller.sol";

import "../lib/erc20.sol";
import "../lib/safe-math.sol";

import "../interfaces/vault.sol";
import "../interfaces/vault-converter.sol";
import "../interfaces/onesplit.sol";
import "../interfaces/strategy.sol";
import "../interfaces/converter.sol"; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 

contract HopController is SphereXProtected {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public constant burn = 0x000000000000000000000000000000000000dEaD;
    address public onesplit = 0xC586BeF4a0992C495Cf22e1aeEE4E446CECDee0E;

    address public governance;
    address public strategist;
    address public devfund;
    address public treasury;
    address public timelock;

    // Convenience fee 0.1%
    uint256 public convenienceFee = 100;
    uint256 public constant convenienceFeeMax = 100000;

    mapping(address => address) public vaults;              // takes lp address and returns associated vault
    mapping(address => address) public strategies;          // takes lp and returns associated strategy
    mapping(address => mapping(address => address)) public converters;
    mapping(address => mapping(address => bool)) public approvedStrategies;
    mapping(address => bool) public approvedVaultConverters;

    uint256 public split = 500;
    uint256 public constant max = 10000;

    constructor(
        address _governance,
        address _strategist,
        address _timelock,
        address _devfund,
        address _treasury
    ) {
        governance = _governance;
        strategist = _strategist;
        timelock = _timelock;
        devfund = _devfund;
        treasury = _treasury;
    }

    function setDevFund(address _devfund) public sphereXGuardPublic(0xfd51e2ce, 0xae4db919) {
        require(msg.sender == governance, "!governance");
        devfund = _devfund;
    }

    function setTreasury(address _treasury) public sphereXGuardPublic(0x07ad30b3, 0xf0f44260) {
        require(msg.sender == governance, "!governance");
        treasury = _treasury;
    }

    function setStrategist(address _strategist) public sphereXGuardPublic(0xe982b845, 0xc7b9d530) {
        require(msg.sender == governance, "!governance");
        strategist = _strategist;
    }

    function setSplit(uint256 _split) public sphereXGuardPublic(0x4558ff37, 0x674e694f) {
        require(msg.sender == governance, "!governance");
        require(_split <= max, "numerator cannot be greater than denominator");
        split = _split;
    }

    function setOneSplit(address _onesplit) public sphereXGuardPublic(0xc4e36f79, 0x8da1df4d) {
        require(msg.sender == governance, "!governance");
        onesplit = _onesplit;
    }

    function setGovernance(address _governance) public sphereXGuardPublic(0xcbe82ff4, 0xab033ea9) {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    function setTimelock(address _timelock) public sphereXGuardPublic(0x799b2928, 0xbdacb303) {
        require(msg.sender == timelock, "!timelock");
        timelock = _timelock;
    }

    function setVault(address _token, address _vault) public sphereXGuardPublic(0xe61d7323, 0x714ccf7b) {
        require(
            msg.sender == strategist || msg.sender == governance,
            "!strategist"
        );
        require(vaults[_token] == address(0), "vault");
        vaults[_token] = _vault;
    }

    function approveVaultConverter(address _converter) public sphereXGuardPublic(0x3bc1faae, 0xa87dda14) {
        require(msg.sender == governance, "!governance");
        approvedVaultConverters[_converter] = true;
    }

    function revokeVaultConverter(address _converter) public sphereXGuardPublic(0x94a135b2, 0x326a3cdc) {
        require(msg.sender == governance, "!governance");
        approvedVaultConverters[_converter] = false;
    }

    function approveStrategy(address _token, address _strategy) public sphereXGuardPublic(0xa6888366, 0xc494448e) {
        require(msg.sender == timelock, "!timelock");
        approvedStrategies[_token][_strategy] = true;
    }

    function revokeStrategy(address _token, address _strategy) public sphereXGuardPublic(0xc83d835d, 0x590bbb60) {
        require(msg.sender == governance, "!governance");
        require(strategies[_token] != _strategy, "cannot revoke active strategy");
        approvedStrategies[_token][_strategy] = false;
    }

    function setConvenienceFee(uint256 _convenienceFee) external sphereXGuardExternal(0x477404b1) {
        require(msg.sender == timelock, "!timelock");
        convenienceFee = _convenienceFee;
    }

    function setStrategy(address _token, address _strategy) public sphereXGuardPublic(0x87936db2, 0x72cb5d97) {
        require(
            msg.sender == strategist || msg.sender == governance,
            "!strategist"
        );
        require(approvedStrategies[_token][_strategy] == true, "!approved");

        address _current = strategies[_token];
        if (_current != address(0)) {
            IStrategy(_current).withdrawAll();
        }
        strategies[_token] = _strategy;
    }

    function earn(address _token, uint256 _amount) public sphereXGuardPublic(0xc4e08624, 0xb02bf4b9) {
        address _strategy = strategies[_token];
        address _want = IStrategy(_strategy).want();
        if (_want != _token) {
            address converter = converters[_token][_want];
            IERC20(_token).safeTransfer(converter, _amount);
            _amount = Converter(converter).convert(_strategy);
            IERC20(_want).safeTransfer(_strategy, _amount);
        } else {
            IERC20(_token).safeTransfer(_strategy, _amount);
        }
        IStrategy(_strategy).deposit();
    }

    function balanceOf(address _token) external view returns (uint256) {
        return IStrategy(strategies[_token]).balanceOf();
    }

    function withdrawAll(address _token) public sphereXGuardPublic(0xcf472c7b, 0xfa09e630) {
        require(
            msg.sender == strategist || msg.sender == governance,
            "!strategist"
        );
        IStrategy(strategies[_token]).withdrawAll();
    }

    function inCaseTokensGetStuck(address _token, uint256 _amount) public sphereXGuardPublic(0x52101e9d, 0xc6d758cb) {
        require(
            msg.sender == strategist || msg.sender == governance,
            "!governance"
        );
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    function inCaseStrategyTokenGetStuck(address _strategy, address _token)
        public
    sphereXGuardPublic(0x69705d7d, 0x197baa6d) {
        require(
            msg.sender == strategist || msg.sender == governance,
            "!governance"
        );
        IStrategy(_strategy).withdraw(_token);
    }

    function getExpectedReturn(
        address _strategy,
        address _token,
        uint256 parts
    ) public view returns (uint256 expected) {
        uint256 _balance = IERC20(_token).balanceOf(_strategy);
        address _want = IStrategy(_strategy).want();
        (expected, ) = OneSplitAudit(onesplit).getExpectedReturn(
            _token,
            _want,
            _balance,
            parts,
            0
        );
    }

    // Only allows to withdraw non-core strategy tokens ~ this is over and above normal yield
    function yearn(
        address _strategy,
        address _token,
        uint256 parts
    ) public sphereXGuardPublic(0xe7ede7ab, 0x04209f48) {
        require(
            msg.sender == strategist || msg.sender == governance,
            "!governance"
        );
        // This contract should never have value in it, but just incase since this is a public call
        uint256 _before = IERC20(_token).balanceOf(address(this));
        IStrategy(_strategy).withdraw(_token);
        uint256 _after = IERC20(_token).balanceOf(address(this));
        if (_after > _before) {
            uint256 _amount = _after.sub(_before);
            address _want = IStrategy(_strategy).want();
            uint256[] memory _distribution;
            uint256 _expected;
            _before = IERC20(_want).balanceOf(address(this));
            IERC20(_token).safeApprove(onesplit, 0);
            IERC20(_token).safeApprove(onesplit, _amount);
            (_expected, _distribution) = OneSplitAudit(onesplit)
                .getExpectedReturn(_token, _want, _amount, parts, 0);
            OneSplitAudit(onesplit).swap(
                _token,
                _want,
                _amount,
                _expected,
                _distribution,
                0
            );
            _after = IERC20(_want).balanceOf(address(this));
            if (_after > _before) {
                _amount = _after.sub(_before);
                uint256 _treasury = _amount.mul(split).div(max);
                earn(_want, _amount.sub(_treasury));
                IERC20(_want).safeTransfer(treasury, _treasury);
            }
        }
    }

    function withdraw(address _token, uint256 _amount) public sphereXGuardPublic(0x865bf049, 0xf3fef3a3) {
        require(msg.sender == vaults[_token], "!vault");
        IStrategy(strategies[_token]).withdraw(_amount);
    }

    function _execute(address _target, bytes memory _data)
        internal
        sphereXGuardInternal(0x8f5eb6ba) returns (bytes memory response)
    {
        require(_target != address(0), "!target");

        // call contract in current context
        assembly {
            let succeeded := delegatecall(
                sub(gas(), 5000),
                _target,
                add(_data, 0x20),
                mload(_data),
                0,
                0
            )
            let size := returndatasize()

            response := mload(0x40)
            mstore(
                0x40,
                add(response, and(add(add(size, 0x20), 0x1f), not(0x1f)))
            )
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            switch iszero(succeeded)
                case 1 {
                    // throw if delegatecall failed
                    revert(add(response, 0x20), size)
                }
        }
    }
}