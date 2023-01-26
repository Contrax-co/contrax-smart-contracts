// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IStargateRouter {
  function addLiquidity(
      uint256 _poolId,
      uint256 _amountLD,
      address _to
  ) external; 

   function instantRedeemLocal(
      uint16 _srcPoolId,
      uint256 _amountLP,
      address _to
  ) external returns (uint256 amountSD);
}

interface ILPStaking{
  function userInfo(uint256 _pid, address _user) external view returns(uint256, uint256);
  function pendingStargate(uint256 _pid, address _user) external view returns (uint256);
  function deposit(uint256 _pid, uint256 _amount) external;
  function withdraw(uint256 _pid, uint256 _amount) external;

}

interface IEthRouter {
  function addLiquidityETH() external payable;
}

interface ILPERC20 {
  function balanceOf(address) external view returns (uint256);

  function approve(address spender, uint256 value) external returns (bool);
}