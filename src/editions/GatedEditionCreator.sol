// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ClonesUpgradeable} from "@openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import {IEdition} from "nft-editions/interfaces/IEdition.sol";

import {IGatedEditionMinter} from "./interfaces/IGatedEditionMinter.sol";
import {IShowtimeVerifier, Attestation, SignedAttestation} from "src/interfaces/IShowtimeVerifier.sol";
import "./interfaces/Errors.sol";

interface IOwnable {
    function transferOwnership(address newOwner) external;
}

contract GatedEditionCreator {
    event CreatedEdition(
        uint256 indexed editionId, address indexed creator, address editionContractAddress, string tags
    );

    string internal constant SYMBOL = unicode"✦ SHOWTIME";
    uint256 internal constant MAX_DURATION_SECONDS = 5 weeks;

    address public immutable editionImpl;
    IGatedEditionMinter public immutable minter;
    IShowtimeVerifier public immutable showtimeVerifier;

    constructor(address _editionImpl, address _minter) {
        if (_editionImpl == address(0) || _minter == address(0)) {
            revert NullAddress();
        }

        editionImpl = _editionImpl;
        minter = IGatedEditionMinter(_minter);
        showtimeVerifier = IGatedEditionMinter(_minter).showtimeVerifier();
    }

    /// Creates a new edition contract as a factory with a deterministic address
    /// @param name Name of the edition contract
    /// @param description Metadata: Description of the edition entry
    /// @param animationUrl Metadata: Animation url (optional) of the edition entry
    /// @param imageUrl Metadata: Image url (semi-required) of the edition entry
    /// @param editionSize Total size of the edition (number of possible editions)
    /// @param royaltyBPS Royalties in basis points (e.g. 250 is 2.5%), will be reflected in EIP-2981 royaltyInfo()
    /// @param mintPeriodSeconds How long after deployment the edition can be claimed, in seconds
    /// @param externalUrl link to an external site will be reflected in contract URI
    /// @param creatorName Profile name of the creator, will be reflected in string properties of token URIs
    /// @param tags Comma-separated list of tags that will be emitted as part of the CreatedEdition event
    /// @param signedAttestation the attestation to verify along with a corresponding signature
    /// @dev we expect the signed attestation's context to correspond to this contract's address
    /// @dev we expect the signed attestation's beneficiary to be the edition's creator
    /// @return edition the address of the created edition
    function createEdition(
        string calldata name,
        string calldata description,
        string calldata animationUrl,
        string calldata imageUrl,
        uint256 editionSize,
        uint256 royaltyBPS,
        uint256 mintPeriodSeconds,
        string calldata externalUrl,
        string calldata creatorName,
        string calldata tags,
        bool enableOpenseaOperatorFiltering,
        SignedAttestation calldata signedAttestation
    ) external returns (IEdition edition) {
        if (mintPeriodSeconds == 0 || mintPeriodSeconds > MAX_DURATION_SECONDS) {
            revert InvalidTimeLimit(mintPeriodSeconds);
        }

        validateAttestation(signedAttestation);
        address creator = signedAttestation.attestation.beneficiary;

        uint256 id = getEditionId(creator, name, animationUrl, imageUrl);
        edition = IEdition(ClonesUpgradeable.cloneDeterministic(editionImpl, bytes32(id)));

        try edition.initialize(
            address(this), name, SYMBOL, description, animationUrl, imageUrl, editionSize, royaltyBPS, mintPeriodSeconds
        ) {} catch {
            // rethrow the problematic way until we have a better way
            // see https://github.com/ethereum/solidity/issues/12654
            assembly ("memory-safe") {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        emit CreatedEdition(id, creator, address(edition), tags);

        configureEdition(edition, signedAttestation, externalUrl, creatorName, enableOpenseaOperatorFiltering);

        // and finally transfer ownership of the configured contract to the actual creator
        IOwnable(address(edition)).transferOwnership(creator);
    }

    function getEditionId(address creator, string calldata name, string calldata animationUrl, string calldata imageUrl)
        public
        pure
        returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(creator, name, animationUrl, imageUrl)));
    }

    function getEditionAtId(uint256 editionId) external view returns (IEdition) {
        return IEdition(ClonesUpgradeable.predictDeterministicAddress(editionImpl, bytes32(editionId), address(this)));
    }

    function validateAttestation(SignedAttestation calldata signedAttestation) internal returns (bool) {
        // verify that the context for this attestation is valid
        address context = signedAttestation.attestation.context;
        if (context != address(this)) {
            revert UnexpectedContext(context);
        }

        // verify attestation
        if (!showtimeVerifier.verifyAndBurn(signedAttestation)) {
            revert VerificationFailed();
        }

        return true;
    }

    function configureEdition(
        IEdition edition,
        SignedAttestation calldata signedAttestation,
        string calldata externalUrl,
        string calldata creatorName,
        bool enableOpenseaOperatorFiltering
    ) internal {
        address creator = signedAttestation.attestation.beneficiary;

        // configure the edition (while we still own it)
        edition.setApprovedMinter(address(minter), true);

        // auto claim one for the creator
        edition.mint(creator);

        edition.setExternalUrl(externalUrl);

        string[] memory propertyNames = new string[](1);
        propertyNames[0] = "Creator";

        string[] memory propertyValues = new string[](1);
        propertyValues[0] = creatorName;

        edition.setStringProperties(propertyNames, propertyValues);

        if (enableOpenseaOperatorFiltering) {
            edition.enableDefaultOperatorFilter();
        }
    }
}
