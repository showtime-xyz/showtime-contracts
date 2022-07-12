// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IEditionSingleMintable } from "@zoralabs/nft-editions-contracts/contracts/IEditionSingleMintable.sol";

import { IShowtimeVerifier, Attestation } from "src/interfaces/IShowtimeVerifier.sol";
import { IGatedEditionMinter } from "./interfaces/IGatedEditionMinter.sol";
import { TimeCop } from "./TimeCop.sol";

contract GatedEditionMinter is IGatedEditionMinter, Initializable {
    event Destroyed(GatedEditionMinter minter, IEditionSingleMintable collection);

    error NullAddress();
    error AlreadyMinted(IEditionSingleMintable collection, address operator);
    error TimeLimitReached(IEditionSingleMintable collection);
    error TimeLimitNotReached(IEditionSingleMintable collection);
    error VerificationFailed();

    /// @dev these would be immutable if they were not set in the initializer
    IShowtimeVerifier public showtimeVerifier;
    IEditionSingleMintable public collection;
    TimeCop public timeCop;

    mapping(address => bool) public minted;

    /// @dev deploy the initial implementation via constructor and lock the contract, preventing calls to initialize()
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IShowtimeVerifier _showtimeVerifier,
        IEditionSingleMintable _collection,
        TimeCop _timeCop
    ) external initializer {
        if (address(_showtimeVerifier) == address(0)
            || address(_collection) == address(0)
            || address(_timeCop) == address(0))
        {
            revert NullAddress();
        }

        showtimeVerifier = _showtimeVerifier;
        collection = _collection;
        timeCop = _timeCop;
    }

    function mintEdition(
        address _to,
        Attestation calldata attestation,
        bytes calldata signature
    )
        external override
    {
        if (timeCop.timeLimitReached(address(collection))) {
            revert TimeLimitReached(collection);
        }

        if (!showtimeVerifier.verify(attestation, signature)) {
            revert VerificationFailed();
        }

        recordMint(_to);

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
    function purge() external {
        // collection is not set in the implementation contract
        if (address(collection) == address(0)) {
            revert NullAddress();
        }

        bool expired = timeCop.timeLimitReached(address(collection));
        if (!expired) {
            revert TimeLimitNotReached(collection);
        }

        emit Destroyed(this, collection);

        selfdestruct(payable(collection.owner()));
    }
}
