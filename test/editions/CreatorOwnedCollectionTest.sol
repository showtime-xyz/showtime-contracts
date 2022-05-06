// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { IForwarder } from "gsn/forwarder/IForwarder.sol";
import { IERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC721Upgradeable.sol";
import { SharedNFTLogic } from "@zoralabs/nft-editions-contracts/contracts/SharedNFTLogic.sol";
import { SingleEditionMintable } from "@zoralabs/nft-editions-contracts/contracts/SingleEditionMintable.sol";
import { SingleEditionMintableCreator } from "@zoralabs/nft-editions-contracts/contracts/SingleEditionMintableCreator.sol";

import { MetaEditionMinter, IEditionSingleMintable } from "src/editions/MetaEditionMinter.sol";
import { MetaSingleEditionMintableCreator } from "src/editions/MetaSingleEditionMintableCreator.sol";
import { TimeCop } from "src/editions/TimeCop.sol";
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
    TimeCop internal timeCop;

    ShowtimeForwarder internal forwarder;

    function setUp() public {
        SharedNFTLogic sharedNFTLogic = new SharedNFTLogic();
        SingleEditionMintable editionImplementation = new SingleEditionMintable(sharedNFTLogic);
        editionCreator = new SingleEditionMintableCreator(address(editionImplementation));

        forwarder = new ShowtimeForwarder();
        metaEditionCreator = new MetaSingleEditionMintableCreator(
            address(forwarder),
            address(editionCreator),
            address(new MetaEditionMinter()),
            address(new TimeCop(31 days))
        );

        forwarder.registerDomainSeparator("showtime.io", "1");
    }

    function testCreateMintableCollectionViaMetaFactory() public {
        // when charlieTheCreator calls `createEdition`
        hevm.prank(address(charlieTheCreator));
        (SingleEditionMintable edition, MetaEditionMinter minter) = createDummyEdition();

        // then we get a properly configured collection
        assertEq(edition.owner(), address(charlieTheCreator));
        assertEq(edition.name(), "The Collection");

        // and anybody can mint once via the minter contract
        sharedTestOnePerAddress(edition, minter);
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
                "createEdition(string,string,string,string,bytes32,string,bytes32,uint256,uint256,uint256)",
                "The Collection",
                "DROP",
                "The best collection in the world",
                "",     // _animationUrl
                0x0,    // _animationHash
                "ipfs://SOME_IMAGE_CID",
                keccak256("this is not really used, is it?"),
                0,      // _editionSize, 0 means unlimited
                1000,   // _royaltyBPS
                2 days  // _claimWindowDurationSeconds
            ),
            validUntilTime: block.timestamp + 1 minutes
        });

        // no pranking! address(this) is acting as a relayer
        (bool success, bytes memory ret) = signAndExecute(forwarder, walletPrivateKey, req, "");
        assertTrue(success);

        address editionAddress = address(uint160(toUint256(ret, 0)));
        address minterAddress =  address(uint160(toUint256(ret, 32)));

        // then we get a properly configured collection
        SingleEditionMintable edition = SingleEditionMintable(editionAddress);
        assertEq(edition.owner(), walletAddress); // the owner is the address of the signer of the meta-tx
        assertEq(edition.name(), "The Collection");

        // and anybody can mint once via the minter contract
        sharedTestOnePerAddress(edition, MetaEditionMinter(minterAddress));
    }

    function testClaimOnePerAddressViaMetaTransaction() public {
        // when charlieTheCreator calls `createEdition` (via a direct tx)
        hevm.prank(address(charlieTheCreator));
        (SingleEditionMintable edition, MetaEditionMinter metaMinter) = createDummyEdition();

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
                "mintEdition(address)",
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
        metaMinter.mintEdition(walletAddress);

        // alice has already claimed via a meta-tx, so she can't be the recipient of a claim again
        hevm.prank(address(bob));
        hevm.expectRevert(abi.encodeWithSignature("AlreadyMinted(address,address)", address(edition), address(alice)));
        metaMinter.mintEdition(address(alice));

        // she also can't claim again for a 3rd party address (she's acting as the operator this time)
        hevm.prank(address(alice));
        hevm.expectRevert(abi.encodeWithSignature("AlreadyMinted(address,address)", address(edition), address(alice)));
        metaMinter.mintEdition(address(bob));
    }

    function sharedTestOnePerAddress(IEditionSingleMintable edition, MetaEditionMinter minter) internal {
        // and anybody can mint
        hevm.prank(address(alice));
        minter.mintEdition(address(alice));

        hevm.prank(address(bob));
        minter.mintEdition(address(bob));

        // but only via the contract (unless you're the owner of the edition)
        hevm.prank(address(alice));
        hevm.expectRevert("Needs to be an allowed minter");
        edition.mintEdition(address(alice));

        // and only once per address
        hevm.prank(address(alice));
        hevm.expectRevert(abi.encodeWithSignature("AlreadyMinted(address,address)", address(edition), address(alice)));
        minter.mintEdition(address(alice));
    }

    function createDummyEdition()
        internal returns (SingleEditionMintable edition, MetaEditionMinter metaMinter)
    {
        (address editionAddress, address minterAddress) = metaEditionCreator.createEdition(
            "The Collection",
            "DROP",
            "The best collection in the world",
            "",     // _animationUrl
            0x0,    // _animationHash
            "ipfs://SOME_IMAGE_CID",
            keccak256("this is not really used, is it?"),
            0,      // _editionSize, 0 means unlimited
            1000,   // _royaltyBPS
            2 hours // _claimWindowDurationSeconds
        );

        edition = SingleEditionMintable(editionAddress);
        metaMinter = MetaEditionMinter(minterAddress);
    }
}
