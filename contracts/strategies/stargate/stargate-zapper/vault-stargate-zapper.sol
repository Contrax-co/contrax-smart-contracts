// SPDX-License-Identifier: MIT	
pragma solidity 0.8.4;

import "../../../lib/erc20.sol";
import "../../../lib/safe-math.sol";

import "../../../interfaces/uniswapv2.sol";
import "../../../interfaces/vault.sol";
import "../../../interfaces/controller.sol";
import "../../../interfaces/weth.sol";
import "../../../interfaces/stargateRouter.sol"; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 

/**
 * The is the Strategy Base that most LPs will inherit 
 */
contract StargateVaultZapper is SphereXProtected {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IVault;

    address public constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    uint256 public constant minimumAmount = 1000;

    address public stargateRouter;

  
    constructor(address _router) {
        // Safety checks to ensure WETH token address
        WETH(weth).deposit{value: 0}();
        WETH(weth).withdraw(0);
        stargateRouter = _router;
    }

    receive() external payable {
        assert(msg.sender == weth);
    }

    // transfers tokens from msg.sender to this contract 
    function zapIn(address vault, address tokenIn, uint256 tokenInAmount, uint256 poolId) external sphereXGuardExternal(0x0d436f52) {
      require(tokenInAmount >= minimumAmount, "Insignificant input amount");
      require(IERC20(tokenIn).allowance(msg.sender, address(this)) >= tokenInAmount, "Input token is not approved");

      // transfer token 
      IERC20(tokenIn).safeTransferFrom(
          msg.sender,
          address(this),
          tokenInAmount
      );

      _swapAndStake(vault, tokenIn, tokenInAmount, poolId);

    }

    function _swapAndStake(address vault_addr, address tokenIn, uint256 _tokenInAmount, uint256 poolId) public sphereXGuardPublic(0x65527ecb, 0x358c1d86) {
      (IVault vault, address vault_token) = _getVaultToken(vault_addr);

      IERC20(tokenIn).safeApprove(stargateRouter, 0);
      IERC20(tokenIn).safeApprove(stargateRouter, _tokenInAmount);
      IStargateRouter(stargateRouter).addLiquidity(poolId, _tokenInAmount, address(this));

      uint256 amountLiquidity = ILPERC20(vault_token).balanceOf(address(this));

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

    function _approveTokenIfNeeded(address token, address spender, uint256 _amountToApprove) internal sphereXGuardInternal(0xdf56317c) {
      if (IERC20(token).allowance(address(this), spender) == 0) {
          IERC20(token).safeApprove(spender, uint256(0));
          IERC20(token).safeApprove(spender, _amountToApprove);
      }
    }


    function zapOut(address vault_addr, uint256 withdrawAmount, address desiredToken, uint256 poolId) public sphereXGuardPublic(0xa53f2018, 0xa863ff2f) {
      (IVault vault, address vault_token) = _getVaultToken(vault_addr);

      vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
      vault.withdraw(withdrawAmount);

      _approveTokenIfNeeded(vault_token, stargateRouter, withdrawAmount);
      IStargateRouter(stargateRouter).instantRedeemLocal(uint16(poolId), withdrawAmount, address(this));

      address[] memory path = new address[](1);
      path[0] = desiredToken;

      _returnAssets(path);

    }

    function _returnAssets(address[] memory token) internal sphereXGuardInternal(0xe59aede1) {
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