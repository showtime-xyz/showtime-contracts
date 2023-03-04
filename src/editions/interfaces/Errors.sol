// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

error AddressMismatch(address expected, address actual);
error DuplicateEdition(address);
error InvalidBatch();
error InvalidTimeLimit(uint256 offsetSeconds);
error NullAddress();
error VerificationFailed();
error UnexpectedContext(address context);
