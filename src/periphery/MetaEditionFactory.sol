// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { IERC2981 } from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/interfaces/IERC721Metadata.sol";


import { BaseRelayRecipient } from "../utils/BaseRelayRecipient.sol";

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
    function getEditionAtId(uint256 editionId) external view returns (ISingleEditionMintable);
}

interface ISingleEditionMintable is IERC721Metadata, IERC2981 {
  function mintEdition(address to) external returns (uint256);
  function mintEditions(address[] memory to) external returns (uint256);
  function numberCanMint() external view returns (uint256);
  function owner() external view returns (address);
  function transferOwnership(address newOwner) external;
  function setApprovedMinter(address minter, bool allowed) external;
}

contract MetaEditionFactory is BaseRelayRecipient {
    ISingleEditionMintableCreator immutable editionCreator;

    constructor(address _trustedForwarder, address _editionCreator) {
        trustedForwarder = _trustedForwarder;
        editionCreator = ISingleEditionMintableCreator(_editionCreator);
    }

    /// @param minter the address of the minter contract to use for this edition, or 0 for an open mint
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
        address minter
    ) external returns (uint256) {
        // deploy the new contract
        uint newId = editionCreator.createEdition(_name, _symbol, _description, _animationUrl, _animationHash,
            _imageUrl, _imageHash, _editionSize, _royaltyBPS);

        // configure it while we still own it
        ISingleEditionMintable edition = editionCreator.getEditionAtId(newId);
        edition.setApprovedMinter(minter, true);

        // and finally transfer ownership of the configured contract to the actual creator
        edition.transferOwnership(_msgSender());

        return newId;
    }

    function getEditionAtId(uint256 editionId) external view returns (ISingleEditionMintable) {
        return editionCreator.getEditionAtId(editionId);
    }
}