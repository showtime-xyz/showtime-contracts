// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { IEditionSingleMintable } from "@zoralabs/nft-editions-contracts/contracts/IEditionSingleMintable.sol";

interface IEditionMinter {
    function mintEdition(IEditionSingleMintable edition, address _to) external;
}
