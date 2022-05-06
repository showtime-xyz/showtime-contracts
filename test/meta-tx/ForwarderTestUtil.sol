// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { IForwarder } from "gsn/forwarder/Forwarder.sol";

import { ShowtimeForwarder, Forwarder } from "src/meta-tx/ShowtimeForwarder.sol";

import { DSTest } from "ds-test/test.sol";
import { Hevm } from "test/Hevm.sol";

contract ForwarderTestUtil is DSTest {
    Hevm private constant hevm = Hevm(HEVM_ADDRESS);

    bytes32 internal constant FORWARDREQUEST_TYPE_HASH = keccak256(
        "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data,uint256 validUntilTime)");

    function getDomainSeparator(Forwarder forwarder, string memory name, string memory version)
        internal view returns (bytes32 domainHash)
    {
        uint256 chainId;
        /* solhint-disable-next-line no-inline-assembly */
        assembly { chainId := chainid() }

        bytes memory domainValue = abi.encode(
            keccak256(bytes(forwarder.EIP712_DOMAIN_TYPE())),
            keccak256(bytes(name)),
            keccak256(bytes(version)),
            chainId,
            address(forwarder));

        domainHash = keccak256(domainValue);
    }

    function signAndExecute(
        Forwarder forwarder,
        uint256 privateKey,
        IForwarder.ForwardRequest memory req,
        bytes memory expectedError) internal returns (bool success, bytes memory ret)
    {
        bytes32 domainSeparator = getDomainSeparator(forwarder, "showtime.io", "1");

        bytes32 digest = keccak256(abi.encodePacked(
                "\x19\x01", domainSeparator,
                keccak256(forwarder._getEncoded(req, FORWARDREQUEST_TYPE_HASH, ""))
        ));

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(privateKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        if (expectedError.length > 0) {
            hevm.expectRevert(expectedError);
        }

        (success, ret) = forwarder.execute{value: req.value}(
            req,
            domainSeparator,
            FORWARDREQUEST_TYPE_HASH,
            "",
            sig);
    }

    // from https://github.com/GNSPS/solidity-bytes-utils/blob/6458fb2780a3092bc756e737f246be1de6d3d362/contracts/BytesLib.sol
    function toUint256(bytes memory _bytes, uint256 _start) internal pure returns (uint256) {
        require(_bytes.length >= _start + 32, "toUint256_outOfBounds");
        uint256 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x20), _start))
        }

        return tempUint;
    }
}

