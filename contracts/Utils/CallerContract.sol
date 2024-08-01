// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

contract CallerContract {
  function callExternalContract(address _target, bytes memory _data) external {
    // call contract in current context
    (bool success, ) = _target.call(_data);
    require(success, "External call failed");
  }
}
