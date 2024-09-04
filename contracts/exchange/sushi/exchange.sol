// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../lib/erc20.sol";
import "../../lib/safe-math.sol";

import "../../interfaces/uniswapv2.sol";
import "../../interfaces/controller.sol";
import "../../interfaces/weth.sol"; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 

contract SushiExchange is SphereXProtected {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    uint256 public constant minimumAmount = 1000;

    // Dex 
    address public sushiRouter = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;

    address public controller;

    constructor(
        address _controller
    ){
        require(_controller != address(0));

        controller = _controller;
    }

    function swapFromEthToToken(
        address _to
    ) external payable sphereXGuardExternal(0xcc045914) {
        require(msg.value >= minimumAmount, "Insignificant input amount");

        WETH(weth).deposit{value: msg.value}();

        uint256 _amount = IERC20(weth).balanceOf(address(this));
        address[] memory path;

        if(_to == weth){
            IERC20(weth).safeTransfer(msg.sender, _amount);

        }else{
            path = new address[](2);
            path[0] = weth;
            path[1] = _to;

            IERC20(weth).safeApprove(sushiRouter, 0);
            IERC20(weth).safeApprove(sushiRouter, _amount);

            UniswapRouterV2(sushiRouter).swapExactTokensForTokens(
                _amount,
                0,
                path,
                address(this),
                block.timestamp.add(60)
            );

            uint256 _toBal = IERC20(_to).balanceOf(address(this));
            IERC20(_to).safeTransfer(msg.sender, _toBal);
        }
    }


    function swapFromTokenToEth(
        address _from, 
        uint256 _amount
    ) public sphereXGuardPublic(0x089e1194, 0x7fd97024) {
        require(_from != address(0));

        IERC20(_from).safeTransferFrom(msg.sender, address(this), _amount);

        if (_from == weth){
            uint256 _weth = IERC20(weth).balanceOf(address(this)); 
            WETH(weth).withdrawTo(msg.sender, _weth);
        }
        else {
            swapFromTokenToWethInternal(_from, _amount);
            uint256 _weth = IERC20(weth).balanceOf(address(this)); 
            WETH(weth).withdrawTo(msg.sender, _weth);
        }
    }

    function swapFromTokenToWethInternal(
        address _from, 
        uint256 _amount
    ) internal sphereXGuardInternal(0x25aa95ce) {
        address[] memory path;
        
        path = new address[](2);
        path[0] = _from;
        path[1] = weth;

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


    function swapFromTokenToToken(
        address _from, 
        address _to, 
        uint256 _amount
    ) public sphereXGuardPublic(0xecc4ba93, 0x46ec8522) {
        require(_to != address(0));
        require(_amount >= minimumAmount, "Insignificant input amount");

        address[] memory path;

        IERC20(_from).safeTransferFrom(msg.sender, address(this), _amount);
        
        if(_from == weth || _to == weth){
            path = new address[](2);
            path[0] = _from;
            path[1] = _to;

        }else{
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

        uint256 _toBal = IERC20(_to).balanceOf(address(this));
        IERC20(_to).safeTransfer(msg.sender, _toBal);
    }


    function swapFromTokenToTokenInternal(
        address _from, 
        address _to, 
        uint256 _amount
    ) internal sphereXGuardInternal(0x7a9aad24) {
        require(_to != address(0));

        address[] memory path;
        
        if(_from == weth || _to == weth){
            path = new address[](2);
            path[0] = _from;
            path[1] = _to;

        }else{
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

    function swapEthForPair(address _to) external payable sphereXGuardExternal(0xb835dee0) {
        require(msg.value >= minimumAmount, "Insignificant input amount");

        WETH(weth).deposit{value: msg.value}();

        uint256 _amount = IERC20(weth).balanceOf(address(this));

        swapEthForPairInternal(weth, _to, _amount); 

    }

    function swapEthForPairInternal(
        address _from, 
        address _to, 
        uint256 _amount
    ) internal sphereXGuardInternal(0x99778ee5) {
        address token0 = IUniswapV2Pair(_to).token0();
        address token1 = IUniswapV2Pair(_to).token1();

        if(_from == token0){
            swapFromTokenToTokenInternal(_from, token1, _amount.div(2));
        }else if (_from == token1){
            swapFromTokenToTokenInternal(_from, token0, _amount.div(2));
        }else{
            swapFromTokenToTokenInternal(_from, token1, _amount.div(2));
            swapFromTokenToTokenInternal(_from, token0, _amount.div(2));
        }
        
        // Adds in liquidity for token0/token1
        uint256 _token0 = IERC20(token0).balanceOf(address(this));
        uint256 _token1 = IERC20(token1).balanceOf(address(this));
        if (_token0 > 0 && _token1 > 0) {
            IERC20(token0).safeApprove(sushiRouter, 0);
            IERC20(token0).safeApprove(sushiRouter, _token0);
            IERC20(token1).safeApprove(sushiRouter, 0);
            IERC20(token1).safeApprove(sushiRouter, _token1);

            UniswapRouterV2(sushiRouter).addLiquidity(
                token0,
                token1,
                _token0,
                _token1,
                0,
                0,
                address(this),
                block.timestamp.add(60)
            );

            // Donates DUST
            IERC20(token0).transfer(
                IController(controller).treasury(),
                IERC20(token0).balanceOf(address(this))
            );
            IERC20(token1).safeTransfer(
                IController(controller).treasury(),
                IERC20(token1).balanceOf(address(this))
            );
        }

        uint256 _toBal = IERC20(_to).balanceOf(address(this));
        IERC20(_to).safeTransfer(msg.sender, _toBal);
    }


    function swapTokenForPair(
        address _from, 
        address _to, 
        uint256 _amount
    ) public sphereXGuardPublic(0xe7f80212, 0x60629de3) {
        require(_to != address(0));
        require(_amount >= minimumAmount, "Insignificant input amount");

        IERC20(_from).safeTransferFrom(msg.sender, address(this), _amount);

        address token0 = IUniswapV2Pair(_to).token0();
        address token1 = IUniswapV2Pair(_to).token1();

        if(_from == token0){
            swapFromTokenToTokenInternal(_from, token1, _amount.div(2));
        }else if (_from == token1){
            swapFromTokenToTokenInternal(_from, token0, _amount.div(2));
        }else{
            swapFromTokenToTokenInternal(_from, token1, _amount.div(2));
            swapFromTokenToTokenInternal(_from, token0, _amount.div(2));
        }
        
        // Adds in liquidity for token0/token1
        uint256 _token0 = IERC20(token0).balanceOf(address(this));
        uint256 _token1 = IERC20(token1).balanceOf(address(this));
        if (_token0 > 0 && _token1 > 0) {
            IERC20(token0).safeApprove(sushiRouter, 0);
            IERC20(token0).safeApprove(sushiRouter, _token0);
            IERC20(token1).safeApprove(sushiRouter, 0);
            IERC20(token1).safeApprove(sushiRouter, _token1);

            UniswapRouterV2(sushiRouter).addLiquidity(
                token0,
                token1,
                _token0,
                _token1,
                0,
                0,
                address(this),
                block.timestamp.add(60)
            );

            // Donates DUST
            IERC20(token0).transfer(
                IController(controller).treasury(),
                IERC20(token0).balanceOf(address(this))
            );
            IERC20(token1).safeTransfer(
                IController(controller).treasury(),
                IERC20(token1).balanceOf(address(this))
            );
        }

        uint256 _toBal = IERC20(_to).balanceOf(address(this));
        IERC20(_to).safeTransfer(msg.sender, _toBal);
    }

    function swapPairForEth(address _from, uint256 _amount) public sphereXGuardPublic(0x759566fa, 0x8212b373) {
        swapPairForWeth(_from, _amount);

        uint256 _weth = IERC20(weth).balanceOf(address(this)); 

        WETH(weth).withdrawTo(msg.sender, _weth);
    }

    function swapPairForWeth(address _from, uint256 _amount) internal sphereXGuardInternal(0xf34ed4c2) {

        IERC20(_from).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _liquidity = IERC20(_from).balanceOf(address(this));

        address token0 = IUniswapV2Pair(_from).token0();
        address token1 = IUniswapV2Pair(_from).token1();

        IERC20(_from).safeApprove(sushiRouter, 0); 
        IERC20(_from).safeApprove(sushiRouter, _liquidity); 

        UniswapRouterV2(sushiRouter).removeLiquidity(
            token0, 
            token1, 
            _liquidity, 
            0, 
            0, 
            address(this), 
            block.timestamp.add(60)
        );

        uint256 _token0 = IERC20(token0).balanceOf(address(this));
        uint256 _token1 = IERC20(token1).balanceOf(address(this)); 

        if(token0 == weth){
            swapFromTokenToTokenInternal(token1, weth, _token1); 
        }else if(token1 == weth) {
            swapFromTokenToTokenInternal(token0, weth, _token0);
        }else {
            swapFromTokenToTokenInternal(token1, weth, _token1); 
            swapFromTokenToTokenInternal(token0, weth, _token0);
        }
    }


    function swapPairForToken(
        address _from, 
        address _to, 
        uint256 _amount
    ) public sphereXGuardPublic(0xf191d8c0, 0x2df6d7c4) {
        require(_to != address(0));

        IERC20(_from).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _liquidity = IERC20(_from).balanceOf(address(this));

        address token0 = IUniswapV2Pair(_from).token0();
        address token1 = IUniswapV2Pair(_from).token1();

        IERC20(_from).safeApprove(sushiRouter, 0); 
        IERC20(_from).safeApprove(sushiRouter, _liquidity); 

        UniswapRouterV2(sushiRouter).removeLiquidity(
            token0, 
            token1, 
            _liquidity, 
            0, 
            0, 
            address(this), 
            block.timestamp.add(60)
        );

        uint256 _token0 = IERC20(token0).balanceOf(address(this));
        uint256 _token1 = IERC20(token1).balanceOf(address(this)); 

        if(_to == token0){
            swapFromTokenToTokenInternal(token1, _to, _token1); 
        }else if(_to == token1) {
            swapFromTokenToTokenInternal(token0, _to, _token0);
        }else {
            swapFromTokenToTokenInternal(token1, _to, _token1); 
            swapFromTokenToTokenInternal(token0, _to, _token0);
        }

        uint256 _toBal = IERC20(_to).balanceOf(address(this));
        IERC20(_to).safeTransfer(msg.sender, _toBal);
    }

    function removeLiquidityInternal(address _from, uint256 _amount) internal sphereXGuardInternal(0x733e900b) {
        address token0 = IUniswapV2Pair(_from).token0();
        address token1 = IUniswapV2Pair(_from).token1();

        IERC20(_from).safeApprove(sushiRouter, 0); 
        IERC20(_from).safeApprove(sushiRouter, _amount); 

        UniswapRouterV2(sushiRouter).removeLiquidity(
            token0, 
            token1, 
            _amount, 
            0, 
            0, 
            address(this), 
            block.timestamp.add(60)
        );

        uint256 _token0 = IERC20(token0).balanceOf(address(this));
        uint256 _token1 = IERC20(token1).balanceOf(address(this)); 

        if(token0 == weth){
            swapFromTokenToTokenInternal(token1, weth, _token1);
        }else if(token1 == weth){
            swapFromTokenToTokenInternal(token0, weth, _token0);
        }else{
            swapFromTokenToTokenInternal(token0, weth, _token0);
            swapFromTokenToTokenInternal(token1, weth, _token1);
        }
    }

    function addLiquidityInternal(address token0, address token1) internal sphereXGuardInternal(0xe2f53984) {
        // Adds in liquidity for token0/token1
        uint256 _token0 = IERC20(token0).balanceOf(address(this));
        uint256 _token1 = IERC20(token1).balanceOf(address(this));

         if (_token0 > 0 && _token1 > 0) {
            IERC20(token0).safeApprove(sushiRouter, 0);
            IERC20(token0).safeApprove(sushiRouter, _token0);
            IERC20(token1).safeApprove(sushiRouter, 0);
            IERC20(token1).safeApprove(sushiRouter, _token1);

             UniswapRouterV2(sushiRouter).addLiquidity(
                token0,
                token1,
                _token0,
                _token1,
                0,
                0,
                address(this),
                block.timestamp.add(60)
            );

            // Donates DUST
            IERC20(token0).transfer(
                IController(controller).treasury(),
                IERC20(token0).balanceOf(address(this))
            );
            IERC20(token1).safeTransfer(
                IController(controller).treasury(),
                IERC20(token1).balanceOf(address(this))
            );

         }
    }

    function swapPairForPair(
        address _from, 
        address _to, 
        uint256 _amount
    ) public sphereXGuardPublic(0xfca6ddce, 0xe0954698) {
        require(_to != address(0));

        IERC20(_from).safeTransferFrom(msg.sender, address(this), _amount);
        
        removeLiquidityInternal(_from, _amount); 

        uint256 _wethBal = IERC20(weth).balanceOf(address(this));

        address token0 = IUniswapV2Pair(_to).token0();
        address token1 = IUniswapV2Pair(_to).token1();

        if(token0 == weth){
            swapFromTokenToTokenInternal(weth, token1, _wethBal.div(2)); 
        }else if(token1 == weth){
            swapFromTokenToTokenInternal(weth, token0, _wethBal.div(2)); 
        }else{
            swapFromTokenToTokenInternal(weth, token0, _wethBal.div(2)); 
            swapFromTokenToTokenInternal(weth, token1, _wethBal.div(2)); 
        }

        addLiquidityInternal(token0, token1); 

        uint256 _toBal = IERC20(_to).balanceOf(address(this)); 
        IERC20(_to).safeTransfer(msg.sender, _toBal);

    }

}