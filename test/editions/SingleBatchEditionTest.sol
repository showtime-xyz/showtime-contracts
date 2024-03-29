// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {SingleBatchEdition} from "nft-editions/SingleBatchEdition.sol";
import {Addresses} from "nft-editions/utils/Addresses.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import "nft-editions/interfaces/Errors.sol";
import {SSTORE2} from "solmate/utils/SSTORE2.sol";

// import {Attestation, SignedAttestation} from "src/interfaces/IShowtimeVerifier.sol";

import "test/fixtures/EditionFactoryFixture.sol";
import "src/editions/interfaces/Errors.sol";

contract SingleBatchEditionTest is Test, EditionFactoryFixture {
    using EditionDataWither for EditionData;

    event CreatedBatchEdition(
        uint256 indexed editionId, address indexed creator, address editionContractAddress, string tags
    );

    address claimer = makeAddr("claimer");
    address badActor = makeAddr("badActor");

    function setUp() public {
        __EditionFactoryFixture_setUp();
    }

    /*//////////////////////////////////////////////////////////////
                            VERIFICATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function test_createWithBatch_happyPath() public {
        uint256 id = editionFactory.getEditionId(DEFAULT_EDITION_DATA);
        address expectedAddr = address(editionFactory.getEditionAtId(SINGLE_BATCH_EDITION_IMPL, id));

        // the edition creator emits the expected event
        vm.expectEmit(true, true, true, true);
        emit CreatedBatchEdition(id, creator, expectedAddr, "tag1,tag2");
        SingleBatchEdition edition = SingleBatchEdition(createWithBatch(abi.encodePacked(claimer)));

        // the edition has the expected address
        assertEq(address(edition), expectedAddr);

        // the edition is owned by the creator
        assertEq(edition.owner(), creator);

        // it has the expected symbol
        assertEq(edition.symbol(), unicode"✦ SHOWTIME");

        // the creator no longer automatically receives the first token (because of the single mint mechanic)
        assertEq(edition.balanceOf(creator), 0);

        // the claimer received a token
        assertEq(edition.balanceOf(claimer), 1);
    }

    function test_createWithBatch_withWrongContext() public {
        // when we have an attestation with the wrong context
        Attestation memory creatorAttestation = getCreatorAttestation();
        address expectedAddr = creatorAttestation.context;
        creatorAttestation.context = address(this); // nonsense context

        // creating a new edition should fail
        createWithBatch(
            DEFAULT_EDITION_DATA,
            signed(signerKey, creatorAttestation),
            abi.encodePacked(claimer),
            abi.encodeWithSignature("AddressMismatch(address,address)", expectedAddr, creatorAttestation.context)
        );
    }

    function test_createWithBatch_withWrongNonce() public {
        // when we have an attestation with the wrong context
        Attestation memory creatorAttestation = getCreatorAttestation();

        uint256 badNonce = uint256(uint160(address(this)));
        creatorAttestation.nonce = badNonce;

        // creating a new edition should fail
        createWithBatch(
            DEFAULT_EDITION_DATA,
            signed(signerKey, creatorAttestation),
            abi.encodePacked(claimer),
            abi.encodeWithSignature("BadNonce(uint256,uint256)", 0, badNonce)
        );
    }

    function test_createWithBatch_canNotReuseCreatorAttestation() public {
        // first one should work
        address editionAddr = address(createWithBatch(abi.encodePacked(claimer)));

        // second one should fail
        createWithBatch(
            DEFAULT_EDITION_DATA,
            signed(signerKey, getCreatorAttestation()),
            abi.encodePacked(claimer),
            abi.encodeWithSignature("DuplicateEdition(address)", editionAddr)
        );
    }

    function test_createWithBatch_canNotHijackCreatorAttestation() public {
        SignedAttestation memory signedAttestation = signed(signerKey, getCreatorAttestation());

        // when the badActor tries to steal the attestation
        signedAttestation.attestation.beneficiary = badActor;
        EditionData memory editionData = DEFAULT_EDITION_DATA.withCreatorAddr(badActor);

        address expectedAddr =
            address(editionFactory.getEditionAtId(SINGLE_BATCH_EDITION_IMPL, editionFactory.getEditionId(editionData)));

        bytes memory errorBytes = abi.encodeWithSignature(
            "AddressMismatch(address,address)",
            getBeneficiary(expectedAddr, relayer),
            signedAttestation.attestation.beneficiary
        );

        // it does not work
        createWithBatch(editionData, signedAttestation, abi.encodePacked(claimer), errorBytes);
    }

    function test_createWithBatch_canNotMintAfterInitialMint() public {
        // first one should work
        SingleBatchEdition edition = SingleBatchEdition(createWithBatch(abi.encodePacked(claimer)));

        assertEq(edition.balanceOf(claimer), 1);

        // the factory has minting rights, so pretend to be it
        vm.prank(address(editionFactory));

        // second one should fail
        vm.expectRevert("ALREADY_MINTED");
        edition.mintBatch(abi.encodePacked(claimer));
    }

    function test_createWithBatch_emptyBatchMint() public {
        // when we mint a batch with no claimers, it fails with INVALID_ADDRESSES
        createWithBatch(DEFAULT_EDITION_DATA, signed(signerKey, getCreatorAttestation()), "", "INVALID_ADDRESSES");
    }

    function test_createWithBatch_mintWithDuplicateClaimer() public {
        // when we mint a batch with a duplicate claimer, it fails with ADDRESSES_NOT_SORTED
        createWithBatch(
            DEFAULT_EDITION_DATA,
            signed(signerKey, getCreatorAttestation()),
            abi.encodePacked(claimer, claimer),
            "ADDRESSES_NOT_SORTED"
        );
    }

    function test_createWithBatch_mintWithUniqueClaimers(uint256 n) public {
        n = bound(n, 1, 1200);

        // when we mint a batch for n unique addresses
        SingleBatchEdition edition = SingleBatchEdition(createWithBatch(Addresses.make(n)));

        // then each claimer receives the expected tokens
        for (uint256 i = 0; i < n; i++) {
            // TODO: extract the ith address
            // assertEq(edition.balanceOf(addresses[i]), 1);
        }

        // and the total supply for the edition is n
        assertEq(edition.totalSupply(), n);
    }
}
