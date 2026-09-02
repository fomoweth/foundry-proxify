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

    /// @dev Thrown when a target address contains no runtime code.
    /// @param target The address expected to contain runtime code.
    error EmptyCode(address target);

    /// @dev Thrown when a contract deployment fails without revert data.
    error DeploymentFailed();

    /// @dev Thrown when an upgrade call fails without revert data.
    error UpgradeFailed();

    /// @dev Thrown when an ERC1967 implementation slot does not contain the expected address.
    /// @param proxy The proxy whose implementation slot was inspected.
    /// @param expected The expected implementation address.
    /// @param actual The implementation address read from the proxy.
    error ImplementationMismatch(address proxy, address expected, address actual);

    /// @dev Thrown when an ERC1967 admin slot does not contain the expected address.
    /// @param proxy The proxy whose admin slot was inspected.
    /// @param expected The expected admin address.
    /// @param actual The admin address read from the proxy.
    error AdminMismatch(address proxy, address expected, address actual);

    /// @dev Thrown when an ERC1967 beacon slot does not contain the expected address.
    /// @param proxy The proxy whose beacon slot was inspected.
    /// @param expected The expected beacon address.
    /// @param actual The beacon address read from the proxy.
    error BeaconMismatch(address proxy, address expected, address actual);

    /// @dev Thrown when a beacon does not report the expected implementation address.
    /// @param beacon The beacon whose implementation was inspected.
    /// @param expected The expected implementation address.
    /// @param actual The implementation address reported by the beacon.
    error BeaconImplementationMismatch(address beacon, address expected, address actual);

    /// @dev Thrown when an ownable contract does not report the expected owner.
    /// @param target The contract whose owner was inspected.
    /// @param expected The expected owner address.
    /// @param actual The owner address reported by the contract.
    error OwnerMismatch(address target, address expected, address actual);

    /*//////////////////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Foundry cheatcode interface at the canonical HEVM cheatcode address.
    Vm private constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    /// @dev ERC-1967 storage slot for the implementation address.
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev ERC-1967 storage slot for the admin address.
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /// @dev ERC-1967 storage slot for the beacon address.
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /*//////////////////////////////////////////////////////////////////////////
                                ARTIFACT DEPLOYMENT
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Deploys a contract from a compiled artifact using CREATE.
    /// @dev Resolves the artifact creation bytecode through Foundry and deploys it without
    ///      constructor arguments or Ether.
    /// @param artifactPath The Foundry artifact identifier used to resolve creation bytecode.
    /// @return instance The deployed contract address.
    function deployCode(string memory artifactPath) internal returns (address instance) {
        return deployCode({artifactPath: artifactPath, value: 0});
    }

    /// @notice Deploys a contract from a compiled artifact using CREATE and forwards Ether.
    /// @dev Resolves the artifact creation bytecode through Foundry and forwards the specified
    ///      amount to the constructor.
    /// @param artifactPath The Foundry artifact identifier used to resolve creation bytecode.
    /// @param value The amount of Ether forwarded during contract creation.
    /// @return instance The deployed contract address.
    function deployCode(string memory artifactPath, uint256 value) internal returns (address instance) {
        return _deployCode(vm.getCode(artifactPath), value, 0, false);
    }

    /// @notice Deploys a contract from a compiled artifact with constructor arguments using CREATE.
    /// @dev Appends the ABI-encoded constructor arguments to the artifact creation bytecode before deployment.
    /// @param artifactPath The Foundry artifact identifier used to resolve creation bytecode.
    /// @param constructorArgs The ABI-encoded constructor arguments appended to the creation bytecode.
    /// @return instance The deployed contract address.
    function deployCode(string memory artifactPath, bytes memory constructorArgs) internal returns (address instance) {
        return deployCode({artifactPath: artifactPath, constructorArgs: constructorArgs, value: 0});
    }

    /// @notice Deploys a contract from a compiled artifact with constructor arguments using CREATE and forwards Ether.
    /// @dev Appends the ABI-encoded constructor arguments to the artifact creation bytecode and forwards the specified
    ///      amount during contract creation.
    /// @param artifactPath The Foundry artifact identifier used to resolve creation bytecode.
    /// @param constructorArgs The ABI-encoded constructor arguments appended to the creation bytecode.
    /// @param value The amount of Ether forwarded during contract creation.
    /// @return instance The deployed contract address.
    function deployCode(string memory artifactPath, bytes memory constructorArgs, uint256 value)
        internal
        returns (address instance)
    {
        return _deployCode(bytes.concat(vm.getCode(artifactPath), constructorArgs), value, 0, false);
    }

    /// @notice Deploys a contract deterministically from a compiled artifact using CREATE2.
    /// @dev Resolves the artifact creation bytecode through Foundry and uses the supplied salt
    ///      without constructor arguments or Ether.
    /// @param artifactPath The Foundry artifact identifier used to resolve creation bytecode.
    /// @param salt The CREATE2 deployment salt.
    /// @return instance The deployed contract address.
    function deployCode(string memory artifactPath, bytes32 salt) internal returns (address instance) {
        return deployCode({artifactPath: artifactPath, salt: salt, value: 0});
    }

    /// @notice Deploys a contract deterministically from a compiled artifact using CREATE2 and forwards Ether.
    /// @dev Resolves the artifact creation bytecode through Foundry and forwards the specified amount during
    ///      deterministic contract creation.
    /// @param artifactPath The Foundry artifact identifier used to resolve creation bytecode.
    /// @param salt The CREATE2 deployment salt.
    /// @param value The amount of Ether forwarded during contract creation.
    /// @return instance The deployed contract address.
    function deployCode(string memory artifactPath, bytes32 salt, uint256 value) internal returns (address instance) {
        return _deployCode(vm.getCode(artifactPath), value, salt, true);
    }

    /// @notice Deploys a contract deterministically from a compiled artifact with constructor arguments.
    /// @dev Appends the ABI-encoded constructor arguments to the artifact creation bytecode and deploys
    ///      the resulting init code using CREATE2.
    /// @param artifactPath The Foundry artifact identifier used to resolve creation bytecode.
    /// @param constructorArgs The ABI-encoded constructor arguments appended to the creation bytecode.
    /// @param salt The CREATE2 deployment salt.
    /// @return instance The deployed contract address.
    function deployCode(string memory artifactPath, bytes memory constructorArgs, bytes32 salt)
        internal
        returns (address instance)
    {
        return deployCode({artifactPath: artifactPath, constructorArgs: constructorArgs, salt: salt, value: 0});
    }

    /// @notice Deploys a contract deterministically from a compiled artifact with constructor arguments and Ether.
    /// @dev Appends the ABI-encoded constructor arguments to the artifact creation bytecode and deploys the resulting
    ///      init code using CREATE2 while forwarding the specified amount.
    /// @param artifactPath The Foundry artifact identifier used to resolve creation bytecode.
    /// @param constructorArgs The ABI-encoded constructor arguments appended to the creation bytecode.
    /// @param salt The CREATE2 deployment salt.
    /// @param value The amount of Ether forwarded during contract creation.
    /// @return instance The deployed contract address.
    function deployCode(string memory artifactPath, bytes memory constructorArgs, bytes32 salt, uint256 value)
        internal
        returns (address instance)
    {
        return _deployCode(bytes.concat(vm.getCode(artifactPath), constructorArgs), value, salt, true);
    }

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

    /// @notice Returns the address stored in an ERC1967 implementation slot.
    /// @dev Performs a raw storage read through Foundry and does not validate
    ///      either the target or the stored address.
    /// @param proxy The address whose ERC1967 implementation slot is read.
    /// @return implementation The address encoded in the implementation slot.
    function getImplementation(address proxy) internal view returns (address implementation) {
        return address(uint160(uint256(vm.load(proxy, IMPLEMENTATION_SLOT))));
    }

    /// @notice Returns the address stored in an ERC1967 admin slot.
    /// @dev Performs a raw storage read and does not prove that the
    ///      stored address represents operative administrative authority.
    /// @param proxy The address whose ERC1967 admin slot is read.
    /// @return admin The address encoded in the admin slot.
    function getAdmin(address proxy) internal view returns (address admin) {
        return address(uint160(uint256(vm.load(proxy, ADMIN_SLOT))));
    }

    /// @notice Returns the address stored in an ERC1967 beacon slot.
    /// @dev Performs a raw storage read and does not prove that the
    ///      target dynamically consults the stored beacon.
    /// @param proxy The address whose ERC1967 beacon slot is read.
    /// @return beacon The address encoded in the beacon slot.
    function getBeacon(address proxy) internal view returns (address beacon) {
        return address(uint160(uint256(vm.load(proxy, BEACON_SLOT))));
    }

    /// @notice Returns the implementation address reported by a beacon.
    /// @dev Calls `implementation()` on the beacon and bubbles downstream revert data on failure.
    /// @param beacon The beacon whose implementation getter is called.
    /// @return implementation The implementation address reported by the beacon.
    function getBeaconImplementation(address beacon) internal view returns (address implementation) {
        assembly ("memory-safe") {
            mstore(0x00, 0x5c60da1b) // implementation()

            if iszero(staticcall(gas(), beacon, 0x1c, 0x04, 0x00, 0x20)) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0x00, returndatasize())
                revert(ptr, returndatasize())
            }

            implementation := mload(0x00)
        }
    }

    /// @notice Returns the upgrade interface version reported by an upgrade interface contract.
    /// @dev Calls `UPGRADE_INTERFACE_VERSION()` and returns the decoded version string when the
    ///      response has the expected ABI layout. Returns an empty string otherwise.
    /// @param upgradeInterface The address whose upgrade interface version getter is called.
    /// @return version The upgrade interface version reported by the contract.
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

    /*//////////////////////////////////////////////////////////////////////////
                                    VALIDATION
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Verifies that an ERC1967 implementation slot contains an expected address.
    /// @param proxy The proxy whose implementation slot is inspected.
    /// @param expected The expected implementation address.
    function validateImplementation(address proxy, address expected) internal view {
        address actual = getImplementation(proxy);
        if (actual != expected) revert ImplementationMismatch(proxy, expected, actual);
    }

    /// @notice Verifies that an ERC1967 admin slot contains an expected address.
    /// @param proxy The proxy whose admin slot is inspected.
    /// @param expected The expected admin address.
    function validateAdmin(address proxy, address expected) internal view {
        address actual = getAdmin(proxy);
        if (actual != expected) revert AdminMismatch(proxy, expected, actual);
    }

    /// @notice Verifies that an ERC1967 beacon slot contains an expected address.
    /// @param proxy The proxy whose beacon slot is inspected.
    /// @param expected The expected beacon address.
    function validateBeacon(address proxy, address expected) internal view {
        address actual = getBeacon(proxy);
        if (actual != expected) revert BeaconMismatch(proxy, expected, actual);
    }

    /// @notice Verifies that a beacon reports an expected implementation address.
    /// @param beacon The beacon whose implementation is inspected.
    /// @param expected The expected implementation address.
    function validateBeaconImplementation(address beacon, address expected) internal view {
        address actual = getBeaconImplementation(beacon);
        if (actual != expected) revert BeaconImplementationMismatch(beacon, expected, actual);
    }

    /// @notice Verifies that an ownable contract reports an expected owner.
    /// @dev Calls the target's `owner()` getter and compares the returned address.
    /// @param target The ownable contract whose owner is inspected.
    /// @param expected The expected owner address.
    function validateOwner(address target, address expected) internal view {
        address actual = _getOwner(target);
        if (actual != expected) revert OwnerMismatch(target, expected, actual);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                PRIVATE INTERNALS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Deploys complete init code using CREATE or CREATE2 and forwards Ether.
    ///      Bubbles constructor revert data when available and reverts with
    ///      {DeploymentFailed} error when creation fails without revert data.
    /// @param initCode The complete contract init code, including constructor arguments.
    /// @param value The amount of Ether forwarded during contract creation.
    /// @param salt The CREATE2 salt when deterministic deployment is selected.
    /// @param useDeterministic Whether to deploy using CREATE2 instead of CREATE.
    /// @return instance The deployed contract address.
    function _deployCode(bytes memory initCode, uint256 value, bytes32 salt, bool useDeterministic)
        private
        returns (address instance)
    {
        assembly ("memory-safe") {
            switch useDeterministic
            case 0x00 { instance := create(value, add(initCode, 0x20), mload(initCode)) }
            case 0x01 { instance := create2(value, add(initCode, 0x20), mload(initCode), salt) }

            if iszero(instance) {
                if iszero(returndatasize()) {
                    mstore(0x00, 0x30116425) // DeploymentFailed()
                    revert(0x1c, 0x04)
                }

                let ptr := mload(0x40)
                returndatacopy(ptr, 0x00, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }

    function _upgradeToAndCall(address proxy, address implementation, bytes memory data, uint256 value) private {}

    function _upgradeAndCall(address admin, address proxy, address implementation, bytes memory data, uint256 value)
        private {}

    function _upgradeBeaconTo(address beacon, address implementation) private {}

    /// @dev Returns the owner reported by an ownable contract.
    ///      Calls `owner()` and bubbles downstream revert data on failure.
    /// @param target The contract whose owner getter is called.
    /// @return owner The owner address reported by the target.
    function _getOwner(address target) private view returns (address owner) {
        assembly ("memory-safe") {
            mstore(0x00, 0x8da5cb5b) // owner()

            if iszero(staticcall(gas(), target, 0x1c, 0x04, 0x00, 0x20)) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0x00, returndatasize())
                revert(ptr, returndatasize())
            }

            owner := mload(0x00)
        }
    }

    /// @dev Reverts if a target contains no runtime code.
    /// @param target The address expected to contain runtime code.
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
