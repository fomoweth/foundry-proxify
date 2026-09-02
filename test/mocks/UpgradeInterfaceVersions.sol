// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract UpgradeInterfaceVersion {
    string public constant UPGRADE_INTERFACE_VERSION = "5.0.0";
}

contract UpgradeInterfaceVersionEmpty {
    string public constant UPGRADE_INTERFACE_VERSION = "";
}

contract UpgradeInterfaceVersionInteger {
    uint256 public constant UPGRADE_INTERFACE_VERSION = 5;
}

contract UpgradeInterfaceVersionVoid {
    function UPGRADE_INTERFACE_VERSION() external pure {}
}

contract UpgradeInterfaceVersionMalformed {
    fallback() external {
        assembly ("memory-safe") {
            mstore(0x00, 0x20)
            mstore(0x20, 0x1000)
            mstore(0x40, "5.0.0")
            return(0x00, 0x60)
        }
    }
}

contract UpgradeInterfaceVersionNoGetter {}
