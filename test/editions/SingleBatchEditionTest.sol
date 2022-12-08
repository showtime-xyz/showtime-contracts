// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {SingleBatchEdition} from "nft-editions/SingleBatchEdition.sol";
import {Addresses} from "nft-editions/utils/Addresses.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import "nft-editions/interfaces/Errors.sol";

import {SingleBatchEditionMinter} from "src/editions/SingleBatchEditionMinter.sol";
import {SingleBatchEditionCreator} from "src/editions/SingleBatchEditionCreator.sol";
import "test/fixtures/ShowtimeVerifierFixture.sol";
import "src/editions/interfaces/Errors.sol";
import {SSTORE2} from "lib/nft-editions/lib/solmate/src/utils/SSTORE2.sol";

contract SingleBatchEditionTest is Test, ShowtimeVerifierFixture {
    uint256 constant ROYALTY_BPS = 1000;

    SingleBatchEditionCreator editionCreator;
    ShowtimeVerifier verifier;
    SingleBatchEditionMinter minter;

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
        minter = new SingleBatchEditionMinter(verifier);

        // configure editionCreator
        SingleBatchEdition editionImpl = new SingleBatchEdition();

        // configure editionCreator
        editionCreator = new SingleBatchEditionCreator(address(editionImpl), address(minter));
    }

    function getVerifier() public view override returns (ShowtimeVerifier) {
        return verifier;
    }

    function createEdition(SignedAttestation memory signedAttestation, bytes memory expectedError)
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
                editionCreator.createEdition(
                    "name",
                    "description",
                    "animationUrl",
                    "imageUrl",
                    ROYALTY_BPS,
                    "externalUrl",
                    "creatorName",
                    signedAttestation
                )
            )
        );
    }

    function createEdition(Attestation memory attestation, bytes memory expectedError)
        public
        returns (SingleBatchEdition)
    {
        return createEdition(signed(signerKey, attestation), expectedError);
    }

    function createEdition(Attestation memory attestation) public returns (SingleBatchEdition) {
        return createEdition(attestation, "");
    }

    function getCreatorAttestation() public view returns (Attestation memory creatorAttestation) {
        return getCreatorAttestation(creator);
    }

    function getCreatorAttestation(address creatorAddr) public view returns (Attestation memory creatorAttestation) {
        // generate a valid attestation
        creatorAttestation = Attestation({
            context: address(editionCreator),
            beneficiary: creatorAddr,
            validUntil: block.timestamp + 2 minutes,
            nonce: verifier.nonces(creator)
        });
    }

    function getBatchAttestation(SingleBatchEdition _edition, address pointer, uint256 _validUntil, uint256 _nonce)
        public
        pure
        returns (Attestation memory)
    {
        // generate a valid attestation
        return Attestation({context: address(_edition), beneficiary: pointer, validUntil: _validUntil, nonce: _nonce});
    }

    function getBatchAttestation(SingleBatchEdition _edition, bytes memory addresses) public returns (Attestation memory) {
        address pointer = SSTORE2.write(addresses);
        return
            getBatchAttestation(_edition, pointer, block.timestamp + 2 minutes, verifier.nonces(pointer));
    }

    function getSingleClaimerBatchAttestation(SingleBatchEdition _edition) public returns (Attestation memory) {
        address pointer = SSTORE2.write(abi.encodePacked(claimer));
        return getBatchAttestation(_edition, pointer, block.timestamp + 2 minutes, verifier.nonces(pointer));
    }

    /*//////////////////////////////////////////////////////////////
                            VERIFICATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function testCreateEditionHappyPath() public {
        SingleBatchEdition edition = createEdition(getCreatorAttestation());

        // the edition is owned by the creator
        assertEq(edition.owner(), creator);

        // it has the expected symbol
        assertEq(edition.symbol(), unicode"✦ SHOWTIME");

        // the creator no longer automatically receives the first token (because of the single mint mechanic)
        assertEq(edition.balanceOf(creator), 0);
        assertEq(edition.balanceOf(claimer), 0);

        // the edition is mintable by the global minter
        Attestation memory batchAttestation = getSingleClaimerBatchAttestation(edition);

        vm.prank(relayer);
        minter.mintBatch(signed(signerKey, batchAttestation));

        // the claimer received a token
        assertEq(edition.balanceOf(claimer), 1);
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

    function testCanNotReuseBatchAttestation() public {
        // setup
        SingleBatchEdition edition = createEdition(getCreatorAttestation());
        Attestation memory batchAttestation = getSingleClaimerBatchAttestation(edition);
        SignedAttestation memory signedAttestation = signed(signerKey, batchAttestation);

        // first one should work
        minter.mintBatch(signedAttestation);

        // second one should fail
        vm.expectRevert(abi.encodeWithSelector(SoldOut.selector));
        minter.mintBatch(signedAttestation);
    }

    function testEmptyBatchMint() public {
        // setup
        SingleBatchEdition edition = createEdition(getCreatorAttestation());
        Attestation memory batchAttestation = getBatchAttestation(edition, "");
        SignedAttestation memory signedAttestation = signed(signerKey, batchAttestation);

        // when we mint a batch with no claimers, it fails with InvalidBatch()
        vm.expectRevert(InvalidBatch.selector);
        minter.mintBatch(signedAttestation);
    }

    function testBatchMintWithDuplicateClaimer() public {
        // setup
        SingleBatchEdition edition = createEdition(getCreatorAttestation());
        bytes memory addresses = abi.encodePacked(claimer, claimer);
        Attestation memory batchAttestation = getBatchAttestation(edition, addresses);
        SignedAttestation memory signedAttestation = signed(signerKey, batchAttestation);

        // when we mint a batch with a duplicate claimer, it fails with ADDRESSES_NOT_SORTED
        vm.expectRevert("ADDRESSES_NOT_SORTED");
        minter.mintBatch(signedAttestation);
    }

    function testBatchMintWithUniqueClaimers(uint256 n) public {
        vm.assume(0 < n);
        vm.assume(n < 1200);

        // setup
        SingleBatchEdition edition = createEdition(getCreatorAttestation());
        Attestation memory batchAttestation = getBatchAttestation(edition, Addresses.make(n));

        // when we mint a batch for n unique addresses
        minter.mintBatch(signed(signerKey, batchAttestation));

        // then each claimer receives the expected tokens
        for (uint256 i = 0; i < n; i++) {
            // TODO: extract the ith address
            // assertEq(edition.balanceOf(addresses[i]), 1);
        }

        // and the total supply for the edition is n
        assertEq(edition.totalSupply(), n);
    }
}
