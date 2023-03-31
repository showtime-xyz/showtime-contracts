// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {IShowtimeVerifier, SignedAttestation} from "src/interfaces/IShowtimeVerifier.sol";

interface IBatchEditionMinter {
    function mintBatch(bytes calldata recipients, SignedAttestation calldata signedAttestation)
        external
        returns (uint256);

    function showtimeVerifier() external view returns (IShowtimeVerifier);
}
