// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Test} from "forge-std/Test.sol";

import {SingleBatchEdition} from "nft-editions/SingleBatchEdition.sol";

import {Attestation, SignedAttestation} from "src/interfaces/IShowtimeVerifier.sol";
import {EditionFactory, EditionData} from "src/editions/EditionFactory.sol";
import {ShowtimeVerifier} from "src/ShowtimeVerifier.sol";

import {ShowtimeVerifierFixture} from "test/fixtures/ShowtimeVerifierFixture.sol";

contract EditionFactoryFixture is Test, ShowtimeVerifierFixture {
    uint256 internal constant ROYALTY_BPS = 1000;
    address internal immutable SINGLE_BATCH_EDITION_IMPL = address(new SingleBatchEdition());
    EditionData internal DEFAULT_EDITION_DATA = EditionData(
        "name", "description", "animationUrl", "imageUrl", ROYALTY_BPS, "externalUrl", "creatorName", "tag1,tag2"
    );

    EditionFactory internal editionFactory;
    ShowtimeVerifier internal verifier;

    address creator = makeAddr("creator");
    address relayer = makeAddr("relayer");
    address verifierOwner = makeAddr("verifierOwner");
    address signerAddr;
    uint256 signerKey;

    function __EditionFactoryFixture_setUp() internal {
        // configure verifier
        verifier = new ShowtimeVerifier(verifierOwner);
        (signerAddr, signerKey) = makeAddrAndKey("signer");
        vm.prank(verifierOwner);
        verifier.registerSigner(signerAddr, 7);

        // configure editionFactory
        editionFactory = new EditionFactory(address(verifier));
    }

    function getVerifier() public view override returns (ShowtimeVerifier) {
        return verifier;
    }

    function createEdition(
        address editionImpl,
        SignedAttestation memory signedAttestation,
        bytes memory recipients,
        bytes memory expectedError
    ) public returns (SingleBatchEdition newEdition) {
        // anyone can broadcast the transaction as long as it has the right signed attestation
        vm.prank(relayer);

        if (expectedError.length > 0) {
            vm.expectRevert(expectedError);
        }

        newEdition = SingleBatchEdition(
            editionFactory.createEdition(
                editionImpl, DEFAULT_EDITION_DATA, recipients, signedAttestation
            )
        );
    }

    function createEdition(
        SignedAttestation memory signedAttestation,
        bytes memory recipients,
        bytes memory expectedError
    ) public returns (SingleBatchEdition newEdition) {
        return createEdition(SINGLE_BATCH_EDITION_IMPL, signedAttestation, recipients, expectedError);
    }


    function createEdition(Attestation memory attestation, bytes memory recipients, bytes memory expectedError)
        public
        returns (SingleBatchEdition)
    {
        return createEdition(SINGLE_BATCH_EDITION_IMPL, signed(signerKey, attestation), recipients, expectedError);
    }

    function createEdition(Attestation memory attestation, bytes memory recipients)
        public
        returns (SingleBatchEdition)
    {
        return createEdition(attestation, recipients, "");
    }

    function getCreatorAttestation() public view returns (Attestation memory creatorAttestation) {
        return getCreatorAttestation(creator);
    }

    function getCreatorAttestation(address creatorAddr) public view returns (Attestation memory creatorAttestation) {
        return getCreatorAttestation(SINGLE_BATCH_EDITION_IMPL, DEFAULT_EDITION_DATA, creatorAddr);
    }

    function getCreatorAttestation(address editionImpl, EditionData memory editionData, address creatorAddr)
        public
        view
        returns (Attestation memory creatorAttestation)
    {
        // generate a valid attestation for the default edition data
        uint256 editionId = editionFactory.getEditionId(editionData, creatorAddr);
        address editionAddr = address(editionFactory.getEditionAtId(editionImpl, editionId));

        creatorAttestation = Attestation({
            context: editionAddr,
            beneficiary: creatorAddr,
            validUntil: block.timestamp + 2 minutes,
            nonce: verifier.nonces(creator)
        });
    }
}
