// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ISingleBatchEdition} from "nft-editions/SingleBatchEdition.sol";

import {IBatchMintable} from "src/editions/interfaces/IBatchMintable.sol";

contract MockBatchEdition is ISingleBatchEdition, IBatchMintable {
    mapping (address => bool) public approvedMinter;

    function contractURI() external pure returns (string memory) {
        return "mock";
    }

    function getPrimaryOwnersPointer() external pure returns (address) {
        return address(0);
    }

    function initialize(
        address _owner,
        string calldata _name,
        string calldata _symbol,
        string calldata _description,
        string calldata _animationUrl,
        string calldata _imageUrl,
        uint256 _royaltyBPS,
        address _minter
    ) external {
        approvedMinter[_owner] = true;
    }

    function isPrimaryOwner(address tokenOwner) external pure returns (bool) {
        return false;
    }

    function mintBatch(bytes calldata addresses)
        external
        override(IBatchMintable, ISingleBatchEdition)
        returns (uint256)
    {
        require(approvedMinter[msg.sender], "UNAUTHORIZED_MINTER");
        return addresses.length / 20;
    }

    function mintBatch(address pointer) external returns (uint256) {
        // mockedy mock mock
    }

    // you'd want this to be onlyOwner or something, but we're a mock
    function setApprovedMinter(address minter, bool allowed) external {
        approvedMinter[minter] = allowed;
    }

    function setExternalUrl(string calldata _externalUrl) external {
        // mockedy mock mock
    }

    function setStringProperties(string[] calldata names, string[] calldata values) external {
        // mockedy mock mock
    }

    function totalSupply() external pure returns (uint256) {
        return 0;
    }

    function withdraw() external {
        // mockedy mock mock
    }

    function transferOwnership(address newOwner) external {
        // mockedy mock mock
    }
}
