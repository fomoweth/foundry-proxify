// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Proxify} from "src/Proxify.sol";
import {ProxifyTest} from "test/Base.t.sol";

contract ProxifyUpgradeTransparentProxyTest is ProxifyTest {
    address internal proxy;
    address internal implementationV1;
    address internal implementationV2;

    function setUp() public {
        implementationV1 = vm.deployCode(GREETER_V1_PATH);
        implementationV2 = vm.deployCode(GREETER_V2_PATH);

        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);
        proxy = Proxify.deployTransparentProxy(implementationV1, DEFAULT_SENDER, data);
    }

    function test_upgradeTransparentProxy_withExistingImplementation() public {
        bytes memory data = encodeReinitializerData();
        Proxify.upgradeTransparentProxy(proxy, implementationV2, data, DEFAULT_SENDER);

        assertTransparentProxy(proxy, implementationV2, DEFAULT_SENDER, 0);
        assertGreeterV2(proxy);
    }

    function test_upgradeTransparentProxy_withExistingImplementationAndValue() public {
        bytes memory data = encodeReinitializerData();
        Proxify.upgradeTransparentProxy(proxy, implementationV2, data, DEFAULT_VALUE, DEFAULT_SENDER);

        assertTransparentProxy(proxy, implementationV2, DEFAULT_SENDER, DEFAULT_VALUE);
        assertGreeterV2(proxy);
    }

    function test_upgradeTransparentProxy_withArtifact() public {
        bytes memory data = encodeReinitializerData();

        implementationV2 = vm.computeCreateAddress(DEFAULT_SENDER, vm.getNonce(DEFAULT_SENDER));
        Proxify.upgradeTransparentProxy(proxy, GREETER_V2_PATH, data, DEFAULT_SENDER);

        assertTransparentProxy(proxy, implementationV2, DEFAULT_SENDER, 0);
        assertGreeterV2(proxy);
    }

    function test_upgradeTransparentProxy_withArtifactAndValue() public {
        bytes memory data = encodeReinitializerData();

        implementationV2 = vm.computeCreateAddress(DEFAULT_SENDER, vm.getNonce(DEFAULT_SENDER));
        Proxify.upgradeTransparentProxy(proxy, GREETER_V2_PATH, data, DEFAULT_VALUE, DEFAULT_SENDER);

        assertTransparentProxy(proxy, implementationV2, DEFAULT_SENDER, DEFAULT_VALUE);
        assertGreeterV2(proxy);
    }

    function test_upgradeTransparentProxy_withArtifactUsesSalt() public {
        bytes memory data = encodeReinitializerData();

        implementationV2 = computeCreate2Address(GREETER_V2_PATH, DEFAULT_SALT, DEFAULT_SENDER);
        Proxify.upgradeTransparentProxy(proxy, GREETER_V2_PATH, data, DEFAULT_SALT, DEFAULT_SENDER);

        assertTransparentProxy(proxy, implementationV2, DEFAULT_SENDER, 0);
        assertGreeterV2(proxy);
    }

    function test_upgradeTransparentProxy_withArtifactAndValueUsesSalt() public {
        bytes memory data = encodeReinitializerData();

        implementationV2 = computeCreate2Address(GREETER_V2_PATH, DEFAULT_SALT, DEFAULT_SENDER);
        Proxify.upgradeTransparentProxy(proxy, GREETER_V2_PATH, data, DEFAULT_SALT, DEFAULT_VALUE, DEFAULT_SENDER);

        assertTransparentProxy(proxy, implementationV2, DEFAULT_SENDER, DEFAULT_VALUE);
        assertGreeterV2(proxy);
    }

    function test_upgradeTransparentProxy_bubblesDownstreamRevert() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(this)));
        this.upgradeTransparentProxy(implementationV2, encodeReinitializerData());
    }

    function test_upgradeTransparentProxy_revertsWhenTargetHasNoCode() public {
        proxy = vm.deployCode("EmptyRuntime.sol:EmptyRuntime");
        vm.expectRevert(abi.encodeWithSelector(Proxify.EmptyCode.selector, proxy));
        Proxify.upgradeTransparentProxy(proxy, implementationV2, encodeReinitializerData());
    }

    function test_upgradeTransparentProxy_revertsWhenAdminHasNoCode() public {
        address admin = vm.deployCode("EmptyRuntime.sol:EmptyRuntime");
        vm.store(proxy, ADMIN_SLOT, bytes32(uint256(uint160(admin))));

        vm.expectRevert(abi.encodeWithSelector(Proxify.EmptyCode.selector, admin));
        Proxify.upgradeTransparentProxy(proxy, implementationV2, encodeReinitializerData());
    }

    function test_fuzz_upgradeTransparentProxy_withExistingImplementationAndValue(uint256 value) public {
        value = bound(value, 0, 100 ether);

        bytes memory data = encodeReinitializerData();
        Proxify.upgradeTransparentProxy(proxy, implementationV2, data, value, DEFAULT_SENDER);

        assertTransparentProxy(proxy, implementationV2, DEFAULT_SENDER, value);
        assertGreeterV2(proxy);
    }

    function test_fuzz_upgradeTransparentProxy_withArtifactUsesSalt(bytes32 salt, uint256 value) public {
        value = bound(value, 0, 100 ether);

        bytes memory data = encodeReinitializerData();

        implementationV2 = computeCreate2Address(GREETER_V2_PATH, salt, DEFAULT_SENDER);
        Proxify.upgradeTransparentProxy(proxy, GREETER_V2_PATH, data, salt, value, DEFAULT_SENDER);

        assertTransparentProxy(proxy, implementationV2, DEFAULT_SENDER, value);
        assertGreeterV2(proxy);
    }

    function upgradeTransparentProxy(address implementation, bytes calldata data) external {
        Proxify.upgradeTransparentProxy(proxy, implementation, data);
    }
}
