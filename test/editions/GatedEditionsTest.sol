// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { SingleEditionMintableCreator } from "@zoralabs/nft-editions-contracts/contracts/SingleEditionMintableCreator.sol";
import { SingleEditionMintable } from "@zoralabs/nft-editions-contracts/contracts/SingleEditionMintable.sol";
import { SharedNFTLogic } from "@zoralabs/nft-editions-contracts/contracts/SharedNFTLogic.sol";
import { Test } from "lib/forge-std/src/Test.sol";

import { TimeCop } from "src/editions/TimeCop.sol";
import { GatedEditionMinter } from "src/editions/GatedEditionMinter.sol";
import { GatedEditionCreator } from "src/editions/GatedEditionCreator.sol";
import "test/fixtures/ShowtimeVerifierFixture.sol";

contract GatedEditionsTest is Test, ShowtimeVerifierFixture {
    uint256 constant EDITION_SIZE = 100;
    uint256 constant ROYALTY_BPS = 1000;
    uint256 constant CLAIM_DURATION_WINDOW_SECONDS = 48 hours;

    GatedEditionCreator gatedEditionCreator;
    GatedEditionMinter gatedEditionMinter;
    TimeCop timeCop;
    ShowtimeVerifier verifier;
    GatedEditionMinter minter;

    address creator = makeAddr("creator");
    address relayer = makeAddr("relayer");
    address verifierOwner = makeAddr("verifierOwner");
    address claimer = makeAddr("claimer");
    address badActor = makeAddr("badActor");
    address signerAddr;
    uint256 signerKey;

    function setUp() public {
        timeCop = new TimeCop(365 days);

        // configure verifier
        verifier = new ShowtimeVerifier(verifierOwner);
        (signerAddr, signerKey) = makeAddrAndKey("signer");
        vm.prank(verifierOwner);
        verifier.registerSigner(signerAddr, 7);

        // configure minter
        minter = new GatedEditionMinter(verifier, timeCop);

        // configure editionCreator
        SingleEditionMintable editionImpl = new SingleEditionMintable(new SharedNFTLogic());
        SingleEditionMintableCreator editionCreator = new SingleEditionMintableCreator(address(editionImpl));

        // configure gatedEditionCreator
        gatedEditionCreator = new GatedEditionCreator(address(editionCreator), address(minter), address(timeCop));
    }

    function getVerifier() public view override returns (ShowtimeVerifier) {
        return verifier;
    }

    function createEdition(SignedAttestation memory signedAttestation, bytes memory expectedError)
        public
        returns (SingleEditionMintable edition)
    {
        // anyone can broadcast the transaction as long as it has the right signed attestation
        vm.prank(relayer);

        if (expectedError.length > 0) {
            vm.expectRevert(expectedError);
        }

        edition = SingleEditionMintable(
            gatedEditionCreator.createEdition(
                "name",
                "description",
                "animationUrl",
                "imageUrl",
                EDITION_SIZE,
                ROYALTY_BPS,
                CLAIM_DURATION_WINDOW_SECONDS,
                signedAttestation
            )
        );
    }

    function createEdition(Attestation memory attestation, bytes memory expectedError)
        public
        returns (SingleEditionMintable edition)
    {
        return createEdition(signed(signerKey, attestation), expectedError);
    }

    function createEdition(Attestation memory attestation) public returns (SingleEditionMintable) {
        return createEdition(attestation, "");
    }

    function getCreatorAttestion() public view returns (Attestation memory creatorAttestation) {
        // generate a valid attestation
        creatorAttestation = Attestation({
            context: address(gatedEditionCreator),
            beneficiary: creator,
            validUntil: block.timestamp + 2 minutes,
            nonce: verifier.nonces(creator)
        });
    }

    function getClaimerAttestion(SingleEditionMintable edition)
        public
        view
        returns (Attestation memory creatorAttestation)
    {
        // generate a valid attestation
        creatorAttestation = Attestation({
            context: address(edition),
            beneficiary: claimer,
            validUntil: block.timestamp + 2 minutes,
            nonce: verifier.nonces(claimer)
        });
    }

    /*//////////////////////////////////////////////////////////////
                            VERIFICATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function testCreateEditionHappyPath() public {
        // create a new edition
        SingleEditionMintable edition = createEdition(getCreatorAttestion());

        // the time limit has been set
        assertEq(timeCop.timeLimits(address(edition)), block.timestamp + CLAIM_DURATION_WINDOW_SECONDS);

        // the edition is owned by the creator
        assertEq(edition.owner(), creator);

        // the creator automatically received the first token
        assertEq(edition.balanceOf(creator), 1);
        assertEq(edition.balanceOf(claimer), 0);

        // the edition is mintable by the global minter
        Attestation memory claimerAttestation = Attestation({
            context: address(edition),
            beneficiary: claimer,
            validUntil: block.timestamp + 2 minutes,
            nonce: verifier.nonces(claimer)
        });

        vm.prank(relayer);
        minter.mintEdition(signed(signerKey, claimerAttestation));

        // the claimer received the second token
        assertEq(edition.balanceOf(claimer), 1);
    }

    function testCreateEditionWithWrongContext() public {
        // when we have an attestation with the wrong context
        Attestation memory creatorAttestation = getCreatorAttestion();
        creatorAttestation.context = address(this); // nonsense context

        // creating a new edition should fail
        createEdition(creatorAttestation, abi.encodeWithSignature("UnexpectedContext(address)", address(this)));
    }

    function testCreateEditionWithWrongNonce() public {
        // when we have an attestation with the wrong context
        Attestation memory creatorAttestation = getCreatorAttestion();

        uint256 badNonce = uint256(uint160(address(this)));
        creatorAttestation.nonce = badNonce;

        // creating a new edition should fail
        createEdition(creatorAttestation, abi.encodeWithSignature("BadNonce(uint256,uint256)", 0, badNonce));
    }

    function testCanNotReuseCreatorAttestation() public {
        Attestation memory creatorAttestation = getCreatorAttestion();

        // first one should work
        createEdition(creatorAttestation);

        // second one should fail
        createEdition(creatorAttestation, abi.encodeWithSignature("BadNonce(uint256,uint256)", 1, 0));
    }

    function testCanNotHijackCreatorAttestation() public {
        SignedAttestation memory signedAttestation = signed(signerKey, getCreatorAttestion());

        // when the badActor tries to steal the attestation
        signedAttestation.attestation.beneficiary = badActor;

        // it does not work
        createEdition(signedAttestation, abi.encodeWithSignature("UnknownSigner()"));
    }

    function testCanNotReuseClaimerAttestation() public {
        // setup
        SingleEditionMintable edition = createEdition(getCreatorAttestion());
        Attestation memory claimerAttestation = getClaimerAttestion(edition);
        SignedAttestation memory signedAttestation = signed(signerKey, claimerAttestation);

        // first one should work
        minter.mintEdition(signedAttestation);

        // second one should fail
        vm.expectRevert(abi.encodeWithSignature("BadNonce(uint256,uint256)", 1, 0));
        minter.mintEdition(signedAttestation);
    }
}
