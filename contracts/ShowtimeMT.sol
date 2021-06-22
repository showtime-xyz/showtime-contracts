// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./utils/AccessProtected.sol";
import "./utils/BaseRelayRecipient.sol";

contract ShowtimeMT is ERC1155(""), AccessProtected, BaseRelayRecipient {
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
    ) public onlyAdmin returns (uint256) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        hashes[newTokenId] = hash;
        _mint(recipient, newTokenId, amount, data);
        return newTokenId;
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
        return string(abi.encodePacked(baseURI, hashes[tokenId]));
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
