// SPDX-License-Identifier: MIT

pragma solidity ^0.6.7;
pragma experimental ABIEncoderV2;

import "../strategy-base.sol";
import "../../../interfaces/dodo.sol";

contract StrategyDodoHndEthLpV2 is StrategyBase {
    // Token addresses
    address public constant hnd = 0x10010078a54396F62c96dF8532dc2B4847d47ED3;

    // How much HND tokens to keep?
    uint256 public keepHND = 0;
    uint256 public constant keepHNDMax = 10000;

    address public constant rewards =
        0x52C7B4aA3F67D3533aAf1153430758c702a3594b;
    address public constant dodo_hnd_eth_lp =
        0x65E17c52128396443d4A9A61EaCf0970F05F8a20;
    address public constant dodoSwap =
        0x88CBf433471A0CD8240D2a12354362988b4593E5;
    address public constant dodoMultiSwap =
        0x3B6067D4CAa8A14c63fdBE6318F27A0bBc9F9237;
    address public constant dodo_approve =
        0xA867241cDC8d3b0C07C85cC06F25a0cD3b5474d8;

    address[] public dodoEthAdapters;
    address[] public dodoEthPairs;
    address[] public dodoEthSwapTo;

    address[] public hndEthRoute = [dodo_hnd_eth_lp];

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        public
        StrategyBase(
            dodo_hnd_eth_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {
        IERC20(hnd).approve(dodo_approve, uint256(-1));
        IERC20(weth).approve(dodo_approve, uint256(-1));
    }

    function balanceOfPool() public view override returns (uint256) {
        uint256 amount = IDodoMine(rewards).balanceOf(address(this));
        return amount;
    }

    function getHarvestable() external view returns (uint256) {
        uint256 _pendingHnd = IDodoMine(rewards).getPendingRewardByToken(
            address(this),
            hnd
        );
        return _pendingHnd;
    }

    // **** Setters ****

    function setKeepHND(uint256 _keepHND) external {
        require(msg.sender == timelock, "!timelock");
        keepHND = _keepHND;
    }

    function deposit() public override {
        uint256 _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            IERC20(want).safeApprove(rewards, 0);
            IERC20(want).safeApprove(rewards, _want);
            IDodoMine(rewards).deposit(_want);
        }
    }

    function _withdrawSome(uint256 _amount)
        internal
        override
        returns (uint256)
    {
        IDodoMine(rewards).withdraw(_amount);
        return _amount;
    }

    // **** State Mutations ****

    function harvest() public override onlyBenevolent {
        // Anyone can harvest it at any given time.
        // I understand the possibility of being frontrun
        // But ETH is a dark forest, and I wanna see how this plays out
        // i.e. will be be heavily frontrunned?
        //      if so, a new strategy will be deployed.

        // Collects DODO tokens
        IDodoMine(rewards).claimAllRewards();
        uint256 _hnd = IERC20(hnd).balanceOf((address(this)));

        uint256 _keepHND = _hnd.mul(keepHND).div(keepHNDMax);
        if (_keepHND > 0) {
            IERC20(hnd).safeTransfer(
                IController(controller).treasury(),
                _keepHND
            );
            _hnd = _hnd.sub(_keepHND);
        }
        address[] memory path = new address[](1);
        path[0] = dodo_hnd_eth_lp;

        if (_hnd > 0) {
            IDodoSwap(dodoSwap).dodoSwapV2TokenToToken(
                hnd,
                weth,
                _hnd.div(2),
                1,
                path,
                1,
                false,
                now + 60
            );
        }

        // Adds in liquidity for WETH/HND
        _hnd = IERC20(hnd).balanceOf(address(this));
        uint256 _weth = IERC20(weth).balanceOf(address(this));
        if (_weth > 0 && _hnd > 0) {
            IDodoSwap(dodoSwap).addDVMLiquidity(
                dodo_hnd_eth_lp,
                _weth,
                _hnd,
                1,
                1,
                0,
                now + 60
            );
        }

        deposit();
    }

    // **** Views ****

    function getName() external pure override returns (string memory) {
        return "StrategyDodoHndEthLpV2";
    }
}
