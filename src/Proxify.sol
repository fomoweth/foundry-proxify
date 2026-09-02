// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Vm} from "forge-std/Vm.sol";

/// @title Proxify
/// @author fomoweth
/// @notice Foundry-native utilities for deploying, upgrading, and inspecting ERC-1967 proxies.
library Proxify {
    /*//////////////////////////////////////////////////////////////////////////
                                CUSTOM ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    error EmptyCode(address target);

    error DeploymentFailed();

    error UpgradeFailed();

    error ImplementationMismatch(address proxy, address expected, address actual);

    error AdminMismatch(address proxy, address expected, address actual);

    error BeaconMismatch(address proxy, address expected, address actual);

    error BeaconImplementationMismatch(address beacon, address expected, address actual);

    error OwnerMismatch(address target, address expected, address actual);

    /*//////////////////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    Vm private constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    bytes32 private constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    bytes32 private constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    bytes32 private constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /*//////////////////////////////////////////////////////////////////////////
                                ARTIFACT DEPLOYMENT
    //////////////////////////////////////////////////////////////////////////*/

    function deployCode(string memory artifactPath) internal returns (address instance) {}

    function deployCode(string memory artifactPath, uint256 value) internal returns (address instance) {}

    function deployCode(string memory artifactPath, bytes memory constructorArgs) internal returns (address instance) {}

    function deployCode(string memory artifactPath, bytes memory constructorArgs, uint256 value)
        internal
        returns (address instance)
    {}

    function deployCode(string memory artifactPath, bytes32 salt) internal returns (address instance) {}

    function deployCode(string memory artifactPath, bytes32 salt, uint256 value) internal returns (address instance) {}

    function deployCode(string memory artifactPath, bytes memory constructorArgs, bytes32 salt)
        internal
        returns (address instance)
    {}

    function deployCode(string memory artifactPath, bytes memory constructorArgs, bytes32 salt, uint256 value)
        internal
        returns (address instance)
    {}

    /*//////////////////////////////////////////////////////////////////////////
                                    UUPS PROXY
    //////////////////////////////////////////////////////////////////////////*/

    function deployUUPSProxy(address implementation, bytes memory initializerData) internal returns (address proxy) {}

    function deployUUPSProxy(address implementation, bytes memory initializerData, uint256 value)
        internal
        returns (address proxy)
    {}

    function deployUUPSProxy(address implementation, bytes memory initializerData, bytes32 salt)
        internal
        returns (address proxy)
    {}

    function deployUUPSProxy(address implementation, bytes memory initializerData, bytes32 salt, uint256 value)
        internal
        returns (address proxy)
    {}

    function deployUUPSProxy(string memory artifactPath, bytes memory initializerData)
        internal
        returns (address proxy)
    {}

    function deployUUPSProxy(string memory artifactPath, bytes memory initializerData, uint256 value)
        internal
        returns (address proxy)
    {}

    function deployUUPSProxy(string memory artifactPath, bytes memory constructorArgs, bytes memory initializerData)
        internal
        returns (address proxy)
    {}

    function deployUUPSProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        uint256 value
    ) internal returns (address proxy) {}

    function deployUUPSProxy(string memory artifactPath, bytes memory initializerData, bytes32 salt)
        internal
        returns (address proxy)
    {}

    function deployUUPSProxy(string memory artifactPath, bytes memory initializerData, bytes32 salt, uint256 value)
        internal
        returns (address proxy)
    {}

    function deployUUPSProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        bytes32 salt
    ) internal returns (address proxy) {}

    function deployUUPSProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal returns (address proxy) {}

    function upgradeUUPSProxy(address proxy, address implementation, bytes memory initializerData) internal {}

    function upgradeUUPSProxy(address proxy, address implementation, bytes memory initializerData, uint256 value)
        internal {}

    function upgradeUUPSProxy(address proxy, string memory artifactPath, bytes memory initializerData) internal {}

    function upgradeUUPSProxy(address proxy, string memory artifactPath, bytes memory initializerData, uint256 value)
        internal {}

    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData
    ) internal {}

    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        uint256 value
    ) internal {}

    function upgradeUUPSProxy(address proxy, string memory artifactPath, bytes memory initializerData, bytes32 salt)
        internal {}

    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal {}

    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        bytes32 salt
    ) internal {}

    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal {}

    /*//////////////////////////////////////////////////////////////////////////
                                TRANSPARENT PROXY
    //////////////////////////////////////////////////////////////////////////*/

    function deployTransparentProxy(address implementation, address initialOwner, bytes memory initializerData)
        internal
        returns (address proxy)
    {}

    function deployTransparentProxy(
        address implementation,
        address initialOwner,
        bytes memory initializerData,
        uint256 value
    ) internal returns (address proxy) {}

    function deployTransparentProxy(
        address implementation,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt
    ) internal returns (address proxy) {}

    function deployTransparentProxy(
        address implementation,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal returns (address proxy) {}

    function deployTransparentProxy(string memory artifactPath, address initialOwner, bytes memory initializerData)
        internal
        returns (address proxy)
    {}

    function deployTransparentProxy(
        string memory artifactPath,
        address initialOwner,
        bytes memory initializerData,
        uint256 value
    ) internal returns (address proxy) {}

    function deployTransparentProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        address initialOwner,
        bytes memory initializerData
    ) internal returns (address proxy) {}

    function deployTransparentProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        address initialOwner,
        bytes memory initializerData,
        uint256 value
    ) internal returns (address proxy) {}

    function deployTransparentProxy(
        string memory artifactPath,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt
    ) internal returns (address proxy) {}

    function deployTransparentProxy(
        string memory artifactPath,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal returns (address proxy) {}

    function deployTransparentProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt
    ) internal returns (address proxy) {}

    function deployTransparentProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal returns (address proxy) {}

    function upgradeTransparentProxy(address proxy, address implementation, bytes memory initializerData) internal {}

    function upgradeTransparentProxy(address proxy, address implementation, bytes memory initializerData, uint256 value)
        internal {}

    function upgradeTransparentProxy(address proxy, string memory artifactPath, bytes memory initializerData)
        internal {}

    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory initializerData,
        uint256 value
    ) internal {}

    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData
    ) internal {}

    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        uint256 value
    ) internal {}

    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory initializerData,
        bytes32 salt
    ) internal {}

    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal {}

    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        bytes32 salt
    ) internal {}

    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal {}

    /*//////////////////////////////////////////////////////////////////////////
                                    BEACON PROXY
    //////////////////////////////////////////////////////////////////////////*/

    function deployBeacon(address implementation, address initialOwner) internal returns (address beacon) {}

    function deployBeacon(address implementation, address initialOwner, bytes32 salt)
        internal
        returns (address beacon)
    {}

    function deployBeacon(string memory artifactPath, address initialOwner) internal returns (address beacon) {}

    function deployBeacon(string memory artifactPath, bytes memory constructorArgs, address initialOwner)
        internal
        returns (address beacon)
    {}

    function deployBeacon(string memory artifactPath, address initialOwner, bytes32 salt)
        internal
        returns (address beacon)
    {}

    function deployBeacon(string memory artifactPath, bytes memory constructorArgs, address initialOwner, bytes32 salt)
        internal
        returns (address beacon)
    {}

    function deployBeaconProxy(address beacon, bytes memory initializerData) internal returns (address proxy) {}

    function deployBeaconProxy(address beacon, bytes memory initializerData, uint256 value)
        internal
        returns (address proxy)
    {}

    function deployBeaconProxy(address beacon, bytes memory initializerData, bytes32 salt)
        internal
        returns (address proxy)
    {}

    function deployBeaconProxy(address beacon, bytes memory initializerData, bytes32 salt, uint256 value)
        internal
        returns (address proxy)
    {}

    function deployBeaconProxy(string memory artifactPath, address initialOwner, bytes memory initializerData)
        internal
        returns (address proxy)
    {}

    function deployBeaconProxy(
        string memory artifactPath,
        address initialOwner,
        bytes memory initializerData,
        uint256 value
    ) internal returns (address proxy) {}

    function deployBeaconProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        address initialOwner,
        bytes memory initializerData
    ) internal returns (address proxy) {}

    function deployBeaconProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        address initialOwner,
        bytes memory initializerData,
        uint256 value
    ) internal returns (address proxy) {}

    function deployBeaconProxy(
        string memory artifactPath,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt
    ) internal returns (address proxy) {}

    function deployBeaconProxy(
        string memory artifactPath,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal returns (address proxy) {}

    function deployBeaconProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt
    ) internal returns (address proxy) {}

    function deployBeaconProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal returns (address proxy) {}

    function upgradeBeacon(address beacon, address implementation) internal {}

    function upgradeBeacon(address beacon, string memory artifactPath) internal {}

    function upgradeBeacon(address beacon, string memory artifactPath, bytes memory constructorArgs) internal {}

    function upgradeBeacon(address beacon, string memory artifactPath, bytes32 salt) internal {}

    function upgradeBeacon(address beacon, string memory artifactPath, bytes memory constructorArgs, bytes32 salt)
        internal {}

    /*//////////////////////////////////////////////////////////////////////////
                                ERC1967 INSPECTION
    //////////////////////////////////////////////////////////////////////////*/

    function getImplementation(address proxy) internal view returns (address implementation) {
        return address(uint160(uint256(vm.load(proxy, IMPLEMENTATION_SLOT))));
    }

    function getAdmin(address proxy) internal view returns (address admin) {
        return address(uint160(uint256(vm.load(proxy, ADMIN_SLOT))));
    }

    function getBeacon(address proxy) internal view returns (address beacon) {
        return address(uint160(uint256(vm.load(proxy, BEACON_SLOT))));
    }

    function getBeaconImplementation(address beacon) internal view returns (address implementation) {}

    function getUpgradeInterfaceVersion(address upgradeInterface) internal view returns (string memory version) {}

    /*//////////////////////////////////////////////////////////////////////////
                                    VALIDATION
    //////////////////////////////////////////////////////////////////////////*/

    function validateImplementation(address proxy, address expected) internal view {}

    function validateAdmin(address proxy, address expected) internal view {}

    function validateBeacon(address proxy, address expected) internal view {}

    function validateBeaconImplementation(address beacon, address expected) internal view {}

    function validateOwner(address target, address expected) internal view {}

    /*//////////////////////////////////////////////////////////////////////////
                                PRIVATE INTERNALS
    //////////////////////////////////////////////////////////////////////////*/

    function _deployCode(bytes memory initCode, uint256 value, bytes32 salt, bool useDeterministic)
        private
        returns (address instance)
    {}

    function _upgradeToAndCall(address proxy, address implementation, bytes memory data, uint256 value) private {}

    function _upgradeAndCall(address admin, address proxy, address implementation, bytes memory data, uint256 value)
        private {}

    function _upgradeBeaconTo(address beacon, address implementation) private {}

    function _getOwner(address target) private view returns (address owner) {}
}
