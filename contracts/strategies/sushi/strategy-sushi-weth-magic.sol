// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../sushi-farm-bases/strategy-sushi-farm-base.sol";

contract StrategySushiWethMagic is StrategySushiFarmBase {
    uint256 public sushi_weth_magic_poolId = 13;
    // Token addresses
    address public sushi_weth_magic_lp = 0xB7E50106A5bd3Cf21AF210A755F9C8740890A8c9;
    address public magic = 0x539bdE0d7Dbd336b79148AA742883198BBF60342;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        StrategySushiFarmBase(
            weth,
            magic,
            sushi_weth_magic_poolId,
            sushi_weth_magic_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategySushiWethMagic";
    }
}