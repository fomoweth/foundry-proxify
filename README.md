# foundry-proxify

[![CI](https://github.com/fomoweth/foundry-proxify/actions/workflows/ci.yml/badge.svg)](https://github.com/fomoweth/foundry-proxify/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/Docs-online-blue)](https://fomoweth.github.io/foundry-proxify)
[![Solidity](https://img.shields.io/badge/Solidity-%5E0.8.25-2b247c)](https://docs.soliditylang.org/en/v0.8.25)
[![License: MIT](https://img.shields.io/badge/License-MIT-orange.svg)](https://opensource.org/licenses/MIT)

> Foundry-native utilities for deploying, upgrading, and inspecting ERC-1967 proxies.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
  - [UUPS Proxy](#uups-proxy)
  - [Transparent Proxy](#transparent-proxy)
  - [Beacon Proxy](#beacon-proxy)
  - [Deployment Inputs](#deployment-inputs)
  - [Inspection](#inspection)
  - [Validation](#validation)
  - [Testing Authorized Upgrades](#testing-authorized-upgrades)
- [Design Notes](#design-notes)
- [API Reference](#api-reference)
- [Development](#development)
- [License](#license)

## Overview

`Proxify` is a lightweight Solidity library for deploying, upgrading, and inspecting ERC-1967 proxy infrastructure directly from Foundry scripts and tests.

It supports the UUPS, transparent, and beacon proxy patterns provided by OpenZeppelin Contracts v5, with utilities for deploying implementations from Foundry artifacts, deterministic deployment through `CREATE2`, forwarding Ether during deployment and upgrades, and validating resulting proxy state.

`Proxify` is designed as a low-level deployment and management utility. It operates directly on OpenZeppelin proxy contracts and ERC-1967 state while leaving concerns such as storage-layout compatibility and initializer safety to the surrounding development workflow.

## Features

- **UUPS proxies** — Deploy and upgrade [`ERC1967Proxy`][oz-erc1967-proxy-url] infrastructure backed by [`UUPSUpgradeable`][oz-uups-upgradeable-url] implementations.
- **Transparent proxies** — Deploy and upgrade [`TransparentUpgradeableProxy`][oz-transparent-upgradeable-proxy-url] infrastructure managed through [`ProxyAdmin`][oz-proxy-admin-url].
- **Beacon proxies** — Deploy and upgrade [`UpgradeableBeacon`][oz-upgradeable-beacon-url] and [`BeaconProxy`][oz-beacon-proxy-url] infrastructure.
- **Artifact deployment** — Deploy implementations directly from Foundry artifacts, with optional constructor arguments.
- **Deterministic deployment** — Deploy implementations, proxies, and beacons through `CREATE2`.
- **Ether forwarding** — Forward `msg.value` during supported proxy deployments and upgrades.
- **Authorized upgrade testing** — Execute upgrades under an impersonated `msg.sender` in Foundry tests.
- **ERC-1967 inspection** — Read implementation, admin, and beacon state directly from ERC-1967 storage.
- **State validation** — Verify implementation, admin, beacon, beacon implementation, and ownership state.

## Requirements

- [Foundry](https://getfoundry.sh/)
- [OpenZeppelin Contracts v5][oz-contracts-url]
- Solidity `^0.8.25`
- Cancun EVM or later

> [!IMPORTANT]
> `foundry-proxify` requires the Cancun EVM or later because its low-level upgrade helpers use the `MCOPY` opcode.

## Installation

Install `foundry-proxify` as a Foundry dependency:

```bash
forge install fomoweth/foundry-proxify
```

Install OpenZeppelin Contracts v5 if it is not already available in your project:

```bash
forge install OpenZeppelin/openzeppelin-contracts
```

Add the following remapping to `foundry.toml` or `remappings.txt`:

```text
foundry-proxify/=lib/foundry-proxify/src/
```

Then import `Proxify`:

```solidity
import {Proxify} from "foundry-proxify/Proxify.sol";
```

> [!IMPORTANT]
> Artifact-backed deployments require read access to the Foundry artifact output directory. Grant access by adding the following configuration to `foundry.toml`:
>
> ```toml
> [profile.default]
> fs_permissions = [{ access = "read", path = "./out" }]
> ```

## Usage

### UUPS Proxy

#### Deploy

Deploy an `ERC1967Proxy` backed by an existing `UUPSUpgradeable` implementation:

```solidity
address proxy = Proxify.deployUUPSProxy(
    implementation,
    initializerData
);
```

Ether can be forwarded as `msg.value` during proxy construction:

```solidity
address proxy = Proxify.deployUUPSProxy(
    implementation,
    initializerData,
    value
);
```

#### Deploy from an Artifact

`Proxify` can deploy the implementation directly from a Foundry artifact before deploying the proxy:

```solidity
address proxy = Proxify.deployUUPSProxy(
    "MyImplementation.sol:MyImplementation",
    initializerData
);
```

Constructor arguments can be supplied separately from the proxy initializer data:

```solidity
address proxy = Proxify.deployUUPSProxy(
    "MyImplementation.sol:MyImplementation",
    abi.encode(constructorArg0, constructorArg1),
    initializerData
);
```

#### Deterministic Deployment

Pass a `bytes32` salt to deploy the proxy using `CREATE2`:

```solidity
address proxy = Proxify.deployUUPSProxy(
    implementation,
    initializerData,
    salt
);
```

Artifact-backed deployments can deterministically deploy both the implementation and proxy:

```solidity
address proxy = Proxify.deployUUPSProxy(
    "MyImplementation.sol:MyImplementation",
    constructorArgs,
    initializerData,
    salt
);
```

#### Upgrade

Upgrade an existing UUPS proxy to an already deployed implementation:

```solidity
Proxify.upgradeUUPSProxy(
    proxy,
    newImplementation,
    upgradeData
);
```

The upgrade is performed through [`UUPSUpgradeable.upgradeToAndCall`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/1f2665e8d52677fd61f8daedc41ca77e1c64259d/contracts/proxy/utils/UUPSUpgradeable.sol#L88) and is subject to the authorization logic of the current implementation.

A new implementation can also be deployed directly from an artifact before performing the upgrade:

```solidity
Proxify.upgradeUUPSProxy(
    proxy,
    "MyImplementationV2.sol:MyImplementationV2",
    upgradeData
);
```

Constructor arguments, `CREATE2` deployment, and Ether forwarding are available through the corresponding overloads.

### Transparent Proxy

#### Deploy

Deploy a `TransparentUpgradeableProxy` backed by an existing implementation:

```solidity
address proxy = Proxify.deployTransparentProxy(
    implementation,
    initialOwner,
    initializerData
);
```

OpenZeppelin Contracts v5 creates a dedicated `ProxyAdmin` during proxy construction. `initialOwner` becomes the owner of that `ProxyAdmin`.

Ether can be forwarded as `msg.value` during proxy construction:

```solidity
address proxy = Proxify.deployTransparentProxy(
    implementation,
    initialOwner,
    initializerData,
    value
);
```

#### Deploy from an Artifact

`Proxify` can deploy the implementation directly from a Foundry artifact before deploying the proxy:

```solidity
address proxy = Proxify.deployTransparentProxy(
    "MyImplementation.sol:MyImplementation",
    initialOwner,
    initializerData
);
```

Constructor arguments can be supplied separately from the proxy initializer data:

```solidity
address proxy = Proxify.deployTransparentProxy(
    "MyImplementation.sol:MyImplementation",
    constructorArgs,
    initialOwner,
    initializerData
);
```

#### Deterministic Deployment

Pass a `bytes32` salt to deploy the proxy using `CREATE2`:

```solidity
address proxy = Proxify.deployTransparentProxy(
    implementation,
    initialOwner,
    initializerData,
    salt
);
```

Artifact-backed deployments can deterministically deploy both the implementation and proxy:

```solidity
address proxy = Proxify.deployTransparentProxy(
    "MyImplementation.sol:MyImplementation",
    constructorArgs,
    initialOwner,
    initializerData,
    salt
);
```

#### Upgrade

Upgrade an existing transparent proxy to an already deployed implementation:

```solidity
Proxify.upgradeTransparentProxy(
    proxy,
    newImplementation,
    upgradeData
);
```

The upgrade is performed through [`ProxyAdmin.upgradeAndCall`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/1f2665e8d52677fd61f8daedc41ca77e1c64259d/contracts/proxy/transparent/ProxyAdmin.sol#L38) on the `ProxyAdmin` associated with the proxy and is subject to its ownership authorization.

A new implementation can also be deployed directly from an artifact before performing the upgrade:

```solidity
Proxify.upgradeTransparentProxy(
    proxy,
    "MyImplementationV2.sol:MyImplementationV2",
    upgradeData
);
```

Constructor arguments, `CREATE2` deployment, and Ether forwarding are available through the corresponding overloads.

### Beacon Proxy

#### Deploy a Beacon

Deploy an `UpgradeableBeacon` backed by an existing implementation:

```solidity
address beacon = Proxify.deployBeacon(
    implementation,
    initialOwner
);
```

`initialOwner` becomes the owner of the deployed beacon.

#### Deploy a Beacon Proxy

Deploy a `BeaconProxy` backed by an existing beacon:

```solidity
address proxy = Proxify.deployBeaconProxy(
    beacon,
    initializerData
);
```

Ether can be forwarded as `msg.value` during proxy construction:

```solidity
address proxy = Proxify.deployBeaconProxy(
    beacon,
    initializerData,
    value
);
```

#### Deploy from an Artifact

`Proxify` can deploy an implementation directly from a Foundry artifact before deploying a beacon:

```solidity
address beacon = Proxify.deployBeacon(
    "MyImplementation.sol:MyImplementation",
    initialOwner
);
```

Constructor arguments can be supplied when deploying the implementation:

```solidity
address beacon = Proxify.deployBeacon(
    "MyImplementation.sol:MyImplementation",
    constructorArgs,
    initialOwner
);
```

`Proxify` can also deploy the complete beacon proxy stack from an artifact:

```solidity
address proxy = Proxify.deployBeaconProxy(
    "MyImplementation.sol:MyImplementation",
    initialOwner,
    initializerData
);
```

Constructor arguments can be supplied separately from the proxy initializer data:

```solidity
address proxy = Proxify.deployBeaconProxy(
    "MyImplementation.sol:MyImplementation",
    constructorArgs,
    initialOwner,
    initializerData
);
```

The resulting deployment topology is:

```text
Implementation
      ↑
UpgradeableBeacon
      ↑
  BeaconProxy
```

#### Deterministic Deployment

Pass a `bytes32` salt to deploy a beacon or beacon proxy using `CREATE2`:

```solidity
address beacon = Proxify.deployBeacon(
    implementation,
    initialOwner,
    salt
);
```

```solidity
address proxy = Proxify.deployBeaconProxy(
    beacon,
    initializerData,
    salt
);
```

Artifact-backed deployments can deterministically deploy the implementation, beacon, and proxy:

```solidity
address proxy = Proxify.deployBeaconProxy(
    "MyImplementation.sol:MyImplementation",
    constructorArgs,
    initialOwner,
    initializerData,
    salt
);
```

#### Upgrade a Beacon

Upgrade a beacon to an already deployed implementation:

```solidity
Proxify.upgradeBeacon(
    beacon,
    newImplementation
);
```

The upgrade is performed through [`UpgradeableBeacon.upgradeTo`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/1f2665e8d52677fd61f8daedc41ca77e1c64259d/contracts/proxy/beacon/UpgradeableBeacon.sol#L52) and is subject to beacon ownership authorization.

A new implementation can also be deployed directly from an artifact before upgrading the beacon:

```solidity
Proxify.upgradeBeacon(
    beacon,
    "MyImplementationV2.sol:MyImplementationV2"
);
```

Constructor arguments and `CREATE2` deployment are available through the corresponding overloads.

> [!IMPORTANT]
> Upgrading a beacon changes the implementation used by every `BeaconProxy` that references it.

### Deployment Inputs

`Proxify` deployment functions accept inputs for resolving implementations, configuring implementation construction, and initializing newly deployed proxies.

#### Artifact Identifiers

Functions accepting `artifactPath` can deploy implementations directly from Foundry artifacts.

Supported contract identifier formats include:

```text
"MyContract.sol:MyContract"
"MyContract"
"MyContract.sol:0.8.25"
"MyContract:0.8.25"
```

Project-relative artifact paths are also supported.

#### Constructor Arguments

When an implementation requires constructor arguments, pass them as ABI-encoded `constructorArgs`:

```solidity
bytes memory constructorArgs = abi.encode(arg0, arg1);

address proxy = Proxify.deployUUPSProxy(
    "MyImplementation.sol:MyImplementation",
    constructorArgs,
    initializerData
);
```

`constructorArgs` are appended to the implementation creation code and configure the implementation deployment itself.

#### Initializer Data

Proxy deployments can execute initialization calldata against the implementation through the newly deployed proxy:

```solidity
bytes memory initializerData = abi.encodeCall(MyImplementation.initialize, (initialOwner));

address proxy = Proxify.deployUUPSProxy(
    implementation,
    initializerData
);
```

`initializerData` is passed to the proxy during construction and executed against the implementation through `delegatecall`, initializing proxy storage rather than implementation storage.

When no initialization call is required, empty bytes can be supplied if permitted by the underlying proxy:

```solidity
bytes memory initializerData = bytes("");
```

Whether empty `initializerData` is valid depends on the underlying proxy and deployment parameters. `Proxify` does not independently validate this condition and propagates any revert from the underlying proxy construction.

`initializerData` is separate from `constructorArgs`, which configure the implementation contract when its creation code is deployed.

### Inspection

Read the implementation stored in a proxy's ERC-1967 implementation slot:

```solidity
address implementation = Proxify.getImplementation(proxy);
```

Read the admin stored in a proxy's ERC-1967 admin slot:

```solidity
address admin = Proxify.getAdmin(proxy);
```

Read the beacon stored in a proxy's ERC-1967 beacon slot:

```solidity
address beacon = Proxify.getBeacon(proxy);
```

Read the implementation exposed by a beacon:

```solidity
address implementation = Proxify.getBeaconImplementation(beacon);
```

Inspect the upgrade interface version exposed by a proxy or admin:

```solidity
string memory version = Proxify.getUpgradeInterfaceVersion(target);
```

Inspection helpers are intentionally lightweight. They read the requested ERC-1967 storage slot or contract getter without attempting to determine whether the supplied address represents a valid proxy, implementation, admin, or beacon.

> [!NOTE]
> For OpenZeppelin Contracts v5 transparent proxies, `getAdmin` reads the ERC-1967 admin slot, which is inspection state rather than the authoritative source of upgrade authority.

### Validation

Validate proxy state against expected addresses:

```solidity
Proxify.validateImplementation(proxy, expectedImplementation);
Proxify.validateAdmin(proxy, expectedAdmin);
Proxify.validateBeacon(proxy, expectedBeacon);
```

Beacon implementation and ownership can be validated in the same way:

```solidity
Proxify.validateBeaconImplementation(beacon, expectedImplementation);
Proxify.validateOwner(target, expectedOwner);
```

Validation helpers compare the observed state against an expected value. They assert state equality rather than perform comprehensive proxy or upgrade-safety validation.

### Testing Authorized Upgrades

Upgrade overloads accepting `msgSender` are intended for Foundry tests that need to exercise authorization logic under a specific caller.

```solidity
Proxify.upgradeUUPSProxy(
    proxy,
    newImplementation,
    upgradeData,
    msgSender
);
```

These overloads attempt to impersonate `msgSender` as `msg.sender` while executing the upgrade.

The required authorization depends on the proxy type:

- **UUPS** — `msgSender` must satisfy the upgrade authorization enforced by the current implementation.
- **Transparent** — `msgSender` must be the owner of the associated `ProxyAdmin`.
- **Beacon** — `msgSender` must be the owner of the beacon.

Artifact-backed upgrade overloads support the same pattern:

```solidity
Proxify.upgradeUUPSProxy(
    proxy,
    "MyImplementationV2.sol:MyImplementationV2",
    upgradeData,
    msgSender
);
```

Corresponding overloads can also forward Ether as `msg.value` while executing the upgrade as `msgSender`.

The `msgSender` overloads are intended for tests rather than broadcast scripts. When broadcasting, configure the transaction sender through Foundry instead.

## Design Notes

### OpenZeppelin Contracts v5

`Proxify` targets the ERC-1967 proxy implementations provided by OpenZeppelin Contracts v5:

- [`ERC1967Proxy`][oz-erc1967-proxy-url] with [`UUPSUpgradeable`][oz-uups-upgradeable-url]
- [`TransparentUpgradeableProxy`][oz-transparent-upgradeable-proxy-url] with [`ProxyAdmin`][oz-proxy-admin-url]
- [`UpgradeableBeacon`][oz-upgradeable-beacon-url] with [`BeaconProxy`][oz-beacon-proxy-url]

Deployment, upgrade, and authorization behavior follows the corresponding OpenZeppelin Contracts v5 semantics.

### UUPS Compatibility

`deployUUPSProxy` deploys an `ERC1967Proxy` backed by the supplied implementation but does not independently verify that the implementation exposes a valid UUPS upgrade mechanism.

During an upgrade, UUPS compatibility is validated through OpenZeppelin's `UUPSUpgradeable` upgrade mechanism, including the ERC-1822 [`proxiableUUID`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/1f2665e8d52677fd61f8daedc41ca77e1c64259d/contracts/proxy/utils/UUPSUpgradeable.sol#L74) check. Upgrade authorization remains the responsibility of the current implementation.

### Transparent Proxy Administration

OpenZeppelin Contracts v5 creates a dedicated `ProxyAdmin` during `TransparentUpgradeableProxy` construction. The supplied `initialOwner` becomes the owner of that `ProxyAdmin`.

The effective admin is retained immutably by `TransparentUpgradeableProxy`. The ERC-1967 admin slot is maintained for compatibility and inspection, but it is not the authoritative source of upgrade authority.

`Proxify` follows the OpenZeppelin Contracts v5 construction semantics when interacting with the associated `ProxyAdmin`.

### Deterministic Deployment

`Proxify` provides `CREATE2` overloads for deterministic deployment of implementations, proxies, and beacons.

Artifact-backed deployments intentionally reuse the same salt across the contracts created as part of the operation:

```text
UUPS
Implementation
ERC1967Proxy

Transparent
Implementation
TransparentUpgradeableProxy

Beacon
Implementation
UpgradeableBeacon
BeaconProxy
```

`CREATE2` addresses are derived from the deployer, salt, and init code hash. Reusing a salt does not cause a collision as long as the resulting init code hashes differ.

Constructor arguments and proxy configuration are part of the corresponding init code and therefore affect deterministic addresses.

### Beacon Upgrades

An `UpgradeableBeacon` stores a single implementation address shared by every `BeaconProxy` that references it.

Upgrading a beacon therefore changes the implementation used by all associated beacon proxies. `Proxify` validates the resulting beacon implementation after an upgrade but does not perform per-proxy validation.

### Ether Forwarding

Deployment and upgrade overloads accepting `value` forward Ether as `msg.value` to the corresponding proxy construction or upgrade call.

OpenZeppelin Contracts v5 determines whether the forwarded value is valid for the requested operation. In particular, initialization or upgrade calldata must be compatible with receiving the forwarded value.

`Proxify` does not independently prevalidate these conditions and instead propagates the underlying revert when the operation is invalid.

### EVM Compatibility

`Proxify`'s low-level UUPS and transparent upgrade helpers use [`MCOPY` (EIP-5656)](https://eips.ethereum.org/EIPS/eip-5656) for direct memory-to-memory copying.

The execution environment must therefore support Cancun EVM or later.

## API Reference

The complete API reference, including all functions, overloads, and NatSpec documentation, is available in the generated documentation:

[View the API documentation](https://fomoweth.github.io/foundry-proxify)

Generate the documentation locally with:

```bash
forge doc
```

To generate and serve it locally:

```bash
forge doc --serve
```

## Development

Clone the repository and install its dependencies:

```bash
git clone https://github.com/fomoweth/foundry-proxify.git
cd foundry-proxify
forge install
```

Build the project:

```bash
forge build
```

Run the test suite:

```bash
forge test
```

Format the codebase:

```bash
forge fmt
```

## License

This project is licensed under the [MIT License](LICENSE).

[oz-contracts-url]: https://github.com/OpenZeppelin/openzeppelin-contracts/tree/1f2665e8d52677fd61f8daedc41ca77e1c64259d
[oz-erc1967-proxy-url]: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/1f2665e8d52677fd61f8daedc41ca77e1c64259d/contracts/proxy/ERC1967/ERC1967Proxy.sol
[oz-uups-upgradeable-url]: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/1f2665e8d52677fd61f8daedc41ca77e1c64259d/contracts/proxy/utils/UUPSUpgradeable.sol
[oz-transparent-upgradeable-proxy-url]: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/1f2665e8d52677fd61f8daedc41ca77e1c64259d/contracts/proxy/transparent/TransparentUpgradeableProxy.sol
[oz-proxy-admin-url]: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/1f2665e8d52677fd61f8daedc41ca77e1c64259d/contracts/proxy/transparent/ProxyAdmin.sol
[oz-upgradeable-beacon-url]: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/1f2665e8d52677fd61f8daedc41ca77e1c64259d/contracts/proxy/beacon/UpgradeableBeacon.sol
[oz-beacon-proxy-url]: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/1f2665e8d52677fd61f8daedc41ca77e1c64259d/contracts/proxy/beacon/BeaconProxy.sol
