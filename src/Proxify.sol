// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Vm} from "forge-std/Vm.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

/// @title Proxify
/// @author fomoweth
/// @notice Foundry-native utilities for deploying, upgrading, and inspecting ERC-1967 proxies.
/// @dev Uses Foundry cheatcodes for artifact resolution and follows OpenZeppelin Contracts v5
///      semantics for proxy deployment, upgrades, and ERC-1967 storage inspection.
///
///      Requires the Cancun EVM or later due to the use of the `MCOPY` opcode.
///
///      `artifactPath` identifies an implementation by contract path or name, optionally
///      qualified by a compiler version. A project-relative artifact path is also supported.
///
///      Supported contract identifier formats:
///
///      - `"MyContract.sol:MyContract"`
///      - `"MyContract"`
///      - `"MyContract.sol:0.8.18"`
///      - `"MyContract:0.8.18"`
///
///      Upgrade overloads accepting `msgSender` are intended for use in Foundry tests;
///      configure the transaction sender through Foundry when broadcasting scripts.
library Proxify {
    /// @dev Thrown when the target address has no runtime code.
    /// @param target The address expected to contain runtime code.
    error EmptyCode(address target);

    /// @dev Thrown when the proxy's implementation does not match the expected address.
    /// @param proxy The address of the proxy being validated.
    /// @param expected The address of the expected implementation.
    /// @param actual The address of the implementation stored in the proxy.
    error ImplementationMismatch(address proxy, address expected, address actual);

    /// @dev Thrown when the proxy's admin does not match the expected address.
    /// @param proxy The address of the proxy being validated.
    /// @param expected The address of the expected admin.
    /// @param actual The address of the admin stored in the proxy.
    error AdminMismatch(address proxy, address expected, address actual);

    /// @dev Thrown when the proxy's beacon does not match the expected address.
    /// @param proxy The address of the proxy being validated.
    /// @param expected The address of the expected beacon.
    /// @param actual The address of the beacon stored in the proxy.
    error BeaconMismatch(address proxy, address expected, address actual);

    /// @dev Thrown when the beacon's implementation does not match the expected address.
    /// @param beacon The address of the beacon being validated.
    /// @param expected The address of the expected implementation.
    /// @param actual The address of the implementation exposed by the beacon.
    error BeaconImplementationMismatch(address beacon, address expected, address actual);

    /// @dev Thrown when the target's owner does not match the expected address.
    /// @param target The address of the contract being validated.
    /// @param expected The address of the expected owner.
    /// @param actual The address of the owner exposed by the target.
    error OwnerMismatch(address target, address expected, address actual);

    /// @dev The Foundry cheatcode interface at the canonical HEVM cheatcode address.
    ///      Derived as `address(uint160(uint256(keccak256("hevm cheat code"))))`.
    Vm private constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    /// @dev The ERC-1967 storage slot for the implementation address.
    ///      Derived as `bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)`.
    bytes32 private constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev The ERC-1967 storage slot for the admin address.
    ///      Derived as `bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)`.
    bytes32 private constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /// @dev The ERC-1967 storage slot for the beacon address.
    ///      Derived as `bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1)`.
    bytes32 private constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /// @dev Attempts to impersonate `msgSender` as `msg.sender` for the modified function.
    ///      Executes the function with the original `msg.sender` if impersonation fails.
    /// @param msgSender The address to impersonate as `msg.sender`.
    modifier tryPrank(address msgSender) {
        try vm.startPrank(msgSender) {
            _;
            vm.stopPrank();
        } catch {
            _;
        }
    }

    /// @notice Deploys a proxy backed by the given implementation.
    /// @dev Overload of {deployUUPSProxy} with `value` set to zero.
    /// @param implementation The address of the implementation to set in the proxy.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @return proxy The address of the deployed proxy.
    function deployUUPSProxy(address implementation, bytes memory initializerData) internal returns (address proxy) {
        return deployUUPSProxy({implementation: implementation, initializerData: initializerData, value: 0});
    }

    /// @notice Deploys a proxy backed by the given implementation.
    /// @dev Deploys an {ERC1967Proxy} using CREATE while forwarding Ether, and verifies
    ///      the resulting ERC-1967 implementation slot. This function does not verify
    ///      that the implementation exposes a valid UUPS upgrade mechanism.
    /// @param implementation The address of the implementation to set in the proxy.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param value The amount of Ether to forward as `msg.value` during proxy construction.
    /// @return proxy The address of the deployed proxy.
    function deployUUPSProxy(address implementation, bytes memory initializerData, uint256 value)
        internal
        returns (address proxy)
    {
        proxy = vm.deployCode({
            artifactPath: "ERC1967Proxy.sol:ERC1967Proxy",
            constructorArgs: abi.encode(implementation, initializerData),
            value: value
        });
        validateImplementation(proxy, implementation);
    }

    /// @notice Deterministically deploys a proxy backed by the given implementation.
    /// @dev Overload of {deployUUPSProxy} with `value` set to zero.
    /// @param implementation The address of the implementation to set in the proxy.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param salt The salt used for deterministic proxy deployment.
    /// @return proxy The address of the deployed proxy.
    function deployUUPSProxy(address implementation, bytes memory initializerData, bytes32 salt)
        internal
        returns (address proxy)
    {
        return deployUUPSProxy({implementation: implementation, initializerData: initializerData, salt: salt, value: 0});
    }

    /// @notice Deterministically deploys a proxy backed by the given implementation.
    /// @dev Deploys an {ERC1967Proxy} using CREATE2 while forwarding Ether, and verifies
    ///      the resulting ERC-1967 implementation slot. This function does not verify
    ///      that the implementation exposes a valid UUPS upgrade mechanism.
    /// @param implementation The address of the implementation to set in the proxy.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param salt The salt used for deterministic proxy deployment.
    /// @param value The amount of Ether to forward as `msg.value` during proxy construction.
    /// @return proxy The address of the deployed proxy.
    function deployUUPSProxy(address implementation, bytes memory initializerData, bytes32 salt, uint256 value)
        internal
        returns (address proxy)
    {
        proxy = vm.deployCode({
            artifactPath: "ERC1967Proxy.sol:ERC1967Proxy",
            constructorArgs: abi.encode(implementation, initializerData),
            salt: salt,
            value: value
        });
        validateImplementation(proxy, implementation);
    }

    /// @notice Deploys an implementation, then a proxy backed by it.
    /// @dev Overload of {deployUUPSProxy} with `constructorArgs` left empty and `value` set to zero.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @return proxy The address of the deployed proxy.
    function deployUUPSProxy(string memory artifactPath, bytes memory initializerData)
        internal
        returns (address proxy)
    {
        return deployUUPSProxy({
            artifactPath: artifactPath, constructorArgs: "", initializerData: initializerData, value: 0
        });
    }

    /// @notice Deploys an implementation, then a proxy backed by it.
    /// @dev Overload of {deployUUPSProxy} with `constructorArgs` left empty.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param value The amount of Ether to forward as `msg.value` during proxy construction.
    /// @return proxy The address of the deployed proxy.
    function deployUUPSProxy(string memory artifactPath, bytes memory initializerData, uint256 value)
        internal
        returns (address proxy)
    {
        return deployUUPSProxy({
            artifactPath: artifactPath, constructorArgs: "", initializerData: initializerData, value: value
        });
    }

    /// @notice Deploys an implementation, then a proxy backed by it.
    /// @dev Overload of {deployUUPSProxy} with `value` set to zero.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the implementation.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @return proxy The address of the deployed proxy.
    function deployUUPSProxy(string memory artifactPath, bytes memory constructorArgs, bytes memory initializerData)
        internal
        returns (address proxy)
    {
        return deployUUPSProxy({
            artifactPath: artifactPath, constructorArgs: constructorArgs, initializerData: initializerData, value: 0
        });
    }

    /// @notice Deploys an implementation, then a proxy backed by it.
    /// @dev Deploys the implementation and proxy using CREATE.
    ///      See {deployUUPSProxy-address-bytes-uint256}.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the implementation.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param value The amount of Ether to forward as `msg.value` during proxy construction.
    /// @return proxy The address of the deployed proxy.
    function deployUUPSProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        uint256 value
    ) internal returns (address proxy) {
        return deployUUPSProxy({
            implementation: vm.deployCode(artifactPath, constructorArgs), initializerData: initializerData, value: value
        });
    }

    /// @notice Deterministically deploys an implementation, then a proxy backed by it.
    /// @dev Overload of {deployUUPSProxy} with `constructorArgs` left empty and `value` set to zero.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param salt The salt used for deterministic implementation and proxy deployment.
    /// @return proxy The address of the deployed proxy.
    function deployUUPSProxy(string memory artifactPath, bytes memory initializerData, bytes32 salt)
        internal
        returns (address proxy)
    {
        return deployUUPSProxy({
            artifactPath: artifactPath, constructorArgs: "", initializerData: initializerData, salt: salt, value: 0
        });
    }

    /// @notice Deterministically deploys an implementation, then a proxy backed by it.
    /// @dev Overload of {deployUUPSProxy} with `constructorArgs` left empty.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param salt The salt used for deterministic implementation and proxy deployment.
    /// @param value The amount of Ether to forward as `msg.value` during proxy construction.
    /// @return proxy The address of the deployed proxy.
    function deployUUPSProxy(string memory artifactPath, bytes memory initializerData, bytes32 salt, uint256 value)
        internal
        returns (address proxy)
    {
        return deployUUPSProxy({
            artifactPath: artifactPath, constructorArgs: "", initializerData: initializerData, salt: salt, value: value
        });
    }

    /// @notice Deterministically deploys an implementation, then a proxy backed by it.
    /// @dev Overload of {deployUUPSProxy} with `value` set to zero.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the implementation.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param salt The salt used for deterministic implementation and proxy deployment.
    /// @return proxy The address of the deployed proxy.
    function deployUUPSProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        bytes32 salt
    ) internal returns (address proxy) {
        return deployUUPSProxy({
            artifactPath: artifactPath,
            constructorArgs: constructorArgs,
            initializerData: initializerData,
            salt: salt,
            value: 0
        });
    }

    /// @notice Deterministically deploys an implementation, then a proxy backed by it.
    /// @dev Deploys the implementation and proxy using CREATE2 with the same salt.
    ///      See {deployUUPSProxy-address-bytes-bytes32-uint256}.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the implementation.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param salt The salt used for deterministic implementation and proxy deployment.
    /// @param value The amount of Ether to forward as `msg.value` during proxy construction.
    /// @return proxy The address of the deployed proxy.
    function deployUUPSProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal returns (address proxy) {
        return deployUUPSProxy({
            implementation: vm.deployCode(artifactPath, constructorArgs, salt),
            initializerData: initializerData,
            salt: salt,
            value: value
        });
    }

    /// @notice Upgrades the proxy to the given implementation.
    /// @dev Overload of {upgradeUUPSProxy} with `value` set to zero.
    /// @param proxy The address of the proxy to upgrade.
    /// @param implementation The address of the new implementation to set in the proxy.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    function upgradeUUPSProxy(address proxy, address implementation, bytes memory data) internal {
        upgradeUUPSProxy({proxy: proxy, implementation: implementation, data: data, value: 0});
    }

    /// @notice Upgrades the proxy to the given implementation.
    /// @dev Calls {UUPSUpgradeable-upgradeToAndCall} on the proxy while forwarding
    ///      Ether, and verifies the resulting ERC-1967 implementation slot. UUPS
    ///      compatibility is validated through the upgrade mechanism, while upgrade
    ///      authorization is enforced by the current implementation.
    /// @param proxy The address of the proxy to upgrade.
    /// @param implementation The address of the new implementation to set in the proxy.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param value The amount of Ether to forward as `msg.value`.
    function upgradeUUPSProxy(address proxy, address implementation, bytes memory data, uint256 value) internal {
        _requireCode(proxy);
        _upgradeToAndCall(proxy, implementation, data, value);
        validateImplementation(proxy, implementation);
    }

    /// @notice Deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeUUPSProxy} with `constructorArgs` left empty and `value` set to zero.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    function upgradeUUPSProxy(address proxy, string memory artifactPath, bytes memory data) internal {
        upgradeUUPSProxy({proxy: proxy, artifactPath: artifactPath, constructorArgs: "", data: data, value: 0});
    }

    /// @notice Deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeUUPSProxy} with `constructorArgs` left empty.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param value The amount of Ether to forward as `msg.value`.
    function upgradeUUPSProxy(address proxy, string memory artifactPath, bytes memory data, uint256 value) internal {
        upgradeUUPSProxy({proxy: proxy, artifactPath: artifactPath, constructorArgs: "", data: data, value: value});
    }

    /// @notice Deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeUUPSProxy} with `value` set to zero.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory data
    ) internal {
        upgradeUUPSProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: constructorArgs, data: data, value: 0
        });
    }

    /// @notice Deploys a new implementation, then upgrades the proxy to it.
    /// @dev Deploys the new implementation using CREATE, then upgrades the proxy.
    ///      See {upgradeUUPSProxy-address-address-bytes-uint256}.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param value The amount of Ether to forward as `msg.value`.
    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory data,
        uint256 value
    ) internal {
        upgradeUUPSProxy({
            proxy: proxy, implementation: vm.deployCode(artifactPath, constructorArgs), data: data, value: value
        });
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeUUPSProxy} with `constructorArgs` left empty and `value` set to zero.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param salt The salt used for deterministic implementation deployment.
    function upgradeUUPSProxy(address proxy, string memory artifactPath, bytes memory data, bytes32 salt) internal {
        upgradeUUPSProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: "", data: data, salt: salt, value: 0
        });
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeUUPSProxy} with `constructorArgs` left empty.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param salt The salt used for deterministic implementation deployment.
    /// @param value The amount of Ether to forward as `msg.value`.
    function upgradeUUPSProxy(address proxy, string memory artifactPath, bytes memory data, bytes32 salt, uint256 value)
        internal
    {
        upgradeUUPSProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: "", data: data, salt: salt, value: value
        });
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeUUPSProxy} with `value` set to zero.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param salt The salt used for deterministic implementation deployment.
    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory data,
        bytes32 salt
    ) internal {
        upgradeUUPSProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: constructorArgs, data: data, salt: salt, value: 0
        });
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the proxy to it.
    /// @dev Deploys the new implementation using CREATE2, then upgrades the proxy.
    ///      See {upgradeUUPSProxy-address-address-bytes-uint256}.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param salt The salt used for deterministic implementation deployment.
    /// @param value The amount of Ether to forward as `msg.value`.
    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory data,
        bytes32 salt,
        uint256 value
    ) internal {
        upgradeUUPSProxy({
            proxy: proxy, implementation: vm.deployCode(artifactPath, constructorArgs, salt), data: data, value: value
        });
    }

    /// @notice Upgrades the proxy to the given implementation.
    /// @dev Overload of {upgradeUUPSProxy} that attempts the upgrade as `msgSender`.
    /// @param proxy The address of the proxy to upgrade.
    /// @param implementation The address of the new implementation to set in the proxy.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeUUPSProxy(address proxy, address implementation, bytes memory data, address msgSender)
        internal
        tryPrank(msgSender)
    {
        upgradeUUPSProxy({proxy: proxy, implementation: implementation, data: data, value: 0});
    }

    /// @notice Upgrades the proxy to the given implementation.
    /// @dev Overload of {upgradeUUPSProxy} that attempts the upgrade as `msgSender`.
    ///      `msgSender` must be authorized by the current implementation.
    /// @param proxy The address of the proxy to upgrade.
    /// @param implementation The address of the new implementation to set in the proxy.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param value The amount of Ether to forward as `msg.value`.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeUUPSProxy(
        address proxy,
        address implementation,
        bytes memory data,
        uint256 value,
        address msgSender
    ) internal tryPrank(msgSender) {
        upgradeUUPSProxy({proxy: proxy, implementation: implementation, data: data, value: value});
    }

    /// @notice Deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeUUPSProxy} that attempts the upgrade as `msgSender`.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeUUPSProxy(address proxy, string memory artifactPath, bytes memory data, address msgSender)
        internal
        tryPrank(msgSender)
    {
        upgradeUUPSProxy({proxy: proxy, artifactPath: artifactPath, constructorArgs: "", data: data, value: 0});
    }

    /// @notice Deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeUUPSProxy} that attempts the upgrade as `msgSender`.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param value The amount of Ether to forward as `msg.value`.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory data,
        uint256 value,
        address msgSender
    ) internal tryPrank(msgSender) {
        upgradeUUPSProxy({proxy: proxy, artifactPath: artifactPath, constructorArgs: "", data: data, value: value});
    }

    /// @notice Deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeUUPSProxy} that attempts the upgrade as `msgSender`.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory data,
        address msgSender
    ) internal tryPrank(msgSender) {
        upgradeUUPSProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: constructorArgs, data: data, value: 0
        });
    }

    /// @notice Deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeUUPSProxy} that attempts the upgrade as `msgSender`.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param value The amount of Ether to forward as `msg.value`.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory data,
        uint256 value,
        address msgSender
    ) internal tryPrank(msgSender) {
        upgradeUUPSProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: constructorArgs, data: data, value: value
        });
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeUUPSProxy} that attempts the upgrade as `msgSender`.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param salt The salt used for deterministic implementation deployment.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory data,
        bytes32 salt,
        address msgSender
    ) internal tryPrank(msgSender) {
        upgradeUUPSProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: "", data: data, salt: salt, value: 0
        });
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeUUPSProxy} that attempts the upgrade as `msgSender`.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param salt The salt used for deterministic implementation deployment.
    /// @param value The amount of Ether to forward as `msg.value`.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory data,
        bytes32 salt,
        uint256 value,
        address msgSender
    ) internal tryPrank(msgSender) {
        upgradeUUPSProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: "", data: data, salt: salt, value: value
        });
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeUUPSProxy} that attempts the upgrade as `msgSender`.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param salt The salt used for deterministic implementation deployment.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory data,
        bytes32 salt,
        address msgSender
    ) internal tryPrank(msgSender) {
        upgradeUUPSProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: constructorArgs, data: data, salt: salt, value: 0
        });
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeUUPSProxy} that attempts the upgrade as `msgSender`.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param salt The salt used for deterministic implementation deployment.
    /// @param value The amount of Ether to forward as `msg.value`.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory data,
        bytes32 salt,
        uint256 value,
        address msgSender
    ) internal tryPrank(msgSender) {
        upgradeUUPSProxy({
            proxy: proxy,
            artifactPath: artifactPath,
            constructorArgs: constructorArgs,
            data: data,
            salt: salt,
            value: value
        });
    }

    /// @notice Deploys a proxy backed by the given implementation.
    /// @dev Overload of {deployTransparentProxy} with `value` set to zero.
    /// @param implementation The address of the implementation to set in the proxy.
    /// @param initialOwner The address of the owner to assign to the proxy admin.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @return proxy The address of the deployed proxy.
    function deployTransparentProxy(address implementation, address initialOwner, bytes memory initializerData)
        internal
        returns (address proxy)
    {
        return deployTransparentProxy({
            implementation: implementation, initialOwner: initialOwner, initializerData: initializerData, value: 0
        });
    }

    /// @notice Deploys a proxy backed by the given implementation.
    /// @dev Deploys a {TransparentUpgradeableProxy} using CREATE while forwarding Ether,
    ///      and verifies the {ProxyAdmin} created by the proxy, its owner, and the
    ///      resulting ERC-1967 implementation and admin slots.
    /// @param implementation The address of the implementation to set in the proxy.
    /// @param initialOwner The address of the owner to assign to the proxy admin.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param value The amount of Ether to forward as `msg.value` during proxy construction.
    /// @return proxy The address of the deployed proxy.
    function deployTransparentProxy(
        address implementation,
        address initialOwner,
        bytes memory initializerData,
        uint256 value
    ) internal returns (address proxy) {
        proxy = vm.deployCode({
            artifactPath: "TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy",
            constructorArgs: abi.encode(implementation, initialOwner, initializerData),
            value: value
        });
        validateImplementation(proxy, implementation);

        // ProxyAdmin is the first contract created by the proxy constructor.
        address admin = vm.computeCreateAddress(proxy, 1);
        validateAdmin(proxy, admin);
        validateOwner(admin, initialOwner);
    }

    /// @notice Deterministically deploys a proxy backed by the given implementation.
    /// @dev Overload of {deployTransparentProxy} with `value` set to zero.
    /// @param implementation The address of the implementation to set in the proxy.
    /// @param initialOwner The address of the owner to assign to the proxy admin.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param salt The salt used for deterministic proxy deployment.
    /// @return proxy The address of the deployed proxy.
    function deployTransparentProxy(
        address implementation,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt
    ) internal returns (address proxy) {
        return deployTransparentProxy({
            implementation: implementation,
            initialOwner: initialOwner,
            initializerData: initializerData,
            salt: salt,
            value: 0
        });
    }

    /// @notice Deterministically deploys a proxy backed by the given implementation.
    /// @dev Deploys a {TransparentUpgradeableProxy} using CREATE2 while forwarding Ether,
    ///      and verifies the {ProxyAdmin} created by the proxy, its owner, and the
    ///      resulting ERC-1967 implementation and admin slots.
    /// @param implementation The address of the implementation to set in the proxy.
    /// @param initialOwner The address of the owner to assign to the proxy admin.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param salt The salt used for deterministic proxy deployment.
    /// @param value The amount of Ether to forward as `msg.value` during proxy construction.
    /// @return proxy The address of the deployed proxy.
    function deployTransparentProxy(
        address implementation,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal returns (address proxy) {
        proxy = vm.deployCode({
            artifactPath: "TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy",
            constructorArgs: abi.encode(implementation, initialOwner, initializerData),
            salt: salt,
            value: value
        });
        validateImplementation(proxy, implementation);

        // ProxyAdmin is the first contract created by the proxy constructor.
        address admin = vm.computeCreateAddress(proxy, 1);
        validateAdmin(proxy, admin);
        validateOwner(admin, initialOwner);
    }

    /// @notice Deploys an implementation, then a proxy backed by it.
    /// @dev Overload of {deployTransparentProxy} with `constructorArgs` left empty and `value` set to zero.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param initialOwner The address of the owner to assign to the proxy admin.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @return proxy The address of the deployed proxy.
    function deployTransparentProxy(string memory artifactPath, address initialOwner, bytes memory initializerData)
        internal
        returns (address proxy)
    {
        return deployTransparentProxy({
            artifactPath: artifactPath,
            constructorArgs: "",
            initialOwner: initialOwner,
            initializerData: initializerData,
            value: 0
        });
    }

    /// @notice Deploys an implementation, then a proxy backed by it.
    /// @dev Overload of {deployTransparentProxy} with `constructorArgs` left empty.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param initialOwner The address of the owner to assign to the proxy admin.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param value The amount of Ether to forward as `msg.value` during proxy construction.
    /// @return proxy The address of the deployed proxy.
    function deployTransparentProxy(
        string memory artifactPath,
        address initialOwner,
        bytes memory initializerData,
        uint256 value
    ) internal returns (address proxy) {
        return deployTransparentProxy({
            artifactPath: artifactPath,
            constructorArgs: "",
            initialOwner: initialOwner,
            initializerData: initializerData,
            value: value
        });
    }

    /// @notice Deploys an implementation, then a proxy backed by it.
    /// @dev Overload of {deployTransparentProxy} with `value` set to zero.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the implementation.
    /// @param initialOwner The address of the owner to assign to the proxy admin.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @return proxy The address of the deployed proxy.
    function deployTransparentProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        address initialOwner,
        bytes memory initializerData
    ) internal returns (address proxy) {
        return deployTransparentProxy({
            artifactPath: artifactPath,
            constructorArgs: constructorArgs,
            initialOwner: initialOwner,
            initializerData: initializerData,
            value: 0
        });
    }

    /// @notice Deploys an implementation, then a proxy backed by it.
    /// @dev Deploys the implementation and proxy using CREATE.
    ///      See {deployTransparentProxy-address-address-bytes-uint256}.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the implementation.
    /// @param initialOwner The address of the owner to assign to the proxy admin.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param value The amount of Ether to forward as `msg.value` during proxy construction.
    /// @return proxy The address of the deployed proxy.
    function deployTransparentProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        address initialOwner,
        bytes memory initializerData,
        uint256 value
    ) internal returns (address proxy) {
        return deployTransparentProxy({
            implementation: vm.deployCode(artifactPath, constructorArgs),
            initialOwner: initialOwner,
            initializerData: initializerData,
            value: value
        });
    }

    /// @notice Deterministically deploys an implementation, then a proxy backed by it.
    /// @dev Overload of {deployTransparentProxy} with `constructorArgs` left empty and `value` set to zero.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param initialOwner The address of the owner to assign to the proxy admin.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param salt The salt used for deterministic implementation and proxy deployment.
    /// @return proxy The address of the deployed proxy.
    function deployTransparentProxy(
        string memory artifactPath,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt
    ) internal returns (address proxy) {
        return deployTransparentProxy({
            artifactPath: artifactPath,
            constructorArgs: "",
            initialOwner: initialOwner,
            initializerData: initializerData,
            salt: salt,
            value: 0
        });
    }

    /// @notice Deterministically deploys an implementation, then a proxy backed by it.
    /// @dev Overload of {deployTransparentProxy} with `constructorArgs` left empty.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param initialOwner The address of the owner to assign to the proxy admin.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param salt The salt used for deterministic implementation and proxy deployment.
    /// @param value The amount of Ether to forward as `msg.value` during proxy construction.
    /// @return proxy The address of the deployed proxy.
    function deployTransparentProxy(
        string memory artifactPath,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal returns (address proxy) {
        return deployTransparentProxy({
            artifactPath: artifactPath,
            constructorArgs: "",
            initialOwner: initialOwner,
            initializerData: initializerData,
            salt: salt,
            value: value
        });
    }

    /// @notice Deterministically deploys an implementation, then a proxy backed by it.
    /// @dev Overload of {deployTransparentProxy} with `value` set to zero.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the implementation.
    /// @param initialOwner The address of the owner to assign to the proxy admin.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param salt The salt used for deterministic implementation and proxy deployment.
    /// @return proxy The address of the deployed proxy.
    function deployTransparentProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt
    ) internal returns (address proxy) {
        return deployTransparentProxy({
            artifactPath: artifactPath,
            constructorArgs: constructorArgs,
            initialOwner: initialOwner,
            initializerData: initializerData,
            salt: salt,
            value: 0
        });
    }

    /// @notice Deterministically deploys an implementation, then a proxy backed by it.
    /// @dev Deploys the implementation and proxy using CREATE2 with the same salt.
    ///      See {deployTransparentProxy-address-address-bytes-bytes32-uint256}.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the implementation.
    /// @param initialOwner The address of the owner to assign to the proxy admin.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param salt The salt used for deterministic implementation and proxy deployment.
    /// @param value The amount of Ether to forward as `msg.value` during proxy construction.
    /// @return proxy The address of the deployed proxy.
    function deployTransparentProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal returns (address proxy) {
        return deployTransparentProxy({
            implementation: vm.deployCode(artifactPath, constructorArgs, salt),
            initialOwner: initialOwner,
            initializerData: initializerData,
            salt: salt,
            value: value
        });
    }

    /// @notice Upgrades the proxy to the given implementation.
    /// @dev Overload of {upgradeTransparentProxy} with `value` set to zero.
    /// @param proxy The address of the proxy to upgrade.
    /// @param implementation The address of the new implementation to set in the proxy.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    function upgradeTransparentProxy(address proxy, address implementation, bytes memory data) internal {
        upgradeTransparentProxy({proxy: proxy, implementation: implementation, data: data, value: 0});
    }

    /// @notice Upgrades the proxy to the given implementation.
    /// @dev Calls {ProxyAdmin-upgradeAndCall} on the associated proxy admin while
    ///      forwarding Ether, and verifies the resulting ERC-1967 implementation slot.
    /// @param proxy The address of the proxy to upgrade.
    /// @param implementation The address of the new implementation to set in the proxy.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param value The amount of Ether to forward as `msg.value`.
    function upgradeTransparentProxy(address proxy, address implementation, bytes memory data, uint256 value) internal {
        _requireCode(proxy);
        address admin = getAdmin(proxy);
        _requireCode(admin);
        _upgradeAndCall(admin, proxy, implementation, data, value);
        validateImplementation(proxy, implementation);
    }

    /// @notice Deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeTransparentProxy} with `constructorArgs` left empty and `value` set to zero.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    function upgradeTransparentProxy(address proxy, string memory artifactPath, bytes memory data) internal {
        upgradeTransparentProxy({proxy: proxy, artifactPath: artifactPath, constructorArgs: "", data: data, value: 0});
    }

    /// @notice Deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeTransparentProxy} with `constructorArgs` left empty.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param value The amount of Ether to forward as `msg.value`.
    function upgradeTransparentProxy(address proxy, string memory artifactPath, bytes memory data, uint256 value)
        internal
    {
        upgradeTransparentProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: "", data: data, value: value
        });
    }

    /// @notice Deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeTransparentProxy} with `value` set to zero.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory data
    ) internal {
        upgradeTransparentProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: constructorArgs, data: data, value: 0
        });
    }

    /// @notice Deploys a new implementation, then upgrades the proxy to it.
    /// @dev Deploys the new implementation using CREATE, then upgrades the proxy.
    ///      See {upgradeTransparentProxy-address-address-bytes-uint256}.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param value The amount of Ether to forward as `msg.value`.
    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory data,
        uint256 value
    ) internal {
        upgradeTransparentProxy({
            proxy: proxy, implementation: vm.deployCode(artifactPath, constructorArgs), data: data, value: value
        });
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeTransparentProxy} with `constructorArgs` left empty and `value` set to zero.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param salt The salt used for deterministic implementation deployment.
    function upgradeTransparentProxy(address proxy, string memory artifactPath, bytes memory data, bytes32 salt)
        internal
    {
        upgradeTransparentProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: "", data: data, salt: salt, value: 0
        });
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeTransparentProxy} with `constructorArgs` left empty.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param salt The salt used for deterministic implementation deployment.
    /// @param value The amount of Ether to forward as `msg.value`.
    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory data,
        bytes32 salt,
        uint256 value
    ) internal {
        upgradeTransparentProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: "", data: data, salt: salt, value: value
        });
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeTransparentProxy} with `value` set to zero.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param salt The salt used for deterministic implementation deployment.
    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory data,
        bytes32 salt
    ) internal {
        upgradeTransparentProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: constructorArgs, data: data, salt: salt, value: 0
        });
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the proxy to it.
    /// @dev Deploys the new implementation using CREATE2, then upgrades the proxy.
    ///      See {upgradeTransparentProxy-address-address-bytes-uint256}.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param salt The salt used for deterministic implementation deployment.
    /// @param value The amount of Ether to forward as `msg.value`.
    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory data,
        bytes32 salt,
        uint256 value
    ) internal {
        upgradeTransparentProxy({
            proxy: proxy, implementation: vm.deployCode(artifactPath, constructorArgs, salt), data: data, value: value
        });
    }

    /// @notice Upgrades the proxy to the given implementation.
    /// @dev Overload of {upgradeTransparentProxy} that attempts the upgrade as `msgSender`.
    /// @param proxy The address of the proxy to upgrade.
    /// @param implementation The address of the new implementation to set in the proxy.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeTransparentProxy(address proxy, address implementation, bytes memory data, address msgSender)
        internal
        tryPrank(msgSender)
    {
        upgradeTransparentProxy({proxy: proxy, implementation: implementation, data: data});
    }

    /// @notice Upgrades the proxy to the given implementation.
    /// @dev Overload of {upgradeTransparentProxy} that attempts the upgrade as `msgSender`.
    ///      `msgSender` must be the owner of the associated proxy admin.
    /// @param proxy The address of the proxy to upgrade.
    /// @param implementation The address of the new implementation to set in the proxy.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param value The amount of Ether to forward as `msg.value`.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeTransparentProxy(
        address proxy,
        address implementation,
        bytes memory data,
        uint256 value,
        address msgSender
    ) internal tryPrank(msgSender) {
        upgradeTransparentProxy({proxy: proxy, implementation: implementation, data: data, value: value});
    }

    /// @notice Deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeTransparentProxy} that attempts the upgrade as `msgSender`.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeTransparentProxy(address proxy, string memory artifactPath, bytes memory data, address msgSender)
        internal
        tryPrank(msgSender)
    {
        upgradeTransparentProxy({proxy: proxy, artifactPath: artifactPath, constructorArgs: "", data: data, value: 0});
    }

    /// @notice Deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeTransparentProxy} that attempts the upgrade as `msgSender`.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param value The amount of Ether to forward as `msg.value`.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory data,
        uint256 value,
        address msgSender
    ) internal tryPrank(msgSender) {
        upgradeTransparentProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: "", data: data, value: value
        });
    }

    /// @notice Deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeTransparentProxy} that attempts the upgrade as `msgSender`.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory data,
        address msgSender
    ) internal tryPrank(msgSender) {
        upgradeTransparentProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: constructorArgs, data: data, value: 0
        });
    }

    /// @notice Deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeTransparentProxy} that attempts the upgrade as `msgSender`.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param value The amount of Ether to forward as `msg.value`.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory data,
        uint256 value,
        address msgSender
    ) internal tryPrank(msgSender) {
        upgradeTransparentProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: constructorArgs, data: data, value: value
        });
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeTransparentProxy} that attempts the upgrade as `msgSender`.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param salt The salt used for deterministic implementation deployment.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory data,
        bytes32 salt,
        address msgSender
    ) internal tryPrank(msgSender) {
        upgradeTransparentProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: "", data: data, salt: salt, value: 0
        });
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeTransparentProxy} that attempts the upgrade as `msgSender`.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param salt The salt used for deterministic implementation deployment.
    /// @param value The amount of Ether to forward as `msg.value`.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory data,
        bytes32 salt,
        uint256 value,
        address msgSender
    ) internal tryPrank(msgSender) {
        upgradeTransparentProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: "", data: data, salt: salt, value: value
        });
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeTransparentProxy} that attempts the upgrade as `msgSender`.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param salt The salt used for deterministic implementation deployment.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory data,
        bytes32 salt,
        address msgSender
    ) internal tryPrank(msgSender) {
        upgradeTransparentProxy({
            proxy: proxy, artifactPath: artifactPath, constructorArgs: constructorArgs, data: data, salt: salt, value: 0
        });
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the proxy to it.
    /// @dev Overload of {upgradeTransparentProxy} that attempts the upgrade as `msgSender`.
    /// @param proxy The address of the proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param salt The salt used for deterministic implementation deployment.
    /// @param value The amount of Ether to forward as `msg.value`.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory data,
        bytes32 salt,
        uint256 value,
        address msgSender
    ) internal tryPrank(msgSender) {
        upgradeTransparentProxy({
            proxy: proxy,
            artifactPath: artifactPath,
            constructorArgs: constructorArgs,
            data: data,
            salt: salt,
            value: value
        });
    }

    /// @notice Deploys a beacon backed by the given implementation.
    /// @dev Deploys an {UpgradeableBeacon} using CREATE and verifies its owner and implementation.
    /// @param implementation The address of the implementation to set in the beacon.
    /// @param initialOwner The address of the owner to set in the beacon.
    /// @return beacon The address of the deployed beacon.
    function deployBeacon(address implementation, address initialOwner) internal returns (address beacon) {
        beacon = vm.deployCode({
            artifactPath: "UpgradeableBeacon.sol:UpgradeableBeacon",
            constructorArgs: abi.encode(implementation, initialOwner)
        });
        validateOwner(beacon, initialOwner);
        validateBeaconImplementation(beacon, implementation);
    }

    /// @notice Deterministically deploys a beacon backed by the given implementation.
    /// @dev Deploys an {UpgradeableBeacon} using CREATE2 and verifies its owner and implementation.
    /// @param implementation The address of the implementation to set in the beacon.
    /// @param initialOwner The address of the owner to set in the beacon.
    /// @param salt The salt used for deterministic beacon deployment.
    /// @return beacon The address of the deployed beacon.
    function deployBeacon(address implementation, address initialOwner, bytes32 salt)
        internal
        returns (address beacon)
    {
        beacon = vm.deployCode({
            artifactPath: "UpgradeableBeacon.sol:UpgradeableBeacon",
            constructorArgs: abi.encode(implementation, initialOwner),
            salt: salt
        });
        validateOwner(beacon, initialOwner);
        validateBeaconImplementation(beacon, implementation);
    }

    /// @notice Deploys an implementation, then a beacon backed by it.
    /// @dev Overload of {deployBeacon} with `constructorArgs` left empty.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param initialOwner The address of the owner to set in the beacon.
    /// @return beacon The address of the deployed beacon.
    function deployBeacon(string memory artifactPath, address initialOwner) internal returns (address beacon) {
        return deployBeacon({artifactPath: artifactPath, constructorArgs: "", initialOwner: initialOwner});
    }

    /// @notice Deploys an implementation, then a beacon backed by it.
    /// @dev Deploys the implementation and beacon using CREATE.
    ///      See {deployBeacon-address-address}.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the implementation.
    /// @param initialOwner The address of the owner to set in the beacon.
    /// @return beacon The address of the deployed beacon.
    function deployBeacon(string memory artifactPath, bytes memory constructorArgs, address initialOwner)
        internal
        returns (address beacon)
    {
        return deployBeacon({implementation: vm.deployCode(artifactPath, constructorArgs), initialOwner: initialOwner});
    }

    /// @notice Deterministically deploys an implementation, then a beacon backed by it.
    /// @dev Overload of {deployBeacon} with `constructorArgs` left empty.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param initialOwner The address of the owner to set in the beacon.
    /// @param salt The salt used for deterministic implementation and beacon deployment.
    /// @return beacon The address of the deployed beacon.
    function deployBeacon(string memory artifactPath, address initialOwner, bytes32 salt)
        internal
        returns (address beacon)
    {
        return deployBeacon({artifactPath: artifactPath, constructorArgs: "", initialOwner: initialOwner, salt: salt});
    }

    /// @notice Deterministically deploys an implementation, then a beacon backed by it.
    /// @dev Deploys the implementation and beacon using CREATE2 with the same salt.
    ///      See {deployBeacon-address-address-bytes32}.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the implementation.
    /// @param initialOwner The address of the owner to set in the beacon.
    /// @param salt The salt used for deterministic implementation and beacon deployment.
    /// @return beacon The address of the deployed beacon.
    function deployBeacon(string memory artifactPath, bytes memory constructorArgs, address initialOwner, bytes32 salt)
        internal
        returns (address beacon)
    {
        return deployBeacon({
            implementation: vm.deployCode(artifactPath, constructorArgs, salt), initialOwner: initialOwner, salt: salt
        });
    }

    /// @notice Deploys a proxy backed by the given beacon.
    /// @dev Overload of {deployBeaconProxy} with `value` set to zero.
    /// @param beacon The address of the beacon to set in the proxy.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @return proxy The address of the deployed proxy.
    function deployBeaconProxy(address beacon, bytes memory initializerData) internal returns (address proxy) {
        return deployBeaconProxy({beacon: beacon, initializerData: initializerData, value: 0});
    }

    /// @notice Deploys a proxy backed by the given beacon.
    /// @dev Deploys a {BeaconProxy} using CREATE while forwarding Ether, and verifies the resulting ERC-1967 beacon slot.
    /// @param beacon The address of the beacon to set in the proxy.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param value The amount of Ether to forward as `msg.value` during proxy construction.
    /// @return proxy The address of the deployed proxy.
    function deployBeaconProxy(address beacon, bytes memory initializerData, uint256 value)
        internal
        returns (address proxy)
    {
        proxy = vm.deployCode({
            artifactPath: "BeaconProxy.sol:BeaconProxy",
            constructorArgs: abi.encode(beacon, initializerData),
            value: value
        });
        validateBeacon(proxy, beacon);
    }

    /// @notice Deterministically deploys a proxy backed by the given beacon.
    /// @dev Overload of {deployBeaconProxy} with `value` set to zero.
    /// @param beacon The address of the beacon to set in the proxy.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param salt The salt used for deterministic proxy deployment.
    /// @return proxy The address of the deployed proxy.
    function deployBeaconProxy(address beacon, bytes memory initializerData, bytes32 salt)
        internal
        returns (address proxy)
    {
        return deployBeaconProxy({beacon: beacon, initializerData: initializerData, salt: salt, value: 0});
    }

    /// @notice Deterministically deploys a proxy backed by the given beacon.
    /// @dev Deploys a {BeaconProxy} using CREATE2 while forwarding Ether, and verifies the resulting ERC-1967 beacon slot.
    /// @param beacon The address of the beacon to set in the proxy.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param salt The salt used for deterministic proxy deployment.
    /// @param value The amount of Ether to forward as `msg.value` during proxy construction.
    /// @return proxy The address of the deployed proxy.
    function deployBeaconProxy(address beacon, bytes memory initializerData, bytes32 salt, uint256 value)
        internal
        returns (address proxy)
    {
        proxy = vm.deployCode({
            artifactPath: "BeaconProxy.sol:BeaconProxy",
            constructorArgs: abi.encode(beacon, initializerData),
            salt: salt,
            value: value
        });
        validateBeacon(proxy, beacon);
    }

    /// @notice Deploys an implementation, then a beacon backed by it and a proxy backed by the beacon.
    /// @dev Overload of {deployBeaconProxy} with `constructorArgs` left empty and `value` set to zero.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param initialOwner The address of the owner to set in the beacon.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @return proxy The address of the deployed proxy.
    function deployBeaconProxy(string memory artifactPath, address initialOwner, bytes memory initializerData)
        internal
        returns (address proxy)
    {
        return deployBeaconProxy({
            artifactPath: artifactPath,
            constructorArgs: "",
            initialOwner: initialOwner,
            initializerData: initializerData,
            value: 0
        });
    }

    /// @notice Deploys an implementation, then a beacon backed by it and a proxy backed by the beacon.
    /// @dev Overload of {deployBeaconProxy} with `constructorArgs` left empty.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param initialOwner The address of the owner to set in the beacon.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param value The amount of Ether to forward as `msg.value` during proxy construction.
    /// @return proxy The address of the deployed proxy.
    function deployBeaconProxy(
        string memory artifactPath,
        address initialOwner,
        bytes memory initializerData,
        uint256 value
    ) internal returns (address proxy) {
        return deployBeaconProxy({
            artifactPath: artifactPath,
            constructorArgs: "",
            initialOwner: initialOwner,
            initializerData: initializerData,
            value: value
        });
    }

    /// @notice Deploys an implementation, then a beacon backed by it and a proxy backed by the beacon.
    /// @dev Overload of {deployBeaconProxy} with `value` set to zero.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the implementation.
    /// @param initialOwner The address of the owner to set in the beacon.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @return proxy The address of the deployed proxy.
    function deployBeaconProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        address initialOwner,
        bytes memory initializerData
    ) internal returns (address proxy) {
        return deployBeaconProxy({
            artifactPath: artifactPath,
            constructorArgs: constructorArgs,
            initialOwner: initialOwner,
            initializerData: initializerData,
            value: 0
        });
    }

    /// @notice Deploys an implementation, then a beacon backed by it and a proxy backed by the beacon.
    /// @dev Deploys the implementation, beacon, and proxy using CREATE.
    ///      See {deployBeaconProxy-address-bytes-uint256}.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the implementation.
    /// @param initialOwner The address of the owner to set in the beacon.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param value The amount of Ether to forward as `msg.value` during proxy construction.
    /// @return proxy The address of the deployed proxy.
    function deployBeaconProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        address initialOwner,
        bytes memory initializerData,
        uint256 value
    ) internal returns (address proxy) {
        return deployBeaconProxy({
            beacon: deployBeacon(vm.deployCode(artifactPath, constructorArgs), initialOwner),
            initializerData: initializerData,
            value: value
        });
    }

    /// @notice Deterministically deploys an implementation, then a beacon backed by it and a proxy backed by the beacon.
    /// @dev Overload of {deployBeaconProxy} with `constructorArgs` left empty and `value` set to zero.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param initialOwner The address of the owner to set in the beacon.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param salt The salt used for deterministic implementation, beacon, and proxy deployment.
    /// @return proxy The address of the deployed proxy.
    function deployBeaconProxy(
        string memory artifactPath,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt
    ) internal returns (address proxy) {
        return deployBeaconProxy({
            artifactPath: artifactPath,
            constructorArgs: "",
            initialOwner: initialOwner,
            initializerData: initializerData,
            salt: salt,
            value: 0
        });
    }

    /// @notice Deterministically deploys an implementation, then a beacon backed by it and a proxy backed by the beacon.
    /// @dev Overload of {deployBeaconProxy} with `constructorArgs` left empty.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param initialOwner The address of the owner to set in the beacon.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param salt The salt used for deterministic implementation, beacon, and proxy deployment.
    /// @param value The amount of Ether to forward as `msg.value` during proxy construction.
    /// @return proxy The address of the deployed proxy.
    function deployBeaconProxy(
        string memory artifactPath,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal returns (address proxy) {
        return deployBeaconProxy({
            artifactPath: artifactPath,
            constructorArgs: "",
            initialOwner: initialOwner,
            initializerData: initializerData,
            salt: salt,
            value: value
        });
    }

    /// @notice Deterministically deploys an implementation, then a beacon backed by it and a proxy backed by the beacon.
    /// @dev Overload of {deployBeaconProxy} with `value` set to zero.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the implementation.
    /// @param initialOwner The address of the owner to set in the beacon.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param salt The salt used for deterministic implementation, beacon, and proxy deployment.
    /// @return proxy The address of the deployed proxy.
    function deployBeaconProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt
    ) internal returns (address proxy) {
        return deployBeaconProxy({
            artifactPath: artifactPath,
            constructorArgs: constructorArgs,
            initialOwner: initialOwner,
            initializerData: initializerData,
            salt: salt,
            value: 0
        });
    }

    /// @notice Deterministically deploys an implementation, then a beacon backed by it and a proxy backed by the beacon.
    /// @dev Deploys the implementation, beacon, and proxy using CREATE2 with the same salt.
    ///      See {deployBeaconProxy-address-bytes-bytes32-uint256}.
    /// @param artifactPath The Foundry artifact identifier for the implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the implementation.
    /// @param initialOwner The address of the owner to set in the beacon.
    /// @param initializerData The ABI-encoded calldata to execute during proxy initialization.
    /// @param salt The salt used for deterministic implementation, beacon, and proxy deployment.
    /// @param value The amount of Ether to forward as `msg.value` during proxy construction.
    /// @return proxy The address of the deployed proxy.
    function deployBeaconProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal returns (address proxy) {
        return deployBeaconProxy({
            beacon: deployBeacon(vm.deployCode(artifactPath, constructorArgs, salt), initialOwner, salt),
            initializerData: initializerData,
            salt: salt,
            value: value
        });
    }

    /// @notice Upgrades the beacon to the given implementation.
    /// @dev Calls {UpgradeableBeacon-upgradeTo} on the beacon and verifies the resulting implementation.
    /// @param beacon The address of the beacon to upgrade.
    /// @param implementation The address of the new implementation to set in the beacon.
    function upgradeBeacon(address beacon, address implementation) internal {
        _requireCode(beacon);
        _upgradeBeaconTo(beacon, implementation);
        validateBeaconImplementation(beacon, implementation);
    }

    /// @notice Deploys a new implementation, then upgrades the beacon to it.
    /// @dev Overload of {upgradeBeacon} with `constructorArgs` left empty.
    /// @param beacon The address of the beacon to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    function upgradeBeacon(address beacon, string memory artifactPath) internal {
        upgradeBeacon({beacon: beacon, artifactPath: artifactPath, constructorArgs: ""});
    }

    /// @notice Deploys a new implementation, then upgrades the beacon to it.
    /// @dev Deploys the new implementation using CREATE, then upgrades the beacon.
    ///      See {upgradeBeacon-address-address}.
    /// @param beacon The address of the beacon to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    function upgradeBeacon(address beacon, string memory artifactPath, bytes memory constructorArgs) internal {
        upgradeBeacon({beacon: beacon, implementation: vm.deployCode(artifactPath, constructorArgs)});
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the beacon to it.
    /// @dev Overload of {upgradeBeacon} with `constructorArgs` left empty.
    /// @param beacon The address of the beacon to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param salt The salt used for deterministic implementation deployment.
    function upgradeBeacon(address beacon, string memory artifactPath, bytes32 salt) internal {
        upgradeBeacon({beacon: beacon, artifactPath: artifactPath, constructorArgs: "", salt: salt});
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the beacon to it.
    /// @dev Deploys the new implementation using CREATE2, then upgrades the beacon.
    ///      See {upgradeBeacon-address-address}.
    /// @param beacon The address of the beacon to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    /// @param salt The salt used for deterministic implementation deployment.
    function upgradeBeacon(address beacon, string memory artifactPath, bytes memory constructorArgs, bytes32 salt)
        internal
    {
        upgradeBeacon({beacon: beacon, implementation: vm.deployCode(artifactPath, constructorArgs, salt)});
    }

    /// @notice Upgrades the beacon to the given implementation.
    /// @dev Overload of {upgradeBeacon} that attempts the upgrade as `msgSender`.
    ///      `msgSender` must be the owner of the beacon.
    /// @param beacon The address of the beacon to upgrade.
    /// @param implementation The address of the new implementation to set in the beacon.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeBeacon(address beacon, address implementation, address msgSender) internal tryPrank(msgSender) {
        upgradeBeacon(beacon, implementation);
    }

    /// @notice Deploys a new implementation, then upgrades the beacon to it.
    /// @dev Overload of {upgradeBeacon} that attempts the upgrade as `msgSender`.
    /// @param beacon The address of the beacon to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeBeacon(address beacon, string memory artifactPath, address msgSender) internal tryPrank(msgSender) {
        upgradeBeacon({beacon: beacon, artifactPath: artifactPath, constructorArgs: ""});
    }

    /// @notice Deploys a new implementation, then upgrades the beacon to it.
    /// @dev Overload of {upgradeBeacon} that attempts the upgrade as `msgSender`.
    /// @param beacon The address of the beacon to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeBeacon(address beacon, string memory artifactPath, bytes memory constructorArgs, address msgSender)
        internal
        tryPrank(msgSender)
    {
        upgradeBeacon({beacon: beacon, artifactPath: artifactPath, constructorArgs: constructorArgs});
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the beacon to it.
    /// @dev Overload of {upgradeBeacon} that attempts the upgrade as `msgSender`.
    /// @param beacon The address of the beacon to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param salt The salt used for deterministic implementation deployment.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeBeacon(address beacon, string memory artifactPath, bytes32 salt, address msgSender)
        internal
        tryPrank(msgSender)
    {
        upgradeBeacon({beacon: beacon, artifactPath: artifactPath, constructorArgs: "", salt: salt});
    }

    /// @notice Deterministically deploys a new implementation, then upgrades the beacon to it.
    /// @dev Overload of {upgradeBeacon} that attempts the upgrade as `msgSender`.
    /// @param beacon The address of the beacon to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation.
    /// @param constructorArgs The ABI-encoded constructor arguments for the new implementation.
    /// @param salt The salt used for deterministic implementation deployment.
    /// @param msgSender The address to impersonate as `msg.sender`.
    function upgradeBeacon(
        address beacon,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes32 salt,
        address msgSender
    ) internal tryPrank(msgSender) {
        upgradeBeacon({beacon: beacon, artifactPath: artifactPath, constructorArgs: constructorArgs, salt: salt});
    }

    /// @notice Returns the address of the implementation stored in the proxy.
    /// @dev Reads the ERC-1967 implementation slot.
    /// @param proxy The address of the proxy to inspect.
    /// @return implementation The address of the implementation stored in the proxy.
    function getImplementation(address proxy) internal view returns (address implementation) {
        return address(uint160(uint256(vm.load(proxy, IMPLEMENTATION_SLOT))));
    }

    /// @notice Returns the address of the admin stored in the proxy.
    /// @dev Reads the ERC-1967 admin slot.
    /// @param proxy The address of the proxy to inspect.
    /// @return admin The address of the admin stored in the proxy.
    function getAdmin(address proxy) internal view returns (address admin) {
        return address(uint160(uint256(vm.load(proxy, ADMIN_SLOT))));
    }

    /// @notice Returns the address of the beacon stored in the proxy.
    /// @dev Reads the ERC-1967 beacon slot.
    /// @param proxy The address of the proxy to inspect.
    /// @return beacon The address of the beacon stored in the proxy.
    function getBeacon(address proxy) internal view returns (address beacon) {
        return address(uint160(uint256(vm.load(proxy, BEACON_SLOT))));
    }

    /// @notice Returns the address of the implementation exposed by the beacon.
    /// @dev Calls the beacon's `implementation()` getter and returns the decoded address.
    /// @param beacon The address of the beacon to inspect.
    /// @return implementation The address of the implementation exposed by the beacon.
    function getBeaconImplementation(address beacon) internal view returns (address implementation) {
        assembly ("memory-safe") {
            mstore(0x00, 0x5c60da1b) // implementation()

            if iszero(staticcall(gas(), beacon, 0x1c, 0x04, 0x00, 0x20)) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0x00, returndatasize())
                revert(ptr, returndatasize())
            }

            implementation := shr(0x60, shl(0x60, mload(0x00)))
        }
    }

    /// @notice Returns the upgrade interface version exposed by the target.
    /// @dev Calls the `UPGRADE_INTERFACE_VERSION()` getter on the proxy or admin and returns
    ///      the decoded string when the call succeeds and the response has the expected
    ///      ABI layout, or an empty string otherwise.
    /// @param upgradeInterface The address of the proxy or admin to inspect.
    /// @return version The exposed upgrade interface version, or an empty string if unavailable.
    function getUpgradeInterfaceVersion(address upgradeInterface) internal view returns (string memory version) {
        assembly ("memory-safe") {
            mstore(0x00, 0xad3cb1cc) // UPGRADE_INTERFACE_VERSION()

            if and(eq(returndatasize(), 0x60), staticcall(gas(), upgradeInterface, 0x1c, 0x04, 0x00, 0x00)) {
                let ptr := mload(0x40)
                mstore(0x40, add(ptr, 0x60))
                returndatacopy(ptr, 0x00, 0x60)

                if and(eq(mload(ptr), 0x20), iszero(gt(mload(add(ptr, 0x20)), 0x20))) {
                    version := add(ptr, 0x20)
                }
            }
        }
    }

    /// @notice Verifies the address of the implementation stored in the proxy.
    /// @param proxy The address of the proxy to inspect.
    /// @param expected The expected address of the implementation.
    function validateImplementation(address proxy, address expected) internal view {
        address actual = getImplementation(proxy);
        if (actual != expected) revert ImplementationMismatch(proxy, expected, actual);
    }

    /// @notice Verifies the address of the admin stored in the proxy.
    /// @param proxy The address of the proxy to inspect.
    /// @param expected The expected address of the admin.
    function validateAdmin(address proxy, address expected) internal view {
        address actual = getAdmin(proxy);
        if (actual != expected) revert AdminMismatch(proxy, expected, actual);
    }

    /// @notice Verifies the address of the beacon stored in the proxy.
    /// @param proxy The address of the proxy to inspect.
    /// @param expected The expected address of the beacon.
    function validateBeacon(address proxy, address expected) internal view {
        address actual = getBeacon(proxy);
        if (actual != expected) revert BeaconMismatch(proxy, expected, actual);
    }

    /// @notice Verifies the address of the implementation exposed by the beacon.
    /// @param beacon The address of the beacon to inspect.
    /// @param expected The expected address of the implementation.
    function validateBeaconImplementation(address beacon, address expected) internal view {
        address actual = getBeaconImplementation(beacon);
        if (actual != expected) revert BeaconImplementationMismatch(beacon, expected, actual);
    }

    /// @notice Verifies the address of the owner exposed by the target.
    /// @param target The address of the contract to inspect.
    /// @param expected The expected address of the owner.
    function validateOwner(address target, address expected) internal view {
        address actual = _getOwner(target);
        if (actual != expected) revert OwnerMismatch(target, expected, actual);
    }

    /// @dev Calls {UUPSUpgradeable-upgradeToAndCall} on the proxy and bubbles revert data.
    /// @param proxy The address of the proxy to upgrade.
    /// @param implementation The address of the new implementation to set in the proxy.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param value The amount of Ether to forward to the upgrade call.
    function _upgradeToAndCall(address proxy, address implementation, bytes memory data, uint256 value) private {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, 0x4f1ef286) // upgradeToAndCall(address,bytes)
            mstore(add(ptr, 0x20), shr(0x60, shl(0x60, implementation)))
            mstore(add(ptr, 0x40), 0x40)

            let length := add(mload(data), 0x20)
            mcopy(add(ptr, 0x60), data, length)

            if iszero(call(gas(), proxy, value, add(ptr, 0x1c), add(length, 0x44), 0x00, 0x00)) {
                returndatacopy(ptr, 0x00, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }

    /// @dev Calls {ProxyAdmin-upgradeAndCall} on the associated proxy admin and bubbles revert data.
    /// @param admin The address of the associated proxy admin.
    /// @param proxy The address of the proxy to upgrade.
    /// @param implementation The address of the new implementation to set in the proxy.
    /// @param data The ABI-encoded calldata to execute during the upgrade.
    /// @param value The amount of Ether to forward to the upgrade call.
    function _upgradeAndCall(address admin, address proxy, address implementation, bytes memory data, uint256 value)
        private
    {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, 0x9623609d) // upgradeAndCall(address,address,bytes)
            mstore(add(ptr, 0x20), shr(0x60, shl(0x60, proxy)))
            mstore(add(ptr, 0x40), shr(0x60, shl(0x60, implementation)))
            mstore(add(ptr, 0x60), 0x60)

            let length := add(mload(data), 0x20)
            mcopy(add(ptr, 0x80), data, length)

            if iszero(call(gas(), admin, value, add(ptr, 0x1c), add(length, 0x64), 0x00, 0x00)) {
                returndatacopy(ptr, 0x00, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }

    /// @dev Calls {UpgradeableBeacon-upgradeTo} on the beacon and bubbles revert data.
    /// @param beacon The address of the beacon to upgrade.
    /// @param implementation The address of the new implementation to set in the beacon.
    function _upgradeBeaconTo(address beacon, address implementation) private {
        assembly ("memory-safe") {
            mstore(0x00, 0x3659cfe6) // upgradeTo(address)
            mstore(0x20, shr(0x60, shl(0x60, implementation)))

            if iszero(call(gas(), beacon, 0x00, 0x1c, 0x24, 0x00, 0x00)) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0x00, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }

    /// @dev Calls the target's `owner()` getter and returns the decoded address.
    /// @param target The address of the contract to inspect.
    /// @return owner The address of the owner exposed by the target.
    function _getOwner(address target) private view returns (address owner) {
        assembly ("memory-safe") {
            mstore(0x00, 0x8da5cb5b) // owner()

            if iszero(staticcall(gas(), target, 0x1c, 0x04, 0x00, 0x20)) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0x00, returndatasize())
                revert(ptr, returndatasize())
            }

            owner := shr(0x60, shl(0x60, mload(0x00)))
        }
    }

    /// @dev Reverts with {EmptyCode} if the target has no runtime code.
    /// @param target The address to validate.
    function _requireCode(address target) private view {
        assembly ("memory-safe") {
            if iszero(extcodesize(target)) {
                mstore(0x00, 0x626c4161) // EmptyCode(address)
                mstore(0x20, shr(0x60, shl(0x60, target)))
                revert(0x1c, 0x24)
            }
        }
    }
}
