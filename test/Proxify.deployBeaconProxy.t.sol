// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Proxify} from "src/Proxify.sol";
import {ProxifyTestBase} from "test/Base.t.sol";

contract ProxifyDeployBeaconProxyTest is ProxifyTestBase {
    string internal constant defaultGreeting = "hello";
    address internal constant defaultOwner = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;
    uint256 internal constant defaultValue = 12 ether;
    bytes32 internal constant defaultSalt = keccak256("proxify-upgradeBeaconProxy-salt");

    address internal implementation;

    function setUp() public {
        implementation = Proxify.deployCode(GREETER_V1_PATH);
    }

    function test_deployBeacon_withExistingImplementation() public {
        address beaconOwner = address(this);

        address expected = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        address beacon = Proxify.deployBeacon(implementation, beaconOwner);

        assertEq(beacon, expected);
        assertBeacon(beacon, implementation, beaconOwner);
    }

    function test_deployBeacon_withExistingImplementationUsesSalt() public {
        address beaconOwner = address(this);

        address expected = computeBeaconAddress(implementation, beaconOwner, defaultSalt);
        address beacon = Proxify.deployBeacon(implementation, beaconOwner, defaultSalt);

        assertEq(beacon, expected);
        assertBeacon(beacon, implementation, beaconOwner);
    }

    function test_deployBeacon_withArtifact() public {
        address beaconOwner = address(this);

        uint64 nonce = vm.getNonce(address(this));
        implementation = vm.computeCreateAddress(address(this), nonce);

        address expected = vm.computeCreateAddress(address(this), ++nonce);
        address beacon = Proxify.deployBeacon(GREETER_V1_PATH, beaconOwner);

        assertEq(beacon, expected);
        assertBeacon(beacon, implementation, beaconOwner);
    }

    function test_deployBeacon_withArtifactUsesSalt() public {
        address beaconOwner = address(this);
        implementation = computeCreate2Address(GREETER_V1_BYTECODE, defaultSalt);

        address expected = computeBeaconAddress(implementation, beaconOwner, defaultSalt);
        address beacon = Proxify.deployBeacon(GREETER_V1_PATH, beaconOwner, defaultSalt);

        assertEq(beacon, expected);
        assertBeacon(beacon, implementation, beaconOwner);
    }

    function test_deployBeaconProxy_withExistingBeacon() public {
        address beaconOwner = address(this);
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        address beacon = Proxify.deployBeacon(implementation, beaconOwner);

        address expected = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        address proxy = Proxify.deployBeaconProxy(beacon, data);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, beaconOwner, 0);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployBeaconProxy_withExistingBeaconAndValue() public {
        address beaconOwner = address(this);
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        address beacon = Proxify.deployBeacon(implementation, beaconOwner);

        address expected = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        address proxy = Proxify.deployBeaconProxy(beacon, data, defaultValue);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, beaconOwner, defaultValue);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployBeaconProxy_withExistingBeaconUsesSalt() public {
        address beaconOwner = address(this);
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        address beacon = Proxify.deployBeacon(implementation, beaconOwner);

        address expected = computeBeaconProxyAddress(beacon, data, defaultSalt);
        address proxy = Proxify.deployBeaconProxy(beacon, data, defaultSalt);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, beaconOwner, 0);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployBeaconProxy_withExistingBeaconAndValueUsesSalt() public {
        address beaconOwner = address(this);
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        address beacon = Proxify.deployBeacon(implementation, beaconOwner);

        address expected = computeBeaconProxyAddress(beacon, data, defaultSalt);
        address proxy = Proxify.deployBeaconProxy(beacon, data, defaultSalt, defaultValue);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, beaconOwner, defaultValue);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployBeaconProxy_withArtifact() public {
        address beaconOwner = address(this);
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        uint64 nonce = vm.getNonce(address(this));
        implementation = vm.computeCreateAddress(address(this), nonce);
        address beacon = vm.computeCreateAddress(address(this), ++nonce);

        address expected = vm.computeCreateAddress(address(this), ++nonce);
        address proxy = Proxify.deployBeaconProxy(GREETER_V1_PATH, beaconOwner, data);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, beaconOwner, 0);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployBeaconProxy_withArtifactAndValue() public {
        address beaconOwner = address(this);
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        uint64 nonce = vm.getNonce(address(this));
        implementation = vm.computeCreateAddress(address(this), nonce);
        address beacon = vm.computeCreateAddress(address(this), ++nonce);

        address expected = vm.computeCreateAddress(address(this), ++nonce);
        address proxy = Proxify.deployBeaconProxy(GREETER_V1_PATH, beaconOwner, data, defaultValue);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, beaconOwner, defaultValue);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployBeaconProxy_withArtifactUsesSalt() public {
        address beaconOwner = address(this);
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        implementation = computeCreate2Address(GREETER_V1_BYTECODE, defaultSalt);
        address beacon = computeBeaconAddress(implementation, beaconOwner, defaultSalt);

        address expected = computeBeaconProxyAddress(beacon, data, defaultSalt);
        address proxy = Proxify.deployBeaconProxy(GREETER_V1_PATH, beaconOwner, data, defaultSalt);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, beaconOwner, 0);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployBeaconProxy_withArtifactAndValueUsesSalt() public {
        address beaconOwner = address(this);
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        implementation = computeCreate2Address(GREETER_V1_BYTECODE, defaultSalt);
        address beacon = computeBeaconAddress(implementation, beaconOwner, defaultSalt);

        address expected = computeBeaconProxyAddress(beacon, data, defaultSalt);
        address proxy = Proxify.deployBeaconProxy(GREETER_V1_PATH, beaconOwner, data, defaultSalt, defaultValue);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, beaconOwner, defaultValue);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployBeaconProxy_bubblesInitializerRevert() public {
        address beacon = Proxify.deployBeacon(implementation, address(this));

        vm.expectRevert(bytes4(keccak256("FailedCall()")));
        this.deployBeaconProxy(beacon, encodeInitializerData(address(0), "FailedCall"));
    }

    function test_deployBeaconProxy_revertsWithDeploymentFailedOnCreate2Collision() public {
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);
        address beacon = Proxify.deployBeacon(implementation, address(this));

        assertContract(Proxify.deployBeaconProxy(beacon, data, defaultSalt));

        vm.expectRevert(Proxify.DeploymentFailed.selector);
        this.deployBeaconProxyWithSalt(beacon, data, defaultSalt);
    }

    function test_fuzz_deployBeacon_withExistingImplementationUsesSalt(address beaconOwner, bytes32 salt) public {
        vm.assume(beaconOwner != address(0));

        address expected = computeBeaconAddress(implementation, beaconOwner, salt);
        address beacon = Proxify.deployBeacon(implementation, beaconOwner, salt);

        assertEq(beacon, expected);
        assertBeacon(beacon, implementation, beaconOwner);
    }

    function test_fuzz_deployBeacon_withArtifactUsesSalt(address beaconOwner, bytes32 salt) public {
        vm.assume(beaconOwner != address(0));

        implementation = computeCreate2Address(GREETER_V1_BYTECODE, salt);

        address expected = computeBeaconAddress(implementation, beaconOwner, salt);
        address beacon = Proxify.deployBeacon(GREETER_V1_PATH, beaconOwner, salt);

        assertEq(beacon, expected);
        assertBeacon(beacon, implementation, beaconOwner);
    }

    function test_fuzz_deployBeaconProxy_withExistingImplementationUsesSalt(
        address beaconOwner,
        address initialOwner,
        string memory initialGreeting,
        bytes32 salt
    ) public {
        vm.assume(beaconOwner != address(0) && initialOwner != address(0));

        bytes memory data = encodeInitializerData(initialOwner, initialGreeting);
        address beacon = Proxify.deployBeacon(implementation, beaconOwner);

        address expected = computeBeaconProxyAddress(beacon, data, salt);
        address proxy = Proxify.deployBeaconProxy(beacon, data, salt);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, beaconOwner, 0);
        assertGreeterV1(proxy, initialOwner, initialGreeting);
    }

    function test_fuzz_deployBeaconProxy_withArtifactUsesSalt(
        address beaconOwner,
        address initialOwner,
        string memory initialGreeting,
        bytes32 salt
    ) public {
        vm.assume(beaconOwner != address(0) && initialOwner != address(0));

        bytes memory data = encodeInitializerData(initialOwner, initialGreeting);

        implementation = computeCreate2Address(GREETER_V1_BYTECODE, salt);
        address beacon = computeBeaconAddress(implementation, beaconOwner, salt);

        address expected = computeBeaconProxyAddress(beacon, data, salt);
        address proxy = Proxify.deployBeaconProxy(GREETER_V1_PATH, beaconOwner, data, salt);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, beaconOwner, 0);
        assertGreeterV1(proxy, initialOwner, initialGreeting);
    }

    function test_fuzz_deployBeaconProxy_forwardsValue(uint256 value) public {
        value = bound(value, 0, 100 ether);

        address beaconOwner = address(this);
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);
        address beacon = Proxify.deployBeacon(implementation, beaconOwner);

        address expected = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        address proxy = Proxify.deployBeaconProxy(beacon, data, value);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, beaconOwner, value);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function deployBeaconProxy(address beacon, bytes calldata data) external returns (address) {
        return Proxify.deployBeaconProxy(beacon, data);
    }

    function deployBeaconProxyWithSalt(address beacon, bytes calldata data, bytes32 salt) external returns (address) {
        return Proxify.deployBeaconProxy(beacon, data, salt);
    }
}
