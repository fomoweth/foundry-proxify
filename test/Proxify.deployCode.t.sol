// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Proxify} from "src/Proxify.sol";
import {ProxifyTestBase} from "test/Base.t.sol";
import {ObserverNoArgs, ObserverWithArgs} from "test/mocks/Observers.sol";

contract ProxifyDeployCodeTest is ProxifyTestBase {
    string internal constant OBSERVER_NO_ARGS_PATH = "Observers.sol:ObserverNoArgs";
    string internal constant OBSERVER_WITH_ARGS_PATH = "Observers.sol:ObserverWithArgs";

    bytes internal constant OBSERVER_NO_ARGS_BYTECODE = type(ObserverNoArgs).creationCode;
    bytes internal constant OBSERVER_WITH_ARGS_BYTECODE = type(ObserverWithArgs).creationCode;

    address internal constant defaultOwner = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;

    uint256 internal constant defaultNumber = 42;

    uint256 internal constant defaultValue = 12 ether;

    bytes32 internal constant defaultSalt = keccak256("proxify-deployCode-salt");

    function test_deployCode_create() public {
        address instance = Proxify.deployCode(OBSERVER_NO_ARGS_PATH);
        assertContract(instance);
        assertEq(instance.balance, 0);

        ObserverNoArgs observer = ObserverNoArgs(instance);
        assertEq(observer.msgSender(), address(this));
        assertEq(observer.msgValue(), 0);
    }

    function test_deployCode_createWithValue() public {
        address instance = Proxify.deployCode(OBSERVER_NO_ARGS_PATH, defaultValue);
        assertContract(instance);
        assertEq(instance.balance, defaultValue);

        ObserverNoArgs observer = ObserverNoArgs(instance);
        assertEq(observer.msgSender(), address(this));
        assertEq(observer.msgValue(), defaultValue);
    }

    function test_deployCode_createWithConstructorArgs() public {
        bytes memory args = abi.encode(defaultOwner, defaultNumber);

        address instance = Proxify.deployCode(OBSERVER_WITH_ARGS_PATH, args);
        assertContract(instance);
        assertEq(instance.balance, 0);

        ObserverWithArgs observer = ObserverWithArgs(instance);
        assertEq(observer.owner(), defaultOwner);
        assertEq(observer.number(), defaultNumber);
        assertEq(observer.msgSender(), address(this));
        assertEq(observer.msgValue(), 0);
    }

    function test_deployCode_createWithConstructorArgsAndValue() public {
        bytes memory args = abi.encode(defaultOwner, defaultNumber);

        address instance = Proxify.deployCode(OBSERVER_WITH_ARGS_PATH, args, defaultValue);
        assertContract(instance);
        assertEq(instance.balance, defaultValue);

        ObserverWithArgs observer = ObserverWithArgs(instance);
        assertEq(observer.owner(), defaultOwner);
        assertEq(observer.number(), defaultNumber);
        assertEq(observer.msgSender(), address(this));
        assertEq(observer.msgValue(), defaultValue);
    }

    function test_deployCode_create2() public {
        address expected = computeCreate2Address(OBSERVER_NO_ARGS_BYTECODE, defaultSalt);
        address instance = Proxify.deployCode(OBSERVER_NO_ARGS_PATH, defaultSalt);

        assertContract(instance);
        assertEq(instance, expected);
        assertEq(instance.balance, 0);

        ObserverNoArgs observer = ObserverNoArgs(instance);
        assertEq(observer.msgSender(), address(this));
        assertEq(observer.msgValue(), 0);
    }

    function test_deployCode_create2WithValue() public {
        address expected = computeCreate2Address(OBSERVER_NO_ARGS_BYTECODE, defaultSalt);
        address instance = Proxify.deployCode(OBSERVER_NO_ARGS_PATH, defaultSalt, defaultValue);

        assertContract(instance);
        assertEq(instance, expected);
        assertEq(instance.balance, defaultValue);

        ObserverNoArgs observer = ObserverNoArgs(instance);
        assertEq(observer.msgSender(), address(this));
        assertEq(observer.msgValue(), defaultValue);
    }

    function test_deployCode_create2WithConstructorArgs() public {
        bytes memory args = abi.encode(defaultOwner, defaultNumber);

        address expected = computeCreate2Address(OBSERVER_WITH_ARGS_BYTECODE, args, defaultSalt);
        address instance = Proxify.deployCode(OBSERVER_WITH_ARGS_PATH, args, defaultSalt);

        assertContract(instance);
        assertEq(instance, expected);
        assertEq(instance.balance, 0);

        ObserverWithArgs observer = ObserverWithArgs(instance);
        assertEq(observer.owner(), defaultOwner);
        assertEq(observer.number(), defaultNumber);
        assertEq(observer.msgSender(), address(this));
        assertEq(observer.msgValue(), 0);
    }

    function test_deployCode_create2WithConstructorArgsAndValue() public {
        bytes memory args = abi.encode(defaultOwner, defaultNumber);

        address expected = computeCreate2Address(OBSERVER_WITH_ARGS_BYTECODE, args, defaultSalt);
        address instance = Proxify.deployCode(OBSERVER_WITH_ARGS_PATH, args, defaultSalt, defaultValue);

        assertContract(instance);
        assertEq(instance, expected);
        assertEq(instance.balance, defaultValue);

        ObserverWithArgs observer = ObserverWithArgs(instance);
        assertEq(observer.owner(), defaultOwner);
        assertEq(observer.number(), defaultNumber);
        assertEq(observer.msgSender(), address(this));
        assertEq(observer.msgValue(), defaultValue);
    }

    function test_deployCode_allowsEmptyRuntimeCode() public {
        address instance = Proxify.deployCode("Observers.sol:EmptyRuntime");
        assertTrue(instance != address(0) && instance.code.length == 0);
    }

    function test_deployCode_bubblesConstructorRevertWithCustomError() public {
        vm.expectRevert(abi.encodeWithSignature("CustomError()"));
        this.deployCode("Observers.sol:CustomReverter", keccak256("custom-revert"));
    }

    function test_deployCode_bubblesConstructorRevertWithString() public {
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "constructor revert"));
        this.deployCode("Observers.sol:StringReverter", keccak256("string-revert"));
    }

    function test_deployCode_bubblesConstructorRevertWithPanic() public {
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x12)));
        this.deployCode("Observers.sol:PanicReverter", keccak256("panic-revert"));
    }

    function test_deployCode_revertsWithDeploymentFailedWhenConstructorRevertsWithoutData() public {
        vm.expectRevert(Proxify.DeploymentFailed.selector);
        this.deployCode("Observers.sol:EmptyReverter", keccak256("empty-revert"));
    }

    function test_deployCode_revertsWithDeploymentFailedOnCreate2Collision() public {
        bytes32 salt = keccak256("collision-salt");
        assertContract(Proxify.deployCode(OBSERVER_NO_ARGS_PATH, salt));

        vm.expectRevert(Proxify.DeploymentFailed.selector);
        this.deployCode(OBSERVER_NO_ARGS_PATH, salt);
    }

    function test_fuzz_deployCode_forwardsConstructorArgs(address initialOwner, uint256 initialNumber) public {
        address instance = Proxify.deployCode(OBSERVER_WITH_ARGS_PATH, abi.encode(initialOwner, initialNumber));
        assertContract(instance);
        assertEq(instance.balance, 0);

        ObserverWithArgs observer = ObserverWithArgs(instance);
        assertEq(observer.owner(), initialOwner);
        assertEq(observer.number(), initialNumber);
        assertEq(observer.msgSender(), address(this));
        assertEq(observer.msgValue(), 0);
    }

    function test_fuzz_deployCode_forwardsValue(uint256 value) public {
        value = bound(value, 0, 100 ether);

        address instance = Proxify.deployCode(OBSERVER_NO_ARGS_PATH, value);
        assertContract(instance);
        assertEq(instance.balance, value);

        ObserverNoArgs observer = ObserverNoArgs(instance);
        assertEq(observer.msgSender(), address(this));
        assertEq(observer.msgValue(), value);
    }

    function test_fuzz_deployCode_create2UsesSalt(bytes32 salt) public {
        address expected = computeCreate2Address(OBSERVER_NO_ARGS_BYTECODE, salt);
        address instance = Proxify.deployCode(OBSERVER_NO_ARGS_PATH, salt);

        assertContract(instance);
        assertEq(instance, expected);
    }

    function test_fuzz_deployCode_create2UsesInitCode(address initialOwner, uint256 initialNumber, bytes32 salt)
        public
    {
        bytes memory args = abi.encode(initialOwner, initialNumber);

        address expected = computeCreate2Address(OBSERVER_WITH_ARGS_BYTECODE, args, salt);
        address instance = Proxify.deployCode(OBSERVER_WITH_ARGS_PATH, args, salt);

        assertContract(instance);
        assertEq(instance, expected);
    }

    function deployCode(string calldata artifactPath, bytes32 salt) external returns (address) {
        return Proxify.deployCode(artifactPath, salt);
    }
}
