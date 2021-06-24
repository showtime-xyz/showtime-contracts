// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./utils/AccessProtected.sol";
import "./utils/BaseRelayRecipient.sol";

contract ShowtimeMT is ERC1155(""), AccessProtected, BaseRelayRecipient {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    string public baseURI = "https://gateway.pinata.cloud/ipfs/";
    mapping(uint256 => string) private _hashes;

    /**
     * Mint + Issue Token
     *
     * @param recipient - Token will be issued to recipient
     * @param amount - amount of tokens to mint
     * @param hash - IPFS hash
     * @param data - additional data
     */
    function issueToken(
        address recipient,
        uint256 amount,
        string memory hash,
        bytes memory data
    ) public onlyMinter returns (uint256) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _hashes[newTokenId] = hash;
        _mint(recipient, newTokenId, amount, data);
        return newTokenId;
    }

    /**
     * Mint + Issue Token Batch
     *
     * @param recipient - Token will be issued to recipient
     * @param amounts - amounts of each token to mint
     * @param hashes - IPFS hashes
     * @param data - additional data
     */
    function issueTokenBatch(
        address recipient,
        uint256[] memory amounts,
        string[] memory hashes,
        bytes memory data
    ) public onlyMinter returns (uint256[] memory) {
        require(
            amounts.length == hashes.length,
            "amounts & hashes length mismatch"
        );
        uint256[] memory ids = new uint256[](amounts.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            _tokenIds.increment();
            uint256 newTokenId = _tokenIds.current();
            _hashes[newTokenId] = hashes[i];
            ids[i] = newTokenId;
        }
        _mintBatch(recipient, ids, amounts, data);
        return ids;
    }

    /**
     * Set Base URI
     *
     * @param _baseURI - Base URI
     */
    function setBaseURI(string calldata _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    /**
     * Get Token URI
     *
     * @param tokenId - Token ID
     */
    function uri(uint256 tokenId)
        external
        view
        override
        returns (string memory)
    {
        return string(abi.encodePacked(baseURI, _hashes[tokenId]));
    }

    /**
     * returns the message sender
     */
    function _msgSender()
        internal
        view
        override(Context, BaseRelayRecipient)
        returns (address payable)
    {
        return BaseRelayRecipient._msgSender();
    }
}
