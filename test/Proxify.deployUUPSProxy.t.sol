// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Proxify} from "src/Proxify.sol";
import {ProxifyTest} from "test/Base.t.sol";

contract ProxifyDeployUUPSProxyTest is ProxifyTest {
    address internal implementation;

    function setUp() public {
        implementation = vm.deployCode(GREETER_V1_PROXIABLE_PATH);
    }

    function test_deployUUPSProxy_withExistingImplementation() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        address expected = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        address proxy = Proxify.deployUUPSProxy(implementation, data);

        assertEq(proxy, expected);
        assertUUPSProxy(proxy, implementation, 0);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployUUPSProxy_withExistingImplementationAndValue() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        address expected = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        address proxy = Proxify.deployUUPSProxy(implementation, data, DEFAULT_VALUE);

        assertEq(proxy, expected);
        assertUUPSProxy(proxy, implementation, DEFAULT_VALUE);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployUUPSProxy_withExistingImplementationUsesSalt() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        address expected = computeUUPSProxyAddress(implementation, data, DEFAULT_SALT);
        address proxy = Proxify.deployUUPSProxy(implementation, data, DEFAULT_SALT);

        assertEq(proxy, expected);
        assertUUPSProxy(proxy, implementation, 0);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployUUPSProxy_withExistingImplementationAndValueUsesSalt() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        address expected = computeUUPSProxyAddress(implementation, data, DEFAULT_SALT);
        address proxy = Proxify.deployUUPSProxy(implementation, data, DEFAULT_SALT, DEFAULT_VALUE);

        assertEq(proxy, expected);
        assertUUPSProxy(proxy, implementation, DEFAULT_VALUE);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployUUPSProxy_withArtifact() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        uint64 nonce = vm.getNonce(address(this));
        implementation = vm.computeCreateAddress(address(this), nonce);

        address expected = vm.computeCreateAddress(address(this), ++nonce);
        address proxy = Proxify.deployUUPSProxy(GREETER_V1_PROXIABLE_PATH, data);

        assertEq(proxy, expected);
        assertUUPSProxy(proxy, implementation, 0);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployUUPSProxy_withArtifactAndValue() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        uint64 nonce = vm.getNonce(address(this));
        implementation = vm.computeCreateAddress(address(this), nonce);

        address expected = vm.computeCreateAddress(address(this), ++nonce);
        address proxy = Proxify.deployUUPSProxy(GREETER_V1_PROXIABLE_PATH, data, DEFAULT_VALUE);

        assertEq(proxy, expected);
        assertUUPSProxy(proxy, implementation, DEFAULT_VALUE);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployUUPSProxy_withArtifactUsesSalt() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);
        implementation = computeCreate2Address(GREETER_V1_PROXIABLE_PATH, DEFAULT_SALT);

        address expected = computeUUPSProxyAddress(implementation, data, DEFAULT_SALT);
        address proxy = Proxify.deployUUPSProxy(GREETER_V1_PROXIABLE_PATH, data, DEFAULT_SALT);

        assertEq(proxy, expected);
        assertUUPSProxy(proxy, implementation, 0);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployUUPSProxy_withArtifactAndValueUsesSalt() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);
        implementation = computeCreate2Address(GREETER_V1_PROXIABLE_PATH, DEFAULT_SALT);

        address expected = computeUUPSProxyAddress(implementation, data, DEFAULT_SALT);
        address proxy = Proxify.deployUUPSProxy(GREETER_V1_PROXIABLE_PATH, data, DEFAULT_SALT, DEFAULT_VALUE);

        assertEq(proxy, expected);
        assertUUPSProxy(proxy, implementation, DEFAULT_VALUE);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployUUPSProxy_bubblesInitializerRevert() public {
        vm.expectRevert(bytes4(keccak256("FailedCall()")));
        Proxify.deployUUPSProxy(implementation, encodeInitializerData(address(0), "FailedCall"), DEFAULT_SALT);
    }

    function test_deployUUPSProxy_revertsWhenInitializerDataIsEmpty() public {
        vm.expectRevert(bytes4(keccak256("ERC1967ProxyUninitialized()")));
        Proxify.deployUUPSProxy(implementation, "", DEFAULT_SALT);
    }

    function test_deployUUPSProxy_revertsOnCreate2Collision() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);
        assertContract(Proxify.deployUUPSProxy(implementation, data, DEFAULT_SALT));

        vm.expectRevert();
        Proxify.deployUUPSProxy(implementation, data, DEFAULT_SALT);
    }

    function test_fuzz_deployUUPSProxy_withExistingImplementationUsesSalt(
        address initialOwner,
        string memory initialGreeting,
        bytes32 salt
    ) public {
        vm.assume(initialOwner != address(0));

        bytes memory data = encodeInitializerData(initialOwner, initialGreeting);

        address expected = computeUUPSProxyAddress(implementation, data, salt);
        address proxy = Proxify.deployUUPSProxy(implementation, data, salt);

        assertEq(proxy, expected);
        assertUUPSProxy(proxy, implementation, 0);
        assertGreeterV1(proxy, initialOwner, initialGreeting);
    }

    function test_fuzz_deployUUPSProxy_withArtifactUsesSalt(
        address initialOwner,
        string memory initialGreeting,
        bytes32 salt
    ) public {
        vm.assume(initialOwner != address(0));

        bytes memory data = encodeInitializerData(initialOwner, initialGreeting);
        implementation = computeCreate2Address(GREETER_V1_PROXIABLE_PATH, salt);

        address expected = computeUUPSProxyAddress(implementation, data, salt);
        address proxy = Proxify.deployUUPSProxy(GREETER_V1_PROXIABLE_PATH, data, salt);

        assertEq(proxy, expected);
        assertUUPSProxy(proxy, implementation, 0);
        assertGreeterV1(proxy, initialOwner, initialGreeting);
    }
}
