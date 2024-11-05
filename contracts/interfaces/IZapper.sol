// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IERC20} from "../lib/erc20.sol";
import {IVault} from "../interfaces/vault.sol";

interface IZapper {
    struct ReturnedAsset {
        address tokens;
        uint256 amounts;
    }

    event WhitelistVault(address indexed vault, bool whitelisted);
    event SetSwapRouter(
        address indexed newSwapRouter,
        address indexed oldSwapRouter
    );

    event ZapIn(
        address indexed user,
        address indexed vault,
        address tokenIn,
        uint256 tokenInAmount,
        uint256 shares
    );
    event ZapOut(
        address indexed user,
        address indexed vault,
        address tokenOut,
        uint256 tokenOutAmount,
        uint256 shares
    );

    function zapInETH(
        IVault vault,
        uint256 tokenAmountOutMin,
        address
    )
        external
        payable
        returns (uint256 shares, ReturnedAsset[] memory returnedAssets);

    function zapIn(
        IVault vault,
        uint256 tokenAmountOutMin,
        IERC20 tokenIn,
        uint256 tokenInAmount
    ) external returns (uint256 shares, ReturnedAsset[] memory returnedAssets);

    function zapOutAndSwap(
        IVault vault,
        uint256 withdrawAmount,
        IERC20 desiredToken,
        uint256 desiredTokenOutMin
    )
        external
        returns (uint256 tokenOutAmount, ReturnedAsset[] memory returnedAssets);

    function zapOutAndSwapEth(
        IVault vault,
        uint256 withdrawAmount,
        uint256 desiredTokenOutMin
    )
        external
        returns (uint256 tokenOutAmount, ReturnedAsset[] memory returnedAssets);
}