// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { Edition, IEdition } from "nft-editions/Edition.sol";
import { Test } from "lib/forge-std/src/Test.sol";
import "nft-editions/interfaces/Errors.sol";

import { GatedEditionMinter } from "src/editions/GatedEditionMinter.sol";
import { GatedEditionCreator } from "src/editions/GatedEditionCreator.sol";
import "test/fixtures/ShowtimeVerifierFixture.sol";

contract GatedEditionsTest is Test, ShowtimeVerifierFixture {
    uint256 constant EDITION_SIZE = 100;
    uint256 constant ROYALTY_BPS = 1000;
    uint256 constant CLAIM_DURATION_WINDOW_SECONDS = 48 hours;

    GatedEditionCreator gatedEditionCreator;
    GatedEditionMinter gatedEditionMinter;
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
        // configure verifier
        verifier = new ShowtimeVerifier(verifierOwner);
        (signerAddr, signerKey) = makeAddrAndKey("signer");
        vm.prank(verifierOwner);
        verifier.registerSigner(signerAddr, 7);

        // configure minter
        minter = new GatedEditionMinter(verifier);

        // configure editionCreator
        Edition editionImpl = new Edition();

        // configure gatedEditionCreator
        gatedEditionCreator = new GatedEditionCreator(address(editionImpl), address(minter));
    }

    function getVerifier() public view override returns (ShowtimeVerifier) {
        return verifier;
    }

    function createEdition(SignedAttestation memory signedAttestation, bytes memory expectedError)
        public
        returns (Edition edition)
    {
        // anyone can broadcast the transaction as long as it has the right signed attestation
        vm.prank(relayer);

        if (expectedError.length > 0) {
            vm.expectRevert(expectedError);
        }

        edition = Edition(
            address(
                gatedEditionCreator.createEdition(
                    "name",
                    "description",
                    "animationUrl",
                    "imageUrl",
                    EDITION_SIZE,
                    ROYALTY_BPS,
                    CLAIM_DURATION_WINDOW_SECONDS,
                    "externalUrl",
                    "creatorName",
                    signedAttestation
                )
            )
        );
    }

    function createEdition(Attestation memory attestation, bytes memory expectedError)
        public
        returns (Edition edition)
    {
        return createEdition(signed(signerKey, attestation), expectedError);
    }

    function createEdition(Attestation memory attestation) public returns (Edition) {
        return createEdition(attestation, "");
    }

    function getCreatorAttestation() public view returns (Attestation memory creatorAttestation) {
        return getCreatorAttestation(creator);
    }

    function getCreatorAttestation(address creatorAddr) public view returns (Attestation memory creatorAttestation) {
        // generate a valid attestation
        creatorAttestation = Attestation({
            context: address(gatedEditionCreator),
            beneficiary: creatorAddr,
            validUntil: block.timestamp + 2 minutes,
            nonce: verifier.nonces(creator)
        });
    }

    function getClaimerAttestation(
        Edition edition,
        address _claimer,
        uint256 _validUntil,
        uint256 _nonce
    ) public pure returns (Attestation memory) {
        // generate a valid attestation
        return
            Attestation({ context: address(edition), beneficiary: _claimer, validUntil: _validUntil, nonce: _nonce });
    }

    function getClaimerAttestation(Edition edition) public view returns (Attestation memory) {
        return getClaimerAttestation(edition, claimer, block.timestamp + 2 minutes, verifier.nonces(claimer));
    }

    /*//////////////////////////////////////////////////////////////
                            VERIFICATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function testCreateEditionHappyPath() public {
        // create a new edition
        Edition edition = createEdition(getCreatorAttestation());

        // the edition is owned by the creator
        assertEq(edition.owner(), creator);

        // it has the expected symbol
        assertEq(edition.symbol(), unicode"✦ SHOWTIME");

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

    function testTimeLimitedOpenEdition() public {
        // create a new edition
        Edition edition = createEdition(getCreatorAttestation());

        // warp into the future
        vm.warp(block.timestamp + CLAIM_DURATION_WINDOW_SECONDS + 1);

        // generate a valid claimer attestation
        SignedAttestation memory claimerAttestation = signed(signerKey, getClaimerAttestation(edition));

        // can no longer mint
        vm.expectRevert(abi.encodeWithSelector(TimeLimitReached.selector));
        minter.mintEdition(claimerAttestation);
    }

    function testCanNotCreateEditionWithNoTimeLimit() public {
        // generate a valid attestation
        SignedAttestation memory creatorAttestation = signed(signerKey, getCreatorAttestation());

        vm.expectRevert(abi.encodeWithSelector(GatedEditionCreator.InvalidTimeLimit.selector, 0));
        gatedEditionCreator.createEdition(
            "name",
            "description",
            "animationUrl",
            "imageUrl",
            EDITION_SIZE,
            ROYALTY_BPS,
            0,
            "externalUrl",
            "creatorName",
            creatorAttestation
        );
    }

    function testCanNotCreateEditionWithHugeTimeLimit() public {
        uint256 hugeTimeLimit = 20 * 365 days;

        // generate a valid attestation
        SignedAttestation memory creatorAttestation = signed(signerKey, getCreatorAttestation());

        vm.expectRevert(abi.encodeWithSelector(GatedEditionCreator.InvalidTimeLimit.selector, hugeTimeLimit));
        gatedEditionCreator.createEdition(
            "name",
            "description",
            "animationUrl",
            "imageUrl",
            EDITION_SIZE,
            ROYALTY_BPS,
            hugeTimeLimit,
            "externalUrl",
            "creatorName",
            creatorAttestation
        );
    }

    function testCreateEditionWithWrongContext() public {
        // when we have an attestation with the wrong context
        Attestation memory creatorAttestation = getCreatorAttestation();
        creatorAttestation.context = address(this); // nonsense context

        // creating a new edition should fail
        createEdition(creatorAttestation, abi.encodeWithSignature("UnexpectedContext(address)", address(this)));
    }

    function testCreateEditionWithWrongNonce() public {
        // when we have an attestation with the wrong context
        Attestation memory creatorAttestation = getCreatorAttestation();

        uint256 badNonce = uint256(uint160(address(this)));
        creatorAttestation.nonce = badNonce;

        // creating a new edition should fail
        createEdition(creatorAttestation, abi.encodeWithSignature("BadNonce(uint256,uint256)", 0, badNonce));
    }

    function testCanNotReuseCreatorAttestation() public {
        Attestation memory creatorAttestation = getCreatorAttestation();

        // first one should work
        createEdition(creatorAttestation);

        // second one should fail
        createEdition(creatorAttestation, abi.encodeWithSignature("BadNonce(uint256,uint256)", 1, 0));
    }

    function testCanNotHijackCreatorAttestation() public {
        SignedAttestation memory signedAttestation = signed(signerKey, getCreatorAttestation());

        // when the badActor tries to steal the attestation
        signedAttestation.attestation.beneficiary = badActor;

        // it does not work
        createEdition(signedAttestation, abi.encodeWithSignature("UnknownSigner()"));
    }

    function testCanNotReuseClaimerAttestation() public {
        // setup
        Edition edition = createEdition(getCreatorAttestation());
        Attestation memory claimerAttestation = getClaimerAttestation(edition);
        SignedAttestation memory signedAttestation = signed(signerKey, claimerAttestation);

        // first one should work
        minter.mintEdition(signedAttestation);

        // second one should fail
        vm.expectRevert(abi.encodeWithSignature("BadNonce(uint256,uint256)", 1, 0));
        minter.mintEdition(signedAttestation);
    }

    function testWithGreatAttestationsComesGreatClaims() public {
        Edition edition = createEdition(getCreatorAttestation());

        // can mint once
        minter.mintEdition(signed(signerKey, getClaimerAttestation(edition)));

        // can mint twice
        minter.mintEdition(signed(signerKey, getClaimerAttestation(edition)));

        // can keep minting, as long as we can get freshly signed attestations
        minter.mintEdition(signed(signerKey, getClaimerAttestation(edition)));

        assertEq(edition.balanceOf(claimer), 3);
    }

    function testBatchMintFromSingleClaimer() public {
        // setup
        Edition edition1 = createEdition(getCreatorAttestation(makeAddr("creator1")));
        Edition edition2 = createEdition(getCreatorAttestation(makeAddr("creator2")));
        Edition edition3 = createEdition(getCreatorAttestation(makeAddr("creator3")));

        SignedAttestation[] memory attestations = new SignedAttestation[](3);
        attestations[0] = signed(
            signerKey,
            getClaimerAttestation(edition1, claimer, block.timestamp + 2 minutes, verifier.nonces(claimer))
        );
        attestations[1] = signed(
            signerKey,
            getClaimerAttestation(edition2, claimer, block.timestamp + 2 minutes, verifier.nonces(claimer) + 1)
        );
        attestations[2] = signed(
            signerKey,
            getClaimerAttestation(edition3, claimer, block.timestamp + 2 minutes, verifier.nonces(claimer) + 2)
        );

        // when we batch mint from 3 editions
        minter.mintEditions(attestations);

        // then the claimer receives all the expected tokens
        assertEq(edition1.balanceOf(claimer), 1);
        assertEq(edition2.balanceOf(claimer), 1);
        assertEq(edition3.balanceOf(claimer), 1);

        // and the claimer's nonce has been incremented 3 times
        assertEq(verifier.nonces(claimer), 3);
    }

    function testBatchMintFromMultipleClaimers() public {
        // setup
        Edition edition = createEdition(getCreatorAttestation());

        address claimer1 = makeAddr("claimer1");
        address claimer2 = makeAddr("claimer2");
        address claimer3 = makeAddr("claimer3");

        SignedAttestation[] memory attestations = new SignedAttestation[](3);
        attestations[0] = signed(
            signerKey,
            getClaimerAttestation(edition, claimer1, block.timestamp + 2 minutes, verifier.nonces(claimer1))
        );
        attestations[1] = signed(
            signerKey,
            getClaimerAttestation(edition, claimer2, block.timestamp + 2 minutes, verifier.nonces(claimer2))
        );
        attestations[2] = signed(
            signerKey,
            getClaimerAttestation(edition, claimer3, block.timestamp + 2 minutes, verifier.nonces(claimer3))
        );

        // when we batch mint from 3 editions
        minter.mintEditions(attestations);

        // then each claimer receives the expected tokens
        assertEq(edition.balanceOf(claimer1), 1);
        assertEq(edition.balanceOf(claimer2), 1);
        assertEq(edition.balanceOf(claimer3), 1);
    }
}
