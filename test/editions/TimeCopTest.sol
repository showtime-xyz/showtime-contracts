// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { TimeCop } from "src/editions/TimeCop.sol";

import { DSTest } from "ds-test/test.sol";
import { Hevm } from "test/Hevm.sol";

contract Collection is Ownable {}

contract TimeCopTest is DSTest {
    event TimeLimitSet(address collection, uint256 deadline);

    Hevm internal constant hevm = Hevm(HEVM_ADDRESS);
    string internal constant InvalidTimeLimit = "InvalidTimeLimit(uint256)";

    address internal collection;
    TimeCop internal timeCopNoMax;
    TimeCop internal timeCop;

    function setUp() public {
        collection = address(new Collection());

        timeCopNoMax = new TimeCop(0);
        timeCop = new TimeCop(48 hours);
    }

    function testZeroTimeLimit() public {
        hevm.expectRevert(abi.encodeWithSignature(InvalidTimeLimit, 0));
        timeCopNoMax.setTimeLimit(collection, 0);

        hevm.expectRevert(abi.encodeWithSignature(InvalidTimeLimit, 0));
        timeCop.setTimeLimit(collection, 0);
    }

    function testValidLimitWithMaxDuration() public {
        timeCop.setTimeLimit(collection, 2 hours);
        assertEq(timeCop.timeLimits(collection) - block.timestamp, 2 hours);
    }

    function testEventEmitted() public {
        hevm.expectEmit(true, true, true, true);
        emit TimeLimitSet(collection, block.timestamp + 2 hours);

        timeCop.setTimeLimit(collection, 2 hours);
    }

    function testLargeTimeLimitWithNoMaxDuration() public {
        timeCopNoMax.setTimeLimit(collection, 500 weeks);
        assertEq(timeCopNoMax.timeLimits(collection) - block.timestamp, 500 weeks);
    }

    function testLargeTimeLimitWithMaxDuration() public {
        hevm.expectRevert(abi.encodeWithSignature(InvalidTimeLimit, 500 weeks));
        timeCop.setTimeLimit(collection, 500 weeks);
    }

    function testNotCollectionOwner() public {
        Ownable(collection).renounceOwnership();

        hevm.expectRevert(abi.encodeWithSignature("NotCollectionOwner()"));
        timeCop.setTimeLimit(collection, 2 hours);
    }

    function testTimeLimitReached() public {
        timeCop.setTimeLimit(collection, 2 hours);
        assertTrue(!timeCop.timeLimitReached(collection));

        hevm.warp(block.timestamp + 3 hours);
        assertTrue(timeCop.timeLimitReached(collection));
    }

    function testTimeLimitAlreadySet() public {
        timeCop.setTimeLimit(collection, 2 hours);

        hevm.expectRevert(abi.encodeWithSignature("TimeLimitAlreadySet()"));
        timeCop.setTimeLimit(collection, 2 hours);
    }
}