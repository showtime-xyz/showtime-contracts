// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {SingleBatchEdition} from "nft-editions/SingleBatchEdition.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import "nft-editions/interfaces/Errors.sol";

import {EditionFactory, EditionData} from "src/editions/EditionFactory.sol";
import {EditionFactoryFixture} from "test/fixtures/EditionFactoryFixture.sol";
import {MockBatchEdition} from "test/fixtures/MockBatchEdition.sol";
import {ShowtimeVerifierFixture, Attestation, SignedAttestation} from "test/fixtures/ShowtimeVerifierFixture.sol";
import "src/editions/interfaces/Errors.sol";


contract EditionFactoryTest is Test, ShowtimeVerifierFixture, EditionFactoryFixture {
    function setUp() public {
        __EditionFactoryFixture_setUp();
    }

    function test_createEdition_nullEditionImplReverts() public {
        uint256 editionId = editionFactory.getEditionId(DEFAULT_EDITION_DATA, creator);

        vm.expectRevert(NullAddress.selector);
        editionFactory.getEditionAtId(address(0), editionId);
    }

    // test that changing the edition impl changes the predicted address
    function test_getEditionAtId_differentEditionImpls() public {
        uint256 editionId = editionFactory.getEditionId(DEFAULT_EDITION_DATA, creator);

        address edition1 = address(editionFactory.getEditionAtId(SINGLE_BATCH_EDITION_IMPL, editionId));
        address edition2 = address(editionFactory.getEditionAtId(address(new SingleBatchEdition()), editionId));

        assertFalse(edition1 == edition2);
    }

    // test that changing the edition impl changes the actual address after createEdition
    function test_createEdition_differentEditionImpls() public {
        address altEditionImpl = address(new SingleBatchEdition());
        Attestation memory altAttestation = getCreatorAttestation(altEditionImpl, DEFAULT_EDITION_DATA, creator);
        SignedAttestation memory altSignedAttestation = signed(signerKey, altAttestation);

        bytes memory recipients = abi.encodePacked(address(this));

        address edition1 = address(createEdition(getCreatorAttestation(), recipients));
        address edition2 = address(createEdition(altEditionImpl, altSignedAttestation, recipients, ""));

        assertFalse(edition1 == edition2);
    }

    // test that we can't reuse a signed attestation with a different edition impl
    function test_createEdition_canNotReuseSignedAttestation() public {
        // a hijacker wants to lift a signed attestation and use it for a different impl address
        address altEditionImpl = address(new SingleBatchEdition());
        bytes memory recipients = abi.encodePacked(address(this));
        SignedAttestation memory ogAttestation = signed(signerKey, getCreatorAttestation());

        uint256 editionId = editionFactory.getEditionId(DEFAULT_EDITION_DATA, creator);
        address hijackedAddr = address(editionFactory.getEditionAtId(altEditionImpl, editionId));

        // the creator can create an edition with the original attestation, but a hijacker can not
        // the error says "this attestation is only valid for the original address, not for the hijacked address"
        createEdition(
            altEditionImpl,
            ogAttestation,
            recipients,
            abi.encodeWithSignature(
                "AddressMismatch(address,address)",
                hijackedAddr,
                ogAttestation.attestation.context
            )
        );
    }

    function test_createEdition_canCreateAlternateContract() public {
        address altEditionImpl = address(new MockBatchEdition());

        SingleBatchEdition edition = createEdition(
            altEditionImpl,
            signed(signerKey, getCreatorAttestation(altEditionImpl, DEFAULT_EDITION_DATA, creator)),
            "",
            ""
        );

        assertEq(edition.contractURI(), "mock");
    }
}
