// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

import { Attestation } from "src/interfaces/IShowtimeVerifier.sol";
import { ShowtimeVerifier } from "src/ShowtimeVerifier.sol";

contract ShowtimeVerifierTest is Test {
    event SignerAdded(address signer, uint256 validUntil);
    event SignerRevoked(address signer);
    event SignerManagerUpdated(address newSignerManager);

    address internal owner;
    address internal signerManager;
    address internal alice;
    address internal bob;

    uint256 internal signerKey;
    address internal signer;

    uint256 internal badActorKey;
    address internal badActor;

    ShowtimeVerifier internal verifier;

    Attestation internal attestation;

    // inspired by https://twitter.com/eth_call/status/1549792921976803328
    function mkaddr(string memory name) public returns(uint256 Key, address addr) {
        Key = uint256(keccak256(bytes(name)));
        addr = vm.addr(Key);
        vm.label(addr, name);
    }

    function digest(Attestation memory _attestation) public view returns (bytes32) {
        bytes memory encodedStruct = verifier.encode(_attestation);
        bytes32 structHash = keccak256(abi.encodePacked(verifier.REQUEST_TYPE_HASH(), encodedStruct));
        return keccak256(abi.encodePacked("\x19\x01", verifier.domainSeparator(), structHash));
    }

    function setUp() public {
        (, owner) = mkaddr("owner");
        (, signerManager) = mkaddr("signerManager");
        (, alice) = mkaddr("alice");
        (, bob) = mkaddr("bob");
        (signerKey, signer) = mkaddr("signer");
        (badActorKey, badActor) = mkaddr("badActor");

        vm.startPrank(owner);
        verifier = new ShowtimeVerifier(owner);

        vm.expectEmit(true, false, false, false);
        emit SignerAdded(signer, 0);
        verifier.registerSigner(signer, 1);

        vm.expectEmit(true, true, true, true);
        emit SignerManagerUpdated(signerManager);
        verifier.setSignerManager(signerManager);
        vm.stopPrank();

        attestation = Attestation({
            beneficiary: bob,
            context: address(0),
            nonce: 0,
            validUntil: reasonableValidUntil()
        });
    }

    function reasonableValidUntil() public view returns (uint256) {
        return block.timestamp + verifier.MAX_ATTESTATION_VALIDITY_SECONDS() / 2;
    }

    function sign(uint256 key, Attestation memory someAttestation) public returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest(someAttestation));
        return abi.encodePacked(r, s, v);
    }

    /*//////////////////////////////////////////////////////////////
                            VERIFICATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function testHappyPath() public {
        assertTrue(verifier.verify(attestation, sign(signerKey, attestation)));
    }


    function testSignerNotRegistered() public {
        // when signed by a non-registered signer
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(badActorKey, digest(attestation));

        // then verification fails (with the expected signer)
        vm.expectRevert(abi.encodeWithSignature("UnknownSigner(address)", badActor));
        verifier.verify(attestation, abi.encodePacked(r, s, v));
    }


    function testFailSignatureTamperedWith() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest(attestation));

        // when the signature is tampered with
        r = keccak256(abi.encodePacked(r));

        // then verification fails
        verifier.verify(attestation, abi.encodePacked(r, s, v));
    }


    function testExpiredSigner() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest(attestation));

        // when we are way out in the future
        vm.warp(block.timestamp + 10000 days);

        // then verification fails
        vm.expectRevert(abi.encodeWithSignature("Expired()"));
        verifier.verify(attestation, abi.encodePacked(r, s, v));
    }


    function testRevokedSigner() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest(attestation));

        // when the signer is revoked
        vm.prank(signerManager);
        vm.expectEmit(true, true, true, true);
        emit SignerRevoked(signer);
        verifier.revokeSigner(signer);

        // then verification fails
        vm.expectRevert(abi.encodeWithSignature("UnknownSigner(address)", signer));
        verifier.verify(attestation, abi.encodePacked(r, s, v));
    }


    function testArbitraryTypeHash() public {
        string memory newType = "ValentineCard(address from,address to,string message)";
        bytes32 newTypeHash = keccak256(abi.encodePacked(newType));

        bytes memory encodedStruct = abi.encodePacked(
            uint256(uint160(bob)),
            uint256(uint160(alice)),
            keccak256("I love you")
        );

        bytes32 structHash = keccak256(abi.encodePacked(newTypeHash, encodedStruct));
        bytes32 _digest = keccak256(abi.encodePacked("\x19\x01", verifier.domainSeparator(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, _digest);

        Attestation memory _attestation = Attestation({
            beneficiary: bob,
            context: address(0),
            nonce: 0,
            validUntil: reasonableValidUntil()
        });
        assertTrue(verifier.verify(_attestation, newTypeHash, encodedStruct, abi.encodePacked(r, s, v)));
    }

    /*//////////////////////////////////////////////////////////////
                    ATTESTATION VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testExpired() public {
        // when the attestation validUntil timestamp is in the past
        attestation.validUntil = block.timestamp - 1;

        // then the verification fails
        vm.expectRevert(abi.encodeWithSignature("Expired()"));
        verifier.verify(attestation, "");
    }


    function testDeadlineTooLong() public {
        // when the attestation validUntil timestamp is too far in the future
        attestation.validUntil = block.timestamp + verifier.MAX_ATTESTATION_VALIDITY_SECONDS() + 1;

        // then the verification fails
        vm.expectRevert(abi.encodeWithSignature("DeadlineTooLong()"));
        verifier.verify(attestation, "");
    }

    /*//////////////////////////////////////////////////////////////
                        NONCE VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testBurnIncrementsNonce() public {
        assertEq(verifier.nonces(attestation.context, attestation.beneficiary), 0);

        // when we call verifyAndBurn
        verifier.verifyAndBurn(attestation, sign(signerKey, attestation));

        // then the nonce is incremented
        assertEq(verifier.nonces(attestation.context, attestation.beneficiary), 1);

        // if we try to reuse the same attestation, nonce verification fails
        bytes memory signature = sign(signerKey, attestation);
        vm.expectRevert(abi.encodeWithSignature("BadNonce(uint256,uint256)", 1, 0));
        verifier.verify(attestation, signature);
    }


    /*//////////////////////////////////////////////////////////////
                            ADMIN TESTS
    //////////////////////////////////////////////////////////////*/

    function testBadActorCanNotRegisterSigner() public {
        vm.prank(badActor);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        verifier.registerSigner(badActor, 365);
    }


    function testBadActorCanNotRevokeSigner() public {
        vm.prank(badActor);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        verifier.revokeSigner(signer);
    }


    function testBadActorCanNotSetSignerManager() public {
        vm.prank(badActor);
        vm.expectRevert("Ownable: caller is not the owner");
        verifier.setSignerManager(badActor);
    }
}
