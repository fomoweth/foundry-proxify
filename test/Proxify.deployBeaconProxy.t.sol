// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Proxify} from "src/Proxify.sol";
import {ProxifyTest} from "test/Base.t.sol";

contract ProxifyDeployBeaconProxyTest is ProxifyTest {
    address internal beacon;
    address internal implementation;

    function setUp() public {
        implementation = vm.deployCode(GREETER_V1_PATH);
        beacon = Proxify.deployBeacon(implementation, DEFAULT_SENDER);
    }

    function test_deployBeaconProxy_withExistingBeacon() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        address expected = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        address proxy = Proxify.deployBeaconProxy(beacon, data);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, DEFAULT_SENDER, 0);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployBeaconProxy_withExistingBeaconAndValue() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        address expected = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        address proxy = Proxify.deployBeaconProxy(beacon, data, DEFAULT_VALUE);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, DEFAULT_SENDER, DEFAULT_VALUE);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployBeaconProxy_withExistingBeaconUsesSalt() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        address expected = computeBeaconProxyAddress(beacon, data, DEFAULT_SALT);
        address proxy = Proxify.deployBeaconProxy(beacon, data, DEFAULT_SALT);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, DEFAULT_SENDER, 0);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployBeaconProxy_withExistingBeaconAndValueUsesSalt() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        address expected = computeBeaconProxyAddress(beacon, data, DEFAULT_SALT);
        address proxy = Proxify.deployBeaconProxy(beacon, data, DEFAULT_SALT, DEFAULT_VALUE);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, DEFAULT_SENDER, DEFAULT_VALUE);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployBeaconProxy_withArtifact() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        uint64 nonce = vm.getNonce(address(this));
        implementation = vm.computeCreateAddress(address(this), nonce);
        beacon = vm.computeCreateAddress(address(this), ++nonce);

        address expected = vm.computeCreateAddress(address(this), ++nonce);
        address proxy = Proxify.deployBeaconProxy(GREETER_V1_PATH, DEFAULT_SENDER, data);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, DEFAULT_SENDER, 0);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployBeaconProxy_withArtifactAndValue() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        uint64 nonce = vm.getNonce(address(this));
        implementation = vm.computeCreateAddress(address(this), nonce);
        beacon = vm.computeCreateAddress(address(this), ++nonce);

        address expected = vm.computeCreateAddress(address(this), ++nonce);
        address proxy = Proxify.deployBeaconProxy(GREETER_V1_PATH, DEFAULT_SENDER, data, DEFAULT_VALUE);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, DEFAULT_SENDER, DEFAULT_VALUE);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployBeaconProxy_withArtifactUsesSalt() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        implementation = computeCreate2Address(GREETER_V1_PATH, DEFAULT_SALT);
        beacon = computeBeaconAddress(implementation, DEFAULT_SENDER, DEFAULT_SALT);

        address expected = computeBeaconProxyAddress(beacon, data, DEFAULT_SALT);
        address proxy = Proxify.deployBeaconProxy(GREETER_V1_PATH, DEFAULT_SENDER, data, DEFAULT_SALT);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, DEFAULT_SENDER, 0);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployBeaconProxy_withArtifactAndValueUsesSalt() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        implementation = computeCreate2Address(GREETER_V1_PATH, DEFAULT_SALT);
        beacon = computeBeaconAddress(implementation, DEFAULT_SENDER, DEFAULT_SALT);

        address expected = computeBeaconProxyAddress(beacon, data, DEFAULT_SALT);
        address proxy = Proxify.deployBeaconProxy(GREETER_V1_PATH, DEFAULT_SENDER, data, DEFAULT_SALT, DEFAULT_VALUE);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, DEFAULT_SENDER, DEFAULT_VALUE);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployBeaconProxy_bubblesInitializerRevert() public {
        vm.expectRevert(bytes4(keccak256("FailedCall()")));
        Proxify.deployBeaconProxy(beacon, encodeInitializerData(address(0), "FailedCall"), DEFAULT_SALT);
    }

    function test_deployBeaconProxy_revertsOnCreate2Collision() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);
        assertContract(Proxify.deployBeaconProxy(beacon, data, DEFAULT_SALT));

        vm.expectRevert();
        Proxify.deployBeaconProxy(beacon, data, DEFAULT_SALT);
    }

    function test_fuzz_deployBeaconProxy_withExistingImplementationUsesSalt(
        address beaconOwner,
        address initialOwner,
        string memory initialGreeting,
        bytes32 salt
    ) public {
        vm.assume(beaconOwner != address(0) && initialOwner != address(0));

        bytes memory data = encodeInitializerData(initialOwner, initialGreeting);
        beacon = Proxify.deployBeacon(implementation, beaconOwner, salt);

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

        implementation = computeCreate2Address(GREETER_V1_PATH, salt);
        beacon = computeBeaconAddress(implementation, beaconOwner, salt);

        address expected = computeBeaconProxyAddress(beacon, data, salt);
        address proxy = Proxify.deployBeaconProxy(GREETER_V1_PATH, beaconOwner, data, salt);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, beaconOwner, 0);
        assertGreeterV1(proxy, initialOwner, initialGreeting);
    }

    function test_fuzz_deployBeaconProxy_forwardsValue(uint256 value) public {
        value = bound(value, 0, 100 ether);

        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        address expected = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        address proxy = Proxify.deployBeaconProxy(beacon, data, value);

        assertEq(proxy, expected);
        assertBeaconProxy(proxy, beacon, implementation, DEFAULT_SENDER, value);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }
}
