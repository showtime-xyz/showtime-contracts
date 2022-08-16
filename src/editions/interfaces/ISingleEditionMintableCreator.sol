// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { IEditionSingleMintable } from "@zoralabs/nft-editions-contracts/contracts/IEditionSingleMintable.sol";

interface ISingleEditionMintableCreator {
    /// @return The ID of the created edition
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
