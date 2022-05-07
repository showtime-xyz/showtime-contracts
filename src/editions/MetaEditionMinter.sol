// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IEditionSingleMintable } from "@zoralabs/nft-editions-contracts/contracts/IEditionSingleMintable.sol";

import { BaseRelayRecipient } from "../utils/BaseRelayRecipient.sol";

import { IEditionMinter } from "./interfaces/IEditionMinter.sol";
import { TimeCop } from "./TimeCop.sol";

contract MetaEditionMinter is BaseRelayRecipient, IEditionMinter, Initializable {
    error NullAddress();
    error AlreadyMinted(IEditionSingleMintable collection, address operator);
    error TimeLimitReached(IEditionSingleMintable collection);

    /// @dev these would be immutable if they were not set in the initializer
    IEditionSingleMintable public collection;
    TimeCop public timeCop;

    mapping(address => bool) public minted;

    /// @dev deploy the initial implementation via constructor and lock the contract, preventing calls to initialize()
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _trustedForwarder,
        IEditionSingleMintable _collection,
        TimeCop _timeCop
    ) external initializer {
        if (address(_collection) == address(0)) {
            revert NullAddress();
        }

        timeCop = _timeCop;

        // we accept the null address for the trusted forwarder (meta-tx disabled)
        trustedForwarder = _trustedForwarder;
        collection = _collection;
    }

    function mintEdition(address _to) external override {
        if (timeCop.timeLimitReached(address(collection))) {
            revert TimeLimitReached(collection);
        }

        address operator = _msgSender();
        recordMint(operator);
        if (operator != _to) {
            recordMint(_to);
        }

        collection.mintEdition(_to);
    }

    function recordMint(address minter) internal {
        if (minted[minter]) {
            revert AlreadyMinted(collection, minter);
        }

        minted[minter] = true;
    }

    /// @notice deletes the record of who minted for that collection if we are past the claim window
    /// @notice no-op if there was no time limit set or it has not expired yet
    function purge() external returns (bool expired) {
        // collection is not set in the implementation contract
        if (address(collection) == address(0)) {
            return false;
        }

        expired = timeCop.timeLimitReached(address(collection));
        if (!expired) {
            return false;
        }

        selfdestruct(payable(collection.owner()));
    }
}
