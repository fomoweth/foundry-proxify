// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Proxify} from "src/Proxify.sol";
import {ProxifyTestBase} from "test/Base.t.sol";

contract ProxifyInspectionTest is ProxifyTestBase {
    string internal constant defaultGreeting = "hello";
    address internal constant defaultOwner = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;

    address internal implementation;
    address internal implementationProxiable;

    function setUp() public {
        implementation = Proxify.deployCode(GREETER_V1_PATH);
        implementationProxiable = Proxify.deployCode(GREETER_V1_PROXIABLE_PATH);
    }

    function test_getImplementation() public {
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        address proxy = Proxify.deployUUPSProxy(implementationProxiable, data);
        assertEq(Proxify.getImplementation(proxy), implementationProxiable);
    }

    function test_getAdmin() public {
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        address proxy = Proxify.deployTransparentProxy(implementation, address(this), data);
        address admin = vm.computeCreateAddress(proxy, 1);

        assertEq(Proxify.getAdmin(proxy), admin);
    }

    function test_getBeacon() public {
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        address beacon = Proxify.deployBeacon(implementation, address(this));
        address proxy = Proxify.deployBeaconProxy(beacon, data);

        assertEq(Proxify.getBeacon(proxy), beacon);
    }

    function test_getBeaconImplementation() public {
        address beacon = Proxify.deployBeacon(implementation, address(this));
        assertEq(Proxify.getBeaconImplementation(beacon), implementation);
    }

    function test_getBeaconImplementation_bubblesDownstreamRevert() public {
        address beacon = Proxify.deployCode("Observers.sol:ImplementationReverter");

        vm.expectRevert(bytes4(keccak256("ImplementationError()")));
        Proxify.getBeaconImplementation(beacon);
    }

    function test_getUpgradeInterfaceVersion() public {
        address upgradeInterface = Proxify.deployCode("UpgradeInterfaceVersions.sol:UpgradeInterfaceVersion");
        assertEq(Proxify.getUpgradeInterfaceVersion(upgradeInterface), "5.0.0");
    }

    function test_getUpgradeInterfaceVersion_empty() public {
        address upgradeInterface = Proxify.deployCode("UpgradeInterfaceVersions.sol:UpgradeInterfaceVersionEmpty");
        assertEq(Proxify.getUpgradeInterfaceVersion(upgradeInterface), "");
    }

    function test_getUpgradeInterfaceVersion_integer() public {
        address upgradeInterface = Proxify.deployCode("UpgradeInterfaceVersions.sol:UpgradeInterfaceVersionInteger");
        assertEq(Proxify.getUpgradeInterfaceVersion(upgradeInterface), "");
    }

    function test_getUpgradeInterfaceVersion_void() public {
        address upgradeInterface = Proxify.deployCode("UpgradeInterfaceVersions.sol:UpgradeInterfaceVersionVoid");
        assertEq(Proxify.getUpgradeInterfaceVersion(upgradeInterface), "");
    }

    function test_getUpgradeInterfaceVersion_noGetter() public {
        address upgradeInterface = Proxify.deployCode("UpgradeInterfaceVersions.sol:UpgradeInterfaceVersionNoGetter");
        assertEq(Proxify.getUpgradeInterfaceVersion(upgradeInterface), "");
    }

    function test_getUpgradeInterfaceVersion_malformed() public {
        address upgradeInterface = Proxify.deployCode("UpgradeInterfaceVersions.sol:UpgradeInterfaceVersionMalformed");
        assertEq(Proxify.getUpgradeInterfaceVersion(upgradeInterface), "");
    }
}
