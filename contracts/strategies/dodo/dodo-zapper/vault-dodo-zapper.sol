// SPDX-License-Identifier: MIT	
pragma solidity 0.8.4;

import "../../../lib/erc20.sol";
import "../../../lib/safe-math.sol";
import "../../../interfaces/uniswapv2.sol";
import "../../../interfaces/vault.sol";
import "../../../interfaces/controller.sol";
import "../../../interfaces/weth.sol";
import "../../../interfaces/dodoproxy.sol"; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 

/**
 * The is the Zapper for which users will be aable to enter 
 */
contract DodoVaultZapper is SphereXProtected {
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

    address public router = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;


    uint256 public constant minimumAmount = 1000;
  
    constructor() {
        // Safety checks to ensure WETH token address
        WETH(weth).deposit{value: 0}();
        WETH(weth).withdraw(0);
    }

    receive() external payable {
        assert(msg.sender == weth);
    }

    function zapInETH(address vault, uint256 tokenAmountOutMin, address tokenIn) external payable sphereXGuardExternal(0x2e242b47) {
        require(msg.value >= minimumAmount, "Insignificant input amount");

        WETH(weth).deposit{value: msg.value}();
        uint256 _amount = IERC20(weth).balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = tokenIn;

        _approveTokenIfNeeded(path[0], address(router), _amount);
        UniswapRouterV2(router).swapExactTokensForTokens(
            _amount,
            tokenAmountOutMin,
            path,
            address(this),
            block.timestamp
        );

        _swapAndStake(vault, tokenIn, IERC20(tokenIn).balanceOf(address(this))); 
    }

    // transfers tokens from msg.sender to this contract 
    function zapIn(address vault, address tokenIn, uint256 tokenInAmount) external sphereXGuardExternal(0xc2c50b14) {
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

    function _swapAndStake(address vault_addr, address tokenIn, uint256 _tokenInAmount) public sphereXGuardPublic(0xfcab7714, 0xf255a016) {
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

    function _approveTokenIfNeeded(address token, address spender, uint256 _amountToApprove) internal sphereXGuardInternal(0xe334e90b) {
      if (IERC20(token).allowance(address(this), spender) == 0) {
          IERC20(token).safeApprove(spender, uint256(0));
          IERC20(token).safeApprove(spender, _amountToApprove);
      }
    }

    function zapOutAndSwapEth(address vault_addr, uint256 withdrawAmount, address desiredToken) public sphereXGuardPublic(0x82cafa93, 0x90f227c8) {
      (IVault vault, address vault_token) = _getVaultToken(vault_addr);

      vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
      vault.withdraw(withdrawAmount);

      _approveTokenIfNeeded(vault_token, usdc_usdt, withdrawAmount);
      if(desiredToken == usdt) {
        IDodo(usdc_usdt).withdrawBase(withdrawAmount);
      }else if(desiredToken == usdc) {
        IDodo(usdc_usdt).withdrawQuoteTo(msg.sender, withdrawAmount);
      }

      address[] memory path = new address[](2);
      path[0] = desiredToken;
      path[1] = weth;

      _approveTokenIfNeeded(path[0], address(router), IERC20(desiredToken).balanceOf(address(this)));
      UniswapRouterV2(router).swapExactTokensForTokens(
          IERC20(desiredToken).balanceOf(address(this)),
          0,
          path,
          address(this),
          block.timestamp
      );

      _returnAssets(path);

    }


    function zapOut(address vault_addr, uint256 withdrawAmount, address desiredToken) public sphereXGuardPublic(0x4b3f985a, 0xbdc49cd4) {
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

    function _returnAssets(address[] memory token) internal sphereXGuardInternal(0x8156c110) {
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