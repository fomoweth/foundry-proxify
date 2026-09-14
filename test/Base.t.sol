// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {GreeterV1, GreeterV2} from "test/mocks/Greeter.sol";

abstract contract ProxifyTest is Test {
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    string internal constant GREETER_V1_PATH = "Greeter.sol:GreeterV1";
    string internal constant GREETER_V2_PATH = "Greeter.sol:GreeterV2";

    string internal constant GREETER_V1_PROXIABLE_PATH = "GreeterProxiable.sol:GreeterV1Proxiable";
    string internal constant GREETER_V2_PROXIABLE_PATH = "GreeterProxiable.sol:GreeterV2Proxiable";

    string internal constant DEFAULT_GREETING = "hello";

    bytes32 internal constant DEFAULT_SALT = keccak256("proxify-test-salt");

    uint256 internal constant DEFAULT_VALUE = 12 ether;

    address internal constant DEFAULT_OWNER = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;

    function computeUUPSProxyAddress(address implementation, bytes memory data, bytes32 salt)
        internal
        view
        returns (address)
    {
        bytes memory constructorArgs = abi.encode(implementation, data);
        bytes32 initCodeHash = hashInitCode(type(ERC1967Proxy).creationCode, constructorArgs);
        return vm.computeCreate2Address(salt, initCodeHash, address(this));
    }

    function computeTransparentProxyAddress(
        address implementation,
        address initialOwner,
        bytes memory data,
        bytes32 salt
    ) internal view returns (address) {
        bytes memory constructorArgs = abi.encode(implementation, initialOwner, data);
        bytes32 initCodeHash = hashInitCode(type(TransparentUpgradeableProxy).creationCode, constructorArgs);
        return vm.computeCreate2Address(salt, initCodeHash, address(this));
    }

    function computeBeaconAddress(address implementation, address initialOwner, bytes32 salt)
        internal
        view
        returns (address)
    {
        bytes memory constructorArgs = abi.encode(implementation, initialOwner);
        bytes32 initCodeHash = hashInitCode(type(UpgradeableBeacon).creationCode, constructorArgs);
        return vm.computeCreate2Address(salt, initCodeHash, address(this));
    }

    function computeBeaconProxyAddress(address beacon, bytes memory data, bytes32 salt)
        internal
        view
        returns (address)
    {
        bytes memory constructorArgs = abi.encode(beacon, data);
        bytes32 initCodeHash = hashInitCode(type(BeaconProxy).creationCode, constructorArgs);
        return vm.computeCreate2Address(salt, initCodeHash, address(this));
    }

    function computeCreate2Address(string memory artifactPath, bytes memory constructorArgs, bytes32 salt)
        internal
        view
        returns (address)
    {
        return vm.computeCreate2Address(salt, hashInitCode(vm.getCode(artifactPath), constructorArgs), address(this));
    }

    function computeCreate2Address(string memory artifactPath, bytes32 salt) internal view returns (address) {
        return vm.computeCreate2Address(salt, hashInitCode(vm.getCode(artifactPath)), address(this));
    }

    function computeCreate2Address(
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes32 salt,
        address deployer
    ) internal view returns (address) {
        return vm.computeCreate2Address(salt, hashInitCode(vm.getCode(artifactPath), constructorArgs), deployer);
    }

    function computeCreate2Address(string memory artifactPath, bytes32 salt, address deployer)
        internal
        view
        returns (address)
    {
        return vm.computeCreate2Address(salt, hashInitCode(vm.getCode(artifactPath)), deployer);
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

    function lsbToAddress(bytes32 x) internal pure returns (address) {
        return address(uint160(uint256(x)));
    }

    function assertUUPSProxy(address proxy, address implementation, uint256 value) internal view {
        assertContract(proxy);
        assertEq(proxy.balance, value);

        assertContract(implementation);
        assertEq(lsbToAddress(vm.load(proxy, IMPLEMENTATION_SLOT)), implementation);
    }

    function assertTransparentProxy(address proxy, address implementation, address owner, uint256 value) internal view {
        assertContract(proxy);
        assertEq(proxy.balance, value);

        assertContract(implementation);
        assertEq(lsbToAddress(vm.load(proxy, IMPLEMENTATION_SLOT)), implementation);

        address admin = vm.computeCreateAddress(proxy, 1);
        assertContract(admin);
        assertEq(lsbToAddress(vm.load(proxy, ADMIN_SLOT)), admin);
        assertEq(ProxyAdmin(admin).owner(), owner);
    }

    function assertBeacon(address beacon, address implementation, address owner) internal view {
        assertContract(beacon);
        assertEq(UpgradeableBeacon(beacon).implementation(), implementation);
        assertEq(UpgradeableBeacon(beacon).owner(), owner);
    }

    function assertBeaconProxy(address proxy, address beacon, address implementation, address owner, uint256 value)
        internal
        view
    {
        assertContract(proxy);
        assertEq(proxy.balance, value);

        assertEq(lsbToAddress(vm.load(proxy, BEACON_SLOT)), beacon);
        assertBeacon(beacon, implementation, owner);
    }

    function assertGreeterV1(address proxy, address owner, string memory greeting) internal view {
        GreeterV1 instance = GreeterV1(proxy);
        assertEq(instance.version(), 1);
        assertEq(instance.owner(), owner);
        assertEq(instance.greeting(), greeting);
    }

    function assertGreeterV2(address proxy) internal {
        GreeterV2 instance = GreeterV2(proxy);
        if (vm.load(proxy, BEACON_SLOT) != bytes32(0)) instance.resetGreeting();
        assertEq(instance.version(), 2);
        assertEq(instance.greeting(), "resetted");
    }

    function assertContract(address target) internal view {
        assertNotEq(target.code.length, 0);
    }
}
