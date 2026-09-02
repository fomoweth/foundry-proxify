// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

abstract contract ProxifyTestBase is Test {
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    function computeUUPSProxyAddress(address implementation, bytes memory data, bytes32 salt)
        internal
        view
        returns (address)
    {
        bytes memory constructorArgs = abi.encode(implementation, data);
        return computeCreate2Address(type(ERC1967Proxy).creationCode, constructorArgs, salt);
    }

    function computeTransparentProxyAddress(
        address implementation,
        address initialOwner,
        bytes memory data,
        bytes32 salt
    ) internal view returns (address) {
        bytes memory constructorArgs = abi.encode(implementation, initialOwner, data);
        return computeCreate2Address(type(TransparentUpgradeableProxy).creationCode, constructorArgs, salt);
    }

    function computeProxyAdminAddress(address proxy) internal pure returns (address) {
        return vm.computeCreateAddress(proxy, 1);
    }

    function computeBeaconAddress(address implementation, address initialOwner, bytes32 salt)
        internal
        view
        returns (address)
    {
        bytes memory constructorArgs = abi.encode(implementation, initialOwner);
        return computeCreate2Address(type(UpgradeableBeacon).creationCode, constructorArgs, salt);
    }

    function computeBeaconProxyAddress(address beacon, bytes memory data, bytes32 salt)
        internal
        view
        returns (address)
    {
        bytes memory constructorArgs = abi.encode(beacon, data);
        return computeCreate2Address(type(BeaconProxy).creationCode, constructorArgs, salt);
    }

    function computeCreate2Address(bytes memory creationCode, bytes memory constructorArgs, bytes32 salt)
        internal
        view
        returns (address)
    {
        return vm.computeCreate2Address(salt, hashInitCode(creationCode, constructorArgs), address(this));
    }

    function computeCreate2Address(bytes memory creationCode, bytes32 salt) internal view returns (address) {
        return vm.computeCreate2Address(salt, hashInitCode(creationCode), address(this));
    }

    function assertContract(address target, string memory message) internal view {
        assertNotEq(target.code.length, 0, message);
    }

    function assertContract(address target) internal view {
        assertNotEq(target.code.length, 0);
    }
}
