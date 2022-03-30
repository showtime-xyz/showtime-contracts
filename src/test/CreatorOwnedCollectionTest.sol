// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./Hevm.sol";
import "../../lib/ds-test/src/test.sol";

import {SharedNFTLogic} from "@zora-nft-editions/SharedNFTLogic.sol";
import {SingleEditionMintable} from "@zora-nft-editions/SingleEditionMintable.sol";
import {SingleEditionMintableCreator} from "@zora-nft-editions/SingleEditionMintableCreator.sol";

contract User {}

contract CreatorOwnedCollectionTest is DSTest {
    Hevm internal constant hevm = Hevm(HEVM_ADDRESS);

    User internal alice = new User();
    User internal bob = new User();
    User internal charlieTheCreator = new User();

    SingleEditionMintableCreator editionCreator;

    function setUp() public {
        SharedNFTLogic sharedNFTLogic = new SharedNFTLogic();
        SingleEditionMintable editionImplementation = new SingleEditionMintable(sharedNFTLogic);
        editionCreator = new SingleEditionMintableCreator(address(editionImplementation));
    }

    function testCreateMintableCollection() public {
        // when charlieTheCreator calls `createEdition`
        hevm.prank(address(charlieTheCreator));
        uint newId = editionCreator.createEdition(
            "The Collection",
            "COLL",
            "The best collection in the world",
            "",     // _animationUrl
            0x0,    // _animationHash
            "http://example.com/image.png",
            keccak256("http://example.com/image.png"),
            2,      // _editionSize
            1000);  // _royaltyBPS

        // then we get a correctly configured collection
        SingleEditionMintable edition = editionCreator.getEditionAtId(newId);
        assertEq(edition.owner(), address(charlieTheCreator));
        assertEq(edition.name(), "The Collection");

        // when alice tries to mint from that collection, it should fail
        hevm.prank(address(alice));
        hevm.expectRevert("Needs to be an allowed minter");
        edition.mintEdition(address(alice));

        // when bob tries to open up public minting, it should fail
        hevm.prank(address(bob));
        hevm.expectRevert("Ownable: caller is not the owner");
        edition.setApprovedMinter(address(0), true);

        // when charlieTheCreator opens up public minting
        hevm.prank(address(charlieTheCreator));
        edition.setApprovedMinter(address(0), true);

        // then anybody can mint
        hevm.prank(address(alice));
        edition.mintEdition(address(alice));

        hevm.prank(address(bob));
        edition.mintEdition(address(bob));

        // when we are sold out, then new mints fail (even for charlieTheCreator)
        hevm.prank(address(charlieTheCreator));
        hevm.expectRevert("Sold out");
        edition.mintEdition(address(charlieTheCreator));
    }
}
