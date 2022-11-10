// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

import { IEdition } from "nft-editions/interfaces/IEdition.sol";
import { Edition } from "nft-editions/Edition.sol";
import { EditionCreator } from "nft-editions/EditionCreator.sol";

import { Test } from "forge-std/Test.sol";

interface IOwnable {
    function owner() external view returns (address);
}

contract User {}

contract CreatorOwnedCollectionTest is Test {
    User internal alice = new User();
    User internal bob = new User();
    User internal charlieTheCreator = new User();

    EditionCreator internal editionCreator;

    function setUp() public {
        Edition editionImpl = new Edition();
        editionCreator = new EditionCreator(address(editionImpl));
    }

    function testCreateMintableCollection() public {
        // when charlieTheCreator calls `createEdition`
        vm.prank(address(charlieTheCreator));
        IEdition edition = editionCreator.createEdition(
            "The Collection",
            "COLL",
            "The best collection in the world",
            "", // _animationUrl
            "http://example.com/image.png",
            2, // _editionSize
            10_00, // _royaltyBPS
            0 // _mintPeriodSeconds
        );

        // then we get a correctly configured collection
        assertEq(IOwnable(address(edition)).owner(), address(charlieTheCreator));
        assertEq(IERC721Metadata(address(edition)).name(), "The Collection");

        // when alice tries to mint from that collection, it should fail
        vm.prank(address(alice));
        vm.expectRevert("Needs to be an allowed minter");
        edition.mint(address(alice));

        // when bob tries to open up public minting, it should fail
        vm.prank(address(bob));
        vm.expectRevert("Ownable: caller is not the owner");
        edition.setApprovedMinter(address(0), true);

        // when charlieTheCreator opens up public minting
        vm.prank(address(charlieTheCreator));
        edition.setApprovedMinter(address(0), true);

        // then anybody can mint
        vm.prank(address(alice));
        edition.mint(address(alice));

        vm.prank(address(bob));
        edition.mint(address(bob));

        // when we are sold out, then new mints fail (even for charlieTheCreator)
        vm.prank(address(charlieTheCreator));
        vm.expectRevert("Sold out");
        edition.mint(address(charlieTheCreator));
    }
}
