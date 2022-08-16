// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { IEditionSingleMintable } from "@zoralabs/nft-editions-contracts/contracts/IEditionSingleMintable.sol";
import { IShowtimeVerifier, SignedAttestation } from "src/interfaces/IShowtimeVerifier.sol";
import { IGatedEditionMinter } from "./interfaces/IGatedEditionMinter.sol";
import { TimeCop } from "./TimeCop.sol";

contract GatedEditionMinter is IGatedEditionMinter {
    error NullAddress();
    error TimeLimitReached(IEditionSingleMintable collection);
    error VerificationFailed();

    IShowtimeVerifier public immutable showtimeVerifier;
    TimeCop public immutable timeCop;

    constructor(IShowtimeVerifier _showtimeVerifier, TimeCop _timeCop) {
        if (address(_showtimeVerifier) == address(0) || address(_timeCop) == address(0)) {
            revert NullAddress();
        }

        showtimeVerifier = _showtimeVerifier;
        timeCop = _timeCop;
    }

    /// @param signedAttestation the attestation to verify along with a corresponding signature
    /// @dev the edition to mint will be determined by the attestation's context
    /// @dev the recipient of the minted edition will be determined by the attestation's beneficiary
    function mintEdition(SignedAttestation calldata signedAttestation) external override {
        IEditionSingleMintable collection = IEditionSingleMintable(signedAttestation.attestation.context);

        if (timeCop.timeLimitReached(address(collection))) {
            revert TimeLimitReached(collection);
        }

        if (!showtimeVerifier.verifyAndBurn(signedAttestation)) {
            revert VerificationFailed();
        }

        collection.mintEdition(signedAttestation.attestation.beneficiary);
    }
}
