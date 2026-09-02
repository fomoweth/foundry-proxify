// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ObserverNoArgs {
    address public msgSender;
    uint256 public msgValue;

    constructor() payable {
        msgSender = msg.sender;
        msgValue = msg.value;
    }
}

contract ObserverWithArgs {
    address public msgSender;
    uint256 public msgValue;
    address public owner;
    uint256 public number;

    constructor(address initialOwner, uint256 initialNumber) payable {
        owner = initialOwner;
        number = initialNumber;
        msgSender = msg.sender;
        msgValue = msg.value;
    }
}

contract ImplementationReverter {
    error ImplementationError();

    function implementation() external pure returns (address) {
        revert ImplementationError();
    }
}

contract CustomReverter {
    error CustomError();

    constructor() {
        revert CustomError();
    }
}

contract StringReverter {
    constructor() {
        revert("constructor revert");
    }
}

contract PanicReverter {
    constructor() {
        uint256 x = uint256(0) / uint256(0);
        x;
    }
}

contract EmptyReverter {
    constructor() {
        assembly ("memory-safe") {
            revert(0x00, 0x00)
        }
    }
}

contract EmptyRuntime {
    constructor() {
        assembly ("memory-safe") {
            return(0x00, 0x00)
        }
    }
}

contract EmptyRevert {
    fallback() external payable {
        assembly ("memory-safe") {
            revert(0x00, 0x00)
        }
    }
}

contract EmptyReturn {
    fallback() external payable {
        assembly ("memory-safe") {
            return(0x00, 0x00)
        }
    }
}
