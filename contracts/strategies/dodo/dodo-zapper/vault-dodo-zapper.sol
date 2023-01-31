// SPDX-License-Identifier: MIT	
pragma solidity 0.8.4;

import "../../../lib/erc20.sol";
import "../../../lib/safe-math.sol";

import "../../../interfaces/uniswapv2.sol";
import "../../../interfaces/vault.sol";
import "../../../interfaces/controller.sol";
import "../../../interfaces/weth.sol";
import "../../../interfaces/dodoproxy.sol";

/**
 * The is the Zapper for which users will be aable to enter 
 */
contract DodoVaultZapper {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IVault;

    // Token addresses
    address public constant usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public constant usdt = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; 
    address public constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    address public constant dodo_approve = 0xA867241cDC8d3b0C07C85cC06F25a0cD3b5474d8; 
    address public constant usdc_usdt = 0xe4B2Dfc82977dd2DCE7E8d37895a6A8F50CbB4fB; 
    address public constant dodo_proxy = 0x88CBf433471A0CD8240D2a12354362988b4593E5;


    uint256 public constant minimumAmount = 1000;
  
    constructor() {
        // Safety checks to ensure WETH token address
        WETH(weth).deposit{value: 0}();
        WETH(weth).withdraw(0);
    }

    receive() external payable {
        assert(msg.sender == weth);
    }

    // transfers tokens from msg.sender to this contract 
    function zapIn(address vault, address tokenIn, uint256 tokenInAmount) external {
      require(tokenInAmount >= minimumAmount, "Insignificant input amount");
      require(IERC20(tokenIn).allowance(msg.sender, address(this)) >= tokenInAmount, "Input token is not approved");

      // transfer token 
      IERC20(tokenIn).safeTransferFrom(
          msg.sender,
          address(this),
          tokenInAmount
      );

      _swapAndStake(vault, tokenIn, tokenInAmount);

    }

    function _swapAndStake(address vault_addr, address tokenIn, uint256 _tokenInAmount) public {
      (IVault vault, address vault_token) = _getVaultToken(vault_addr);

      _approveTokenIfNeeded(tokenIn, dodo_approve, _tokenInAmount);
      if(tokenIn == usdt) {
          IDodoProxy(dodo_proxy).addLiquidityToV1(usdc_usdt, _tokenInAmount, 0, 0, 0, 0, block.timestamp.add(60));
      }else if (tokenIn == usdc) {
          IDodoProxy(dodo_proxy).addLiquidityToV1(usdc_usdt, 0, _tokenInAmount, 0, 0, 0, block.timestamp.add(60));
      }

      uint256 amountLiquidity = IERC20(vault_token).balanceOf(address(this));

      _approveTokenIfNeeded(vault_token, vault_addr, amountLiquidity);
      vault.deposit(amountLiquidity);

      // add to guage if possible instead of returning to user, and so no receipt token
      vault.safeTransfer(msg.sender, vault.balanceOf(address(this)));

      // taking receipt token and sending back to user
      vault.safeTransfer(msg.sender, vault.balanceOf(address(this)));

    }

    function _getVaultToken(address vault_addr) internal view returns (IVault vault,address vault_token){
      vault = IVault(vault_addr);
      vault_token = IVault(vault_addr).token();
    }

    function _approveTokenIfNeeded(address token, address spender, uint256 _amountToApprove) internal {
      if (IERC20(token).allowance(address(this), spender) == 0) {
          IERC20(token).safeApprove(spender, uint256(0));
          IERC20(token).safeApprove(spender, _amountToApprove);
      }
    }


    function zapOut(address vault_addr, uint256 withdrawAmount, address desiredToken) public {
      (IVault vault, address vault_token) = _getVaultToken(vault_addr);

      vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
      vault.withdraw(withdrawAmount);

      _approveTokenIfNeeded(vault_token, usdc_usdt, withdrawAmount);
      if(desiredToken == usdt) {
        IDodo(usdc_usdt).withdrawBase(withdrawAmount);
      }else if(desiredToken == usdc) {
        IDodo(usdc_usdt).withdrawQuoteTo(msg.sender, withdrawAmount);
      }

      address[] memory path = new address[](1);
      path[0] = desiredToken;

      _returnAssets(path);

    }

    function _returnAssets(address[] memory token) internal {
      uint256 balance;
      for (uint256 i; i < token.length; i++) {
          balance = IERC20(token[i]).balanceOf(address(this));
          if (balance > 0) {
              if (token[i] == weth) {
                  WETH(weth).withdraw(balance);
                  (bool success, ) = msg.sender.call{value: balance}(
                      new bytes(0)
                  );
                  require(success, "ETH transfer failed");
              } else {
                  IERC20(token[i]).safeTransfer(msg.sender, balance);
              }
          }
      }
    }

}