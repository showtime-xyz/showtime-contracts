// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {IShowtimeVerifier, SignedAttestation} from "src/interfaces/IShowtimeVerifier.sol";

interface ISingleBatchEditionMinter {
    function mintBatch(SignedAttestation calldata signedAttestation) external;

    function showtimeVerifier() external view returns (IShowtimeVerifier);
}
