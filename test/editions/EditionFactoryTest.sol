// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {SingleBatchEdition} from "nft-editions/SingleBatchEdition.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import "nft-editions/interfaces/Errors.sol";

import {EditionFactory, EditionData} from "src/editions/EditionFactory.sol";
import {EditionFactoryFixture, EditionDataWither} from "test/fixtures/EditionFactoryFixture.sol";
import {IBatchMintable} from "src/editions/interfaces/IBatchMintable.sol";
import {MockBatchEdition} from "test/fixtures/MockBatchEdition.sol";
import {ShowtimeVerifierFixture, Attestation, SignedAttestation} from "test/fixtures/ShowtimeVerifierFixture.sol";
import "src/editions/interfaces/Errors.sol";

contract EditionFactoryTest is Test, ShowtimeVerifierFixture, EditionFactoryFixture {
    using EditionDataWither for EditionData;

    address batchImpl;

    function setUp() public {
        __EditionFactoryFixture_setUp();

        batchImpl = address(new MockBatchEdition());
    }

    function test_create_nullEditionImplReverts() public {
        uint256 editionId = editionFactory.getEditionId(DEFAULT_EDITION_DATA);

        vm.expectRevert(NullAddress.selector);
        editionFactory.getEditionAtId(address(0), editionId);
    }

    // test that changing the edition impl changes the predicted address
    function test_getEditionAtId_differentEditionImpls() public {
        uint256 editionId = editionFactory.getEditionId(DEFAULT_EDITION_DATA);

        address edition1 = address(editionFactory.getEditionAtId(SINGLE_BATCH_EDITION_IMPL, editionId));
        address edition2 = address(editionFactory.getEditionAtId(address(new SingleBatchEdition()), editionId));

        assertFalse(edition1 == edition2);
    }

    // test that changing the edition impl changes the actual address after create
    function test_create_differentEditionImpls() public {
        // deploy a new edition impl
        address altEditionImpl = address(new SingleBatchEdition());

        // configure edition data to use it
        EditionData memory editionData = DEFAULT_EDITION_DATA.withEditionImpl(altEditionImpl);
        Attestation memory altAttestation = getCreatorAttestation(editionData);
        SignedAttestation memory altSignedAttestation = signed(signerKey, altAttestation);

        address edition1 = address(create());
        address edition2 = address(create(editionData, altSignedAttestation, ""));

        assertFalse(edition1 == edition2);
    }

    // test that we can't reuse a signed attestation with a different edition impl
    function test_create_canNotReuseSignedAttestation() public {
        // a hijacker wants to lift a signed attestation and use it for a different impl address
        address altEditionImpl = address(new SingleBatchEdition());
        SignedAttestation memory ogAttestation = signed(signerKey, getCreatorAttestation());

        EditionData memory editionData = DEFAULT_EDITION_DATA.withEditionImpl(altEditionImpl);
        uint256 editionId = editionFactory.getEditionId(editionData);
        address hijackedAddr = address(editionFactory.getEditionAtId(altEditionImpl, editionId));

        // the creator can create an edition with the original attestation, but a hijacker can not
        // the error says "this attestation is only valid for the original address, not for the hijacked address"
        create(
            editionData,
            ogAttestation,
            abi.encodeWithSignature(
                "AddressMismatch(address,address)",
                getBeneficiary(hijackedAddr, relayer),
                ogAttestation.attestation.beneficiary
            )
        );
    }

    function test_create_canCreateAlternateContract() public {
        address altEditionImpl = address(new MockBatchEdition());

        EditionData memory editionData = DEFAULT_EDITION_DATA.withEditionImpl(altEditionImpl);

        SingleBatchEdition edition =
            SingleBatchEdition(create(editionData, signed(signerKey, getCreatorAttestation(editionData)), ""));

        assertEq(edition.contractURI(), "mock");
    }

    function test_create_multiBatchSupportHappyPath() public {
        EditionData memory editionData = DEFAULT_EDITION_DATA.withEditionImpl(batchImpl);
        address edition = create(editionData);

        bytes memory recipients_1 = abi.encodePacked(address(this));
        bytes memory recipients_2 = abi.encodePacked(address(0x1), address(0x2));

        SignedAttestation memory signedAttestation = signed(signerKey, getCreatorAttestation(editionData));

        vm.prank(relayer);
        uint256 numMinted = editionFactory.mintBatch(edition, recipients_1, signedAttestation);
        assertEq(numMinted, 1);

        // note: the same signed attestation can be used for multiple batches as long as it comes from the same relayer
        // it is a tradeoff to avoid having to sign the recipients list -- the relayer is trusted for the duration
        // of the validity period of the attestation
        vm.prank(relayer);
        numMinted = editionFactory.mintBatch(edition, recipients_2, signedAttestation);
        assertEq(numMinted, 2);
    }

    function test_create_multiBatchSupportWrongContextReverts() public {
        EditionData memory editionData = DEFAULT_EDITION_DATA;
        editionData.editionImpl = batchImpl;

        Attestation memory attestation = getCreatorAttestation(editionData);
        address predicted = attestation.context;

        // tamper with the context before signing
        attestation.context = address(0xC0FFEE);
        SignedAttestation memory signedAttestation = signed(signerKey, attestation);

        vm.expectRevert(abi.encodeWithSignature("AddressMismatch(address,address)", predicted, address(0xC0FFEE)));
        editionFactory.create(editionData, signedAttestation);
    }

    function test_create_multiBatchSupportWrongRelayerReverts() public {
        EditionData memory editionData = DEFAULT_EDITION_DATA.withEditionImpl(batchImpl);
        address edition = create(editionData);

        SignedAttestation memory signedAttestation = signed(signerKey, getCreatorAttestation(editionData));

        // the factory will reject the call because it is not coming from the expected relayer
        vm.expectRevert(
            abi.encodeWithSignature(
                "AddressMismatch(address,address)",
                getBeneficiary(edition, address(this)), // actual
                getBeneficiary(edition, relayer) // expected
            )
        );
        editionFactory.mintBatch(edition, abi.encodePacked(address(this)), signedAttestation);

        // we also can't mint directly against the edition
        vm.expectRevert("UNAUTHORIZED_MINTER");
        IBatchMintable(edition).mintBatch(abi.encodePacked(address(this)));
    }
}
