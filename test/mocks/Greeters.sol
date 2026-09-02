// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

abstract contract GreeterStorage {
    address public owner;
    string public greeting;
}

contract GreeterV1 is GreeterStorage, Initializable {
    error Unauthorized();

    constructor() {
        _disableInitializers();
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    function initialize(address initialOwner, string memory initialGreeting) external payable initializer {
        require(initialOwner != address(0));
        owner = initialOwner;
        greeting = initialGreeting;
    }

    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function version() external view returns (uint64) {
        return _getInitializedVersion();
    }
}

contract GreeterV2 is GreeterStorage, Initializable {
    error Unauthorized();

    constructor() {
        _disableInitializers();
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    function initialize(address initialOwner, string memory initialGreeting) external payable initializer {
        require(initialOwner != address(0));
        owner = initialOwner;
        greeting = initialGreeting;
    }

    function resetGreeting() external payable reinitializer(2) {
        greeting = "resetted";
    }

    function setGreeting(string memory newGreeting) external payable {
        greeting = newGreeting;
    }

    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function version() external view returns (uint64) {
        return _getInitializedVersion();
    }
}

contract GreeterV1Proxiable is GreeterV1, UUPSUpgradeable {
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}
}

contract GreeterV2Proxiable is GreeterV2, UUPSUpgradeable {
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}
}
