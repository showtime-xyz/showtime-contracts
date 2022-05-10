// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { TestForwarder } from "lib/gsn/packages/contracts/src/forwarder/test/TestForwarder.sol";
import { TestForwarderTarget } from "lib/gsn/packages/contracts/src/forwarder/test/TestForwarderTarget.sol";

import { ShowtimeForwarder } from "src/meta-tx/ShowtimeForwarder.sol";

import { DSTest } from "ds-test/test.sol";
import { Hevm } from "test/Hevm.sol";
import { ForwarderTestUtil } from "test/meta-tx/ForwarderTestUtil.sol";

contract ShowtimeForwarderTest is DSTest, ForwarderTestUtil {
    Hevm internal constant hevm = Hevm(HEVM_ADDRESS);
    uint256 internal constant FROM_PRIVATE_KEY = 0xbfea5ee5076b0bff4a26f7e3b5a8b8093c664a330cb7ab024f041b9ae077fa2e;
    address internal constant FROM_ADDRESS = 0xDE5E327cE4E7c1b64A757AaB8f2E699585977a34;



    ShowtimeForwarder forwarder = new ShowtimeForwarder();
    TestForwarderTarget target = new TestForwarderTarget(address(forwarder));

    function setUp() public {
        forwarder = new ShowtimeForwarder();
        forwarder.registerDomainSeparator("showtime.io", "1");
    }

    function testForwardFunctionCall() public {
        ShowtimeForwarder.ForwardRequest memory req;
        req.from = FROM_ADDRESS;
        req.to = address(target);
        req.value = 0;
        req.gas = 10000;
        req.nonce = forwarder.getNonce(req.from);
        req.data = abi.encodeWithSignature("emitMessage(string)", "hello");
        req.validUntilTime = 7697467249; // some arbitrary time in the year 2213

        (bool success, ) = signAndExecute(forwarder, FROM_PRIVATE_KEY, req, /* expectedError */ "");
        assertTrue(success);

        // when we replay the call
        // then it fails (because the nonce has incremented so we need to generate and sign a new request)
        signAndExecute(forwarder, FROM_PRIVATE_KEY, req, "FWD: nonce mismatch");
    }

    function testForwardTransfer() public {
        hevm.deal(address(this), 1 ether);

        // note: we can't call the receive() function of the target contract,
        // because by definition of the forwarder we can't call the target with empty calldata

        ShowtimeForwarder.ForwardRequest memory req;
        req.from = FROM_ADDRESS;
        req.to = address(target);
        req.value = 0.05 ether;
        req.gas = 10000;
        req.nonce = forwarder.getNonce(req.from);
        req.data = abi.encodeWithSignature("mustReceiveEth(uint256)", req.value);
        req.validUntilTime = 7697467249; // some arbitrary time in the year 2213

        uint256 balanceBefore = address(target).balance;
        (bool success, ) = signAndExecute(forwarder, FROM_PRIVATE_KEY, req, /* expectedError */ "");
        assertTrue(success);
        assertEq(address(target).balance, balanceBefore + req.value);
    }

    function getChainId() internal view returns (uint256 chainId) {
        /* solhint-disable-next-line no-inline-assembly */
        assembly { chainId := chainid() }
    }
}