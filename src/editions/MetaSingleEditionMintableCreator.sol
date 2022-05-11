// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { IEditionSingleMintable } from "@zoralabs/nft-editions-contracts/contracts/IEditionSingleMintable.sol";

import { BaseRelayRecipient } from "src/utils/BaseRelayRecipient.sol";
import { MetaEditionMinter } from "./MetaEditionMinter.sol";
import { MetaEditionMinterFactory } from "./MetaEditionMinterFactory.sol";
import { TimeCop } from "./TimeCop.sol";

interface ISingleEditionMintableCreator {
    /// Creates a new edition contract as a factory with a deterministic address
    /// Important: None of these fields (except the Url fields with the same hash) can be changed after calling
    /// @param _name Name of the edition contract
    /// @param _symbol Symbol of the edition contract
    /// @param _description Metadata: Description of the edition entry
    /// @param _animationUrl Metadata: Animation url (optional) of the edition entry
    /// @param _animationHash Metadata: SHA-256 Hash of the animation (if no animation url, can be 0x0)
    /// @param _imageUrl Metadata: Image url (semi-required) of the edition entry
    /// @param _imageHash Metadata: SHA-256 hash of the Image of the edition entry (if not image, can be 0x0)
    /// @param _editionSize Total size of the edition (number of possible editions)
    /// @param _royaltyBPS BPS amount of royalty
    function createEdition(
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _animationUrl,
        bytes32 _animationHash,
        string memory _imageUrl,
        bytes32 _imageHash,
        uint256 _editionSize,
        uint256 _royaltyBPS
    ) external returns (uint256);

    /// Get edition given the created ID
    /// @param editionId id of edition to get contract for
    /// @return SingleEditionMintable Edition NFT contract
    function getEditionAtId(uint256 editionId) external view returns (IEditionSingleMintable);
}

interface _IEditionSingleMintable {
    function transferOwnership(address newOwner) external;
    function setApprovedMinter(address minter, bool allowed) external;
}

contract MetaSingleEditionMintableCreator is BaseRelayRecipient {
    error NullAddress();

    ISingleEditionMintableCreator public immutable editionCreator;
    MetaEditionMinterFactory public immutable minterFactory;
    TimeCop public immutable timeCop;

    constructor(
        address _trustedForwarder,
        address _editionCreator,
        address _minterFactory,
        address _timeCop
    ) {
        if (_editionCreator == address(0)
            || _minterFactory == address(0)
            || _timeCop == address(0))
        {
            revert NullAddress();
        }
        editionCreator = ISingleEditionMintableCreator(_editionCreator);
        minterFactory = MetaEditionMinterFactory(_minterFactory);
        timeCop = TimeCop(_timeCop);

        trustedForwarder = _trustedForwarder;
    }

    function createEdition(
        // ISingleEditionMintableCreator parameters
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _animationUrl,
        bytes32 _animationHash,
        string memory _imageUrl,
        bytes32 _imageHash,
        uint256 _editionSize,
        uint256 _royaltyBPS,
        // additional parameters
        uint256 _claimWindowDurationSeconds
    ) external returns (address, address) {
        // deploy the new contract
        uint256 newId = editionCreator.createEdition(
            _name,
            _symbol,
            _description,
            _animationUrl,
            _animationHash,
            _imageUrl,
            _imageHash,
            _editionSize,
            _royaltyBPS
        );

        // deploy the edition
        IEditionSingleMintable edition = editionCreator.getEditionAtId(newId);

        // deploy the minter for this edition
        MetaEditionMinter newMinter = minterFactory.createMinter(edition);

        // configure the time limit
        timeCop.setTimeLimit(address(edition), _claimWindowDurationSeconds);

        // configure the edition (while we still own it)
        _IEditionSingleMintable(address(edition)).setApprovedMinter(address(newMinter), true);

        // and finally transfer ownership of the configured contract to the actual creator
        _IEditionSingleMintable(address(edition)).transferOwnership(_msgSender());

        return (address(edition), address(newMinter));
    }

    function getEditionAtId(uint256 editionId) external view returns (IEditionSingleMintable) {
        return editionCreator.getEditionAtId(editionId);
    }
}
