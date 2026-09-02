// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Proxify} from "src/Proxify.sol";
import {ProxifyTestBase} from "test/Base.t.sol";

contract ProxifyUpgradeTransparentProxyTest is ProxifyTestBase {
    string internal constant defaultGreeting = "hello";
    address internal constant defaultOwner = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;
    uint256 internal constant defaultNumber = 42;
    uint256 internal constant defaultValue = 12 ether;
    bytes32 internal constant defaultSalt = keccak256("proxify-upgradeTransparentProxy-salt");

    address internal proxy;
    address internal implementationV1;
    address internal implementationV2;

    function setUp() public {
        implementationV1 = Proxify.deployCode(GREETER_V1_PATH);
        implementationV2 = Proxify.deployCode(GREETER_V2_PATH);

        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);
        proxy = Proxify.deployTransparentProxy(implementationV1, address(this), data);
    }

    function test_upgradeTransparentProxy_withExistingImplementation() public {
        bytes memory data = encodeReinitializerData();
        Proxify.upgradeTransparentProxy(proxy, implementationV2, data);

        assertTransparentProxy(proxy, implementationV2, address(this), 0);
        assertGreeterV2(proxy, false);
    }

    function test_upgradeTransparentProxy_withExistingImplementationAndValue() public {
        bytes memory data = encodeReinitializerData();
        Proxify.upgradeTransparentProxy(proxy, implementationV2, data, defaultValue);

        assertTransparentProxy(proxy, implementationV2, address(this), defaultValue);
        assertGreeterV2(proxy, false);
    }

    function test_upgradeTransparentProxy_withArtifact() public {
        bytes memory data = encodeReinitializerData();

        implementationV2 = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        Proxify.upgradeTransparentProxy(proxy, GREETER_V2_PATH, data);

        assertTransparentProxy(proxy, implementationV2, address(this), 0);
        assertGreeterV2(proxy, false);
    }

    function test_upgradeTransparentProxy_withArtifactAndValue() public {
        bytes memory data = encodeReinitializerData();

        implementationV2 = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        Proxify.upgradeTransparentProxy(proxy, GREETER_V2_PATH, data, defaultValue);

        assertTransparentProxy(proxy, implementationV2, address(this), defaultValue);
        assertGreeterV2(proxy, false);
    }

    function test_upgradeTransparentProxy_withArtifactUsesSalt() public {
        bytes memory data = encodeReinitializerData();

        implementationV2 = computeCreate2Address(GREETER_V2_BYTECODE, defaultSalt);
        Proxify.upgradeTransparentProxy(proxy, GREETER_V2_PATH, data, defaultSalt);

        assertTransparentProxy(proxy, implementationV2, address(this), 0);
        assertGreeterV2(proxy, false);
    }

    function test_upgradeTransparentProxy_withArtifactAndValueUsesSalt() public {
        bytes memory data = encodeReinitializerData();

        implementationV2 = computeCreate2Address(GREETER_V2_BYTECODE, defaultSalt);
        Proxify.upgradeTransparentProxy(proxy, GREETER_V2_PATH, data, defaultSalt, defaultValue);

        assertTransparentProxy(proxy, implementationV2, address(this), defaultValue);
        assertGreeterV2(proxy, false);
    }

    function test_upgradeTransparentProxy_bubblesDownstreamRevert() public {
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);
        proxy = Proxify.deployTransparentProxy(implementationV1, defaultOwner, data);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(this)));
        this.upgradeTransparentProxy(implementationV2, encodeReinitializerData());
    }

    function test_upgradeTransparentProxy_revertsWhenTargetHasNoCode() public {
        proxy = Proxify.deployCode("Observers.sol:EmptyRuntime");

        vm.expectRevert(abi.encodeWithSelector(Proxify.EmptyCode.selector, proxy));
        this.upgradeTransparentProxy(implementationV2, encodeReinitializerData());
    }

    function test_upgradeTransparentProxy_revertsWhenAdminHasNoCode() public {
        address admin = Proxify.deployCode("Observers.sol:EmptyRuntime");
        vm.store(proxy, ADMIN_SLOT, bytes32(uint256(uint160(admin))));

        vm.expectRevert(abi.encodeWithSelector(Proxify.EmptyCode.selector, admin));
        this.upgradeTransparentProxy(implementationV2, encodeReinitializerData());
    }

    function test_upgradeTransparentProxy_revertsWithUpgradeFailedWhenCallRevertsWithoutData() public {
        address admin = Proxify.deployCode("Observers.sol:EmptyRevert");
        vm.store(proxy, ADMIN_SLOT, bytes32(uint256(uint160(admin))));

        vm.expectRevert(Proxify.UpgradeFailed.selector);
        this.upgradeTransparentProxy(implementationV2, "");
    }

    function test_fuzz_upgradeTransparentProxy_withExistingImplementationAndValue(uint256 value) public {
        value = bound(value, 0, 100 ether);

        bytes memory data = encodeReinitializerData();
        Proxify.upgradeTransparentProxy(proxy, implementationV2, data, value);

        assertTransparentProxy(proxy, implementationV2, address(this), value);
        assertGreeterV2(proxy, false);
    }

    function test_fuzz_upgradeTransparentProxy_withArtifactUsesSalt(bytes32 salt, uint256 value) public {
        value = bound(value, 0, 100 ether);

        bytes memory data = encodeReinitializerData();

        implementationV2 = computeCreate2Address(GREETER_V2_BYTECODE, salt);
        Proxify.upgradeTransparentProxy(proxy, GREETER_V2_PATH, data, salt, value);

        assertTransparentProxy(proxy, implementationV2, address(this), value);
        assertGreeterV2(proxy, false);
    }

    function upgradeTransparentProxy(address implementation, bytes calldata data) external {
        Proxify.upgradeTransparentProxy(proxy, implementation, data);
    }
}
