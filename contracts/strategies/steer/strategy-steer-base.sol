// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../lib/erc20.sol";
import "../../interfaces/controller.sol";
import "../../lib/safe-math.sol";
import "../../interfaces/ISushiMultiPositionLiquidityManager.sol";
import "../../interfaces/IVaultSteerBase.sol";
import "../../Utils/PriceCalculator.sol";
import "../../interfaces/uniswapv3.sol";
import "../../interfaces/weth.sol";

// import hardhat console log
import "hardhat/console.sol";

abstract contract StrategySteerBase is PriceCalculator {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;


  
  // tokenIn => tokenOut => poolFee
  mapping(address => mapping(address => uint24)) public poolFees;
  // Tokens
  address public want;
  address public feeDistributor = 0xAd86ef5fD2eBc25bb9Db41A1FE8d0f2a322c7839;

  address public steerPeriphery = 0x806c2240793b3738000fcb62C66BF462764B903F;
  ISushiMultiPositionLiquidityManager public steerVault;

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

  // How much tokens to keep? 10%
  uint256 public keep = 1000;
  uint256 public keepReward = 1000;
  uint256 public constant keepMax = 10000;

  address public controller;
  address public strategist;
  address public timelock;
  address public rewardToken;

  // Dex
  address public uniRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

  mapping(address => bool) public harvesters;

  constructor(address _want, address _governance, address _strategist, address _controller, address _timelock) PriceCalculator(_governance) {
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
    
    steerVault = ISushiMultiPositionLiquidityManager(want);

  }

  // **** Modifiers **** //

  modifier onlyBenevolent() {
    require(harvesters[msg.sender] || msg.sender == governance || msg.sender == strategist);
    _;
  }

  function balanceOf() public view returns (uint256) {
    return IERC20(want).balanceOf(address(this));
  }
  

  // **** Setters **** //

  function whitelistHarvester(address _harvester) external {
    require(msg.sender == governance || msg.sender == strategist || harvesters[msg.sender], "not authorized");
    harvesters[_harvester] = true;
  }

  function revokeHarvester(address _harvester) external {
    require(msg.sender == governance || msg.sender == strategist, "not authorized");
    harvesters[_harvester] = false;
  }

  // **** Setters ****

  function setKeep(uint256 _keep) external {
    require(msg.sender == timelock, "!timelock");
    keep = _keep;
  }

  function setKeepReward(uint256 _keepReward) external {
    require(msg.sender == timelock, "!timelock");
    keepReward = _keepReward;
  }

  function setRewardToken(address _rewardToken) external {
    require(msg.sender == timelock || msg.sender == strategist, "!timelock");
    rewardToken = _rewardToken;
  }

  function setFeeDistributor(address _feeDistributor) external {
    require(msg.sender == governance, "not authorized");
    feeDistributor = _feeDistributor;
  }

  function setWithdrawalDevFundFee(uint256 _withdrawalDevFundFee) external {
    require(msg.sender == timelock, "!timelock");
    withdrawalDevFundFee = _withdrawalDevFundFee;
  }

  function setWithdrawalTreasuryFee(uint256 _withdrawalTreasuryFee) external {
    require(msg.sender == timelock, "!timelock");
    withdrawalTreasuryFee = _withdrawalTreasuryFee;
  }

  function setPerformanceDevFee(uint256 _performanceDevFee) external {
    require(msg.sender == timelock, "!timelock");
    performanceDevFee = _performanceDevFee;
  }

  function setPerformanceTreasuryFee(uint256 _performanceTreasuryFee) external {
    require(msg.sender == timelock, "!timelock");
    performanceTreasuryFee = _performanceTreasuryFee;
  }

  function setStrategist(address _strategist) external {
    require(msg.sender == governance, "!governance");
    strategist = _strategist;
  }

  function setGovernance(address _governance) external {
    require(msg.sender == governance, "!governance");
    governance = _governance;
  }

  function setTimelock(address _timelock) external {
    require(msg.sender == timelock, "!timelock");
    timelock = _timelock;
  }

  function setController(address _controller) external {
    require(msg.sender == timelock, "!timelock");
    controller = _controller;
  }

  function getPoolFee(address token0, address token1) public view returns (uint24) {
    uint24 fee = poolFees[token0][token1];
    require(fee > 0, "pool fee is not set");
    return fee;
  }

  function setPoolFees(address _token0, address _token1, uint24 _poolFee) external onlyGovernance {
    require(_poolFee > 0, "pool fee must be greater than 0");
    require(_token0 != address(0) && _token1 != address(0), "invalid address");

    poolFees[_token0][_token1] = _poolFee;
    // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
    poolFees[_token1][_token0] = _poolFee;
  }

  // Controller only function for creating additional rewards from dust
  function withdraw(IERC20 _asset) external returns (uint256 balance) {
    require(msg.sender == controller, "!controller");
    require(want != address(_asset), "want");
    balance = _asset.balanceOf(address(this));
    _asset.safeTransfer(controller, balance);
  }

  // Withdraw partial funds, normally used with a vault withdrawal

  function withdraw(uint256 _amount) external {
    require(msg.sender == controller, "!controller");
    require(balanceOf() >= _amount, "!balance");

    uint256 _feeDev = _amount.mul(withdrawalDevFundFee).div(withdrawalDevFundMax);
    IERC20(want).safeTransfer(IController(controller).devfund(), _feeDev);

    uint256 _feeTreasury = _amount.mul(withdrawalTreasuryFee).div(withdrawalTreasuryMax);
    IERC20(want).safeTransfer(IController(controller).treasury(), _feeTreasury);

    address _vault = IController(controller).vaults(address(want));
    require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds

    IERC20(want).safeTransfer(_vault, _amount.sub(_feeDev).sub(_feeTreasury));
  }

  // Withdraw funds, used to swap between strategies
  function withdrawForSwap(uint256 _amount) external returns (uint256 balance) {
    require(msg.sender == controller, "!controller");
    balance = balanceOf();
    require(balance >= _amount, "!balance");

    address _vault = IController(controller).vaults(address(want));
    require(_vault != address(0), "!vault");
    IERC20(want).safeTransfer(_vault, _amount);
  }

  // Withdraw all funds, normally used when migrating strategies
  function withdrawAll() external returns (uint256 balance) {
    require(msg.sender == controller, "!controller");
    balance = balanceOf();
    address _vault = IController(controller).vaults(address(want));
    require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
    IERC20(want).safeTransfer(_vault, balance);
  }

  function harvest() public virtual;

  function depositToSteerVault(uint256 _amount0, uint256 _amount1) public virtual;

  function getTotalAmounts() public view returns (uint256, uint256) {
    return steerVault.getTotalAmounts();
  }

  function steerVaultTokens() public view  returns (address, address) {
    return (steerVault.token0(), steerVault.token1());
  }

  //returns DUST
  function _returnAssets(address[] memory tokens) internal {
    uint256 balance;
    for (uint256 i; i < tokens.length; i++) {
      balance = IERC20(tokens[i]).balanceOf(address(this));
      if (balance > 0) {
        if (tokens[i] == weth) {
          WETH(weth).withdraw(balance);
          (bool success, ) = msg.sender.call{value: balance}(new bytes(0));
          require(success, "ETH transfer failed");
        } else {
          IERC20(tokens[i]).safeTransfer(msg.sender, balance);
        }
      }
    }
  }


  function _swap(address tokenIn, address tokenOut, uint256 amountIn) internal {
    address[] memory path = new address[](2);
    path[0] = tokenIn;
    path[1] = tokenOut;

    _approveTokenIfNeeded(path[0], address(uniRouter));
    ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
      tokenIn: path[0],
      tokenOut: path[1],
      fee: getPoolFee(tokenIn, tokenOut),
      recipient: address(this),
      deadline: block.timestamp,
      amountIn: amountIn,
      amountOutMinimum: 0,
      sqrtPriceLimitX96: 0
    });

    ISwapRouter(address(uniRouter)).exactInputSingle(params);
  }

  function _approveTokenIfNeeded(address token, address spender) internal {
    if (IERC20(token).allowance(address(this), spender) == 0) {
      IERC20(token).safeApprove(spender, type(uint256).max);
    }
  }

  // **** Emergency functions ****

  function execute(address _target, bytes memory _data) public payable returns (bytes memory response) {
    require(msg.sender == timelock, "!timelock");
    require(_target != address(0), "!target");

    // call contract in current context
    assembly {
      let succeeded := delegatecall(sub(gas(), 5000), _target, add(_data, 0x20), mload(_data), 0, 0)
      let size := returndatasize()

      response := mload(0x40)
      mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
      mstore(response, size)
      returndatacopy(add(response, 0x20), 0, size)

      switch iszero(succeeded)
      case 1 {
        // throw if delegatecall failed
        revert(add(response, 0x20), size)
      }
    }
  }

  function _distributePerformanceFeesAndDeposit() internal {
    uint256 _want = IERC20(want).balanceOf(address(this));

    if (_want > 0) {
      // Treasury fees
      IERC20(want).safeTransfer(
        IController(controller).treasury(),
        _want.mul(performanceTreasuryFee).div(performanceTreasuryMax)
      );

      // Performance fee
      IERC20(want).safeTransfer(IController(controller).devfund(), _want.mul(performanceDevFee).div(performanceDevMax));
    }
  }

  function _distributePerformanceFeesBasedAmountAndDeposit(uint256 _amount) internal {
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
    }
  }
}
