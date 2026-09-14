// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EmptyRuntime {
    constructor() {
        assembly ("memory-safe") {
            return(0x00, 0x00)
        }
    }
}
