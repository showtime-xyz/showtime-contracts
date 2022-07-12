// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { Attestation } from "src/interfaces/IShowtimeVerifier.sol";

interface IGatedEditionMinter {
    function mintEdition(
        address _to,
        Attestation calldata attestation,
        bytes calldata signature
    ) external;
}
