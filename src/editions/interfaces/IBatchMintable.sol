// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IBatchMintable {
    function mintBatch(bytes calldata recipients) external returns (uint256);
    function mintBatch(address pointer) external returns (uint256);
    function setApprovedMinter(address minter, bool allowed) external;
}
