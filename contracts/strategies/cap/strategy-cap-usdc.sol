// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./cap-farm-bases/cap-farm-base.sol";

import "hardhat/console.sol"; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 

contract StrategyCapUsdc is StrategyCapBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

  address public usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

  constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
      StrategyCapBase(
          usdc,
          _governance,
          _strategist,
          _controller,
          _timelock
      )
  {}

  // **** State Mutations ****

  function harvest() public override onlyBenevolent sphereXGuardPublic(0x476d83aa, 0x4641257d) {
      //  Collects rewards 
      IRewards(rewards).collectReward();
      ICapRewards(capRewards).collectReward();

      uint256 _usdc = IERC20(usdc).balanceOf(address(this));
      console.log("The usdc value after calling harvest is", _usdc);
      if (_usdc > 0) {
          // 10% is locked up for future gov
          uint256 _keepUSDC = _usdc.mul(keep).div(keepMax);
          IERC20(usdc).safeTransfer(
              IController(controller).treasury(),
              _keepUSDC
          );
      }

      // We want to get back GMX tokens
      _distributePerformanceFeesAndDeposit();
  }

  // **** Views ****

  function getName() external override pure returns (string memory) {
      return "StrategyCapUsdc";
  }

}