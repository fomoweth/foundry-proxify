// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Proxify} from "src/Proxify.sol";
import {ProxifyTestBase} from "test/Base.t.sol";

contract ProxifyUpgradeBeaconTest is ProxifyTestBase {
    string internal constant defaultGreeting = "hello";
    address internal constant defaultOwner = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;
    uint256 internal constant defaultNumber = 42;
    uint256 internal constant defaultValue = 12 ether;
    bytes32 internal constant defaultSalt = keccak256("proxify-upgradeBeacon-salt");

    address internal proxy;
    address internal beacon;
    address internal implementationV1;
    address internal implementationV2;

    function setUp() public {
        implementationV1 = Proxify.deployCode(GREETER_V1_PATH);
        implementationV2 = Proxify.deployCode(GREETER_V2_PATH);

        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);
        beacon = Proxify.deployBeacon(implementationV1, address(this));
        proxy = Proxify.deployBeaconProxy(beacon, data);
    }

    function test_upgradeBeacon_withExistingImplementation() public {
        Proxify.upgradeBeacon(beacon, implementationV2);

        assertBeacon(beacon, implementationV2, address(this));
        assertGreeterV2(proxy, true);
    }

    function test_upgradeBeacon_withArtifact() public {
        implementationV2 = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));

        Proxify.upgradeBeacon(beacon, GREETER_V2_PATH);

        assertBeacon(beacon, implementationV2, address(this));
        assertGreeterV2(proxy, true);
    }

    function test_upgradeBeacon_withArtifactAndSalt() public {
        implementationV2 = computeCreate2Address(GREETER_V2_BYTECODE, defaultSalt);
        Proxify.upgradeBeacon(beacon, GREETER_V2_PATH, defaultSalt);

        assertBeacon(beacon, implementationV2, address(this));
        assertGreeterV2(proxy, true);
    }

    function test_upgradeBeacon_bubblesDownstreamRevert() public {
        beacon = Proxify.deployBeacon(implementationV1, defaultOwner);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(this)));
        this.upgradeBeacon(implementationV2);
    }

    function test_upgradeBeacon_revertsWhenTargetHasNoCode() public {
        beacon = Proxify.deployCode("Observers.sol:EmptyRuntime");
        vm.expectRevert(abi.encodeWithSelector(Proxify.EmptyCode.selector, beacon));
        this.upgradeBeacon(implementationV2);
    }

    function test_upgradeBeacon_revertsWithUpgradeFailedWhenCallRevertsWithoutData() public {
        beacon = Proxify.deployCode("Observers.sol:EmptyRevert");

        vm.expectRevert(Proxify.UpgradeFailed.selector);
        this.upgradeBeacon(implementationV2);
    }

    function test_fuzz_upgradeBeacon_artifactUsesSalt(bytes32 salt) public {
        implementationV2 = computeCreate2Address(GREETER_V2_BYTECODE, salt);
        Proxify.upgradeBeacon(beacon, GREETER_V2_PATH, salt);

        assertBeacon(beacon, implementationV2, address(this));
        assertGreeterV2(proxy, true);
    }

    function upgradeBeacon(address implementation) external {
        Proxify.upgradeBeacon(beacon, implementation);
    }
}
