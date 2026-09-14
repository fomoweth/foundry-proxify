// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ImplementationReverter {
    error ImplementationError();

    function implementation() external pure returns (address) {
        revert ImplementationError();
    }
}
