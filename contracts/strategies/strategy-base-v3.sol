// SPDX-License-Identifier: MIT	
pragma solidity 0.8.4;
pragma abicoder v2;

import "../lib/erc20.sol";
import "../lib/safe-math.sol";

import "../interfaces/staking-rewards.sol";
import "../interfaces/vault.sol";
import "../interfaces/controller.sol";
import "../interfaces/uniswapv2.sol";
import "../interfaces/uniswapv3.sol"; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 


/**
 * The is the Strategy Base that most LPs will inherit 
 */
abstract contract StrategyBaseV3 is SphereXProtected {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // Tokens
    address public want;
    address public constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    // Dex
    address public uniswapRouterV3 = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public sushiRouter = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address public feeDistributor = 0xAd86ef5fD2eBc25bb9Db41A1FE8d0f2a322c7839;

    // For this example, we will set the pool fee to 0.3%.
    uint24 public constant poolFee = 3000;

    // Perfomance fees - start with 10%
    uint256 public performanceTreasuryFee = 1000;
    uint256 public constant performanceTreasuryMax = 10000;

    uint256 public performanceDevFee = 0;
    uint256 public constant performanceDevMax = 10000;

    // Withdrawal fee 0%
    // - 0% to treasury
    // - 0% to dev fund
    uint256 public withdrawalTreasuryFee = 0;
    uint256 public constant withdrawalTreasuryMax = 100000;

    uint256 public withdrawalDevFundFee = 0;
    uint256 public constant withdrawalDevFundMax = 100000;

    // User accounts
    address public governance;
    address public controller;
    address public strategist;
    address public timelock;

    mapping(address => bool) public harvesters;

    constructor(
        address _want,
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    ) {
        require(_want != address(0));
        require(_governance != address(0));
        require(_strategist != address(0));
        require(_controller != address(0));
        require(_timelock != address(0));

        want = _want;
        governance = _governance;
        strategist = _strategist;
        controller = _controller;
        timelock = _timelock;
    }

    // **** Modifiers **** //

    modifier onlyBenevolent {
        require(
            harvesters[msg.sender] ||
                msg.sender == governance ||
                msg.sender == strategist
        );
        _;
    }

    // **** Views **** //

    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    function balanceOfPool() public virtual view returns (uint256);

    function balanceOf() public view returns (uint256) {
        return balanceOfWant().add(balanceOfPool());
    }

    function getName() external virtual pure returns (string memory);

    // **** Setters **** //

    function whitelistHarvester(address _harvester) external sphereXGuardExternal(0x86fc9901) {
        require(msg.sender == governance ||
             msg.sender == strategist || harvesters[msg.sender], "not authorized");
        harvesters[_harvester] = true;
    }

    function revokeHarvester(address _harvester) external sphereXGuardExternal(0x02b6e561) {
        require(msg.sender == governance ||
             msg.sender == strategist, "not authorized");
        harvesters[_harvester] = false;
    }

    function setFeeDistributor(address _feeDistributor) external sphereXGuardExternal(0x97a57936) {
        require(msg.sender == governance, "not authorized");
        feeDistributor = _feeDistributor;
    }

    function setWithdrawalDevFundFee(uint256 _withdrawalDevFundFee) external sphereXGuardExternal(0xebd49d3d) {
        require(msg.sender == timelock, "!timelock");
        withdrawalDevFundFee = _withdrawalDevFundFee;
    }

    function setWithdrawalTreasuryFee(uint256 _withdrawalTreasuryFee) external sphereXGuardExternal(0xec74197e) {
        require(msg.sender == timelock, "!timelock");
        withdrawalTreasuryFee = _withdrawalTreasuryFee;
    }

    function setPerformanceDevFee(uint256 _performanceDevFee) external sphereXGuardExternal(0x4018db58) {
        require(msg.sender == timelock, "!timelock");
        performanceDevFee = _performanceDevFee;
    }

    function setPerformanceTreasuryFee(uint256 _performanceTreasuryFee)
        external
    sphereXGuardExternal(0xf779b846) {
        require(msg.sender == timelock, "!timelock");
        performanceTreasuryFee = _performanceTreasuryFee;
    }

    function setStrategist(address _strategist) external sphereXGuardExternal(0xc1583d73) {
        require(msg.sender == governance, "!governance");
        strategist = _strategist;
    }

    function setGovernance(address _governance) external sphereXGuardExternal(0x9e0f0547) {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    function setTimelock(address _timelock) external sphereXGuardExternal(0xf7019ba3) {
        require(msg.sender == timelock, "!timelock");
        timelock = _timelock;
    }

    function setController(address _controller) external sphereXGuardExternal(0x630034b2) {
        require(msg.sender == timelock, "!timelock");
        controller = _controller;
    }

    // **** State mutations **** //
    function deposit() public virtual;

    // Controller only function for creating additional rewards from dust
    function withdraw(IERC20 _asset) external sphereXGuardExternal(0x5cc664c5) returns (uint256 balance) {
        require(msg.sender == controller, "!controller");
        require(want != address(_asset), "want");
        balance = _asset.balanceOf(address(this));
        _asset.safeTransfer(controller, balance);
    }

    // Withdraw partial funds, normally used with a vault withdrawal
    function withdraw(uint256 _amount) external sphereXGuardExternal(0xc7631565) {
        require(msg.sender == controller, "!controller");
        uint256 _balance = IERC20(want).balanceOf(address(this));
        if (_balance < _amount) {
            _amount = _withdrawSome(_amount.sub(_balance));
            _amount = _amount.add(_balance);
        }

        uint256 _feeDev = _amount.mul(withdrawalDevFundFee).div(
            withdrawalDevFundMax
        );
        IERC20(want).safeTransfer(IController(controller).devfund(), _feeDev);

        uint256 _feeTreasury = _amount.mul(withdrawalTreasuryFee).div(
            withdrawalTreasuryMax
        );
        IERC20(want).safeTransfer(
            IController(controller).treasury(),
            _feeTreasury
        );

        address _vault = IController(controller).vaults(address(want));
        require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds

        IERC20(want).safeTransfer(_vault, _amount.sub(_feeDev).sub(_feeTreasury));
    }

    // Withdraw funds, used to swap between strategies
    function withdrawForSwap(uint256 _amount)
        external
        sphereXGuardExternal(0xfa7277c5) returns (uint256 balance)
    {
        require(msg.sender == controller, "!controller");
        _withdrawSome(_amount);

        balance = IERC20(want).balanceOf(address(this));

        address _vault = IController(controller).vaults(address(want));
        require(_vault != address(0), "!vault");
        IERC20(want).safeTransfer(_vault, balance);
    }

    // Withdraw all funds, normally used when migrating strategies
    function withdrawAll() external sphereXGuardExternal(0x7d986e0b) returns (uint256 balance) {
        require(msg.sender == controller, "!controller");
        _withdrawAll();

        balance = IERC20(want).balanceOf(address(this));

        address _vault = IController(controller).vaults(address(want));
        require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
        IERC20(want).safeTransfer(_vault, balance);
    }

    function _withdrawAll() internal sphereXGuardInternal(0x4bf43ac1) {
        _withdrawSome(balanceOfPool());
    }

    function _withdrawSome(uint256 _amount) internal virtual returns (uint256);

    function harvest() public virtual;

    // **** Emergency functions ****

    function execute(address _target, bytes memory _data)
        public
        payable
        sphereXGuardPublic(0xabbe62d5, 0x1cff79cd) returns (bytes memory response)
    {
        require(msg.sender == timelock, "!timelock");
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
    // **** Internal functions ****
    function _swapSushiswap(
        address _from,
        address _to,
        uint256 _amount
    ) internal sphereXGuardInternal(0x8bc057a0) {
        require(_to != address(0));

        address[] memory path;

        if (_from == weth || _to == weth) {
            path = new address[](2);
            path[0] = _from;
            path[1] = _to;
        } else {
            path = new address[](3);
            path[0] = _from;
            path[1] = weth;
            path[2] = _to;
        }
        
        IERC20(_from).safeApprove(sushiRouter, 0);
        IERC20(_from).safeApprove(sushiRouter, _amount);
        UniswapRouterV2(sushiRouter).swapExactTokensForTokens(
            _amount,
            0,
            path,
            address(this),
            block.timestamp.add(60)
        );
    }

    function _swapSushiswapWithPath(
        address[] memory path,
        uint256 _amount
    ) internal sphereXGuardInternal(0x40d0c7c3) {
        require(path[1] != address(0));

        IERC20(path[0]).safeApprove(sushiRouter, 0);
        IERC20(path[0]).safeApprove(sushiRouter, _amount);
        UniswapRouterV2(sushiRouter).swapExactTokensForTokens(
            _amount,
            0,
            path,
            address(this),
            block.timestamp.add(60)
        );
    }

    /// @notice swapExactInputSingle swaps a fixed amount of one token for a maximum possible amount of another
    /// using the _from/_to 0.3% pool by calling `exactInputSingle` in the swap router.
    /// @dev The calling address must approve this contract to spend at least `amountIn` worth of its _from token for this function to succeed.
    /// @param _amount The exact amount of _from that will be swapped for _to.
    /// @return amountOut The amount of _to received.
    function _swapUniswap(
        address _from,
        address _to,
        uint256 _amount
    ) internal sphereXGuardInternal(0xb738a882) returns (uint256 amountOut){

        IERC20(_from).safeApprove(uniswapRouterV3, 0);
        IERC20(_from).safeApprove(uniswapRouterV3, _amount);

        ISwapRouter.ExactInputSingleParams memory params =
        ISwapRouter.ExactInputSingleParams({
            tokenIn: _from,
            tokenOut: _to,
            fee: poolFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: _amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        // The call to `exactInputSingle` executes the swap.
        amountOut = ISwapRouter(uniswapRouterV3).exactInputSingle(params);
    }

    function _swapUniswapWithPath(
        address[] memory path,
        uint256 _amount
    ) internal sphereXGuardInternal(0x3e0426f6) returns (uint256 amountOut){

        IERC20(path[0]).safeApprove(uniswapRouterV3, 0);
        IERC20(path[0]).safeApprove(uniswapRouterV3, _amount);

        ISwapRouter.ExactInputParams memory params =
            ISwapRouter.ExactInputParams({
                path: abi.encodePacked(path[0], poolFee, path[1], poolFee, path[2]),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: _amount,
                amountOutMinimum: 0
            });

        // Executes the swap
        amountOut = ISwapRouter(uniswapRouterV3).exactInput(params);
    }

    function _distributePerformanceFeesAndDeposit() internal sphereXGuardInternal(0x5770305f) {
        uint256 _want = IERC20(want).balanceOf(address(this));

        if (_want > 0) {
            // Treasury fees
            IERC20(want).safeTransfer(
                IController(controller).treasury(),
                _want.mul(performanceTreasuryFee).div(performanceTreasuryMax)
            );

            // Performance fee
            IERC20(want).safeTransfer(
                IController(controller).devfund(),
                _want.mul(performanceDevFee).div(performanceDevMax)
            );

            deposit();
        }
    }

    function _distributePerformanceFeesBasedAmountAndDeposit(uint256 _amount) internal sphereXGuardInternal(0x76d32f0a) {
        uint256 _want = IERC20(want).balanceOf(address(this));

        if (_amount > _want) {
            _amount = _want;
        }

        if (_amount > 0) {
            // Treasury fees
            IERC20(want).safeTransfer(
                IController(controller).treasury(),
                _amount.mul(performanceTreasuryFee).div(performanceTreasuryMax)
            );

            // Performance fee
            IERC20(want).safeTransfer(
                IController(controller).devfund(),
                _amount.mul(performanceDevFee).div(performanceDevMax)
            );

            deposit();
        }
    }

}