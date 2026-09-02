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

    /// @notice Deploys a UUPS proxy backed by an existing implementation.
    /// @dev Deploys an OpenZeppelin Contracts v5-compatible ERC1967 proxy using CREATE and verifies
    ///      the resulting ERC1967 implementation slot. This function does not independently verify
    ///      that the initial implementation exposes a valid UUPS upgrade mechanism.
    /// @param implementation The initial implementation address.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @return proxy The deployed proxy address.
    function deployUUPSProxy(address implementation, bytes memory initializerData) internal returns (address proxy) {
        return deployUUPSProxy({implementation: implementation, initializerData: initializerData, value: 0});
    }

    /// @notice Deploys a UUPS proxy backed by an existing implementation and forwards Ether during initialization.
    /// @dev Deploys an OpenZeppelin Contracts v5-compatible ERC1967 proxy using CREATE and verifies
    ///      the resulting ERC1967 implementation slot. This function does not independently verify
    ///      that the initial implementation exposes a valid UUPS upgrade mechanism.
    /// @param implementation The initial implementation address.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @param value The amount of Ether forwarded during proxy construction.
    /// @return proxy The deployed proxy address.
    function deployUUPSProxy(address implementation, bytes memory initializerData, uint256 value)
        internal
        returns (address proxy)
    {
        proxy = deployCode({
            artifactPath: "ERC1967Proxy.sol:ERC1967Proxy",
            constructorArgs: abi.encode(implementation, initializerData),
            value: value
        });
        validateImplementation(proxy, implementation);
    }

    /// @notice Deploys a UUPS proxy deterministically around an existing implementation.
    /// @dev Deploys an OpenZeppelin Contracts v5-compatible ERC1967 proxy using CREATE2 and verifies
    ///      the resulting ERC1967 implementation slot.
    /// @param implementation The initial implementation address.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @param salt The CREATE2 deployment salt.
    /// @return proxy The deployed proxy address.
    function deployUUPSProxy(address implementation, bytes memory initializerData, bytes32 salt)
        internal
        returns (address proxy)
    {
        return deployUUPSProxy({implementation: implementation, initializerData: initializerData, salt: salt, value: 0});
    }

    /// @notice Deploys a UUPS proxy deterministically around an existing implementation and forwards Ether.
    /// @dev Deploys an OpenZeppelin Contracts v5-compatible ERC1967 proxy using CREATE2 and verifies
    ///      the resulting ERC1967 implementation slot.
    /// @param implementation The initial implementation address.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @param salt The CREATE2 deployment salt.
    /// @param value The amount of Ether forwarded during proxy construction.
    /// @return proxy The deployed proxy address.
    function deployUUPSProxy(address implementation, bytes memory initializerData, bytes32 salt, uint256 value)
        internal
        returns (address proxy)
    {
        proxy = deployCode({
            artifactPath: "ERC1967Proxy.sol:ERC1967Proxy",
            constructorArgs: abi.encode(implementation, initializerData),
            salt: salt,
            value: value
        });
        validateImplementation(proxy, implementation);
    }

    /// @notice Deploys an implementation from an artifact and creates a UUPS proxy backed by it.
    /// @dev Deploys the implementation using CREATE, then deploys an OpenZeppelin Contracts
    ///      v5-compatible ERC1967 proxy using CREATE.
    /// @param artifactPath The Foundry artifact identifier for the implementation contract.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @return proxy The deployed proxy address.
    function deployUUPSProxy(string memory artifactPath, bytes memory initializerData)
        internal
        returns (address proxy)
    {
        return deployUUPSProxy({artifactPath: artifactPath, initializerData: initializerData, value: 0});
    }

    /// @notice Deploys an implementation from an artifact and creates a UUPS proxy while forwarding Ether.
    /// @dev Deploys the implementation using CREATE, then deploys an OpenZeppelin Contracts
    ///      v5-compatible ERC1967 proxy using CREATE and forwards Ether only to the proxy deployment.
    /// @param artifactPath The Foundry artifact identifier for the implementation contract.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @param value The amount of Ether forwarded during proxy construction.
    /// @return proxy The deployed proxy address.
    function deployUUPSProxy(string memory artifactPath, bytes memory initializerData, uint256 value)
        internal
        returns (address proxy)
    {
        return deployUUPSProxy({
            implementation: deployCode(artifactPath), initializerData: initializerData, value: value
        });
    }

    /// @notice Deploys an implementation from an artifact and creates a UUPS proxy backed by it.
    /// @dev Deploys the implementation using CREATE, then deploys an OpenZeppelin Contracts
    ///      v5-compatible ERC1967 proxy using CREATE.
    /// @param artifactPath The Foundry artifact identifier for the implementation contract.
    /// @param constructorArgs The ABI-encoded implementation constructor arguments.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @return proxy The deployed proxy address.
    function deployUUPSProxy(string memory artifactPath, bytes memory constructorArgs, bytes memory initializerData)
        internal
        returns (address proxy)
    {
        return deployUUPSProxy({
            artifactPath: artifactPath, constructorArgs: constructorArgs, initializerData: initializerData, value: 0
        });
    }

    /// @notice Deploys an implementation from an artifact and creates a UUPS proxy while forwarding Ether.
    /// @dev Deploys the implementation using CREATE, then deploys an OpenZeppelin Contracts
    ///      v5-compatible ERC1967 proxy using CREATE and forwards Ether only to the proxy deployment.
    /// @param artifactPath The Foundry artifact identifier for the implementation contract.
    /// @param constructorArgs The ABI-encoded implementation constructor arguments.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @param value The amount of Ether forwarded during proxy construction.
    /// @return proxy The deployed proxy address.
    function deployUUPSProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        uint256 value
    ) internal returns (address proxy) {
        return deployUUPSProxy({
            implementation: deployCode(artifactPath, constructorArgs), initializerData: initializerData, value: value
        });
    }

    /// @notice Deploys an implementation and UUPS proxy deterministically using a shared CREATE2 salt.
    /// @dev Deploys both contracts with the same salt. Their distinct init-code hashes produce
    ///      independently derived CREATE2 addresses.
    /// @param artifactPath The Foundry artifact identifier for the implementation contract.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @param salt The CREATE2 deployment salt used for both implementation and proxy deployment.
    /// @return proxy The deployed proxy address.
    function deployUUPSProxy(string memory artifactPath, bytes memory initializerData, bytes32 salt)
        internal
        returns (address proxy)
    {
        return deployUUPSProxy({artifactPath: artifactPath, initializerData: initializerData, salt: salt, value: 0});
    }

    /// @notice Deploys an implementation and UUPS proxy deterministically using a shared CREATE2 salt and forwards Ether.
    /// @dev Deploys both contracts with the same salt and forwards Ether only to the proxy deployment.
    /// @param artifactPath The Foundry artifact identifier for the implementation contract.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @param salt The CREATE2 deployment salt used for both implementation and proxy deployment.
    /// @param value The amount of Ether forwarded during proxy construction.
    /// @return proxy The deployed proxy address.
    function deployUUPSProxy(string memory artifactPath, bytes memory initializerData, bytes32 salt, uint256 value)
        internal
        returns (address proxy)
    {
        return deployUUPSProxy({
            implementation: deployCode(artifactPath, salt), initializerData: initializerData, salt: salt, value: value
        });
    }

    /// @notice Deploys an implementation and UUPS proxy deterministically using a shared CREATE2 salt.
    /// @dev Deploys both contracts with the same salt. Their distinct init-code hashes produce
    ///      independently derived CREATE2 addresses.
    /// @param artifactPath The Foundry artifact identifier for the implementation contract.
    /// @param constructorArgs The ABI-encoded implementation constructor arguments.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @param salt The CREATE2 deployment salt used for both implementation and proxy deployment.
    /// @return proxy The deployed proxy address.
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

    /// @notice Deploys an implementation and UUPS proxy deterministically using a shared CREATE2 salt and forwards Ether.
    /// @dev Deploys both contracts with the same salt and forwards Ether only to the proxy deployment.
    /// @param artifactPath The Foundry artifact identifier for the implementation contract.
    /// @param constructorArgs The ABI-encoded implementation constructor arguments.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @param salt The CREATE2 deployment salt used for both implementation and proxy deployment.
    /// @param value The amount of Ether forwarded during proxy construction.
    /// @return proxy The deployed proxy address.
    function deployUUPSProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal returns (address proxy) {
        return deployUUPSProxy({
            implementation: deployCode(artifactPath, constructorArgs, salt),
            initializerData: initializerData,
            salt: salt,
            value: value
        });
    }

    /// @notice Upgrades a UUPS proxy to an existing implementation and optionally executes initialization calldata.
    /// @dev Calls the OpenZeppelin Contracts v5-compatible `upgradeToAndCall(address,bytes)` entry point
    ///      with zero Ether and verifies the resulting ERC1967 implementation slot.
    /// @param proxy The UUPS proxy to upgrade.
    /// @param implementation The new implementation address.
    /// @param initializerData Complete calldata executed after the implementation update.
    function upgradeUUPSProxy(address proxy, address implementation, bytes memory initializerData) internal {
        upgradeUUPSProxy({proxy: proxy, implementation: implementation, initializerData: initializerData, value: 0});
    }

    /// @notice Upgrades a UUPS proxy to an existing implementation and forwards Ether during the upgrade call.
    /// @dev Calls the OpenZeppelin Contracts v5-compatible `upgradeToAndCall(address,bytes)` entry point
    ///      and verifies the resulting ERC1967 implementation slot.
    /// @param proxy The UUPS proxy to upgrade.
    /// @param implementation The new implementation address.
    /// @param initializerData Complete calldata executed after the implementation update.
    /// @param value The amount of Ether forwarded to the proxy upgrade call.
    function upgradeUUPSProxy(address proxy, address implementation, bytes memory initializerData, uint256 value)
        internal
    {
        _requireCode(proxy);
        _upgradeToAndCall(proxy, implementation, initializerData, value);
        validateImplementation(proxy, implementation);
    }

    /// @notice Deploys a new implementation from an artifact and upgrades a UUPS proxy to it.
    /// @dev Deploys the implementation using CREATE, then performs an OpenZeppelin Contracts
    ///      v5-compatible UUPS upgrade with zero Ether.
    /// @param proxy The UUPS proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation contract.
    /// @param initializerData Complete calldata executed after the implementation update.
    function upgradeUUPSProxy(address proxy, string memory artifactPath, bytes memory initializerData) internal {
        upgradeUUPSProxy({proxy: proxy, artifactPath: artifactPath, initializerData: initializerData, value: 0});
    }

    /// @notice Deploys a new implementation from an artifact and upgrades a UUPS proxy to it while forwarding Ether.
    /// @dev Deploys the implementation using CREATE, then forwards Ether to the UUPS upgrade call.
    /// @param proxy The UUPS proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation contract.
    /// @param initializerData Complete calldata executed after the implementation update.
    /// @param value The amount of Ether forwarded to the proxy upgrade call.
    function upgradeUUPSProxy(address proxy, string memory artifactPath, bytes memory initializerData, uint256 value)
        internal
    {
        upgradeUUPSProxy({
            proxy: proxy, implementation: deployCode(artifactPath), initializerData: initializerData, value: value
        });
    }

    /// @notice Deploys a new implementation from an artifact and upgrades a UUPS proxy to it.
    /// @dev Deploys the implementation using CREATE, then performs an OpenZeppelin Contracts
    ///      v5-compatible UUPS upgrade with zero Ether.
    /// @param proxy The UUPS proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation contract.
    /// @param constructorArgs The ABI-encoded implementation constructor arguments.
    /// @param initializerData Complete calldata executed after the implementation update.
    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData
    ) internal {
        upgradeUUPSProxy({
            proxy: proxy,
            artifactPath: artifactPath,
            constructorArgs: constructorArgs,
            initializerData: initializerData,
            value: 0
        });
    }

    /// @notice Deploys a new implementation from an artifact and upgrades a UUPS proxy to it while forwarding Ether.
    /// @dev Deploys the implementation using CREATE, then forwards Ether to the UUPS upgrade call.
    /// @param proxy The UUPS proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation contract.
    /// @param constructorArgs The ABI-encoded implementation constructor arguments.
    /// @param initializerData Complete calldata executed after the implementation update.
    /// @param value The amount of Ether forwarded to the proxy upgrade call.
    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        uint256 value
    ) internal {
        upgradeUUPSProxy({
            proxy: proxy,
            implementation: deployCode(artifactPath, constructorArgs),
            initializerData: initializerData,
            value: value
        });
    }

    /// @notice Deploys a new implementation deterministically and upgrades a UUPS proxy to it.
    /// @dev Deploys the implementation using CREATE2, then performs the UUPS upgrade with zero Ether.
    /// @param proxy The UUPS proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation contract.
    /// @param initializerData Complete calldata executed after the implementation update.
    /// @param salt The CREATE2 deployment salt used for the new implementation.
    function upgradeUUPSProxy(address proxy, string memory artifactPath, bytes memory initializerData, bytes32 salt)
        internal
    {
        upgradeUUPSProxy({
            proxy: proxy, artifactPath: artifactPath, initializerData: initializerData, salt: salt, value: 0
        });
    }

    /// @notice Deploys a new implementation deterministically and upgrades a UUPS proxy to it while forwarding Ether.
    /// @dev Deploys the implementation using CREATE2, then forwards Ether to the UUPS upgrade call.
    /// @param proxy The UUPS proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation contract.
    /// @param initializerData Complete calldata executed after the implementation update.
    /// @param salt The CREATE2 deployment salt used for the new implementation.
    /// @param value The amount of Ether forwarded to the proxy upgrade call.
    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal {
        upgradeUUPSProxy({
            proxy: proxy, implementation: deployCode(artifactPath, salt), initializerData: initializerData, value: value
        });
    }

    /// @notice Deploys a new implementation deterministically and upgrades a UUPS proxy to it.
    /// @dev Deploys the implementation using CREATE2, then performs the UUPS upgrade with zero Ether.
    /// @param proxy The UUPS proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation contract.
    /// @param constructorArgs The ABI-encoded implementation constructor arguments.
    /// @param initializerData Complete calldata executed after the implementation update.
    /// @param salt The CREATE2 deployment salt used for the new implementation.
    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        bytes32 salt
    ) internal {
        upgradeUUPSProxy({
            proxy: proxy,
            artifactPath: artifactPath,
            constructorArgs: constructorArgs,
            initializerData: initializerData,
            salt: salt,
            value: 0
        });
    }

    /// @notice Deploys a new implementation deterministically and upgrades a UUPS proxy to it while forwarding Ether.
    /// @dev Deploys the implementation using CREATE2, then forwards Ether to the UUPS upgrade call.
    /// @param proxy The UUPS proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation contract.
    /// @param constructorArgs The ABI-encoded implementation constructor arguments.
    /// @param initializerData Complete calldata executed after the implementation update.
    /// @param salt The CREATE2 deployment salt used for the new implementation.
    /// @param value The amount of Ether forwarded to the proxy upgrade call.
    function upgradeUUPSProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal {
        upgradeUUPSProxy({
            proxy: proxy,
            implementation: deployCode(artifactPath, constructorArgs, salt),
            initializerData: initializerData,
            value: value
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                TRANSPARENT PROXY
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Deploys a transparent proxy backed by an existing implementation.
    /// @dev Deploys an OpenZeppelin Contracts v5-compatible TransparentUpgradeableProxy using CREATE,
    ///      validates the associated ProxyAdmin and owner, and verifies the implementation slot.
    /// @param implementation The initial implementation address.
    /// @param initialOwner The initial owner assigned to the generated ProxyAdmin.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @return proxy The deployed transparent proxy address.
    function deployTransparentProxy(address implementation, address initialOwner, bytes memory initializerData)
        internal
        returns (address proxy)
    {
        return deployTransparentProxy({
            implementation: implementation, initialOwner: initialOwner, initializerData: initializerData, value: 0
        });
    }

    /// @notice Deploys a transparent proxy backed by an existing implementation and forwards Ether during initialization.
    /// @dev Deploys an OpenZeppelin Contracts v5-compatible TransparentUpgradeableProxy using CREATE,
    ///      validates the generated ProxyAdmin, and verifies the proxy's ERC1967 state.
    /// @param implementation The initial implementation address.
    /// @param initialOwner The initial owner assigned to the generated ProxyAdmin.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @param value The amount of Ether forwarded during proxy construction.
    /// @return proxy The deployed transparent proxy address.
    function deployTransparentProxy(
        address implementation,
        address initialOwner,
        bytes memory initializerData,
        uint256 value
    ) internal returns (address proxy) {
        proxy = deployCode({
            artifactPath: "TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy",
            constructorArgs: abi.encode(implementation, initialOwner, initializerData),
            value: value
        });

        address admin = vm.computeCreateAddress(proxy, 1);
        validateAdmin(proxy, admin);
        validateOwner(admin, initialOwner);
        validateImplementation(proxy, implementation);
    }

    /// @notice Deploys a transparent proxy deterministically around an existing implementation.
    /// @dev Uses CREATE2 for the proxy deployment and verifies the generated ProxyAdmin,
    ///      its owner, and the proxy's ERC1967 implementation and admin state.
    /// @param implementation The initial implementation address.
    /// @param initialOwner The initial owner assigned to the generated ProxyAdmin.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @param salt The CREATE2 deployment salt.
    /// @return proxy The deployed transparent proxy address.
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

    /// @notice Deploys a transparent proxy deterministically and forwards Ether during initialization.
    /// @dev Uses CREATE2 for the proxy deployment and verifies the generated ProxyAdmin,
    ///      its owner, and the proxy's ERC1967 implementation and admin state.
    /// @param implementation The initial implementation address.
    /// @param initialOwner The initial owner assigned to the generated ProxyAdmin.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @param salt The CREATE2 deployment salt.
    /// @param value The amount of Ether forwarded during proxy construction.
    /// @return proxy The deployed transparent proxy address.
    function deployTransparentProxy(
        address implementation,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal returns (address proxy) {
        proxy = deployCode({
            artifactPath: "TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy",
            constructorArgs: abi.encode(implementation, initialOwner, initializerData),
            salt: salt,
            value: value
        });

        address admin = vm.computeCreateAddress(proxy, 1);
        validateAdmin(proxy, admin);
        validateOwner(admin, initialOwner);
        validateImplementation(proxy, implementation);
    }

    /// @notice Deploys an implementation from an artifact and creates a transparent proxy backed by it.
    /// @dev Deploys the implementation and proxy using CREATE and assigns ownership of the generated
    ///      ProxyAdmin to the specified initial owner.
    /// @param artifactPath The Foundry artifact identifier for the implementation contract.
    /// @param initialOwner The initial owner assigned to the generated ProxyAdmin.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @return proxy The deployed transparent proxy address.
    function deployTransparentProxy(string memory artifactPath, address initialOwner, bytes memory initializerData)
        internal
        returns (address proxy)
    {
        return deployTransparentProxy({
            artifactPath: artifactPath, initialOwner: initialOwner, initializerData: initializerData, value: 0
        });
    }

    /// @notice Deploys an implementation from an artifact and creates a transparent proxy while forwarding Ether.
    /// @dev Deploys both implementation and proxy using CREATE and forwards Ether only to the proxy deployment.
    /// @param artifactPath The Foundry artifact identifier for the implementation contract.
    /// @param initialOwner The initial owner assigned to the generated ProxyAdmin.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @param value The amount of Ether forwarded during proxy construction.
    /// @return proxy The deployed transparent proxy address.
    function deployTransparentProxy(
        string memory artifactPath,
        address initialOwner,
        bytes memory initializerData,
        uint256 value
    ) internal returns (address proxy) {
        return deployTransparentProxy({
            implementation: deployCode(artifactPath),
            initialOwner: initialOwner,
            initializerData: initializerData,
            value: value
        });
    }

    /// @notice Deploys an implementation from an artifact and creates a transparent proxy backed by it.
    /// @dev Deploys the implementation and proxy using CREATE and assigns ownership of the generated
    ///      ProxyAdmin to the specified initial owner.
    /// @param artifactPath The Foundry artifact identifier for the implementation contract.
    /// @param constructorArgs The ABI-encoded implementation constructor arguments.
    /// @param initialOwner The initial owner assigned to the generated ProxyAdmin.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @return proxy The deployed transparent proxy address.
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

    /// @notice Deploys an implementation from an artifact and creates a transparent proxy while forwarding Ether.
    /// @dev Deploys both implementation and proxy using CREATE and forwards Ether only to the proxy deployment.
    /// @param artifactPath The Foundry artifact identifier for the implementation contract.
    /// @param constructorArgs The ABI-encoded implementation constructor arguments.
    /// @param initialOwner The initial owner assigned to the generated ProxyAdmin.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @param value The amount of Ether forwarded during proxy construction.
    /// @return proxy The deployed transparent proxy address.
    function deployTransparentProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        address initialOwner,
        bytes memory initializerData,
        uint256 value
    ) internal returns (address proxy) {
        return deployTransparentProxy({
            implementation: deployCode(artifactPath, constructorArgs),
            initialOwner: initialOwner,
            initializerData: initializerData,
            value: value
        });
    }

    /// @notice Deploys an implementation and transparent proxy deterministically using a shared CREATE2 salt.
    /// @dev Uses the same salt for implementation and proxy deployment and verifies the generated
    ///      ProxyAdmin and resulting ERC1967 proxy state.
    /// @param artifactPath The Foundry artifact identifier for the implementation contract.
    /// @param initialOwner The initial owner assigned to the generated ProxyAdmin.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @param salt The CREATE2 deployment salt used for both implementation and proxy deployment.
    /// @return proxy The deployed transparent proxy address.
    function deployTransparentProxy(
        string memory artifactPath,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt
    ) internal returns (address proxy) {
        return deployTransparentProxy({
            artifactPath: artifactPath,
            initialOwner: initialOwner,
            initializerData: initializerData,
            salt: salt,
            value: 0
        });
    }

    /// @notice Deploys an implementation and transparent proxy deterministically and forwards Ether during initialization.
    /// @dev Uses the same CREATE2 salt for both deployments and forwards Ether only to the proxy deployment.
    /// @param artifactPath The Foundry artifact identifier for the implementation contract.
    /// @param initialOwner The initial owner assigned to the generated ProxyAdmin.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @param salt The CREATE2 deployment salt used for both implementation and proxy deployment.
    /// @param value The amount of Ether forwarded during proxy construction.
    /// @return proxy The deployed transparent proxy address.
    function deployTransparentProxy(
        string memory artifactPath,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal returns (address proxy) {
        return deployTransparentProxy({
            implementation: deployCode(artifactPath, salt),
            initialOwner: initialOwner,
            initializerData: initializerData,
            salt: salt,
            value: value
        });
    }

    /// @notice Deploys an implementation and transparent proxy deterministically using a shared CREATE2 salt.
    /// @dev Uses the same salt for implementation and proxy deployment and verifies the generated
    ///      ProxyAdmin and resulting ERC1967 proxy state.
    /// @param artifactPath The Foundry artifact identifier for the implementation contract.
    /// @param constructorArgs The ABI-encoded implementation constructor arguments.
    /// @param initialOwner The initial owner assigned to the generated ProxyAdmin.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @param salt The CREATE2 deployment salt used for both implementation and proxy deployment.
    /// @return proxy The deployed transparent proxy address.
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

    /// @notice Deploys an implementation and transparent proxy deterministically and forwards Ether during initialization.
    /// @dev Uses the same CREATE2 salt for both deployments and forwards Ether only to the proxy deployment.
    /// @param artifactPath The Foundry artifact identifier for the implementation contract.
    /// @param constructorArgs The ABI-encoded implementation constructor arguments.
    /// @param initialOwner The initial owner assigned to the generated ProxyAdmin.
    /// @param initializerData Complete initialization calldata executed during proxy construction.
    /// @param salt The CREATE2 deployment salt used for both implementation and proxy deployment.
    /// @param value The amount of Ether forwarded during proxy construction.
    /// @return proxy The deployed transparent proxy address.
    function deployTransparentProxy(
        string memory artifactPath,
        bytes memory constructorArgs,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal returns (address proxy) {
        return deployTransparentProxy({
            implementation: deployCode(artifactPath, constructorArgs, salt),
            initialOwner: initialOwner,
            initializerData: initializerData,
            salt: salt,
            value: value
        });
    }

    /// @notice Upgrades a transparent proxy to an existing implementation and optionally executes initialization calldata.
    /// @dev Resolves the proxy's ERC1967 admin and calls the OpenZeppelin Contracts v5-compatible
    ///      ProxyAdmin `upgradeAndCall(address,address,bytes)` entry point with zero Ether.
    /// @param proxy The transparent proxy to upgrade.
    /// @param implementation The new implementation address.
    /// @param initializerData Complete calldata executed after the implementation update.
    function upgradeTransparentProxy(address proxy, address implementation, bytes memory initializerData) internal {
        upgradeTransparentProxy({
            proxy: proxy, implementation: implementation, initializerData: initializerData, value: 0
        });
    }

    /// @notice Upgrades a transparent proxy to an existing implementation and forwards Ether during the upgrade call.
    /// @dev Resolves and validates the proxy's ProxyAdmin, calls `upgradeAndCall`, and verifies
    ///      the resulting ERC1967 implementation slot.
    /// @param proxy The transparent proxy to upgrade.
    /// @param implementation The new implementation address.
    /// @param initializerData Complete calldata executed after the implementation update.
    /// @param value The amount of Ether forwarded to the ProxyAdmin upgrade call.
    function upgradeTransparentProxy(address proxy, address implementation, bytes memory initializerData, uint256 value)
        internal
    {
        _requireCode(proxy);
        address admin = getAdmin(proxy);
        _requireCode(admin);
        _upgradeAndCall(admin, proxy, implementation, initializerData, value);
        validateImplementation(proxy, implementation);
    }

    /// @notice Deploys a new implementation from an artifact and upgrades a transparent proxy to it.
    /// @dev Deploys the implementation using CREATE and performs the upgrade through the proxy's
    ///      OpenZeppelin Contracts v5-compatible ProxyAdmin.
    /// @param proxy The transparent proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation contract.
    /// @param initializerData Complete calldata executed after the implementation update.
    function upgradeTransparentProxy(address proxy, string memory artifactPath, bytes memory initializerData) internal {
        upgradeTransparentProxy({proxy: proxy, artifactPath: artifactPath, initializerData: initializerData, value: 0});
    }

    /// @notice Deploys a new implementation from an artifact and upgrades a transparent proxy while forwarding Ether.
    /// @dev Deploys the implementation using CREATE and forwards Ether to the ProxyAdmin upgrade call.
    /// @param proxy The transparent proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation contract.
    /// @param initializerData Complete calldata executed after the implementation update.
    /// @param value The amount of Ether forwarded to the ProxyAdmin upgrade call.
    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory initializerData,
        uint256 value
    ) internal {
        upgradeTransparentProxy({
            proxy: proxy, implementation: deployCode(artifactPath), initializerData: initializerData, value: value
        });
    }

    /// @notice Deploys a new implementation from an artifact and upgrades a transparent proxy to it.
    /// @dev Deploys the implementation using CREATE and performs the upgrade through the proxy's
    ///      OpenZeppelin Contracts v5-compatible ProxyAdmin.
    /// @param proxy The transparent proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation contract.
    /// @param constructorArgs The ABI-encoded implementation constructor arguments.
    /// @param initializerData Complete calldata executed after the implementation update.
    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData
    ) internal {
        upgradeTransparentProxy({
            proxy: proxy,
            artifactPath: artifactPath,
            constructorArgs: constructorArgs,
            initializerData: initializerData,
            value: 0
        });
    }

    /// @notice Deploys a new implementation from an artifact and upgrades a transparent proxy while forwarding Ether.
    /// @dev Deploys the implementation using CREATE and forwards Ether to the ProxyAdmin upgrade call.
    /// @param proxy The transparent proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation contract.
    /// @param constructorArgs The ABI-encoded implementation constructor arguments.
    /// @param initializerData Complete calldata executed after the implementation update.
    /// @param value The amount of Ether forwarded to the ProxyAdmin upgrade call.
    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        uint256 value
    ) internal {
        upgradeTransparentProxy({
            proxy: proxy,
            implementation: deployCode(artifactPath, constructorArgs),
            initializerData: initializerData,
            value: value
        });
    }

    /// @notice Deploys a new implementation deterministically and upgrades a transparent proxy to it.
    /// @dev Deploys the new implementation using CREATE2 and performs the upgrade through the
    ///      proxy's OpenZeppelin Contracts v5-compatible ProxyAdmin.
    /// @param proxy The transparent proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation contract.
    /// @param initializerData Complete calldata executed after the implementation update.
    /// @param salt The CREATE2 deployment salt used for the new implementation.
    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory initializerData,
        bytes32 salt
    ) internal {
        upgradeTransparentProxy({
            proxy: proxy, artifactPath: artifactPath, initializerData: initializerData, salt: salt, value: 0
        });
    }

    /// @notice Deploys a new implementation deterministically and upgrades a transparent proxy while forwarding Ether.
    /// @dev Deploys the new implementation using CREATE2 and forwards Ether to the ProxyAdmin upgrade call.
    /// @param proxy The transparent proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation contract.
    /// @param initializerData Complete calldata executed after the implementation update.
    /// @param salt The CREATE2 deployment salt used for the new implementation.
    /// @param value The amount of Ether forwarded to the ProxyAdmin upgrade call.
    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal {
        upgradeTransparentProxy({
            proxy: proxy, implementation: deployCode(artifactPath, salt), initializerData: initializerData, value: value
        });
    }

    /// @notice Deploys a new implementation deterministically and upgrades a transparent proxy to it.
    /// @dev Deploys the new implementation using CREATE2 and performs the upgrade through the
    ///      proxy's OpenZeppelin Contracts v5-compatible ProxyAdmin.
    /// @param proxy The transparent proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation contract.
    /// @param constructorArgs The ABI-encoded implementation constructor arguments.
    /// @param initializerData Complete calldata executed after the implementation update.
    /// @param salt The CREATE2 deployment salt used for the new implementation.
    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        bytes32 salt
    ) internal {
        upgradeTransparentProxy({
            proxy: proxy,
            artifactPath: artifactPath,
            constructorArgs: constructorArgs,
            initializerData: initializerData,
            salt: salt,
            value: 0
        });
    }

    /// @notice Deploys a new implementation deterministically and upgrades a transparent proxy while forwarding Ether.
    /// @dev Deploys the new implementation using CREATE2 and forwards Ether to the ProxyAdmin upgrade call.
    /// @param proxy The transparent proxy to upgrade.
    /// @param artifactPath The Foundry artifact identifier for the new implementation contract.
    /// @param constructorArgs The ABI-encoded implementation constructor arguments.
    /// @param initializerData Complete calldata executed after the implementation update.
    /// @param salt The CREATE2 deployment salt used for the new implementation.
    /// @param value The amount of Ether forwarded to the ProxyAdmin upgrade call.
    function upgradeTransparentProxy(
        address proxy,
        string memory artifactPath,
        bytes memory constructorArgs,
        bytes memory initializerData,
        bytes32 salt,
        uint256 value
    ) internal {
        upgradeTransparentProxy({
            proxy: proxy,
            implementation: deployCode(artifactPath, constructorArgs, salt),
            initializerData: initializerData,
            value: value
        });
    }

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
    ///      {DeploymentFailed} when creation fails without revert data.
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

    /// @dev Calls an OpenZeppelin Contracts v5-compatible UUPS `upgradeToAndCall(address,bytes)` entry point through the proxy.
    ///      Bubbles downstream revert data when available and reverts with {UpgradeFailed} when the call fails without revert data.
    /// @param proxy The UUPS proxy receiving the upgrade call.
    /// @param implementation The new implementation address.
    /// @param data Complete calldata executed after the implementation update.
    /// @param value The amount of Ether forwarded to the proxy call.
    function _upgradeToAndCall(address proxy, address implementation, bytes memory data, uint256 value) private {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, 0x4f1ef286) // upgradeToAndCall(address,bytes)
            mstore(add(ptr, 0x20), shr(0x60, shl(0x60, implementation)))
            mstore(add(ptr, 0x40), 0x40)

            let length := add(mload(data), 0x20)
            mcopy(add(ptr, 0x60), data, length)

            if iszero(call(gas(), proxy, value, add(ptr, 0x1c), add(length, 0x44), 0x00, 0x00)) {
                if iszero(returndatasize()) {
                    mstore(0x00, 0x55299b49) // UpgradeFailed()
                    revert(0x1c, 0x04)
                }

                returndatacopy(ptr, 0x00, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }

    /// @dev Calls an OpenZeppelin Contracts v5-compatible ProxyAdmin `upgradeAndCall(address,address,bytes)` entry point.
    ///      Bubbles downstream revert data when available and reverts with {UpgradeFailed} when the call fails without revert data.
    /// @param admin The ProxyAdmin receiving the upgrade call.
    /// @param proxy The transparent proxy being upgraded.
    /// @param implementation The new implementation address.
    /// @param data Complete calldata executed after the implementation update.
    /// @param value The amount of Ether forwarded to the ProxyAdmin call.
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
                if iszero(returndatasize()) {
                    mstore(0x00, 0x55299b49) // UpgradeFailed()
                    revert(0x1c, 0x04)
                }

                returndatacopy(ptr, 0x00, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }

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
