// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {IEditionSingleMintable} from "@zoralabs/nft-editions-contracts/contracts/IEditionSingleMintable.sol";

import { BaseRelayRecipient } from "../utils/BaseRelayRecipient.sol";

import { IEditionMinter } from "./interfaces/IEditionMinter.sol";
import { TimeCop } from "./TimeCop.sol";

contract OnePerAddressEditionMinter is BaseRelayRecipient, TimeCop, IEditionMinter {
    error AlreadyMinted(IEditionSingleMintable collection, address operator);
    error TimeLimitReached(IEditionSingleMintable collection);

    mapping(IEditionSingleMintable => mapping(address => bool)) minted;

    constructor(address _trustedForwarder, uint256 _maxDurationSeconds) TimeCop(_maxDurationSeconds) {
        trustedForwarder = _trustedForwarder;
    }

    function mintEdition(IEditionSingleMintable collection, address _to) override external {
        if (timeLimitReached(address(collection))) {
            revert TimeLimitReached(collection);
        }

        address operator = _msgSender();
        recordMint(collection, operator);
        if (operator != _to) {
            recordMint(collection, _to);
        }

        collection.mintEdition(_to);
    }

    function recordMint(IEditionSingleMintable collection, address minter) internal {
        if (hasMinted(collection, minter)) {
            revert AlreadyMinted(collection, minter);
        }

        minted[collection][minter] = true;
    }

    function hasMinted(IEditionSingleMintable collection, address minter) public view returns (bool) {
        return minted[collection][minter];
    }

    /// @notice deletes the record of who minted for that collection if we are past the claim window
    /// @notice no-op if there was no time limit set or it has not expired yet
    function purgeStorage(IEditionSingleMintable collection) external returns (bool expired) {
        expired = timeLimitReached(address(collection));
        if (!expired) {
            return false;
        }

        // TODO: do the thing
    }
}