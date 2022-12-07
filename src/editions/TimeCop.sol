// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TimeCop {
    event TimeLimitSet(address collection, uint256 deadline);

    error InvalidTimeLimit(uint256 offsetSeconds);
    error NotCollectionOwner();
    error TimeLimitAlreadySet();

    uint256 public immutable MAX_DURATION_SECONDS;

    /// @notice the time limits expressed as a timestamp in seconds
    mapping(address => uint256) public timeLimits;

    /// @param _maxDurationSeconds maximum time limit
    /// @dev _maxDurationSeconds can be set to 0 to have no maximum time limit
    constructor(uint256 _maxDurationSeconds) {
        MAX_DURATION_SECONDS = _maxDurationSeconds;
    }

    /// @notice Sets the deadline for the given collection
    /// @notice Only the owner of the collection can set the deadline
    /// @param collection The address to set the deadline for
    /// @param offsetSeconds a duration in seconds that will be used to set the time limit
    function setTimeLimit(address collection, uint256 offsetSeconds) external {
        if (offsetSeconds == 0) {
            revert InvalidTimeLimit(offsetSeconds);
        }

        if (MAX_DURATION_SECONDS > 0 && offsetSeconds > MAX_DURATION_SECONDS) {
            revert InvalidTimeLimit(offsetSeconds);
        }

        if (timeLimitSet(collection)) {
            revert TimeLimitAlreadySet();
        }

        if (msg.sender != Ownable(collection).owner()) {
            revert NotCollectionOwner();
        }

        uint256 deadline = block.timestamp + offsetSeconds;
        timeLimits[collection] = deadline;

        emit TimeLimitSet(collection, deadline);
    }

    function timeLimitSet(address collection) public view returns (bool) {
        return timeLimits[collection] > 0;
    }

    /// @return false if there is no time limit set for that collection
    function timeLimitReached(address collection) public view returns (bool) {
        return timeLimitSet(collection) && block.timestamp > timeLimits[collection];
    }
}
