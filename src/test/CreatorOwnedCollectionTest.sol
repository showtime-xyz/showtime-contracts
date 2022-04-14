// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {SharedNFTLogic} from "@zoralabs/nft-editions-contracts/contracts/SharedNFTLogic.sol";
import {SingleEditionMintable} from "@zoralabs/nft-editions-contracts/contracts/SingleEditionMintable.sol";
import {SingleEditionMintableCreator} from "@zoralabs/nft-editions-contracts/contracts/SingleEditionMintableCreator.sol";

import "./Hevm.sol";
import "../../lib/ds-test/src/test.sol";
import "../../lib/gsn/packages/contracts/src/forwarder/IForwarder.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC721Upgradeable.sol";

import {OnePerAddressEditionMinter} from "../periphery/OnePerAddressEditionMinter.sol";
import {MetaSingleEditionMintableCreator, ISingleEditionMintable} from "../periphery/MetaSingleEditionMintableCreator.sol";
import {ShowtimeForwarder} from "../periphery/ShowtimeForwarder.sol";

contract User {}

contract CreatorOwnedCollectionTest is DSTest {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    Hevm internal constant hevm = Hevm(HEVM_ADDRESS);
    bytes32 internal constant FORWARDREQUEST_TYPE_HASH = keccak256("ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data,uint256 validUntilTime)");

    User internal alice = new User();
    User internal bob = new User();
    User internal charlieTheCreator = new User();
    User internal relayer = new User();

    SingleEditionMintableCreator editionCreator;
    MetaSingleEditionMintableCreator metaEditionCreator;
    OnePerAddressEditionMinter minter;
    ShowtimeForwarder forwarder;

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
        sharedTestOnePerAddress(address(edition));
    }

    function testCreateMintableCollectionViaMetaFactory() public {
        // when charlieTheCreator calls `createEdition`
        hevm.prank(address(charlieTheCreator));
        ISingleEditionMintable edition = createDummyEdition(address(minter));

        // then we get a properly configured collection
        assertEq(edition.owner(), address(charlieTheCreator));
        assertEq(edition.name(), "The Collection");

        // and anybody can mint once via the minter contract
        sharedTestOnePerAddress(address(edition));
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
            validUntilTime: 7697467249 // some arbitrary time in the year 2213
        });

        // look! no pranking!
        (bool success, bytes memory ret) = signAndExecute(walletPrivateKey, req, "");
        assertTrue(success);

        uint newId = uint(bytes32(ret));

        // then we get a properly configured collection
        ISingleEditionMintable edition = metaEditionCreator.getEditionAtId(newId);
        assertEq(edition.owner(), walletAddress); // the owner is the address of the signer of the meta-tx
        assertEq(edition.name(), "The Collection");

        // and anybody can mint once via the minter contract
        sharedTestOnePerAddress(address(edition));
    }

    function testClaimOnePerAddressViaMetaTransaction() public {
        // setup
        OnePerAddressEditionMinter metaMinter = new OnePerAddressEditionMinter(address(forwarder));

        // when charlieTheCreator calls `createEdition` (via a direct tx)
        hevm.prank(address(charlieTheCreator));
        ISingleEditionMintable edition = createDummyEdition(address(metaMinter));

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
                walletAddress
            ),
            validUntilTime: block.timestamp + 1 minutes
        });

        // anybody can mint via a meta-tx, and the owner of the NFT is the meta-tx signer
        hevm.expectEmit(true, true, true, true);
        emit Transfer(address(0), walletAddress, 1);
        (bool success, bytes memory ret) = signAndExecute(walletPrivateKey, req, "");
        assertTrue(success);

        // can't straight up replay
        signAndExecute(walletPrivateKey, req, "FWD: nonce mismatch");

        // if we try to mint again...
        req.nonce = 1;

        // then we get an error because walletAddress has already claimed this edition
        //   (can't get this expect revert to work for some reason)
        // hevm.expectRevert(abi.encodeWithSignature("AlreadyMinted(address,address)", address(edition), walletAddress));
        (success, ret) = signAndExecute(walletPrivateKey, req, "");
        assertTrue(!success);

        // can't try to be cute and go straight to the contract, bypassing the forwarder
        hevm.prank(walletAddress);
        hevm.expectRevert(abi.encodeWithSignature("AlreadyMinted(address,address)", address(edition), walletAddress));
        metaMinter.mintEdition(address(edition), walletAddress);
    }

    function sharedTestOnePerAddress(address _edition) internal {
        ISingleEditionMintable edition = ISingleEditionMintable(_edition);

        // and anybody can mint
        hevm.prank(address(alice));
        minter.mintEdition(address(edition), address(alice));

        hevm.prank(address(bob));
        minter.mintEdition(address(edition), address(bob));

        // but only via the contract (unless you're the owner of the edition)
        hevm.prank(address(alice));
        hevm.expectRevert("Needs to be an allowed minter");
        edition.mintEdition(address(alice));

        // and only once per address
        hevm.prank(address(alice));
        hevm.expectRevert(abi.encodeWithSignature("AlreadyMinted(address,address)", address(edition), address(alice)));
        minter.mintEdition(address(edition), address(alice));
    }

    function getDomainSeparator(string memory name, string memory version)
        internal view returns (bytes32 domainHash)
    {
        uint256 chainId;
        /* solhint-disable-next-line no-inline-assembly */
        assembly { chainId := chainid() }

        bytes memory domainValue = abi.encode(
            keccak256(bytes(forwarder.EIP712_DOMAIN_TYPE())),
            keccak256(bytes(name)),
            keccak256(bytes(version)),
            chainId,
            address(forwarder));

        domainHash = keccak256(domainValue);
    }

    function signAndExecute(
        uint256 privateKey,
        IForwarder.ForwardRequest memory req,
        bytes memory expectedError) internal returns (bool, bytes memory)
    {
        bytes32 domainSeparator = getDomainSeparator("showtime.io", "1");

        bytes32 digest = keccak256(abi.encodePacked(
                "\x19\x01", domainSeparator,
                keccak256(forwarder._getEncoded(req, FORWARDREQUEST_TYPE_HASH, ""))
        ));

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(privateKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        if (expectedError.length > 0) {
            hevm.expectRevert(expectedError);
        }

        (bool success, bytes memory ret) = forwarder.execute(
            req,
            domainSeparator,
            FORWARDREQUEST_TYPE_HASH,
            "",
            sig);

        return (success, ret);
    }

    function createDummyEdition(address _minter)
        internal returns (ISingleEditionMintable edition)
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

        edition = metaEditionCreator.getEditionAtId(newId);
    }
}
