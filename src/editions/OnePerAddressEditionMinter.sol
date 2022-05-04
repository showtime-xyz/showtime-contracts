// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {IEditionSingleMintable} from "@zoralabs/nft-editions-contracts/contracts/IEditionSingleMintable.sol";

import { BaseRelayRecipient } from "../utils/BaseRelayRecipient.sol";

import { IEditionMinter } from "./interfaces/IEditionMinter.sol";

contract OnePerAddressEditionMinter is BaseRelayRecipient, IEditionMinter {
    error AlreadyMinted(IEditionSingleMintable collection, address operator);

    mapping(bytes32 => bool) minted;

    constructor(address _trustedForwarder) {
        trustedForwarder = _trustedForwarder;
    }

    function mintEdition(IEditionSingleMintable collection, address _to) override external {
        address operator = _msgSender();
        recordMint(collection, operator);
        if (operator != _to) {
            recordMint(collection, _to);
        }

        collection.mintEdition(_to);
    }

    function recordMint(IEditionSingleMintable collection, address minter) internal {
        bytes32 _mintId = mintId(collection, minter);

        if (minted[_mintId]) {
            revert AlreadyMinted(collection, minter);
        }

        minted[_mintId] = true;
    }

    function mintId(IEditionSingleMintable collection, address operator) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(collection, operator));
    }

    function hasMinted(IEditionSingleMintable collection, address operator) public view returns (bool) {
        return minted[mintId(collection, operator)];
    }
}