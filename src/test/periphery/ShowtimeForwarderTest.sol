// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ShowtimeForwarder} from "../../periphery/ShowtimeForwarder.sol";
import {TestForwarder} from "gsn/forwarder/test/TestForwarder.sol";
import {TestForwarderTarget} from "gsn/forwarder/test/TestForwarderTarget.sol";

import "../Hevm.sol";
import "../../../lib/ds-test/src/test.sol";

contract ShowtimeForwarderTest is DSTest {
    ShowtimeForwarder forwarder = new ShowtimeForwarder();
    TestForwarderTarget target = new TestForwarderTarget(address(forwarder));

    function setUp() public {
    }

    function testForward() public {
        // // verifying contract: 0xce71065d4017f316ec606fe4422e11eb2c47c246
        // emit log("verifying contract:");
        // emit log_address(address(forwarder));

        // // target address: 0x185a4dc360ce69bdccee33b3784b0282f7961aea
        // emit log("target address:");
        // emit log_address(address(target));

        // emit log("chain id:");
        // emit log_uint(getChainId());

        // bytes memory data = abi.encodeWithSignature("emitMessage(string)", "hello");
        // emit log("encoded function call data:");
        // emit log_bytes(data);

        // the domain separator depends on the address of the forwarder and the chain id, update accordingly
        forwarder.registerDomainSeparator("showtime.io", "1");
        bytes32 domainSeparator = 0xd4902b142b24e322de5733208247036df197359c2cb2c333baf08873b47f56f1;

        // keccak256("ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data,uint256 validUntilTime)")
        bytes32 requestTypeHash = 0xb91ae508e6f0e8e33913dec60d2fdcb39fe037ce56198c70a7927d7cd813fd96;

        ShowtimeForwarder.ForwardRequest memory req;

        // Private Key: bfea5ee5076b0bff4a26f7e3b5a8b8093c664a330cb7ab024f041b9ae077fa2e
        req.from = 0xDE5E327cE4E7c1b64A757AaB8f2E699585977a34;
        req.to = address(target);
        req.value = 0;
        req.gas = 10000;
        req.nonce = forwarder.getNonce(req.from); // initially 0
        req.data = data;
        req.validUntilTime = 7697467249; // some arbitrary time in the year 2213

        bytes memory suffixData = "";

        // generate with `node scripts/sign_eip712.mjs`
        bytes memory sig = hex"2933c598de4e399921331224f2964da4fbfc6708f0ca5b89c969b463416cd49035c9263317b71fdd993d893f15207ba1926c59b548fcfe9b268e69af73b7bd561c";

        (bool success, bytes memory ret) = forwarder.execute(req, domainSeparator, requestTypeHash, suffixData, sig);
        assertTrue(success);

        emit log("ret:");
        emit log_bytes(ret);
    }

    function testDirectCall() public {}

    function getChainId() internal view returns (uint256 chainId) {
        /* solhint-disable-next-line no-inline-assembly */
        assembly { chainId := chainid() }
    }
}