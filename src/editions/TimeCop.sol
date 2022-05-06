// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract TimeCop {
    event DeadlineSet(address collection, uint256 deadline);

    error InvalidDeadline(uint256 delta);
    error NotCollectionOwner();
    error NullAddress();

    uint256 public immutable MAX_DURATION_SECONDS;

    mapping(address => uint256) public deadlines;

    /// @param _maxDurationSeconds maximum time limit
    /// @dev _maxDurationSeconds can be set to 0 to have no maximum time limit
    constructor(uint256 _maxDurationSeconds) {
        MAX_DURATION_SECONDS = _maxDurationSeconds;
    }

    /// @notice Sets the deadline for the given collection
    /// @notice Only the owner of the collection can set the deadline
    /// @param collection The address to set the deadline for
    /// @param timeLimitSeconds a duration in seconds that will be used to set the deadline
    function setTimeLimit(address collection, uint256 timeLimitSeconds) external {
        if (timeLimitSeconds == 0) {
            revert InvalidDeadline(timeLimitSeconds);
        }

        if (MAX_DURATION_SECONDS > 0 && timeLimitSeconds > MAX_DURATION_SECONDS) {
            revert InvalidDeadline(timeLimitSeconds);
        }

        if (msg.sender != Ownable(collection).owner()) {
            revert NotCollectionOwner();
        }

        uint256 deadline = block.timestamp + timeLimitSeconds;
        deadlines[collection] = deadline;

        emit DeadlineSet(collection, deadline);
    }

    function timeLimitSet(address collection) public view returns (bool) {
        return deadlines[collection] > 0;
    }

    /// @return false if there is no time limit set for that collection
    function timeLimitReached(address collection) public view returns (bool) {
        return timeLimitSet(collection) && block.timestamp > deadlines[collection];
    }
}