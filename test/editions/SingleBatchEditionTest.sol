// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {SingleBatchEdition} from "nft-editions/SingleBatchEdition.sol";
import {Addresses} from "nft-editions/utils/Addresses.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import "nft-editions/interfaces/Errors.sol";
import {SSTORE2} from "solmate/utils/SSTORE2.sol";

import {SingleBatchEditionFactory, EditionData} from "src/editions/SingleBatchEditionFactory.sol";
import "test/fixtures/ShowtimeVerifierFixture.sol";
import "src/editions/interfaces/Errors.sol";

contract SingleBatchEditionTest is Test, ShowtimeVerifierFixture {
    event CreatedBatchEdition(
        uint256 indexed editionId, address indexed creator, address editionContractAddress, string tags
    );

    uint256 constant ROYALTY_BPS = 1000;

    SingleBatchEditionFactory editionFactory;
    ShowtimeVerifier verifier;

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

        // configure editionFactory
        SingleBatchEdition editionImpl = new SingleBatchEdition();
        editionFactory = new SingleBatchEditionFactory(
            address(editionImpl),
            address(verifier)
        );
    }

    function getVerifier() public view override returns (ShowtimeVerifier) {
        return verifier;
    }

    function createEdition(SignedAttestation memory signedAttestation, bytes memory recipients, bytes memory expectedError)
        public
        returns (SingleBatchEdition newEdition)
    {
        // anyone can broadcast the transaction as long as it has the right signed attestation
        vm.prank(relayer);

        if (expectedError.length > 0) {
            vm.expectRevert(expectedError);
        }

        newEdition = SingleBatchEdition(
            address(
                editionFactory.createEdition(
                    EditionData(
                        "name",
                        "description",
                        "animationUrl",
                        "imageUrl",
                        ROYALTY_BPS,
                        "externalUrl",
                        "creatorName",
                        "tag1,tag2"
                    ),
                    recipients,
                    signedAttestation
                )
            )
        );
    }

    function createEdition(Attestation memory attestation, bytes memory recipients, bytes memory expectedError)
        public
        returns (SingleBatchEdition)
    {
        return createEdition(signed(signerKey, attestation), recipients, expectedError);
    }

    function createEdition(Attestation memory attestation, bytes memory recipients) public returns (SingleBatchEdition) {
        return createEdition(attestation, recipients, "");
    }

    function getCreatorAttestation() public view returns (Attestation memory creatorAttestation) {
        return getCreatorAttestation(creator);
    }

    function getCreatorAttestation(address creatorAddr) public view returns (Attestation memory creatorAttestation) {
        // generate a valid attestation
        creatorAttestation = Attestation({
            context: address(editionFactory),
            beneficiary: creatorAddr,
            validUntil: block.timestamp + 2 minutes,
            nonce: verifier.nonces(creator)
        });
    }

    /*//////////////////////////////////////////////////////////////
                            VERIFICATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function testCreateEditionHappyPath() public {
        uint256 id = uint256(keccak256(abi.encodePacked(creator, "name", "animationUrl", "imageUrl")));
        address expectedAddr = address(editionFactory.getEditionAtId(id));

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
        creatorAttestation.context = address(this); // nonsense context

        // creating a new edition should fail
        createEdition(
            creatorAttestation,
            abi.encodePacked(claimer),
            abi.encodeWithSignature("UnexpectedContext(address)", address(this))
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
        createEdition(creatorAttestation, abi.encodePacked(claimer));

        // second one should fail
        createEdition(
            creatorAttestation,
            abi.encodePacked(claimer),
            abi.encodeWithSignature("BadNonce(uint256,uint256)", 1, 0)
        );
    }

    function testCanNotHijackCreatorAttestation() public {
        SignedAttestation memory signedAttestation = signed(signerKey, getCreatorAttestation());

        // when the badActor tries to steal the attestation
        signedAttestation.attestation.beneficiary = badActor;

        // it does not work
        createEdition(
            signedAttestation,
            abi.encodePacked(claimer),
            abi.encodeWithSignature("UnknownSigner()")
        );
    }

    function testCanNotMintAfterInitialMint() public {
        // first one should work
        SingleBatchEdition edition = createEdition(getCreatorAttestation(), abi.encodePacked(claimer));

        assertEq(edition.balanceOf(claimer), 1);

        // the factory has minting rights, so pretend to be it
        vm.prank(address(editionFactory));

        // second one should fail
        vm.expectRevert(SoldOut.selector);
        edition.mintBatch(abi.encodePacked(claimer));
    }

    function testEmptyBatchMint() public {
        // when we mint a batch with no claimers, it fails with InvalidBatch()
        createEdition(getCreatorAttestation(), "", abi.encodeWithSignature("InvalidBatch()"));
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
