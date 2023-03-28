// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ClonesUpgradeable} from "@openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import {ISingleBatchEdition} from "nft-editions/interfaces/ISingleBatchEdition.sol";
import {SingleBatchEdition} from "nft-editions/SingleBatchEdition.sol";
import {SSTORE2} from "solmate/utils/SSTORE2.sol";

import {IGatedEditionMinter} from "./interfaces/IGatedEditionMinter.sol";
import {IShowtimeVerifier, Attestation, SignedAttestation} from "src/interfaces/IShowtimeVerifier.sol";
import "./interfaces/Errors.sol";

interface IOwnable {
    function transferOwnership(address newOwner) external;
}

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
    string name;
    string description;
    string animationUrl;
    string imageUrl;
    uint256 royaltyBPS;
    string externalUrl;
    string creatorName;
    string tags;
}

contract EditionFactory {
    /// @dev we expect tags to be a comma-separated list of strings e.g. "music,location,password"
    event CreatedBatchEdition(
        uint256 indexed editionId, address indexed creator, address editionContractAddress, string tags
    );

    string internal constant SYMBOL = unicode"✦ SHOWTIME";

    IShowtimeVerifier public immutable showtimeVerifier;

    constructor(address _showtimeVerifier) {
        showtimeVerifier = IShowtimeVerifier(_showtimeVerifier);
    }

    /// Creates and mint a new batch edition contract with a deterministic address
    /// @dev we expect the signed attestation's context to correspond to the predicted edition address
    /// @dev we expect the signed attestation's beneficiary to be the edition's creator
    /// @param editionImpl the address of the implementation contract for the edition to clone
    /// @param packedRecipients an abi.encodePacked() array of recipient addresses for the batch mint
    /// @param signedAttestation a signed message from Showtime authorizing this action on behalf of the edition creator
    /// @return editionAddress the address of the created edition
    function createEdition(
        address editionImpl,
        EditionData calldata data,
        bytes calldata packedRecipients,
        SignedAttestation calldata signedAttestation
    ) external returns (address editionAddress) {
        editionAddress = beforeMint(editionImpl, data, signedAttestation);
        ISingleBatchEdition(editionAddress).mintBatch(packedRecipients);
        afterMint(editionAddress, signedAttestation, data);
    }

    /// Creates and mint a new batch edition contract with a deterministic address
    /// @dev we expect the signed attestation's context to correspond to the predicted edition address
    /// @dev we expect the signed attestation's beneficiary to be the edition's creator
    /// @param editionImpl the address of the implementation contract for the edition to clone
    /// @param pointer the address of the SSTORE2 pointer with the recipients of the batch mint for this edition
    /// @param signedAttestation a signed message from Showtime authorizing this action on behalf of the edition creator
    /// @return editionAddress the address of the created edition
    function createEdition(
        address editionImpl,
        EditionData calldata data,
        address pointer,
        SignedAttestation calldata signedAttestation
    ) public returns (address editionAddress) {
        editionAddress = beforeMint(editionImpl, data, signedAttestation);
        ISingleBatchEdition(editionAddress).mintBatch(pointer);
        afterMint(editionAddress, signedAttestation, data);
    }

    function beforeMint(address editionImpl, EditionData calldata data, SignedAttestation calldata signedAttestation)
        internal
        returns (address editionAddress)
    {
        address creator = signedAttestation.attestation.beneficiary;
        uint256 editionId = getEditionId(data, creator);

        // we expect this to revert if editionImpl is null
        address predicted = address(getEditionAtId(editionImpl, editionId));
        validateAttestation(signedAttestation, predicted);

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

        emit CreatedBatchEdition(editionId, creator, address(edition), data.tags);
    }

    function afterMint(address editionAddress, SignedAttestation calldata signedAttestation, EditionData calldata data)
        internal
    {
        address creator = signedAttestation.attestation.beneficiary;
        configureEdition(ISingleBatchEdition(editionAddress), signedAttestation, data.externalUrl, data.creatorName);

        // and finally transfer ownership of the configured contract to the actual creator
        IOwnable(editionAddress).transferOwnership(creator);
    }

    function getEditionId(EditionData calldata data, address creator) public pure returns (uint256 editionId) {
        return uint256(keccak256(abi.encodePacked(creator, data.name, data.animationUrl, data.imageUrl)));
    }

    function getEditionAtId(address editionImpl, uint256 editionId) public view returns (ISingleBatchEdition) {
        if (editionImpl == address(0)) {
            revert NullAddress();
        }

        return ISingleBatchEdition(
            ClonesUpgradeable.predictDeterministicAddress(editionImpl, bytes32(editionId), address(this))
        );
    }

    function validateAttestation(SignedAttestation calldata signedAttestation, address editionAddress)
        public
        view
        returns (bool)
    {
        // verify that the context for this attestation is valid
        address context = signedAttestation.attestation.context;
        if (context != editionAddress) {
            revert AddressMismatch({expected: editionAddress, actual: context});
        }

        // verify attestation without burning, because the editionAddress can not be reused
        if (!showtimeVerifier.verify(signedAttestation)) {
            revert VerificationFailed();
        }

        return true;
    }

    function configureEdition(
        ISingleBatchEdition edition,
        SignedAttestation calldata, /* signedAttestation */
        string calldata externalUrl,
        string calldata creatorName
    ) internal {
        edition.setExternalUrl(externalUrl);

        string[] memory propertyNames = new string[](1);
        propertyNames[0] = "Creator";

        string[] memory propertyValues = new string[](1);
        propertyValues[0] = creatorName;

        edition.setStringProperties(propertyNames, propertyValues);
    }
}
