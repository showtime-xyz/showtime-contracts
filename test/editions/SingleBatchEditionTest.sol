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

    function testCreateEditionHappyPath() public {
        uint256 id = editionFactory.getEditionId(DEFAULT_EDITION_DATA, creator);
        address expectedAddr = address(editionFactory.getEditionAtId(SINGLE_BATCH_EDITION_IMPL, id));

        // the edition creator emits the expected event
        vm.expectEmit(true, true, true, true);
        emit CreatedBatchEdition(id, creator, expectedAddr, "tag1,tag2");
        SingleBatchEdition edition = createEdition(getCreatorAttestation(), abi.encodePacked(claimer));

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

    function testCreateEditionWithWrongContext() public {
        // when we have an attestation with the wrong context
        Attestation memory creatorAttestation = getCreatorAttestation();
        address expectedAddr = creatorAttestation.context;
        creatorAttestation.context = address(this); // nonsense context

        // creating a new edition should fail
        createEdition(
            creatorAttestation,
            abi.encodePacked(claimer),
            abi.encodeWithSignature("AddressMismatch(address,address)", expectedAddr, creatorAttestation.context)
        );
    }

    function testCreateEditionWithWrongNonce() public {
        // when we have an attestation with the wrong context
        Attestation memory creatorAttestation = getCreatorAttestation();

        uint256 badNonce = uint256(uint160(address(this)));
        creatorAttestation.nonce = badNonce;

        // creating a new edition should fail
        createEdition(
            creatorAttestation,
            abi.encodePacked(claimer),
            abi.encodeWithSignature("BadNonce(uint256,uint256)", 0, badNonce)
        );
    }

    function testCanNotReuseCreatorAttestation() public {
        Attestation memory creatorAttestation = getCreatorAttestation();

        // first one should work
        address editionAddr = address(createEdition(creatorAttestation, abi.encodePacked(claimer)));

        // second one should fail
        createEdition(
            creatorAttestation,
            abi.encodePacked(claimer),
            abi.encodeWithSignature("DuplicateEdition(address)", editionAddr)
        );
    }

    function testCanNotHijackCreatorAttestation() public {
        SignedAttestation memory signedAttestation = signed(signerKey, getCreatorAttestation());

        // when the badActor tries to steal the attestation
        signedAttestation.attestation.beneficiary = badActor;

        address expectedAddr = address(
            editionFactory.getEditionAtId(
                SINGLE_BATCH_EDITION_IMPL,
                editionFactory.getEditionId(DEFAULT_EDITION_DATA, badActor)));

        // it does not work
        createEdition(
            signedAttestation,
            abi.encodePacked(claimer),
            abi.encodeWithSignature("AddressMismatch(address,address)", expectedAddr, signedAttestation.attestation.context)
        );
    }

    function testCanNotMintAfterInitialMint() public {
        // first one should work
        SingleBatchEdition edition = createEdition(getCreatorAttestation(), abi.encodePacked(claimer));

        assertEq(edition.balanceOf(claimer), 1);

        // the factory has minting rights, so pretend to be it
        vm.prank(address(editionFactory));

        // second one should fail
        vm.expectRevert("ALREADY_MINTED");
        edition.mintBatch(abi.encodePacked(claimer));
    }

    function testEmptyBatchMint() public {
        // when we mint a batch with no claimers, it fails with InvalidBatch()
        createEdition(getCreatorAttestation(), "", "INVALID_ADDRESSES");
    }

    function testBatchMintWithDuplicateClaimer() public {
        // when we mint a batch with a duplicate claimer, it fails with ADDRESSES_NOT_SORTED
        createEdition(
            getCreatorAttestation(),
            abi.encodePacked(claimer, claimer),
            "ADDRESSES_NOT_SORTED"
        );
    }

    function testBatchMintWithUniqueClaimers(uint256 n) public {
        n = bound(n, 1, 1200);

        // when we mint a batch for n unique addresses
        SingleBatchEdition edition = createEdition(
            getCreatorAttestation(),
            Addresses.make(n)
        );

        // then each claimer receives the expected tokens
        for (uint256 i = 0; i < n; i++) {
            // TODO: extract the ith address
            // assertEq(edition.balanceOf(addresses[i]), 1);
        }

        // and the total supply for the edition is n
        assertEq(edition.totalSupply(), n);
    }
}
