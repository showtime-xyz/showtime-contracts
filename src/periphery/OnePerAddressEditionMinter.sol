// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {IEditionSingleMintable} from "@zora-nft-editions/IEditionSingleMintable.sol";

import { BaseRelayRecipient } from "../utils/BaseRelayRecipient.sol";

contract OnePerAddressEditionMinter is BaseRelayRecipient {
    error AlreadyMinted(address collection, address operator);

    mapping(bytes32 => bool) minted;

    constructor(address _trustedForwarder) {
        trustedForwarder = _trustedForwarder;
    }

    function mintEdition(address collection, address _to) external {
        address operator = _msgSender();
        bytes32 _mintId = mintId(collection, operator);

        if (minted[_mintId]) {
            revert AlreadyMinted(collection, operator);
        }

        minted[_mintId] = true;
        IEditionSingleMintable(collection).mintEdition(_to);
    }

    function mintId(address collection, address operator) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(collection, operator));
    }

    function hasMinted(address collection, address operator) public view returns (bool) {
        return minted[mintId(collection, operator)];
    }
}