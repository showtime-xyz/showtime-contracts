// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {IShowtimeVerifier, SignedAttestation} from "src/interfaces/IShowtimeVerifier.sol";

interface IBatchEditionMinter {
    function mintBatch(SignedAttestation calldata signedAttestation, bytes calldata recipients) external;

    function showtimeVerifier() external view returns (IShowtimeVerifier);
}
