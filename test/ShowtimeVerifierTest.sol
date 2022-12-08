// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

import {Attestation, SignedAttestation} from "src/interfaces/IShowtimeVerifier.sol";
import {ShowtimeVerifier} from "src/ShowtimeVerifier.sol";

import {ShowtimeVerifierFixture} from "./fixtures/ShowtimeVerifierFixture.sol";

contract ShowtimeVerifierTest is Test, ShowtimeVerifierFixture {
    event SignerAdded(address signer, uint256 validUntil);
    event SignerRevoked(address signer);
    event ManagerUpdated(address newmanager);

    address internal owner;
    address internal manager;
    address internal alice;
    address internal bob;

    uint256 internal signerKey;
    address internal signer;

    uint256 internal badActorKey;
    address internal badActor;

    ShowtimeVerifier internal verifier;

    Attestation internal attestation;

    function setUp() public {
        owner = makeAddr("owner");
        manager = makeAddr("manager");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        (signer, signerKey) = makeAddrAndKey("signer");
        (badActor, badActorKey) = makeAddrAndKey("badActor");

        vm.startPrank(owner);
        verifier = new ShowtimeVerifier(owner);

        vm.expectEmit(true, false, false, false);
        emit SignerAdded(signer, 0);
        verifier.registerSigner(signer, 42);

        vm.expectEmit(true, true, true, true);
        emit ManagerUpdated(manager);
        verifier.setManager(manager);
        vm.stopPrank();

        attestation = Attestation({beneficiary: bob, context: address(0), nonce: 0, validUntil: reasonableValidUntil()});
    }

    function reasonableValidUntil() public view returns (uint256) {
        return block.timestamp + verifier.MAX_ATTESTATION_VALIDITY_SECONDS() / 2;
    }

    function getVerifier() public view override returns (ShowtimeVerifier) {
        return verifier;
    }

    /*//////////////////////////////////////////////////////////////
                            VERIFICATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function testHappyPath() public {
        assertTrue(verifier.verify(signed(signerKey, attestation)));
    }

    function testSignerNotRegistered() public {
        // when signed by a non-registered signer
        SignedAttestation memory signedAttestation =
            SignedAttestation({attestation: attestation, signature: sign(badActorKey, attestation)});

        // then verification fails (with the expected signer)
        vm.expectRevert(abi.encodeWithSignature("UnknownSigner()"));
        verifier.verify(signedAttestation);
    }

    function testFailSignatureTamperedWith() public view {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest(attestation));

        // when the signature is tampered with
        r = keccak256(abi.encodePacked(r));

        // then verification fails
        verifier.verify(SignedAttestation({attestation: attestation, signature: abi.encodePacked(r, s, v)}));
    }

    function testExpiredSigner() public {
        // when we are way out in the future
        vm.warp(block.timestamp + 10000 days);

        // then verification fails
        SignedAttestation memory signedAttestation = signed(signerKey, attestation);
        vm.expectRevert(abi.encodeWithSignature("Expired()"));
        verifier.verify(signedAttestation);
    }

    function testRevokedSigner() public {
        // when the signer is revoked
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit SignerRevoked(signer);
        verifier.revokeSigner(signer);

        // then verification fails
        SignedAttestation memory signedAttestation = signed(signerKey, attestation);
        vm.expectRevert(abi.encodeWithSignature("UnknownSigner()"));
        verifier.verify(signedAttestation);
    }

    function testArbitraryTypeHash() public {
        string memory newType = "ValentineCard(address from,address to,string message)";
        bytes32 newTypeHash = keccak256(abi.encodePacked(newType));

        bytes memory encodedStruct =
            abi.encodePacked(uint256(uint160(bob)), uint256(uint160(alice)), keccak256("I love you"));

        bytes32 structHash = keccak256(abi.encodePacked(newTypeHash, encodedStruct));
        bytes32 _digest = keccak256(abi.encodePacked("\x19\x01", verifier.domainSeparator(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, _digest);

        Attestation memory _attestation =
            Attestation({beneficiary: bob, context: address(0), nonce: 0, validUntil: reasonableValidUntil()});
        assertTrue(verifier.verify(_attestation, newTypeHash, encodedStruct, abi.encodePacked(r, s, v)));
    }

    /*//////////////////////////////////////////////////////////////
                    ATTESTATION VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testExpired() public {
        // when the attestation validUntil timestamp is in the past
        attestation.validUntil = block.timestamp - 1;

        // then the verification fails
        SignedAttestation memory signedAttestation = signed(signerKey, attestation);
        vm.expectRevert(abi.encodeWithSignature("Expired()"));
        verifier.verify(signedAttestation);
    }

    function testDeadlineTooLong() public {
        // when the attestation validUntil timestamp is too far in the future
        attestation.validUntil = block.timestamp + verifier.MAX_ATTESTATION_VALIDITY_SECONDS() + 1;

        // then the verification fails
        SignedAttestation memory signedAttestation = signed(signerKey, attestation);
        vm.expectRevert(abi.encodeWithSignature("DeadlineTooLong()"));
        verifier.verify(signedAttestation);
    }

    /*//////////////////////////////////////////////////////////////
                        NONCE VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testBurnIncrementsNonce() public {
        assertEq(verifier.nonces(attestation.beneficiary), 0);

        // when we call verifyAndBurn
        verifier.verifyAndBurn(signed(signerKey, attestation));

        // then the nonce is incremented
        assertEq(verifier.nonces(attestation.beneficiary), 1);

        // if we try to reuse the same attestation, nonce verification fails
        SignedAttestation memory signedAttestation = signed(signerKey, attestation);
        vm.expectRevert(abi.encodeWithSignature("BadNonce(uint256,uint256)", 1, 0));
        verifier.verify(signedAttestation);
    }

    function testBurnIncrementsNonce100Times() public {
        for (uint160 i = 0; i < 100; i++) {
            address context = address(i);
            attestation.context = context;
            attestation.nonce = i;
            assertEq(verifier.nonces(attestation.beneficiary), i);

            // when we call verifyAndBurn
            verifier.verifyAndBurn(signed(signerKey, attestation));

            // then the nonce is incremented
            assertEq(verifier.nonces(attestation.beneficiary), i + 1);

            // if we try to reuse the same attestation, nonce verification fails
            SignedAttestation memory signedAttestation = signed(signerKey, attestation);
            vm.expectRevert(abi.encodeWithSignature("BadNonce(uint256,uint256)", i + 1, i));
            verifier.verify(signedAttestation);
        }
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

    function testBadActorCanNotSetmanager() public {
        vm.prank(badActor);
        vm.expectRevert("Ownable: caller is not the owner");
        verifier.setManager(badActor);
    }

    function testOverridingSignerValidity() public {
        uint256 startingValidUntil = verifier.signerValidity(signer);

        // when we register the signer again with a bigger validity period
        vm.prank(manager);
        verifier.registerSigner(signer, 365);

        // then the new validity period is used
        uint256 extendedValidUntil = verifier.signerValidity(signer);
        assertLt(startingValidUntil, extendedValidUntil);

        // when we register the signer again with a smaller validity period
        vm.prank(manager);
        uint256 restrictedValidUntil = verifier.registerSigner(signer, 1);
        assertLt(restrictedValidUntil, extendedValidUntil);
    }

    function testBadActorCanNotRegisterAndRevoke() public {
        vm.prank(badActor);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        verifier.registerAndRevoke(badActor, signer, 365);
    }

    function testRegisterAndRevoke() public {
        address newSigner = makeAddr("newSigner");

        // when the manager calls registerAndRevoke
        vm.expectEmit(true, false, false, false);
        emit SignerAdded(newSigner, 0);
        emit SignerRevoked(signer);
        vm.prank(manager);
        verifier.registerAndRevoke(newSigner, signer, 365);

        // then the old signer is revoked and the new signer is registered
        assertEq(verifier.signerValidity(signer), 0);
        assertGt(verifier.signerValidity(newSigner), 0);
    }
}
