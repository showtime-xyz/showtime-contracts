// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ISingleBatchEdition} from "nft-editions/interfaces/ISingleBatchEdition.sol";

import {IShowtimeVerifier, SignedAttestation} from "src/interfaces/IShowtimeVerifier.sol";
import {ISingleBatchEditionMinter} from "./interfaces/ISingleBatchEditionMinter.sol";
import "./interfaces/Errors.sol";

contract SingleBatchEditionMinter is ISingleBatchEditionMinter {
    IShowtimeVerifier public immutable override showtimeVerifier;

    constructor(IShowtimeVerifier _showtimeVerifier) {
        if (address(_showtimeVerifier) == address(0)) {
            revert NullAddress();
        }

        showtimeVerifier = _showtimeVerifier;
    }

    /// @param signedAttestation the attestation to verify along with a corresponding signature
    /// @dev the edition to mint will be determined by the attestation's context
    /// @dev the attestation's beneficiary will be interpreted as the SSTORE2 pointer for this batch mint
    function mintBatch(SignedAttestation calldata signedAttestation) public override {
        ISingleBatchEdition collection = ISingleBatchEdition(signedAttestation.attestation.context);

        // no need to call verifyAndBurn because this is a *SingleBatch*Edition,
        // meaning that this attestation can not be replayed
        if (!showtimeVerifier.verify(signedAttestation)) {
            revert VerificationFailed();
        }

        collection.mintBatch(signedAttestation.attestation.beneficiary);
    }
}
