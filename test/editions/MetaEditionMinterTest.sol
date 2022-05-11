// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { IEditionSingleMintable } from "@zoralabs/nft-editions-contracts/contracts/IEditionSingleMintable.sol";

import { MetaEditionMinter } from "src/editions/MetaEditionMinter.sol";
import { MetaEditionMinterFactory } from "src/editions/MetaEditionMinterFactory.sol";
import { TimeCop } from "src/editions/TimeCop.sol";

import { DSTest } from "ds-test/test.sol";
import { Hevm } from "test/Hevm.sol";

contract MockEdition {
    address public owner;

    constructor() {
        owner = msg.sender;
    }
}

contract MetaEditionMinterTest is DSTest {
    event Destroyed(address minter, address edition);

    Hevm internal constant hevm = Hevm(HEVM_ADDRESS);

    TimeCop internal timeCop;
    MetaEditionMinterFactory internal minterFactory;

    function setUp() public {
        timeCop = new TimeCop(2 hours);
        minterFactory = new MetaEditionMinterFactory(address(0), address(timeCop));
    }

    function testCanNotInitializeBaseImpl() public {
        MetaEditionMinter minterImplementation = new MetaEditionMinter();
        IEditionSingleMintable edition = dummyEdition();

        hevm.expectRevert("Initializable: contract is already initialized");
        minterImplementation.initialize(
            address(0),
            edition,
            timeCop
        );
    }

    function testTimeCopCanNotBeNullInFactory() public {
        hevm.expectRevert(abi.encodeWithSignature("NullAddress()"));
        new MetaEditionMinterFactory(address(0), address(0));
    }

    function testEditionCanNotBeNull() public {
        hevm.expectRevert(abi.encodeWithSignature("NullAddress()"));
        minterFactory.createMinter(IEditionSingleMintable(address(0)));
    }

    function testCanNotPurgeBaseImplementation() public {
        MetaEditionMinter minterImplementation = new MetaEditionMinter();

        hevm.expectRevert(abi.encodeWithSignature("NullAddress()"));
        minterImplementation.purge();
    }

    function testPurgeBeforeExpiration() public {
        IEditionSingleMintable edition = dummyEdition();
        MetaEditionMinter minter = minterFactory.createMinter(edition);

        hevm.expectRevert(abi.encodeWithSignature("TimeLimitNotReached(address)", edition));
        minter.purge();
    }

    function testPurgeWithNoTimeLimitSet() public {
        IEditionSingleMintable edition = dummyEdition();
        MetaEditionMinter minter = minterFactory.createMinter(edition);

        hevm.warp(block.timestamp + 2812039812 days);
        hevm.expectRevert(abi.encodeWithSignature("TimeLimitNotReached(address)", edition));
        minter.purge();
    }

    function testPurgeAfterExpiration() public {
        IEditionSingleMintable edition = dummyEdition();
        MetaEditionMinter minter = minterFactory.createMinter(edition);

        timeCop.setTimeLimit(address(edition), 2 hours);
        hevm.warp(block.timestamp + 2812039812 days);

        hevm.expectEmit(true, true, true, true);
        emit Destroyed(address(minter), address(edition));

        minter.purge();
    }

    function dummyEdition() public returns (IEditionSingleMintable) {
        return IEditionSingleMintable(address(new MockEdition()));
    }
}