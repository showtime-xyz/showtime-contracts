// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { IEdition, IEditionCreator } from "nft-editions/interfaces/IEditionCreator.sol";

import { IGatedEditionMinter } from "./interfaces/IGatedEditionMinter.sol";
import { IShowtimeVerifier, Attestation, SignedAttestation } from "src/interfaces/IShowtimeVerifier.sol";
import { TimeCop } from "./TimeCop.sol";

interface IOwnable {
    function transferOwnership(address newOwner) external;
}

contract GatedEditionCreator {
    error NullAddress();
    error VerificationFailed();
    error UnexpectedContext(address context);

    string constant SYMBOL = "SHOWTIME";

    IEditionCreator public immutable editionCreator;
    IGatedEditionMinter public immutable minter;
    IShowtimeVerifier public immutable showtimeVerifier;
    TimeCop public immutable timeCop;

    constructor(
        address _editionCreator,
        address _minter,
        address _timeCop
    ) {
        if (_editionCreator == address(0) || _minter == address(0) || _timeCop == address(0)) {
            revert NullAddress();
        }
        editionCreator = IEditionCreator(_editionCreator);
        minter = IGatedEditionMinter(_minter);
        timeCop = TimeCop(_timeCop);

        showtimeVerifier = IGatedEditionMinter(_minter).showtimeVerifier();
    }

    /// Creates a new edition contract as a factory with a deterministic address
    /// Important: None of these fields (except the Url fields with the same hash) can be changed after calling
    /// @param name Name of the edition contract
    /// @param description Metadata: Description of the edition entry
    /// @param animationUrl Metadata: Animation url (optional) of the edition entry
    /// @param imageUrl Metadata: Image url (semi-required) of the edition entry
    /// @param editionSize Total size of the edition (number of possible editions)
    /// @param royaltyBPS BPS amount of royalty
    /// @param claimWindowDurationSeconds How long after deployment the edition can be claimed, in seconds
    /// @param signedAttestation the attestation to verify along with a corresponding signature
    /// @dev we expect the signed attestation's context to correspond to this contract's address
    /// @dev we expect the signed attestation's beneficiary to be the edition's creator
    /// @return the address of the created edition
    function createEdition(
        // ISingleEditionMintableCreator parameters
        string memory name,
        string memory description,
        string memory animationUrl,
        string memory imageUrl,
        uint256 editionSize,
        uint256 royaltyBPS,
        // additional parameters
        uint256 claimWindowDurationSeconds,
        SignedAttestation calldata signedAttestation
    ) external returns (address) {
        validateAttestation(signedAttestation);

        // deploy the new edition
        IEdition edition = editionCreator.createEdition(
            name,
            SYMBOL,
            description,
            animationUrl,
            imageUrl,
            editionSize,
            royaltyBPS,
            claimWindowDurationSeconds
        );

        configureEdition(edition, signedAttestation, claimWindowDurationSeconds);

        return address(edition);
    }

    function getEditionAtId(uint256 editionId) external view returns (IEdition) {
        return editionCreator.getEditionAtId(editionId);
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
        // address creator,
        SignedAttestation calldata signedAttestation,
        uint256 _claimWindowDurationSeconds
    ) internal {
        address creator = signedAttestation.attestation.beneficiary;

        // configure the time limit
        timeCop.setTimeLimit(address(edition), _claimWindowDurationSeconds);

        // configure the edition (while we still own it)
        edition.setApprovedMinter(address(minter), true);

        // auto claim one for the creator
        edition.mint(creator);

        // and finally transfer ownership of the configured contract to the actual creator
        IOwnable(address(edition)).transferOwnership(creator);
    }
}
