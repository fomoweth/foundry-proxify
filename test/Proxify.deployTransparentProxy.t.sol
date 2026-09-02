// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Proxify} from "src/Proxify.sol";
import {ProxifyTestBase} from "test/Base.t.sol";

contract ProxifyDeployTransparentProxyTest is ProxifyTestBase {
    string internal constant defaultGreeting = "hello";
    address internal constant defaultOwner = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;
    uint256 internal constant defaultValue = 12 ether;
    bytes32 internal constant defaultSalt = keccak256("proxify-deployTransparentProxy-salt");

    address internal implementation;

    function setUp() public {
        implementation = Proxify.deployCode(GREETER_V1_PATH);
    }

    function test_deployTransparentProxy_withExistingImplementation() public {
        address adminOwner = address(this);
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        address expected = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        address proxy = Proxify.deployTransparentProxy(implementation, adminOwner, data);

        assertEq(proxy, expected);
        assertTransparentProxy(proxy, implementation, adminOwner, 0);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployTransparentProxy_withExistingImplementationAndValue() public {
        address adminOwner = address(this);
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        address expected = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        address proxy = Proxify.deployTransparentProxy(implementation, adminOwner, data, defaultValue);

        assertEq(proxy, expected);
        assertTransparentProxy(proxy, implementation, adminOwner, defaultValue);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployTransparentProxy_withExistingImplementationUsesSalt() public {
        address adminOwner = address(this);
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        address expected = computeTransparentProxyAddress(implementation, address(this), data, defaultSalt);
        address proxy = Proxify.deployTransparentProxy(implementation, adminOwner, data, defaultSalt);

        assertEq(proxy, expected);
        assertTransparentProxy(proxy, implementation, adminOwner, 0);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployTransparentProxy_withExistingImplementationAndValueUsesSalt() public {
        address adminOwner = address(this);
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        address expected = computeTransparentProxyAddress(implementation, address(this), data, defaultSalt);
        address proxy = Proxify.deployTransparentProxy(implementation, adminOwner, data, defaultSalt, defaultValue);

        assertEq(proxy, expected);
        assertTransparentProxy(proxy, implementation, adminOwner, defaultValue);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployTransparentProxy_withArtifact() public {
        address adminOwner = address(this);
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        uint64 nonce = vm.getNonce(address(this));
        implementation = vm.computeCreateAddress(address(this), nonce);

        address expected = vm.computeCreateAddress(address(this), ++nonce);
        address proxy = Proxify.deployTransparentProxy(GREETER_V1_PATH, adminOwner, data);

        assertEq(proxy, expected);
        assertTransparentProxy(proxy, implementation, adminOwner, 0);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployTransparentProxy_withArtifactAndValue() public {
        address adminOwner = address(this);
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        uint64 nonce = vm.getNonce(address(this));
        implementation = vm.computeCreateAddress(address(this), nonce);

        address expected = vm.computeCreateAddress(address(this), ++nonce);
        address proxy = Proxify.deployTransparentProxy(GREETER_V1_PATH, adminOwner, data, defaultValue);

        assertEq(proxy, expected);
        assertTransparentProxy(proxy, implementation, adminOwner, defaultValue);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployTransparentProxy_withArtifactUsesSalt() public {
        address adminOwner = address(this);
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        implementation = computeCreate2Address(GREETER_V1_BYTECODE, defaultSalt);

        address expected = computeTransparentProxyAddress(implementation, address(this), data, defaultSalt);
        address proxy = Proxify.deployTransparentProxy(GREETER_V1_PATH, adminOwner, data, defaultSalt);

        assertEq(proxy, expected);
        assertTransparentProxy(proxy, implementation, adminOwner, 0);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployTransparentProxy_withArtifactAndValueUsesSalt() public {
        address adminOwner = address(this);
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        implementation = computeCreate2Address(GREETER_V1_BYTECODE, defaultSalt);

        address expected = computeTransparentProxyAddress(implementation, adminOwner, data, defaultSalt);
        address proxy = Proxify.deployTransparentProxy(GREETER_V1_PATH, adminOwner, data, defaultSalt, defaultValue);

        assertEq(proxy, expected);
        assertTransparentProxy(proxy, implementation, adminOwner, defaultValue);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployTransparentProxy_bubblesInitializerRevert() public {
        vm.expectRevert(bytes4(keccak256("FailedCall()")));
        this.deployTransparentProxy(address(this), encodeInitializerData(address(0), "FailedCall"), defaultSalt);
    }

    function test_deployTransparentProxy_revertsWhenInitializerDataIsEmpty() public {
        vm.expectRevert(bytes4(keccak256("ERC1967ProxyUninitialized()")));
        this.deployTransparentProxy(address(this), "", defaultSalt);
    }

    function test_deployTransparentProxy_revertsWithDeploymentFailedOnCreate2Collision() public {
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);
        assertContract(this.deployTransparentProxy(address(this), data, defaultSalt));

        vm.expectRevert(Proxify.DeploymentFailed.selector);
        this.deployTransparentProxy(address(this), data, defaultSalt);
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

        implementation = computeCreate2Address(GREETER_V1_BYTECODE, salt);

        address expected = computeTransparentProxyAddress(implementation, adminOwner, data, salt);
        address proxy = Proxify.deployTransparentProxy(GREETER_V1_PATH, adminOwner, data, salt);

        assertEq(proxy, expected);
        assertTransparentProxy(proxy, implementation, adminOwner, 0);
        assertGreeterV1(proxy, initialOwner, initialGreeting);
    }

    function deployTransparentProxy(address initialOwner, bytes calldata data, bytes32 salt)
        external
        returns (address)
    {
        return Proxify.deployTransparentProxy(implementation, initialOwner, data, salt);
    }
}
