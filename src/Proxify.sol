// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Vm} from "forge-std/Vm.sol";

/// @title Proxify
/// @author fomoweth
/// @notice Foundry-native utilities for deploying, upgrading, and inspecting ERC-1967 proxies.
library Proxify {
    Vm private constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    bytes32 private constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    bytes32 private constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    bytes32 private constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;
}
