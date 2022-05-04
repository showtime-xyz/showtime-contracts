// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { IForwarder } from "gsn/forwarder/IForwarder.sol";
import { IERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC721Upgradeable.sol";
import { SharedNFTLogic } from "@zoralabs/nft-editions-contracts/contracts/SharedNFTLogic.sol";
import { SingleEditionMintable } from "@zoralabs/nft-editions-contracts/contracts/SingleEditionMintable.sol";
import { SingleEditionMintableCreator } from "@zoralabs/nft-editions-contracts/contracts/SingleEditionMintableCreator.sol";

import { OnePerAddressEditionMinter, IEditionSingleMintable } from "src/editions/OnePerAddressEditionMinter.sol";
import { MetaSingleEditionMintableCreator } from "src/editions/MetaSingleEditionMintableCreator.sol";
import { ShowtimeForwarder } from "src/meta-tx/ShowtimeForwarder.sol";

import { DSTest } from "ds-test/test.sol";
import { Hevm } from "test/Hevm.sol";
import { ForwarderTestUtil } from "test/meta-tx/ForwarderTestUtil.sol";

contract User {}

contract CreatorOwnedCollectionTest is DSTest, ForwarderTestUtil {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    Hevm internal constant hevm = Hevm(HEVM_ADDRESS);

    User internal alice = new User();
    User internal bob = new User();
    User internal charlieTheCreator = new User();
    User internal relayer = new User();

    SingleEditionMintableCreator internal editionCreator;
    MetaSingleEditionMintableCreator internal metaEditionCreator;
    OnePerAddressEditionMinter internal minter;
    ShowtimeForwarder internal forwarder;

    function setUp() public {
        SharedNFTLogic sharedNFTLogic = new SharedNFTLogic();
        SingleEditionMintable editionImplementation = new SingleEditionMintable(sharedNFTLogic);
        editionCreator = new SingleEditionMintableCreator(address(editionImplementation));

        forwarder = new ShowtimeForwarder();
        metaEditionCreator = new MetaSingleEditionMintableCreator(address(forwarder), address(editionCreator));
        minter = new OnePerAddressEditionMinter(address(0));

        forwarder.registerDomainSeparator("showtime.io", "1");
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

    function testCreateMintableCollectionViaOnePerAddressContract() public {
        // when charlieTheCreator calls `createEdition`
        hevm.prank(address(charlieTheCreator));
        uint newId = editionCreator.createEdition(
            "The Collection",
            "DROP",
            "The best collection in the world",
            "",     // _animationUrl
            0x0,    // _animationHash
            "ipfs://SOME_IMAGE_CID",
            keccak256("this is not really used, is it?"),
            0,      // _editionSize, 0 means unlimited
            1000);  // _royaltyBPS

        SingleEditionMintable edition = editionCreator.getEditionAtId(newId);
        assertEq(edition.owner(), address(charlieTheCreator));
        assertEq(edition.name(), "The Collection");

        // when charlieTheCreator opens up public minting
        hevm.prank(address(charlieTheCreator));
        edition.setApprovedMinter(address(minter), true);

        // then anybody can mint once via the minter contract
        sharedTestOnePerAddress(edition);
    }

    function testCreateMintableCollectionViaMetaFactory() public {
        // when charlieTheCreator calls `createEdition`
        hevm.prank(address(charlieTheCreator));
        SingleEditionMintable edition = createDummyEdition(address(minter));

        // then we get a properly configured collection
        assertEq(edition.owner(), address(charlieTheCreator));
        assertEq(edition.name(), "The Collection");

        // and anybody can mint once via the minter contract
        sharedTestOnePerAddress(edition);
    }

    function testCreateMintableCollectionViaMetaTransaction() public {
        // setup
        uint256 walletPrivateKey = 0xbfea5ee5076b0bff4a26f7e3b5a8b8093c664a330cb7ab024f041b9ae077fa2e;
        address walletAddress = hevm.addr(walletPrivateKey);

        // craft the meta-tx
        IForwarder.ForwardRequest memory req = IForwarder.ForwardRequest({
            from: walletAddress,
            to: address(metaEditionCreator),
            value: 0,
            gas: 1000000,
            nonce: forwarder.getNonce(walletAddress),
            data: abi.encodeWithSignature(
                "createEdition(string,string,string,string,bytes32,string,bytes32,uint256,uint256,address)",
                "The Collection",
                "DROP",
                "The best collection in the world",
                "",     // _animationUrl
                0x0,    // _animationHash
                "ipfs://SOME_IMAGE_CID",
                keccak256("this is not really used, is it?"),
                0,      // _editionSize, 0 means unlimited
                1000,   // _royaltyBPS
                address(minter)
            ),
            validUntilTime: block.timestamp + 1 minutes
        });

        // no pranking! address(this) is acting as a relayer
        (bool success, bytes memory ret) = signAndExecute(forwarder, walletPrivateKey, req, "");
        assertTrue(success);

        uint newId = uint(bytes32(ret));

        // then we get a properly configured collection
        SingleEditionMintable edition = SingleEditionMintable(address(metaEditionCreator.getEditionAtId(newId)));
        assertEq(edition.owner(), walletAddress); // the owner is the address of the signer of the meta-tx
        assertEq(edition.name(), "The Collection");

        // and anybody can mint once via the minter contract
        sharedTestOnePerAddress(edition);
    }

    function testClaimOnePerAddressViaMetaTransaction() public {
        // setup
        OnePerAddressEditionMinter metaMinter = new OnePerAddressEditionMinter(address(forwarder));

        // when charlieTheCreator calls `createEdition` (via a direct tx)
        hevm.prank(address(charlieTheCreator));
        SingleEditionMintable edition = createDummyEdition(address(metaMinter));

        uint256 walletPrivateKey = 0xbfea5ee5076b0bff4a26f7e3b5a8b8093c664a330cb7ab024f041b9ae077fa2e;
        address walletAddress = hevm.addr(walletPrivateKey);

        // craft the meta-tx
        IForwarder.ForwardRequest memory req = IForwarder.ForwardRequest({
            from: walletAddress,
            to: address(metaMinter),
            value: 0,
            gas: 200000,
            nonce: forwarder.getNonce(walletAddress),
            data: abi.encodeWithSignature(
                "mintEdition(address,address)",
                address(edition),
                address(alice)    // alice is the recipient of the claim
            ),
            validUntilTime: block.timestamp + 1 minutes
        });

        // anybody can mint via a meta-tx, and the owner of the NFT is the meta-tx signer
        hevm.expectEmit(true, true, true, true);
        emit Transfer(address(0), address(alice), 1);
        (bool success, bytes memory ret) = signAndExecute(forwarder, walletPrivateKey, req, "");
        assertTrue(success);

        // can't straight up replay
        signAndExecute(forwarder, walletPrivateKey, req, "FWD: nonce mismatch");

        // if we try to mint again...
        req.nonce = forwarder.getNonce(walletAddress);

        // then we get an error because walletAddress has already claimed this edition
        (success, ret) = signAndExecute(forwarder, walletPrivateKey, req, "");
        assertTrue(!success);
        assertEq0(ret, abi.encodeWithSignature("AlreadyMinted(address,address)", address(edition), walletAddress));

        // can't try to be cute and go straight to the contract, bypassing the forwarder
        hevm.prank(walletAddress);
        hevm.expectRevert(abi.encodeWithSignature("AlreadyMinted(address,address)", address(edition), walletAddress));
        metaMinter.mintEdition(edition, walletAddress);

        // alice has already claimed via a meta-tx, so she can't be the recipient of a claim again
        hevm.prank(address(bob));
        hevm.expectRevert(abi.encodeWithSignature("AlreadyMinted(address,address)", address(edition), address(alice)));
        metaMinter.mintEdition(edition, address(alice));

        // she also can't claim again for a 3rd party address (she's acting as the operator this time)
        hevm.prank(address(alice));
        hevm.expectRevert(abi.encodeWithSignature("AlreadyMinted(address,address)", address(edition), address(alice)));
        metaMinter.mintEdition(edition, address(bob));
    }

    function sharedTestOnePerAddress(IEditionSingleMintable edition) internal {
        // and anybody can mint
        hevm.prank(address(alice));
        minter.mintEdition(edition, address(alice));

        hevm.prank(address(bob));
        minter.mintEdition(edition, address(bob));

        // but only via the contract (unless you're the owner of the edition)
        hevm.prank(address(alice));
        hevm.expectRevert("Needs to be an allowed minter");
        edition.mintEdition(address(alice));

        // and only once per address
        hevm.prank(address(alice));
        hevm.expectRevert(abi.encodeWithSignature("AlreadyMinted(address,address)", address(edition), address(alice)));
        minter.mintEdition(edition, address(alice));
    }

    function createDummyEdition(address _minter)
        internal returns (SingleEditionMintable edition)
    {
        uint newId = metaEditionCreator.createEdition(
            "The Collection",
            "DROP",
            "The best collection in the world",
            "",     // _animationUrl
            0x0,    // _animationHash
            "ipfs://SOME_IMAGE_CID",
            keccak256("this is not really used, is it?"),
            0,      // _editionSize, 0 means unlimited
            1000,   // _royaltyBPS

            _minter);

        edition = SingleEditionMintable(address(metaEditionCreator.getEditionAtId(newId)));
    }
}
