// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Proxify} from "src/Proxify.sol";
import {ProxifyTest} from "test/Base.t.sol";

contract ProxifyUpgradeBeaconTest is ProxifyTest {
    address internal proxy;
    address internal beacon;
    address internal implementationV1;
    address internal implementationV2;

    function setUp() public {
        implementationV1 = vm.deployCode(GREETER_V1_PATH);
        implementationV2 = vm.deployCode(GREETER_V2_PATH);

        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);
        beacon = Proxify.deployBeacon(implementationV1, DEFAULT_SENDER);
        proxy = Proxify.deployBeaconProxy(beacon, data);
    }

    function test_upgradeBeacon_withExistingImplementation() public {
        Proxify.upgradeBeacon(beacon, implementationV2, DEFAULT_SENDER);

        assertBeacon(beacon, implementationV2, DEFAULT_SENDER);
        assertGreeterV2(proxy);
    }

    function test_upgradeBeacon_withArtifact() public {
        implementationV2 = vm.computeCreateAddress(DEFAULT_SENDER, vm.getNonce(DEFAULT_SENDER));
        Proxify.upgradeBeacon(beacon, GREETER_V2_PATH, DEFAULT_SENDER);

        assertBeacon(beacon, implementationV2, DEFAULT_SENDER);
        assertGreeterV2(proxy);
    }

    function test_upgradeBeacon_withArtifactAndSalt() public {
        implementationV2 = computeCreate2Address(GREETER_V2_PATH, DEFAULT_SALT, DEFAULT_SENDER);
        Proxify.upgradeBeacon(beacon, GREETER_V2_PATH, DEFAULT_SALT, DEFAULT_SENDER);

        assertBeacon(beacon, implementationV2, DEFAULT_SENDER);
        assertGreeterV2(proxy);
    }

    function test_upgradeBeacon_bubblesDownstreamRevert() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(this)));
        this.upgradeBeacon(implementationV2);
    }

    function test_upgradeBeacon_revertsWhenTargetHasNoCode() public {
        beacon = vm.deployCode("EmptyRuntime.sol:EmptyRuntime");
        vm.expectRevert(abi.encodeWithSelector(Proxify.EmptyCode.selector, beacon));
        Proxify.upgradeBeacon(beacon, implementationV2);
    }

    function test_fuzz_upgradeBeacon_artifactUsesSalt(bytes32 salt) public {
        implementationV2 = computeCreate2Address(GREETER_V2_PATH, salt, DEFAULT_SENDER);
        Proxify.upgradeBeacon(beacon, GREETER_V2_PATH, salt, DEFAULT_SENDER);

        assertBeacon(beacon, implementationV2, DEFAULT_SENDER);
        assertGreeterV2(proxy);
    }

    function upgradeBeacon(address implementation) external {
        Proxify.upgradeBeacon(beacon, implementation);
    }
}
