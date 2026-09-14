// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Proxify} from "src/Proxify.sol";
import {ProxifyTest} from "test/Base.t.sol";

contract ProxifyUpgradeUUPSProxyTest is ProxifyTest {
    address internal proxy;
    address internal implementationV1;
    address internal implementationV2;

    function setUp() public {
        implementationV1 = vm.deployCode(GREETER_V1_PROXIABLE_PATH);
        implementationV2 = vm.deployCode(GREETER_V2_PROXIABLE_PATH);

        bytes memory data = encodeInitializerData(DEFAULT_SENDER, DEFAULT_GREETING);
        proxy = Proxify.deployUUPSProxy(implementationV1, data);
    }

    function test_upgradeUUPSProxy_withExistingImplementation() public {
        Proxify.upgradeUUPSProxy(proxy, implementationV2, encodeReinitializerData(), DEFAULT_SENDER);

        assertUUPSProxy(proxy, implementationV2, 0);
        assertGreeterV2(proxy);
    }

    function test_upgradeUUPSProxy_withExistingImplementationAndValue() public {
        bytes memory data = encodeReinitializerData();
        Proxify.upgradeUUPSProxy(proxy, implementationV2, data, DEFAULT_VALUE, DEFAULT_SENDER);

        assertUUPSProxy(proxy, implementationV2, DEFAULT_VALUE);
        assertGreeterV2(proxy);
    }

    function test_upgradeUUPSProxy_withArtifact() public {
        bytes memory data = encodeReinitializerData();

        implementationV2 = vm.computeCreateAddress(DEFAULT_SENDER, vm.getNonce(DEFAULT_SENDER));
        Proxify.upgradeUUPSProxy(proxy, GREETER_V2_PROXIABLE_PATH, data, DEFAULT_SENDER);

        assertUUPSProxy(proxy, implementationV2, 0);
        assertGreeterV2(proxy);
    }

    function test_upgradeUUPSProxy_withArtifactAndValue() public {
        bytes memory data = encodeReinitializerData();

        implementationV2 = vm.computeCreateAddress(DEFAULT_SENDER, vm.getNonce(DEFAULT_SENDER));
        Proxify.upgradeUUPSProxy(proxy, GREETER_V2_PROXIABLE_PATH, data, DEFAULT_VALUE, DEFAULT_SENDER);

        assertUUPSProxy(proxy, implementationV2, DEFAULT_VALUE);
        assertGreeterV2(proxy);
    }

    function test_upgradeUUPSProxy_withArtifactUsesSalt() public {
        bytes memory data = encodeReinitializerData();

        implementationV2 = computeCreate2Address(GREETER_V2_PROXIABLE_PATH, DEFAULT_SALT, DEFAULT_SENDER);
        Proxify.upgradeUUPSProxy(proxy, GREETER_V2_PROXIABLE_PATH, data, DEFAULT_SALT, DEFAULT_SENDER);

        assertUUPSProxy(proxy, implementationV2, 0);
        assertGreeterV2(proxy);
    }

    function test_upgradeUUPSProxy_withArtifactAndValueUsesSalt() public {
        bytes memory data = encodeReinitializerData();

        implementationV2 = computeCreate2Address(GREETER_V2_PROXIABLE_PATH, DEFAULT_SALT, DEFAULT_SENDER);
        Proxify.upgradeUUPSProxy(proxy, GREETER_V2_PROXIABLE_PATH, data, DEFAULT_SALT, DEFAULT_VALUE, DEFAULT_SENDER);

        assertUUPSProxy(proxy, implementationV2, DEFAULT_VALUE);
        assertGreeterV2(proxy);
    }

    function test_upgradeUUPSProxy_bubblesDownstreamRevert() public {
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        this.upgradeUUPSProxy(implementationV2, encodeReinitializerData());
    }

    function test_upgradeUUPSProxy_revertsWhenTargetHasNoCode() public {
        proxy = vm.deployCode("EmptyRuntime.sol:EmptyRuntime");
        vm.expectRevert(abi.encodeWithSelector(Proxify.EmptyCode.selector, proxy));
        Proxify.upgradeUUPSProxy(proxy, implementationV2, encodeReinitializerData());
    }

    function test_fuzz_upgradeUUPSProxy_withExistingImplementationAndValue(uint256 value) public {
        value = bound(value, 0, 100 ether);

        bytes memory data = encodeReinitializerData();
        Proxify.upgradeUUPSProxy(proxy, implementationV2, data, value, DEFAULT_SENDER);

        assertUUPSProxy(proxy, implementationV2, value);
        assertGreeterV2(proxy);
    }

    function test_fuzz_upgradeUUPSProxy_withArtifactUsesSalt(bytes32 salt, uint256 value) public {
        value = bound(value, 0, 100 ether);

        bytes memory data = encodeReinitializerData();

        implementationV2 = computeCreate2Address(GREETER_V2_PROXIABLE_PATH, salt, DEFAULT_SENDER);
        Proxify.upgradeUUPSProxy(proxy, GREETER_V2_PROXIABLE_PATH, data, salt, value, DEFAULT_SENDER);

        assertUUPSProxy(proxy, implementationV2, value);
        assertGreeterV2(proxy);
    }

    function upgradeUUPSProxy(address implementation, bytes calldata data) external {
        Proxify.upgradeUUPSProxy(proxy, implementation, data);
    }
}
