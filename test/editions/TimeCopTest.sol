// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {TimeCop} from "src/editions/TimeCop.sol";

import {Test} from "forge-std/Test.sol";

contract Collection is Ownable {}

contract TimeCopTest is Test {
    event TimeLimitSet(address collection, uint256 deadline);

    string internal constant InvalidTimeLimit = "InvalidTimeLimit(uint256)";
    uint256 internal constant MAX_DURATION_SECONDS = 48 hours;

    address internal collection;
    TimeCop internal timeCopNoMax;
    TimeCop internal timeCop;

    function setUp() public {
        collection = address(new Collection());

        timeCopNoMax = new TimeCop(0);
        timeCop = new TimeCop(MAX_DURATION_SECONDS);
    }

    function testZeroTimeLimit(uint256 maxDuration) public {
        TimeCop _timeCop = new TimeCop(maxDuration);
        vm.expectRevert(abi.encodeWithSignature(InvalidTimeLimit, 0));
        _timeCop.setTimeLimit(collection, 0);
    }

    function testValidLimitWithMaxDuration(uint256 timeLimit) public {
        vm.assume(timeLimit < MAX_DURATION_SECONDS);
        vm.assume(timeLimit != 0);

        timeCop.setTimeLimit(collection, timeLimit);
        assertEq(timeCop.timeLimits(collection) - block.timestamp, timeLimit);
    }

    function testEventEmitted(uint256 timeLimit) public {
        vm.assume(timeLimit < MAX_DURATION_SECONDS);
        vm.assume(timeLimit != 0);

        vm.expectEmit(true, true, true, true);
        emit TimeLimitSet(collection, block.timestamp + timeLimit);

        timeCop.setTimeLimit(collection, timeLimit);
    }

    function testLargeTimeLimitWithNoMaxDuration(uint256 timeLimit) public {
        vm.assume(timeLimit > MAX_DURATION_SECONDS);
        vm.assume(timeLimit < type(uint256).max - block.timestamp);

        timeCopNoMax.setTimeLimit(collection, timeLimit);
        assertEq(timeCopNoMax.timeLimits(collection) - block.timestamp, timeLimit);
    }

    function testLargeTimeLimitWithMaxDuration(uint256 timeLimit) public {
        vm.assume(timeLimit > MAX_DURATION_SECONDS);
        vm.assume(timeLimit < type(uint256).max - block.timestamp);

        vm.expectRevert(abi.encodeWithSignature(InvalidTimeLimit, timeLimit));
        timeCop.setTimeLimit(collection, timeLimit);
    }

    function testNotCollectionOwner() public {
        Ownable(collection).renounceOwnership();

        vm.expectRevert(abi.encodeWithSignature("NotCollectionOwner()"));
        timeCop.setTimeLimit(collection, 2 hours);
    }

    function testTimeLimitReached() public {
        timeCop.setTimeLimit(collection, 2 hours);
        assertTrue(!timeCop.timeLimitReached(collection));

        vm.warp(block.timestamp + 3 hours);
        assertTrue(timeCop.timeLimitReached(collection));
    }

    function testTimeLimitAlreadySet() public {
        timeCop.setTimeLimit(collection, 2 hours);

        vm.expectRevert(abi.encodeWithSignature("TimeLimitAlreadySet()"));
        timeCop.setTimeLimit(collection, 2 hours);
    }
}
