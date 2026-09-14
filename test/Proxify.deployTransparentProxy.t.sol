// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Proxify} from "src/Proxify.sol";
import {ProxifyTest} from "test/Base.t.sol";

contract ProxifyDeployTransparentProxyTest is ProxifyTest {
    address internal implementation;

    function setUp() public {
        implementation = vm.deployCode(GREETER_V1_PATH);
    }

    function test_deployTransparentProxy_withExistingImplementation() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        address expected = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        address proxy = Proxify.deployTransparentProxy(implementation, DEFAULT_SENDER, data);

        assertEq(proxy, expected);
        assertTransparentProxy(proxy, implementation, DEFAULT_SENDER, 0);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployTransparentProxy_withExistingImplementationAndValue() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        address expected = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        address proxy = Proxify.deployTransparentProxy(implementation, DEFAULT_SENDER, data, DEFAULT_VALUE);

        assertEq(proxy, expected);
        assertTransparentProxy(proxy, implementation, DEFAULT_SENDER, DEFAULT_VALUE);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployTransparentProxy_withExistingImplementationUsesSalt() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        address expected = computeTransparentProxyAddress(implementation, DEFAULT_SENDER, data, DEFAULT_SALT);
        address proxy = Proxify.deployTransparentProxy(implementation, DEFAULT_SENDER, data, DEFAULT_SALT);

        assertEq(proxy, expected);
        assertTransparentProxy(proxy, implementation, DEFAULT_SENDER, 0);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployTransparentProxy_withExistingImplementationAndValueUsesSalt() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        address expected = computeTransparentProxyAddress(implementation, DEFAULT_SENDER, data, DEFAULT_SALT);
        address proxy =
            Proxify.deployTransparentProxy(implementation, DEFAULT_SENDER, data, DEFAULT_SALT, DEFAULT_VALUE);

        assertEq(proxy, expected);
        assertTransparentProxy(proxy, implementation, DEFAULT_SENDER, DEFAULT_VALUE);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployTransparentProxy_withArtifact() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        uint64 nonce = vm.getNonce(address(this));
        implementation = vm.computeCreateAddress(address(this), nonce);

        address expected = vm.computeCreateAddress(address(this), ++nonce);
        address proxy = Proxify.deployTransparentProxy(GREETER_V1_PATH, DEFAULT_SENDER, data);

        assertEq(proxy, expected);
        assertTransparentProxy(proxy, implementation, DEFAULT_SENDER, 0);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployTransparentProxy_withArtifactAndValue() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);

        uint64 nonce = vm.getNonce(address(this));
        implementation = vm.computeCreateAddress(address(this), nonce);

        address expected = vm.computeCreateAddress(address(this), ++nonce);
        address proxy = Proxify.deployTransparentProxy(GREETER_V1_PATH, DEFAULT_SENDER, data, DEFAULT_VALUE);

        assertEq(proxy, expected);
        assertTransparentProxy(proxy, implementation, DEFAULT_SENDER, DEFAULT_VALUE);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployTransparentProxy_withArtifactUsesSalt() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);
        implementation = computeCreate2Address(GREETER_V1_PATH, DEFAULT_SALT);

        address expected = computeTransparentProxyAddress(implementation, DEFAULT_SENDER, data, DEFAULT_SALT);
        address proxy = Proxify.deployTransparentProxy(GREETER_V1_PATH, DEFAULT_SENDER, data, DEFAULT_SALT);

        assertEq(proxy, expected);
        assertTransparentProxy(proxy, implementation, DEFAULT_SENDER, 0);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployTransparentProxy_withArtifactAndValueUsesSalt() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);
        implementation = computeCreate2Address(GREETER_V1_PATH, DEFAULT_SALT);

        address expected = computeTransparentProxyAddress(implementation, DEFAULT_SENDER, data, DEFAULT_SALT);
        address proxy =
            Proxify.deployTransparentProxy(GREETER_V1_PATH, DEFAULT_SENDER, data, DEFAULT_SALT, DEFAULT_VALUE);

        assertEq(proxy, expected);
        assertTransparentProxy(proxy, implementation, DEFAULT_SENDER, DEFAULT_VALUE);
        assertGreeterV1(proxy, DEFAULT_OWNER, DEFAULT_GREETING);
    }

    function test_deployTransparentProxy_bubblesInitializerRevert() public {
        bytes memory data = encodeInitializerData(address(0), "FailedCall");
        vm.expectRevert(bytes4(keccak256("FailedCall()")));
        Proxify.deployTransparentProxy(implementation, DEFAULT_SENDER, data, DEFAULT_SALT);
    }

    function test_deployTransparentProxy_revertsWhenInitializerDataIsEmpty() public {
        vm.expectRevert(bytes4(keccak256("ERC1967ProxyUninitialized()")));
        Proxify.deployTransparentProxy(implementation, DEFAULT_SENDER, "", DEFAULT_SALT);
    }

    function test_deployTransparentProxy_revertsOnCreate2Collision() public {
        bytes memory data = encodeInitializerData(DEFAULT_OWNER, DEFAULT_GREETING);
        assertContract(Proxify.deployTransparentProxy(implementation, DEFAULT_SENDER, data, DEFAULT_SALT));

        vm.expectRevert();
        Proxify.deployTransparentProxy(implementation, DEFAULT_SENDER, data, DEFAULT_SALT);
    }

    function test_fuzz_deployTransparentProxy_withExistingImplementationUsesSalt(
        address adminOwner,
        address initialOwner,
        string memory initialGreeting,
        bytes32 salt
    ) public {
        vm.assume(adminOwner != address(0) && initialOwner != address(0));

        bytes memory data = encodeInitializerData(initialOwner, initialGreeting);

        address expected = computeTransparentProxyAddress(implementation, adminOwner, data, salt);
        address proxy = Proxify.deployTransparentProxy(implementation, adminOwner, data, salt);

        assertEq(proxy, expected);
        assertTransparentProxy(proxy, implementation, adminOwner, 0);
        assertGreeterV1(proxy, initialOwner, initialGreeting);
    }

    function test_fuzz_deployTransparentProxy_withArtifactUsesSalt(
        address adminOwner,
        address initialOwner,
        string memory initialGreeting,
        bytes32 salt
    ) public {
        vm.assume(adminOwner != address(0) && initialOwner != address(0));

        bytes memory data = encodeInitializerData(initialOwner, initialGreeting);
        implementation = computeCreate2Address(GREETER_V1_PATH, salt);

        address expected = computeTransparentProxyAddress(implementation, adminOwner, data, salt);
        address proxy = Proxify.deployTransparentProxy(GREETER_V1_PATH, adminOwner, data, salt);

        assertEq(proxy, expected);
        assertTransparentProxy(proxy, implementation, adminOwner, 0);
        assertGreeterV1(proxy, initialOwner, initialGreeting);
    }
}
