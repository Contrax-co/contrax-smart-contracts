// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IDodoProxy {
  function addLiquidityToV1(
    address pair,
    uint256 baseAmount,
    uint256 quoteAmount,
    uint256 baseMinShares,
    uint256 quoteMinShares,
    uint8 flag, 
    uint256 deadLine
  ) external payable returns(uint256, uint256);
}

interface IDodoMining {
  function deposit(address _lpToken, uint256 _amount) external; 
  function getPendingReward(address _lpToken, address _user) external view returns (uint256); 
  function getUserLpBalance(address _lpToken, address _user) external view returns (uint256); 
  function withdraw(address _lpToken, uint256 _amount) external; 
  function claim(address _lpToken) external;
}

interface IDodo {
  function withdrawBase(uint256 amount) external returns (uint256); 
  function withdrawQuote(uint256 amount) external returns (uint256);
  function getLpBaseBalance(address lp) external view returns (uint256 lpBalance);
  function getLpQuoteBalance(address lp) external view returns (uint256 lpBalance);
}