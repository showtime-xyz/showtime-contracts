// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

import {StdUtils} from "forge-std/StdUtils.sol";

abstract contract Create2Helper is StdUtils {
    address public constant DEFAULT_CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    /// @dev returns the hash of the init code (creation code + no args) used in CREATE2 with no constructor arguments
    /// @param creationCode the creation code of a contract C, as returned by type(C).creationCode
    function initCodeHashNoConstructorArgs(bytes memory creationCode) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(creationCode));
    }

    /// @dev returns the hash of the init code (creation code + ABI-encoded args) used in CREATE2
    /// @param creationCode the creation code of a contract C, as returned by type(C).creationCode
    /// @param args the ABI-encoded arguments to the constructor of C
    function initCodeHash(bytes memory creationCode, bytes memory args) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(creationCode, args));
    }

    /// @dev returns the address of a contract created with CREATE2 using the default CREATE2 deployer
    function computeCreate2Address(bytes32 salt, bytes32 _initCodeHash) internal pure returns (address) {
        return computeCreate2Address(salt, _initCodeHash, DEFAULT_CREATE2_DEPLOYER);
    }
}
