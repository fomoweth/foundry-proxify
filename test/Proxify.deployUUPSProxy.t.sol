// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Proxify} from "src/Proxify.sol";
import {ProxifyTestBase} from "test/Base.t.sol";

contract ProxifyDeployUUPSProxyTest is ProxifyTestBase {
    string internal constant defaultGreeting = "hello";
    address internal constant defaultOwner = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;
    uint256 internal constant defaultNumber = 42;
    uint256 internal constant defaultValue = 12 ether;
    bytes32 internal constant defaultSalt = keccak256("proxify-deployUUPSProxy-salt");

    address internal implementation;

    function setUp() public {
        implementation = Proxify.deployCode(GREETER_V1_PROXIABLE_PATH);
    }

    function test_deployUUPSProxy_withExistingImplementation() public {
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        address expected = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        address proxy = Proxify.deployUUPSProxy(implementation, data);

        assertEq(proxy, expected);
        assertUUPSProxy(proxy, implementation, 0);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployUUPSProxy_withExistingImplementationAndValue() public {
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        address expected = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        address proxy = Proxify.deployUUPSProxy(implementation, data, defaultValue);

        assertEq(proxy, expected);
        assertUUPSProxy(proxy, implementation, defaultValue);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployUUPSProxy_withExistingImplementationUsesSalt() public {
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        address expected = computeUUPSProxyAddress(implementation, data, defaultSalt);
        address proxy = Proxify.deployUUPSProxy(implementation, data, defaultSalt);

        assertEq(proxy, expected);
        assertUUPSProxy(proxy, implementation, 0);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployUUPSProxy_withExistingImplementationAndValueUsesSalt() public {
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        address expected = computeUUPSProxyAddress(implementation, data, defaultSalt);
        address proxy = Proxify.deployUUPSProxy(implementation, data, defaultSalt, defaultValue);

        assertEq(proxy, expected);
        assertUUPSProxy(proxy, implementation, defaultValue);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployUUPSProxy_withArtifact() public {
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        uint64 nonce = vm.getNonce(address(this));
        implementation = vm.computeCreateAddress(address(this), nonce);

        address expected = vm.computeCreateAddress(address(this), ++nonce);
        address proxy = Proxify.deployUUPSProxy(GREETER_V1_PROXIABLE_PATH, data);

        assertEq(proxy, expected);
        assertUUPSProxy(proxy, implementation, 0);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployUUPSProxy_withArtifactAndValue() public {
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);

        uint64 nonce = vm.getNonce(address(this));
        implementation = vm.computeCreateAddress(address(this), nonce);

        address expected = vm.computeCreateAddress(address(this), ++nonce);
        address proxy = Proxify.deployUUPSProxy(GREETER_V1_PROXIABLE_PATH, data, defaultValue);

        assertEq(proxy, expected);
        assertUUPSProxy(proxy, implementation, defaultValue);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployUUPSProxy_withArtifactUsesSalt() public {
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);
        implementation = computeCreate2Address(GREETER_V1_PROXIABLE_BYTECODE, defaultSalt);

        address expected = computeUUPSProxyAddress(implementation, data, defaultSalt);
        address proxy = Proxify.deployUUPSProxy(GREETER_V1_PROXIABLE_PATH, data, defaultSalt);

        assertEq(proxy, expected);
        assertUUPSProxy(proxy, implementation, 0);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployUUPSProxy_withArtifactAndValueUsesSalt() public {
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);
        implementation = computeCreate2Address(GREETER_V1_PROXIABLE_BYTECODE, defaultSalt);

        address expected = computeUUPSProxyAddress(implementation, data, defaultSalt);
        address proxy = Proxify.deployUUPSProxy(GREETER_V1_PROXIABLE_PATH, data, defaultSalt, defaultValue);

        assertEq(proxy, expected);
        assertUUPSProxy(proxy, implementation, defaultValue);
        assertGreeterV1(proxy, defaultOwner, defaultGreeting);
    }

    function test_deployUUPSProxy_bubblesInitializerRevert() public {
        vm.expectRevert(bytes4(keccak256("FailedCall()")));
        this.deployUUPSProxy(encodeInitializerData(address(0), "FailedCall"), defaultSalt);
    }

    function test_deployUUPSProxy_revertsWhenInitializerDataIsEmpty() public {
        vm.expectRevert(bytes4(keccak256("ERC1967ProxyUninitialized()")));
        this.deployUUPSProxy("", defaultSalt);
    }

    function test_deployUUPSProxy_revertsWithDeploymentFailedOnCreate2Collision() public {
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);
        assertContract(this.deployUUPSProxy(data, defaultSalt));

        vm.expectRevert(Proxify.DeploymentFailed.selector);
        this.deployUUPSProxy(data, defaultSalt);
    }

    function test_deployUUPSProxy_withArtifactRevertsWithDeploymentFailedOnCreate2Collision() public {
        bytes memory data = encodeInitializerData(defaultOwner, defaultGreeting);
        assertContract(this.deployUUPSProxy(GREETER_V1_PROXIABLE_PATH, data, defaultSalt));

        vm.expectRevert(Proxify.DeploymentFailed.selector);
        this.deployUUPSProxy(GREETER_V1_PROXIABLE_PATH, data, defaultSalt);
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
        implementation = computeCreate2Address(GREETER_V1_PROXIABLE_BYTECODE, salt);

        address expected = computeUUPSProxyAddress(implementation, data, salt);
        address proxy = Proxify.deployUUPSProxy(GREETER_V1_PROXIABLE_PATH, data, salt);

        assertEq(proxy, expected);
        assertUUPSProxy(proxy, implementation, 0);
        assertGreeterV1(proxy, initialOwner, initialGreeting);
    }

    function deployUUPSProxy(bytes calldata data, bytes32 salt) external returns (address) {
        return Proxify.deployUUPSProxy(implementation, data, salt);
    }

    function deployUUPSProxy(string calldata artifactPath, bytes calldata data, bytes32 salt)
        external
        returns (address)
    {
        return Proxify.deployUUPSProxy(artifactPath, data, salt);
    }
}
