// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../lib/erc20.sol";
import "../../lib/safe-math.sol";

import "../../interfaces/uniswapv2.sol";
import "../../interfaces/controller.sol";
import "hardhat/console.sol";

contract SushiExchange {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    // Dex 
    address public sushiRouter = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;

    address public controller;

    constructor(
        address _controller
    ){
        require(_controller != address(0));

        controller = _controller;
    }

    function swapFromTokenToToken(
        address _from, 
        address _to, 
        uint256 _amount
    ) public {
        require(_to != address(0));

        address[] memory path;

        IERC20(_from).safeTransferFrom(msg.sender, address(this), _amount);

        uint256 bal2 = IERC20(_from).balanceOf(address(this));
        console.log("the balance of the from token for contract is", bal2);
        
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

        console.log("the amount is", _amount);
   
        UniswapRouterV2(sushiRouter).swapExactTokensForTokens(
            _amount,
            0,
            path,
            address(this),
            block.timestamp.add(60)
        );

    }


    function swapTokenForPair(address _from, address _to, uint256 _amount) public {
        require(_to != address(0));

        address token0 = IUniswapV2Pair(_to).token0();
        address token1 = IUniswapV2Pair(_to).token1();

        if(_from == token0){
            swapFromTokenToToken(_from, token1, _amount.div(2));
        }else if (_from == token1){
            swapFromTokenToToken(_from, token0, _amount.div(2));
        }else{
            swapFromTokenToToken(_from, token1, _amount.div(2));
            swapFromTokenToToken(_from, token0, _amount.div(2));
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

    }


    function swapPairForToken(address _from, address _to, uint256 _amount) public {
        require(_to != address(0));

        address token0 = address(IUniswapV2Pair(_from).token0());
        address token1 = address(IUniswapV2Pair(_from).token1());

        IERC20(_from).safeApprove(sushiRouter, 0); 
        IERC20(_from).safeApprove(sushiRouter, _amount); 

        (uint256 _token0, uint256 _token1) = UniswapRouterV2(sushiRouter).removeLiquidity(
            token0, 
            token1, 
            _amount, 
            0, 
            0, 
            address(this), 
            block.timestamp.add(60)
        );

        console.log("are we reaching the far1");

        _token0 = IERC20(token0).balanceOf(address(this));
        _token1 = IERC20(token1).balanceOf(address(this)); 

        if(_to == token0){
            swapFromTokenToToken(token1, _to, _token1); 
        }else if(_to == token1) {
            swapFromTokenToToken(token0, _to, _token0);
        }else {
            swapFromTokenToToken(token1, _to, _token1); 
            swapFromTokenToToken(token0, _to, _token0);
        }
    }

}