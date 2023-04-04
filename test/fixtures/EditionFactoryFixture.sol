// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Test, console2} from "forge-std/Test.sol";

import {SingleBatchEdition} from "nft-editions/SingleBatchEdition.sol";

import {Attestation, SignedAttestation} from "src/interfaces/IShowtimeVerifier.sol";
import {EditionFactory, EditionData} from "src/editions/EditionFactory.sol";
import {ShowtimeVerifier} from "src/ShowtimeVerifier.sol";

import {ShowtimeVerifierFixture} from "test/fixtures/ShowtimeVerifierFixture.sol";

library EditionDataWither {
    function withEditionImpl(EditionData memory self, address editionImpl) internal pure returns (EditionData memory) {
        self.editionImpl = editionImpl;
        return self;
    }

    function withCreatorAddr(EditionData memory self, address creatorAddr) internal pure returns (EditionData memory) {
        self.creatorAddr = creatorAddr;
        return self;
    }
}

contract EditionFactoryFixture is Test, ShowtimeVerifierFixture {
    uint256 internal constant ROYALTY_BPS = 1000;
    address internal immutable SINGLE_BATCH_EDITION_IMPL = address(new SingleBatchEdition());
    EditionData internal DEFAULT_EDITION_DATA;

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

        // configure default edition data
        DEFAULT_EDITION_DATA = EditionData({
            editionImpl: SINGLE_BATCH_EDITION_IMPL,
            creatorAddr: creator,
            minterAddr: address(editionFactory),
            name: "name",
            description: "description",
            animationUrl: "animationUrl",
            imageUrl: "imageUrl",
            royaltyBPS: ROYALTY_BPS,
            externalUrl: "externalUrl",
            creatorName: "creatorName",
            tags: "tag1,tag2"
        });
    }

    function getVerifier() public view override returns (ShowtimeVerifier) {
        return verifier;
    }

    /// @dev takes care of pranking the relayer
    function createWithBatch(
        EditionData memory editionData,
        SignedAttestation memory signedAttestation,
        bytes memory recipients,
        bytes memory expectedError
    ) public returns (address newEdition) {
        // the attestation is bound to a specific relayer
        vm.prank(relayer);

        if (expectedError.length > 0) {
            vm.expectRevert(expectedError);
        }

        newEdition = editionFactory.createWithBatch(editionData, recipients, signedAttestation);
    }

    function createWithBatch(
        bytes memory recipients
    ) public returns (address newEdition) {
        return createWithBatch(DEFAULT_EDITION_DATA, signed(signerKey, getCreatorAttestation()), recipients, "");
    }

    /// @dev takes care of pranking the relayer
    function create(
        EditionData memory editionData,
        SignedAttestation memory signedAttestation,
        bytes memory expectedError
    ) public returns (address newEdition) {
        // the attestation is bound to a specific relayer
        vm.prank(relayer);

        if (expectedError.length > 0) {
            vm.expectRevert(expectedError);
        }

        newEdition = editionFactory.create(editionData, signedAttestation);
    }

    function create(EditionData memory editionData) public returns (address newEdition) {
        return create(editionData, signed(signerKey, getCreatorAttestation(editionData)), "");
    }

    function create() public returns (address newEdition) {
        return create(DEFAULT_EDITION_DATA, signed(signerKey, getCreatorAttestation()), "");
    }

    function getCreatorAttestation() public view returns (Attestation memory) {
        return getCreatorAttestation(DEFAULT_EDITION_DATA);
    }

    function getCreatorAttestation(EditionData memory editionData)
        public
        view
        returns (Attestation memory creatorAttestation)
    {
        uint256 editionId = getEditionId(editionData);
        address editionAddr = getExpectedEditionAddr(editionData.editionImpl, editionId);

        creatorAttestation = Attestation({
            context: getExpectedContext(),
            beneficiary: getBeneficiary(editionAddr, relayer),
            validUntil: block.timestamp + 2 minutes,
            nonce: verifier.nonces(editionData.creatorAddr)
        });
    }

    function getExpectedContext() public view returns (address) {
        return address(editionFactory);
    }

    function getEditionId(EditionData memory editionData) public view returns (uint256) {
        return editionFactory.getEditionId(editionData);
    }

    function getEditionId() public view returns (uint256) {
        return getEditionId(DEFAULT_EDITION_DATA);
    }

    function getExpectedEditionAddr(address editionImpl, uint256 editionId) public view returns (address) {
        return address(editionFactory.getEditionAtId(editionImpl, editionId));
    }

    function getExpectedEditionAddr() public view returns (address) {
        return getExpectedEditionAddr(SINGLE_BATCH_EDITION_IMPL, getEditionId());
    }

    function getBeneficiary(address edition, address msgSender) public view returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(edition, msgSender)))));
    }

    function getBeneficiary() public view returns (address) {
        return getBeneficiary(getExpectedEditionAddr(), relayer);
    }
}
