// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {GreeterV1, GreeterV2} from "test/mocks/Greeter.sol";

contract GreeterV1Proxiable is GreeterV1, UUPSUpgradeable {
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}
}

contract GreeterV2Proxiable is GreeterV2, UUPSUpgradeable {
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}
}
