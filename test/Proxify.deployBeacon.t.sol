// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Proxify} from "src/Proxify.sol";
import {ProxifyTest} from "test/Base.t.sol";

contract ProxifyDeployBeaconTest is ProxifyTest {
    address internal implementation;

    function setUp() public {
        implementation = vm.deployCode(GREETER_V1_PATH);
    }

    function test_deployBeacon_withExistingImplementation() public {
        address expected = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        address beacon = Proxify.deployBeacon(implementation, DEFAULT_SENDER);

        assertEq(beacon, expected);
        assertBeacon(beacon, implementation, DEFAULT_SENDER);
    }

    function test_deployBeacon_withExistingImplementationUsesSalt() public {
        address expected = computeBeaconAddress(implementation, DEFAULT_SENDER, DEFAULT_SALT);
        address beacon = Proxify.deployBeacon(implementation, DEFAULT_SENDER, DEFAULT_SALT);

        assertEq(beacon, expected);
        assertBeacon(beacon, implementation, DEFAULT_SENDER);
    }

    function test_deployBeacon_withArtifact() public {
        uint64 nonce = vm.getNonce(address(this));
        implementation = vm.computeCreateAddress(address(this), nonce);

        address expected = vm.computeCreateAddress(address(this), ++nonce);
        address beacon = Proxify.deployBeacon(GREETER_V1_PATH, DEFAULT_SENDER);

        assertEq(beacon, expected);
        assertBeacon(beacon, implementation, DEFAULT_SENDER);
    }

    function test_deployBeacon_withArtifactUsesSalt() public {
        implementation = computeCreate2Address(GREETER_V1_PATH, DEFAULT_SALT);

        address expected = computeBeaconAddress(implementation, DEFAULT_SENDER, DEFAULT_SALT);
        address beacon = Proxify.deployBeacon(GREETER_V1_PATH, DEFAULT_SENDER, DEFAULT_SALT);

        assertEq(beacon, expected);
        assertBeacon(beacon, implementation, DEFAULT_SENDER);
    }

    function test_deployBeaconProxy_bubblesInitializerRevert() public {
        vm.expectRevert(bytes4(keccak256("FailedCall()")));
        bytes memory data = encodeInitializerData(address(0), "FailedCall");
        Proxify.deployTransparentProxy(implementation, DEFAULT_SENDER, data, DEFAULT_SALT);
    }

    function test_deployBeacon_revertsOnCreate2Collision() public {
        assertContract(Proxify.deployBeacon(implementation, DEFAULT_SENDER, DEFAULT_SALT));

        vm.expectRevert();
        Proxify.deployBeacon(implementation, DEFAULT_SENDER, DEFAULT_SALT);
    }

    function test_deployBeacon_revertsWhenInvalidImplementationReceived() public {
        implementation = vm.deployCode("EmptyRuntime.sol:EmptyRuntime");

        vm.expectRevert(abi.encodeWithSignature("BeaconInvalidImplementation(address)", implementation = address(0)));
        Proxify.deployBeacon(implementation, DEFAULT_SENDER, DEFAULT_SALT);
    }

    function test_deployBeacon_revertsWhenInvalidOwnerReceived() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableInvalidOwner(address)", address(0)));
        Proxify.deployBeacon(implementation, address(0), DEFAULT_SALT);
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

        implementation = computeCreate2Address(GREETER_V1_PATH, salt);

        address expected = computeBeaconAddress(implementation, beaconOwner, salt);
        address beacon = Proxify.deployBeacon(GREETER_V1_PATH, beaconOwner, salt);

        assertEq(beacon, expected);
        assertBeacon(beacon, implementation, beaconOwner);
    }
}
