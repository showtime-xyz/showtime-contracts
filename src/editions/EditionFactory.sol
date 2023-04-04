// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ClonesUpgradeable} from "@openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import {SingleBatchEdition, ISingleBatchEdition} from "nft-editions/SingleBatchEdition.sol";

import {IBatchEditionMinter} from "src/editions/interfaces/IBatchEditionMinter.sol";
import {IBatchMintable} from "src/editions/interfaces/IBatchMintable.sol";
import {IShowtimeVerifier, Attestation, SignedAttestation} from "src/interfaces/IShowtimeVerifier.sol";

import "./interfaces/Errors.sol";

interface IOwnable {
    function transferOwnership(address newOwner) external;
}

/// @param editionImpl the address of the implementation contract for the edition to clone
/// @param creatorAddr the address that will be configured as the owner of the edition
/// @param minterAddr the address that will be configured as the allowed minter for the edition
/// @param name Name of the edition contract
/// @param description Description of the edition entry
/// @param animationUrl Animation url (optional) of the edition entry
/// @param imageUrl Metadata: Image url (semi-required) of the edition entry
/// @param royaltyBPS BPS amount of royalties
/// @param signedAttestation the attestation to verify along with a corresponding signature
/// @param externalUrl Metadata: External url (optional) of the edition entry
/// @param creatorName Metadata: Creator name (optional) of the edition entry
/// @param tags list of comma-separated tags for this edition, emitted as part of the CreatedBatchEdition event
struct EditionData {
    address editionImpl;
    address creatorAddr;
    address minterAddr;
    string name;
    string description;
    string animationUrl;
    string imageUrl;
    uint256 royaltyBPS;
    string externalUrl;
    string creatorName;
    string tags;
}

contract EditionFactory is IBatchEditionMinter {
    /// @dev we expect tags to be a comma-separated list of strings e.g. "music,location,password"
    event CreatedBatchEdition(
        uint256 indexed editionId, address indexed creator, address editionContractAddress, string tags
    );

    string internal constant SYMBOL = unicode"✦ SHOWTIME";

    IShowtimeVerifier public immutable showtimeVerifier;

    constructor(address _showtimeVerifier) {
        showtimeVerifier = IShowtimeVerifier(_showtimeVerifier);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// Create a new batch edition contract with a deterministic address, with delayed batch minting
    /// @param signedAttestation a signed message from Showtime authorizing this action on behalf of the edition creator
    /// @return editionAddress the address of the created edition
    function createEdition(
        EditionData calldata data,
        SignedAttestation calldata signedAttestation
    ) public returns (address editionAddress) {
        editionAddress = beforeMint(data, signedAttestation);

        // we don't mint at this stage, we expect subsequent calls to `mintBatch`

        afterMint(editionAddress, data);
    }

    /// Create and mint a new batch edition contract with a deterministic address

    /// @param packedRecipients an abi.encodePacked() array of recipient addresses for the batch mint
    /// @param signedAttestation a signed message from Showtime authorizing this action on behalf of the edition creator
    /// @return editionAddress the address of the created edition
    function createEdition(
        EditionData calldata data,
        bytes calldata packedRecipients,
        SignedAttestation calldata signedAttestation
    ) external returns (address editionAddress) {
        // this will revert if the attestation is invalid
        editionAddress = beforeMint(data, signedAttestation);

        // mint a batch, using a direct list of recipients
        IBatchMintable(editionAddress).mintBatch(packedRecipients);

        // finish configuring the edition
        afterMint(editionAddress, data);
    }

    /// Create and mint a new batch edition contract with a deterministic address
    /// @param pointer the address of the SSTORE2 pointer with the recipients of the batch mint for this edition
    /// @param signedAttestation a signed message from Showtime authorizing this action on behalf of the edition creator
    /// @return editionAddress the address of the created edition
    function createEdition(
        EditionData calldata data,
        address pointer,
        SignedAttestation calldata signedAttestation
    ) public returns (address editionAddress) {
        // this will revert if the attestation is invalid
        editionAddress = beforeMint(data, signedAttestation);

        // mint a batch, using an SSTORE2 pointer
        IBatchMintable(editionAddress).mintBatch(pointer);

        // finish configuring the edition
        afterMint(editionAddress, data);
    }

    function mintBatch(
        address editionAddress,
        bytes calldata packedRecipients,
        SignedAttestation calldata signedAttestation
    ) external override returns (uint256 numMinted) {
        validateAttestation(signedAttestation, editionAddress, msg.sender);

        return IBatchMintable(editionAddress).mintBatch(packedRecipients);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev we expect the signed attestation's context to correspond to the address of this contract (EditionFactory)
    /// @dev we expect the signed attestation's beneficiary to be the lowest 160 bits of hash(edition || relayer)
    /// @dev note: this function does _not_ burn the nonce for the attestation
    function validateAttestation(SignedAttestation calldata signedAttestation, address edition, address relayer)
        public
        view
        returns (bool)
    {
        // verify that the context is valid
        address context = signedAttestation.attestation.context;
        address expectedContext = address(this);
        if (context != expectedContext) {
            revert AddressMismatch({expected: expectedContext, actual: context});
        }

        // verify that the beneficiary is valid
        address expectedBeneficiary = address(uint160(uint256(keccak256(abi.encodePacked(edition, relayer)))));
        address beneficiary = signedAttestation.attestation.beneficiary;
        if (beneficiary != expectedBeneficiary) {
            revert AddressMismatch({expected: expectedBeneficiary, actual: beneficiary});
        }

        // verify the signature _without_ burning
        // important: it's up to the clients of this function to make sure that the attestation can not be reused
        // for example:
        // - trying to deploy to an existing edition address will revert
        // - trying to deploy the same batch twice should revert
        if (!showtimeVerifier.verify(signedAttestation)) {
            revert VerificationFailed();
        }

        return true;
    }

    function getEditionId(EditionData calldata data) public pure returns (uint256 editionId) {
        return uint256(keccak256(abi.encodePacked(data.creatorAddr, data.name, data.animationUrl, data.imageUrl)));
    }

    function getEditionAtId(address editionImpl, uint256 editionId) public view returns (ISingleBatchEdition) {
        if (editionImpl == address(0)) {
            revert NullAddress();
        }

        return ISingleBatchEdition(
            ClonesUpgradeable.predictDeterministicAddress(editionImpl, bytes32(editionId), address(this))
        );
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function beforeMint(EditionData calldata data, SignedAttestation calldata signedAttestation)
        internal
        returns (address editionAddress)
    {
        uint256 editionId = getEditionId(data);
        address editionImpl = data.editionImpl;

        // we expect this to revert if editionImpl is null
        address predicted = address(getEditionAtId(editionImpl, editionId));
        validateAttestation(signedAttestation, predicted, msg.sender);

        // avoid burning all available gas if an edition already exists at this address
        if (predicted.code.length > 0) {
            revert DuplicateEdition(predicted);
        }

        editionAddress = ClonesUpgradeable.cloneDeterministic(editionImpl, bytes32(editionId));
        ISingleBatchEdition edition = ISingleBatchEdition(editionAddress);

        try edition.initialize(
            address(this),
            data.name,
            SYMBOL,
            data.description,
            data.animationUrl,
            data.imageUrl,
            data.royaltyBPS,
            address(this) //
        ) {
            // nothing to do
        } catch {
            // rethrow the problematic way until we have a better way
            // see https://github.com/ethereum/solidity/issues/12654
            assembly ("memory-safe") {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        emit CreatedBatchEdition(editionId, data.creatorAddr, address(edition), data.tags);
    }

    function afterMint(
        address edition,
        EditionData calldata data
    ) internal {
        address minter = data.minterAddr;
        if (minter != address(0)) {
            IBatchMintable(edition).setApprovedMinter(minter, true);
        }

        string memory creatorName = data.creatorName;
        if (bytes(creatorName).length > 0) {
            string[] memory propertyNames = new string[](1);
            propertyNames[0] = "Creator";

            string[] memory propertyValues = new string[](1);
            propertyValues[0] = data.creatorName;

            ISingleBatchEdition(edition).setStringProperties(propertyNames, propertyValues);
        }

        string memory externalUrl = data.externalUrl;
        if (bytes(externalUrl).length > 0) {
            ISingleBatchEdition(edition).setExternalUrl(data.externalUrl);
        }

        // and finally transfer ownership of the configured contract to the actual creator
        IOwnable(edition).transferOwnership(data.creatorAddr);
    }
}
