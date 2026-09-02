// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {GreeterV1, GreeterV2, GreeterV1Proxiable, GreeterV2Proxiable} from "test/mocks/Greeters.sol";

abstract contract ProxifyTestBase is Test {
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    string internal constant GREETER_V1_PATH = "Greeters.sol:GreeterV1";
    string internal constant GREETER_V2_PATH = "Greeters.sol:GreeterV2";

    string internal constant GREETER_V1_PROXIABLE_PATH = "Greeters.sol:GreeterV1Proxiable";
    string internal constant GREETER_V2_PROXIABLE_PATH = "Greeters.sol:GreeterV2Proxiable";

    bytes internal constant GREETER_V1_BYTECODE = type(GreeterV1).creationCode;
    bytes internal constant GREETER_V2_BYTECODE = type(GreeterV2).creationCode;

    bytes internal constant GREETER_V1_PROXIABLE_BYTECODE = type(GreeterV1Proxiable).creationCode;
    bytes internal constant GREETER_V2_PROXIABLE_BYTECODE = type(GreeterV2Proxiable).creationCode;

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

    function encodeInitializerData(address initialOwner, string memory initialGreeting)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(GreeterV1.initialize, (initialOwner, initialGreeting));
    }

    function encodeReinitializerData() internal pure returns (bytes memory) {
        return abi.encodeCall(GreeterV2.resetGreeting, ());
    }

    function assertUUPSProxy(address proxy, address implementation, uint256 value) internal view {
        assertContract(proxy);
        assertEq(proxy.balance, value);

        assertContract(implementation);
        assertEq(address(uint160(uint256(vm.load(proxy, IMPLEMENTATION_SLOT)))), implementation);
    }

    function assertTransparentProxy(address proxy, address implementation, address initialOwner, uint256 value)
        internal
        view
    {
        assertContract(proxy);
        assertEq(proxy.balance, value);

        assertContract(implementation);
        assertEq(address(uint160(uint256(vm.load(proxy, IMPLEMENTATION_SLOT)))), implementation);

        address admin = computeProxyAdminAddress(proxy);
        assertContract(admin);
        assertEq(address(uint160(uint256(vm.load(proxy, ADMIN_SLOT)))), admin);
        assertEq(ProxyAdmin(admin).owner(), initialOwner);
    }

    function assertBeacon(address beacon, address implementation, address initialOwner) internal view {
        assertContract(beacon);
        assertEq(UpgradeableBeacon(beacon).implementation(), implementation);
        assertEq(UpgradeableBeacon(beacon).owner(), initialOwner);
    }

    function assertBeaconProxy(
        address proxy,
        address beacon,
        address implementation,
        address initialOwner,
        uint256 value
    ) internal view {
        assertContract(proxy);
        assertEq(proxy.balance, value);

        assertEq(address(uint160(uint256(vm.load(proxy, BEACON_SLOT)))), beacon);
        assertBeacon(beacon, implementation, initialOwner);
    }

    function assertGreeterV1(address proxy, address initialOwner, string memory initialGreeting) internal view {
        GreeterV1 instance = GreeterV1(proxy);
        assertEq(instance.version(), 1);
        assertEq(instance.owner(), initialOwner);
        assertEq(instance.greeting(), initialGreeting);
    }

    function assertGreeterV2(address proxy) internal view {
        GreeterV2 instance = GreeterV2(proxy);
        assertEq(instance.version(), 2);
        assertEq(instance.greeting(), "resetted");
    }

    function assertContract(address target) internal view {
        assertNotEq(target.code.length, 0);
    }
}
