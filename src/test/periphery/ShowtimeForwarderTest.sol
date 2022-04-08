// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ShowtimeForwarder} from "../../periphery/ShowtimeForwarder.sol";
import {TestForwarder} from "../../lib/gsn/forwarder/test/TestForwarder.sol";
import {TestForwarderTarget} from "../../lib/gsn/forwarder/test/TestForwarderTarget.sol";

import "../Hevm.sol";
import "../../../lib/ds-test/src/test.sol";

contract ShowtimeForwarderTest is DSTest {
    ShowtimeForwarder forwarder = new ShowtimeForwarder();
    TestForwarderTarget target = new TestForwarderTarget(address(forwarder));

    function setUp() public {
        forwarder.registerDomainSeparator("showtime.io", 1);
    }

    function testSanity() public {
        assertEq(true, true);
    }

    function testInsanity() public {
        assertEq(true, false);
    }
}