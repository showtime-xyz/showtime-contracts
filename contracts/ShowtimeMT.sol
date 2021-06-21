// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./utils/AccessProtected.sol";

contract ShowtimeMT is ERC1155(""), AccessProtected {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    string public baseURI = "https://gateway.pinata.cloud/ipfs/";
    mapping(uint256 => string) private hashes;

    /**
     * Mint + Issue Token
     *
     * @param recipient - Token will be issued to recipient
     * @param amount - amount of tokens to mint
     * @param data - token Metadata URI/Data
     */
    function issueToken(
        address recipient,
        uint256 amount,
        string memory hash,
        bytes memory data
    ) public onlyOwner returns (uint256) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        hashes[newTokenId] = hash;
        _mint(recipient, newTokenId, amount, data);
        return newTokenId;
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
        return string(abi.encodePacked(baseURI, hashes[tokenId]));
    }
}
