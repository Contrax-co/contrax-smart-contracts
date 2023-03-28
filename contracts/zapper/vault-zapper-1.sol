// Sources flattened with hardhat v2.9.9 https://hardhat.org

// File contracts/lib/safe-math.sol

// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "../lib/erc20.sol";
import "../lib/safe-math.sol";

// File contracts/interfaces/uniswapv2.sol


pragma solidity 0.8.4;

interface UniswapRouterV2 {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

     function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

     function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
}

interface IUniswapV2Pair {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;
}

interface IUniswapV2Factory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}


// File contracts/lib/square-root.sol

// File: @uniswap/lib/contracts/libraries/Babylonian.sol

pragma solidity 0.8.4;

// computes square roots using the babylonian method
// https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method
library Babylonian {
    // credit for this implementation goes to
    // https://github.com/abdk-consulting/abdk-libraries-solidity/blob/master/ABDKMath64x64.sol#L687
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        // this block is equivalent to r = uint256(1) << (BitMath.mostSignificantBit(x) / 2);
        // however that code costs significantly more gas
        uint256 xx = x;
        uint256 r = 1;
        if (xx >= 0x100000000000000000000000000000000) {
            xx >>= 128;
            r <<= 64;
        }
        if (xx >= 0x10000000000000000) {
            xx >>= 64;
            r <<= 32;
        }
        if (xx >= 0x100000000) {
            xx >>= 32;
            r <<= 16;
        }
        if (xx >= 0x10000) {
            xx >>= 16;
            r <<= 8;
        }
        if (xx >= 0x100) {
            xx >>= 8;
            r <<= 4;
        }
        if (xx >= 0x10) {
            xx >>= 4;
            r <<= 2;
        }
        if (xx >= 0x8) {
            r <<= 1;
        }
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1; // Seven iterations should be enough
        uint256 r1 = x / r;
        return (r < r1 ? r : r1);
    }
}


// File contracts/interfaces/weth.sol



pragma solidity 0.8.4;

interface WETH {
    function name() external view returns (string memory);

    function approve(address guy, uint256 wad) external returns (bool);

    function totalSupply() external view returns (uint256);

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) external returns (bool);

    function withdraw(uint256 wad) external;

    function decimals() external view returns (uint8);

    function balanceOf(address) external view returns (uint256);

    function symbol() external view returns (string memory);

    function transfer(address dst, uint256 wad) external returns (bool);

    function deposit() external payable;

    function allowance(address, address) external view returns (uint256);
}


// File contracts/interfaces/vault.sol


pragma solidity 0.8.4;

interface IVault is IERC20 {
    function token() external view returns (address);
    
    function reward() external view returns (address);

    function claimInsurance() external; // NOTE: Only yDelegatedVault implements this

    function getRatio() external view returns (uint256);

    function depositAll() external;
    
    function balance() external view returns (uint256);

    function deposit(uint256) external;

    function withdrawAll() external;

    function withdraw(uint256) external;

    function earn() external;

    function decimals() external view returns (uint8);
}


// File contracts/zapper/zapper-base.sol


pragma solidity 0.8.4;






abstract contract ZapperBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IVault;

    address public router;

    address public constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    uint256 public constant minimumAmount = 1000;

    constructor(address _router) {
        // Safety checks to ensure WETH token address
        WETH(weth).deposit{value: 0}();
        WETH(weth).withdraw(0);
        router = _router;
    }

    receive() external payable {
        assert(msg.sender == weth);
    }

    function _getSwapAmount(uint256 investmentA, uint256 reserveA, uint256 reserveB) public view virtual returns (uint256 swapAmount);

    //returns DUST
    function _returnAssets(address[] memory tokens) internal {
        uint256 balance;
        for (uint256 i; i < tokens.length; i++) {
            balance = IERC20(tokens[i]).balanceOf(address(this));
            if (balance > 0) {
                if (tokens[i] == weth) {
                    WETH(weth).withdraw(balance);
                    (bool success, ) = msg.sender.call{value: balance}(
                        new bytes(0)
                    );
                    require(success, "ETH transfer failed");
                } else {
                    IERC20(tokens[i]).safeTransfer(msg.sender, balance);
                }
            }
        }
    }

    function _swapAndStake(address vault, uint256 tokenAmountOutMin, address tokenIn) public virtual;

    function zapInETH(address vault, uint256 tokenAmountOutMin, address tokenIn) external payable{
        require(msg.value >= minimumAmount, "Insignificant input amount");

        WETH(weth).deposit{value: msg.value}();

        // allows us to zapIn if eth isn't part of the original pair
        if (tokenIn != weth){
            uint256 _amount = IERC20(weth).balanceOf(address(this));

            (, IUniswapV2Pair pair) = _getVaultPair(vault);

            (uint256 reserveA, uint256 reserveB, ) = pair.getReserves();
            require(reserveA > minimumAmount && reserveB > minimumAmount, "Liquidity pair reserves too low");

            bool isInputA = pair.token0() == tokenIn;
            require(isInputA || pair.token1() == tokenIn, "Input token not present in liquidity pair");

            address[] memory path = new address[](2);
            path[0] = weth;
            path[1] = tokenIn;

            uint256 swapAmountIn;
        
            swapAmountIn = _getSwapAmount(_amount, reserveA, reserveB);
       
            _approveTokenIfNeeded(path[0], address(router));
            UniswapRouterV2(router).swapExactTokensForTokens(
                swapAmountIn,
                tokenAmountOutMin,
                path,
                address(this),
                block.timestamp
            );
            _swapAndStake(vault, tokenAmountOutMin, tokenIn);
        }else{
            _swapAndStake(vault, tokenAmountOutMin, tokenIn);
        }
    }

    // transfers tokens from msg.sender to this contract 
    function zapIn(address vault, uint256 tokenAmountOutMin, address tokenIn, uint256 tokenInAmount) external {
        require(tokenInAmount >= minimumAmount, "Insignificant input amount");
        require(IERC20(tokenIn).allowance(msg.sender, address(this)) >= tokenInAmount, "Input token is not approved");

        // transfer token 
        IERC20(tokenIn).safeTransferFrom(
            msg.sender,
            address(this),
            tokenInAmount
        );

        (, IUniswapV2Pair pair) = _getVaultPair(vault);

        if(tokenIn != pair.token0() && tokenIn != pair.token1()){
            (address desiredToken) = pair.token0();

            if(tokenIn != weth && desiredToken != weth){
                // execute swap from tokenin to desired token
                uint256 _amount = IERC20(tokenIn).balanceOf(address(this));

                address[] memory path = new address[](3);
                path[0] = tokenIn;
                path[1] = weth;
                path[2] = desiredToken;
        
                _approveTokenIfNeeded(path[0], address(router));
                UniswapRouterV2(router).swapExactTokensForTokens(
                    _amount,
                    tokenAmountOutMin,
                    path,
                    address(this),
                    block.timestamp
                );
            
            }else {
                // execute swap from tokenin to desired token
                uint256 _amount = IERC20(tokenIn).balanceOf(address(this));

                address[] memory path = new address[](2);
                path[0] = tokenIn;
                path[1] = desiredToken;
        
                _approveTokenIfNeeded(path[0], address(router));
                UniswapRouterV2(router).swapExactTokensForTokens(
                    _amount,
                    tokenAmountOutMin,
                    path,
                    address(this),
                    block.timestamp
                );
            }

            _swapAndStake(vault, tokenAmountOutMin, desiredToken);
        }else {
            _swapAndStake(vault, tokenAmountOutMin, tokenIn);
        }
    }

    function zapOutAndSwap(address vault, uint256 withdrawAmount, address desiredToken, uint256 desiredTokenOutMin) public virtual;

    function _removeLiquidity(address pair, address to) internal {
        IERC20(pair).safeTransfer(pair, IERC20(pair).balanceOf(address(this)));
        (uint256 amount0, uint256 amount1) = IUniswapV2Pair(pair).burn(to);

        require(amount0 >= minimumAmount, "Router: INSUFFICIENT_A_AMOUNT");
        require(amount1 >= minimumAmount, "Router: INSUFFICIENT_B_AMOUNT");
    }

    function _getVaultPair(address vault_addr) internal view returns (IVault vault, IUniswapV2Pair pair){

        vault = IVault(vault_addr);
        pair = IUniswapV2Pair(vault.token());

        require(pair.factory() == IUniswapV2Pair(router).factory(), "Incompatible liquidity pair factory");
    }

    function _approveTokenIfNeeded(address token, address spender) internal {
        if (IERC20(token).allowance(address(this), spender) == 0) {
            IERC20(token).safeApprove(spender, type(uint256).max);
        }
    }

    function zapOut(address vault_addr, uint256 withdrawAmount) external {
        (IVault vault, IUniswapV2Pair pair) = _getVaultPair(vault_addr);

        IERC20(vault_addr).safeTransferFrom(msg.sender, address(this), withdrawAmount);
        vault.withdraw(withdrawAmount);

        if (pair.token0() != weth && pair.token1() != weth) {
            return _removeLiquidity(address(pair), msg.sender);
        }


        _removeLiquidity(address(pair), address(this));

        address[] memory tokens = new address[](2);
        tokens[0] = pair.token0();
        tokens[1] = pair.token1();

        _returnAssets(tokens);
    }
}


// File contracts/zapper/vault-zapper.sol


pragma solidity 0.8.4;

contract VaultZapEthSushi is ZapperBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IVault;

    constructor()
        ZapperBase(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506){}

    function zapOutAndSwap(address vault_addr, uint256 withdrawAmount, address desiredToken, uint256 desiredTokenOutMin) public override {
        (IVault vault, IUniswapV2Pair pair) = _getVaultPair(vault_addr);
        address token0 = pair.token0();
        address token1 = pair.token1();

        address firstToken = token0;

        vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
        vault.withdraw(withdrawAmount);
        _removeLiquidity(address(pair), address(this));

        address swapToken = token1 == firstToken ? token0 : token1;
        address[] memory path = new address[](2);
        path[0] = swapToken;
        path[1] = firstToken;

        _approveTokenIfNeeded(path[0], address(router));
        UniswapRouterV2(router).swapExactTokensForTokens(
            IERC20(swapToken).balanceOf(address(this)),
            desiredTokenOutMin,
            path,
            address(this),
            block.timestamp
        );

        if(desiredToken != firstToken) {
            address[] memory path1 = new address[](2);
            path1[0] = firstToken;
            path1[1] = desiredToken;

            _approveTokenIfNeeded(path1[0], address(router));
            UniswapRouterV2(router).swapExactTokensForTokens(
                IERC20(firstToken).balanceOf(address(this)),
                desiredTokenOutMin,
                path1,
                address(this),
                block.timestamp
            );

            _returnAssets(path1); 

        }
        _returnAssets(path);
    }

    function zapOutAndSwapEth(address vault_addr, uint256 withdrawAmount, uint256 desiredTokenOutMin) public {
        (IVault vault, IUniswapV2Pair pair) = _getVaultPair(vault_addr);
        address token0 = pair.token0();
        address token1 = pair.token1();

        address desiredToken = token0; 

        vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
        vault.withdraw(withdrawAmount);
        _removeLiquidity(address(pair), address(this));

        address swapToken = token1 == desiredToken ? token0 : token1;
        address[] memory path = new address[](2);
        path[0] = swapToken;
        path[1] = desiredToken;

        _approveTokenIfNeeded(path[0], address(router));
        UniswapRouterV2(router).swapExactTokensForTokens(
            IERC20(swapToken).balanceOf(address(this)),
            desiredTokenOutMin,
            path,
            address(this),
            block.timestamp
        );

        if(desiredToken != weth) {
            address[] memory path1 = new address[](2);
            path1[0] = desiredToken;
            path1[1] = weth;

            _approveTokenIfNeeded(path1[0], address(router));
            UniswapRouterV2(router).swapExactTokensForTokens(
                IERC20(desiredToken).balanceOf(address(this)),
                desiredTokenOutMin,
                path1,
                address(this),
                block.timestamp
            );

             _returnAssets(path1);

        }

        _returnAssets(path);
    }


    function _swapAndStake(address vault_addr, uint256 tokenAmountOutMin, address tokenIn) public override {
        (IVault vault, IUniswapV2Pair pair) = _getVaultPair(vault_addr);

        (uint256 reserveA, uint256 reserveB, ) = pair.getReserves();
        require(reserveA > minimumAmount && reserveB > minimumAmount, "Liquidity pair reserves too low");

        bool isInputA = pair.token0() == tokenIn;
        require(isInputA || pair.token1() == tokenIn, "Input token not present in liquidity pair");

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = isInputA ? pair.token1() : pair.token0();

        uint256 fullInvestment = IERC20(tokenIn).balanceOf(address(this));
        uint256 swapAmountIn;
        if (isInputA) {
            swapAmountIn = _getSwapAmount(fullInvestment, reserveA, reserveB);
        } else {
            swapAmountIn = _getSwapAmount(fullInvestment, reserveB, reserveA);
        }

        _approveTokenIfNeeded(path[0], address(router));
        uint256[] memory swappedAmounts = UniswapRouterV2(router)
            .swapExactTokensForTokens(
                swapAmountIn,
                tokenAmountOutMin,
                path,
                address(this),
                block.timestamp
            );

        _approveTokenIfNeeded(path[1], address(router));
        (, , uint256 amountLiquidity) = UniswapRouterV2(router).addLiquidity(
            path[0],
            path[1],
            fullInvestment.sub(swappedAmounts[0]),
            swappedAmounts[1],
            1,
            1,
            address(this),
            block.timestamp
        );

        _approveTokenIfNeeded(address(pair), address(vault));
        vault.deposit(amountLiquidity);

        //add to guage if possible instead of returning to user, and so no receipt token
        vault.safeTransfer(msg.sender, vault.balanceOf(address(this)));

        //taking receipt token and sending back to user
        vault.safeTransfer(msg.sender, vault.balanceOf(address(this)));

        _returnAssets(path);
    }

    function _getSwapAmount(uint256 investmentA, uint256 reserveA, uint256 reserveB) public view override returns (uint256 swapAmount) {
        uint256 halfInvestment = investmentA.div(2);
        uint256 nominator = UniswapRouterV2(router).getAmountOut(
            halfInvestment,
            reserveA,
            reserveB
        );
        uint256 denominator = UniswapRouterV2(router).quote(
            halfInvestment,
            reserveA.add(halfInvestment),
            reserveB.sub(nominator)
        );
        swapAmount = investmentA.sub(
            Babylonian.sqrt(
                (halfInvestment * halfInvestment * nominator) / denominator
            )
        );
    }

    function estimateSwap(address vault_addr, address tokenIn, uint256 fullInvestmentIn) public view returns (uint256 swapAmountIn, uint256 swapAmountOut, address swapTokenOut){
        (, IUniswapV2Pair pair) = _getVaultPair(vault_addr);

        bool isInputA = pair.token0() == tokenIn;
        require(isInputA || pair.token1() == tokenIn, "Input token not present in liquidity pair");

        (uint256 reserveA, uint256 reserveB, ) = pair.getReserves();
        (reserveA, reserveB) = isInputA ? (reserveA, reserveB) : (reserveB, reserveA);

        swapAmountIn = _getSwapAmount(fullInvestmentIn, reserveA, reserveB);
        swapAmountOut = UniswapRouterV2(router).getAmountOut(
            swapAmountIn,
            reserveA,
            reserveB
        );
        swapTokenOut = isInputA ? pair.token1() : pair.token0();
    }
}
