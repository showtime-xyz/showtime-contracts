// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ClonesUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import { SharedNFTLogic } from "@zoralabs/nft-editions-contracts/contracts/SharedNFTLogic.sol";
import { SingleEditionMintable } from "@zoralabs/nft-editions-contracts/contracts/SingleEditionMintable.sol";
import { SingleEditionMintableCreator } from "@zoralabs/nft-editions-contracts/contracts/SingleEditionMintableCreator.sol";

import { MetaEditionMinter } from "src/editions/MetaEditionMinter.sol";
import { TimeCop } from "src/editions/TimeCop.sol";

import { DSTest } from "ds-test/test.sol";
import { Hevm } from "test/Hevm.sol";

contract User {}

contract MetaEditionMinterTest is DSTest {
    event Destroyed(address minter, address edition);

    Hevm internal constant hevm = Hevm(HEVM_ADDRESS);

    SingleEditionMintableCreator internal editionCreator;
    SingleEditionMintable internal edition;
    TimeCop internal timeCop;

    MetaEditionMinter minterImplementation;

    function setUp() public {
        SharedNFTLogic sharedNFTLogic = new SharedNFTLogic();
        SingleEditionMintable editionImplementation = new SingleEditionMintable(sharedNFTLogic);
        editionCreator = new SingleEditionMintableCreator(address(editionImplementation));

        edition = editionCreator.getEditionAtId(
            editionCreator.createEdition(
                "The Collection",
                "DROP",
                "The best collection in the world",
                "",     // _animationUrl
                0x0,    // _animationHash
                "ipfs://SOME_IMAGE_CID",
                keccak256("this is not really used, is it?"),
                0,      // _editionSize, 0 means unlimited
                1000    // _royaltyBPS
            )
        );

        timeCop = new TimeCop(2 hours);

        minterImplementation = new MetaEditionMinter();
    }

    function testCanNotInitializeBaseImpl() public {
        hevm.expectRevert("Initializable: contract is already initialized");
        minterImplementation.initialize(
            address(0),
            edition,
            timeCop
        );
    }

    function testTimeCopNotNull() public {
        MetaEditionMinter minter = createNewMinter("testTimeCopNotNull");

        hevm.expectRevert(abi.encodeWithSignature("NullAddress()"));
        minter.initialize(
            address(0),
            edition,
            TimeCop(address(0))
        );
    }

    function testEditionNotNull() public {
        MetaEditionMinter minter = createNewMinter("testTimeCopNotNull");

        hevm.expectRevert(abi.encodeWithSignature("NullAddress()"));
        minter.initialize(
            address(0),
            SingleEditionMintable(address(0)),
            timeCop
        );
    }

    function testCanNotPurgeBaseImplementation() public {
        hevm.expectRevert(abi.encodeWithSignature("NullAddress()"));
        minterImplementation.purge();
    }

    function testPurgeBeforeExpiration() public {
        MetaEditionMinter minter = createNewMinter("testTimeCopNotNull");
        minter.initialize(address(0), edition, timeCop);

        hevm.expectRevert(abi.encodeWithSignature("TimeLimitNotReached(address)", edition));
        minter.purge();
    }

    function testPurgeWithNoTimeLimitSet() public {
        MetaEditionMinter minter = createNewMinter("testTimeCopNotNull");
        minter.initialize(address(0), edition, timeCop);

        hevm.warp(block.timestamp + 2812039812 days);
        hevm.expectRevert(abi.encodeWithSignature("TimeLimitNotReached(address)", edition));
        minter.purge();
    }

    function testPurgeAfterExpiration() public {
        MetaEditionMinter minter = createNewMinter("testTimeCopNotNull");
        minter.initialize(address(0), edition, timeCop);

        timeCop.setTimeLimit(address(edition), 2 hours);
        hevm.warp(block.timestamp + 2812039812 days);

        hevm.expectEmit(true, true, true, true);
        emit Destroyed(address(minter), address(edition));

        minter.purge();
    }

    function createNewMinter(string memory name) internal returns (MetaEditionMinter newMinter) {
        newMinter = MetaEditionMinter(
            ClonesUpgradeable.cloneDeterministic(
                address(minterImplementation),
                keccak256(bytes(name))
            )
        );
    }
}