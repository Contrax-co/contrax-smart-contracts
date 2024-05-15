// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../interfaces/vault.sol";
import "../../interfaces/controller.sol";
import "../../lib/erc20.sol";
import "../../lib/safe-math.sol";
import "../../interfaces/ISushiMultiPositionLiquidityManager.sol";
import "../../interfaces/ISteerPeriphery.sol";
import "../../interfaces/IVaultSteerBase.sol";

abstract contract StrategyBase {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  // Tokens
  address public want;
  address public constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
  address public feeDistributor = 0xAd86ef5fD2eBc25bb9Db41A1FE8d0f2a322c7839;

  
  ISushiMultiPositionLiquidityManager public steerVault;
  address public steerPeriphery = 0x806c2240793b3738000fcb62C66BF462764B903F;

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

  // User accounts
  address public governance;
  address public controller;
  address public strategist;
  address public timelock;
  address rewardToken;

  // Dex
  address public sushiRouter = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;

  mapping(address => bool) public harvesters;

  constructor(address _want, address _governance, address _strategist, address _controller, address _timelock) {
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

  modifier onlyBenevolent() {
    require(harvesters[msg.sender] || msg.sender == governance || msg.sender == strategist);
    _;
  }

  function balanceOfWant() public view returns (uint256) {
    return IERC20(want).balanceOf(address(this));
  }

  function getName() external pure virtual returns (string memory);

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
    require(balanceOfWant() >= _amount, "!balance");

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
    balance = balanceOfWant();
    require(balance >= _amount, "!balance");

    address _vault = IController(controller).vaults(address(want));
    require(_vault != address(0), "!vault");
    IERC20(want).safeTransfer(_vault, _amount);
  }

  // Withdraw all funds, normally used when migrating strategies
  function withdrawAll() external returns (uint256 balance) {
    require(msg.sender == controller, "!controller");
    balance = balanceOfWant();
    address _vault = IController(controller).vaults(address(want));
    require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
    IERC20(want).safeTransfer(_vault, balance);
  }

  function harvest() public onlyBenevolent {
    require(rewardToken != address(0), "!rewardToken");
    uint256 _reward = IERC20(rewardToken).balanceOf(address(this));
    require(_reward > 0, "!reward");
    uint256 _keepReward = _reward.mul(keepReward).div(keepMax);
    IERC20(rewardToken).safeTransfer(IController(controller).treasury(), _keepReward);

    _reward = IERC20(rewardToken).balanceOf(address(this));

    // convert _rewardToken to to steer vault tokens and add them into steer vaults
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
