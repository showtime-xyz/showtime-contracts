// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {TestForwarder} from "gsn/forwarder/test/TestForwarder.sol";
// import { TestForwarder } from "lib/gsn/packages/contracts/src/forwarder/test/TestForwarder.sol";
import {TestForwarderTarget} from "gsn/forwarder/test/TestForwarderTarget.sol";
// import { TestForwarderTarget } from "lib/gsn/packages/contracts/src/forwarder/test/TestForwarderTarget.sol";

import { ShowtimeForwarder } from "src/meta-tx/ShowtimeForwarder.sol";

import { DSTest } from "ds-test/test.sol";
import { Hevm } from "test/Hevm.sol";
import { ForwarderTestUtil } from "test/meta-tx/ForwarderTestUtil.sol";

contract ShowtimeForwarderTest is DSTest, ForwarderTestUtil {
    Hevm internal constant hevm = Hevm(HEVM_ADDRESS);
    ShowtimeForwarder forwarder = new ShowtimeForwarder();
    TestForwarderTarget target = new TestForwarderTarget(address(forwarder));

    function setUp() public {}

    function testForward() public {
        // // verifying contract: 0xce71065d4017f316ec606fe4422e11eb2c47c246
        // emit log("verifying contract:");
        // emit log_address(address(forwarder));

        // // target address: 0x185a4dc360ce69bdccee33b3784b0282f7961aea
        // emit log("target address:");
        // emit log_address(address(target));

        // emit log("chain id:");
        // emit log_uint(getChainId());

        uint nonce = forwarder.getNonce(0xDE5E327cE4E7c1b64A757AaB8f2E699585977a34);
        // emit log("forwarder.getNonce(from):");
        // emit log_uint(nonce);

        bytes memory data = abi.encodeWithSignature("emitMessage(string)", "hello");
        // emit log("encoded function call data:");
        // emit log_bytes(data);

        // the domain separator depends on the address of the forwarder and the chain id, update accordingly
        forwarder.registerDomainSeparator("showtime.io", "1");
        bytes32 domainSeparator = getDomainSeparator(forwarder, "showtime.io", "1");

        // keccak256("ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data,uint256 validUntilTime)")
        bytes32 requestTypeHash = FORWARDREQUEST_TYPE_HASH;

        ShowtimeForwarder.ForwardRequest memory req;

        // Private Key: bfea5ee5076b0bff4a26f7e3b5a8b8093c664a330cb7ab024f041b9ae077fa2e
        req.from = 0xDE5E327cE4E7c1b64A757AaB8f2E699585977a34;
        req.to = address(target);
        req.value = 0;
        req.gas = 10000;
        req.nonce = nonce;
        req.data = data;
        req.validUntilTime = 7697467249; // some arbitrary time in the year 2213

        bytes memory suffixData = "";

        // generate with `node scripts/sign_eip712.mjs`
        bytes memory sig = hex"317b4500265b302c2dbf937bbe7e5c31531aadbd8e6997bf00e234bd5c9b92fb5a3f1d8706dddc09d7e5b1b84bc28056d2c305e21427613a31f07381424b1d9c1c";

        (bool success, ) = forwarder.execute(req, domainSeparator, requestTypeHash, suffixData, sig);
        assertTrue(success);

        // when we replay the call
        // then it fails (because the nonce has incremented so we need to generate and sign a new request)
        hevm.expectRevert("FWD: nonce mismatch");
        forwarder.execute(req, domainSeparator, requestTypeHash, suffixData, sig);
    }

    function getChainId() internal view returns (uint256 chainId) {
        /* solhint-disable-next-line no-inline-assembly */
        assembly { chainId := chainid() }
    }
}