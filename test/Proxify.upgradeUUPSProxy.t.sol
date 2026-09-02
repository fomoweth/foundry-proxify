// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Proxify} from "src/Proxify.sol";
import {ProxifyTestBase} from "test/Base.t.sol";

contract ProxifyUpgradeUUPSProxyTest is ProxifyTestBase {
    string internal constant defaultGreeting = "hello";
    address internal constant defaultOwner = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;
    uint256 internal constant defaultValue = 12 ether;
    bytes32 internal constant defaultSalt = keccak256("proxify-upgradeUUPSProxy-salt");

    address internal proxy;
    address internal implementationV1;
    address internal implementationV2;

    function setUp() public {
        implementationV1 = Proxify.deployCode(GREETER_V1_PROXIABLE_PATH);
        implementationV2 = Proxify.deployCode(GREETER_V2_PROXIABLE_PATH);

        bytes memory data = encodeInitializerData(address(this), defaultGreeting);
        proxy = Proxify.deployUUPSProxy(implementationV1, data);
    }

    function test_upgradeUUPSProxy_withExistingImplementation() public {
        Proxify.upgradeUUPSProxy(proxy, implementationV2, encodeReinitializerData());

        assertUUPSProxy(proxy, implementationV2, 0);
        assertGreeterV2(proxy, false);
    }

    function test_upgradeUUPSProxy_withExistingImplementationAndValue() public {
        Proxify.upgradeUUPSProxy(proxy, implementationV2, encodeReinitializerData(), defaultValue);

        assertUUPSProxy(proxy, implementationV2, defaultValue);
        assertGreeterV2(proxy, false);
    }

    function test_upgradeUUPSProxy_withArtifact() public {
        implementationV2 = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        Proxify.upgradeUUPSProxy(proxy, GREETER_V2_PROXIABLE_PATH, encodeReinitializerData());

        assertUUPSProxy(proxy, implementationV2, 0);
        assertGreeterV2(proxy, false);
    }

    function test_upgradeUUPSProxy_withArtifactAndValue() public {
        bytes memory data = encodeReinitializerData();

        implementationV2 = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        Proxify.upgradeUUPSProxy(proxy, GREETER_V2_PROXIABLE_PATH, data, defaultValue);

        assertUUPSProxy(proxy, implementationV2, defaultValue);
        assertGreeterV2(proxy, false);
    }

    function test_upgradeUUPSProxy_withArtifactUsesSalt() public {
        bytes memory data = encodeReinitializerData();

        implementationV2 = computeCreate2Address(GREETER_V2_PROXIABLE_BYTECODE, defaultSalt);
        Proxify.upgradeUUPSProxy(proxy, GREETER_V2_PROXIABLE_PATH, data, defaultSalt);

        assertUUPSProxy(proxy, implementationV2, 0);
        assertGreeterV2(proxy, false);
    }

    function test_upgradeUUPSProxy_withArtifactAndValueUsesSalt() public {
        bytes memory data = encodeReinitializerData();

        implementationV2 = computeCreate2Address(GREETER_V2_PROXIABLE_BYTECODE, defaultSalt);
        Proxify.upgradeUUPSProxy(proxy, GREETER_V2_PROXIABLE_PATH, data, defaultSalt, defaultValue);

        assertUUPSProxy(proxy, implementationV2, defaultValue);
        assertGreeterV2(proxy, false);
    }

    function test_upgradeUUPSProxy_bubblesDownstreamRevert() public {
        proxy = Proxify.deployUUPSProxy(implementationV1, encodeInitializerData(defaultOwner, defaultGreeting));

        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        this.upgradeUUPSProxy(implementationV2, encodeReinitializerData());
    }

    function test_upgradeUUPSProxy_revertsWhenTargetHasNoCode() public {
        proxy = Proxify.deployCode("Observers.sol:EmptyRuntime");

        vm.expectRevert(abi.encodeWithSelector(Proxify.EmptyCode.selector, proxy));
        this.upgradeUUPSProxy(implementationV2, encodeReinitializerData());
    }

    function test_upgradeUUPSProxy_revertsWithUpgradeFailedWhenCallRevertsWithoutData() public {
        proxy = Proxify.deployCode("Observers.sol:EmptyRevert");

        vm.expectRevert(Proxify.UpgradeFailed.selector);
        this.upgradeUUPSProxy(implementationV2, encodeReinitializerData());
    }

    function test_fuzz_upgradeUUPSProxy_withExistingImplementationAndValue(uint256 value) public {
        value = bound(value, 0, 100 ether);

        Proxify.upgradeUUPSProxy(proxy, implementationV2, encodeReinitializerData(), value);

        assertUUPSProxy(proxy, implementationV2, value);
        assertGreeterV2(proxy, false);
    }

    function test_fuzz_upgradeUUPSProxy_withArtifactUsesSalt(bytes32 salt, uint256 value) public {
        value = bound(value, 0, 100 ether);

        bytes memory data = encodeReinitializerData();

        implementationV2 = computeCreate2Address(GREETER_V2_PROXIABLE_BYTECODE, salt);
        Proxify.upgradeUUPSProxy(proxy, GREETER_V2_PROXIABLE_PATH, data, salt, value);

        assertUUPSProxy(proxy, implementationV2, value);
        assertGreeterV2(proxy, false);
    }

    function upgradeUUPSProxy(address implementation, bytes calldata data) external {
        Proxify.upgradeUUPSProxy(proxy, implementation, data);
    }
}
