// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {IEdition} from "nft-editions/interfaces/IEdition.sol";

import {IShowtimeVerifier, SignedAttestation} from "src/interfaces/IShowtimeVerifier.sol";
import {IGatedEditionMinter} from "./interfaces/IGatedEditionMinter.sol";

contract GatedEditionMinter is IGatedEditionMinter {
    error NullAddress();
    error VerificationFailed();

    IShowtimeVerifier public immutable override showtimeVerifier;

    constructor(IShowtimeVerifier _showtimeVerifier) {
        if (address(_showtimeVerifier) == address(0)) {
            revert NullAddress();
        }

        showtimeVerifier = _showtimeVerifier;
    }

    /// @param signedAttestation the attestation to verify along with a corresponding signature
    /// @dev the edition to mint will be determined by the attestation's context
    /// @dev the recipient of the minted edition will be determined by the attestation's beneficiary
    function mintEdition(SignedAttestation calldata signedAttestation) public override {
        IEdition collection = IEdition(signedAttestation.attestation.context);

        if (!showtimeVerifier.verifyAndBurn(signedAttestation)) {
            revert VerificationFailed();
        }

        collection.mint(signedAttestation.attestation.beneficiary);
    }

    /// @notice a batch version of mintEdition
    /// @notice any failed call to mintEdition will revert the entire batch
    function mintEditions(SignedAttestation[] calldata signedAttestations) external override {
        uint256 length = signedAttestations.length;
        for (uint256 i = 0; i < length;) {
            mintEdition(signedAttestations[i]);

            unchecked {
                ++i;
            }
        }
    }
}
