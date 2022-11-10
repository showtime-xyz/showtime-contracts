// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ERC1155Holder } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { Test } from "forge-std/Test.sol";

import { ShowtimeMT } from "src/ShowtimeMT.sol";
import { ShowtimeV1Market } from "src/ShowtimeV1Market.sol";

import { TestToken } from "test/TestToken.sol";

contract User is ERC1155Holder {}

contract ShowtimeMTAccessTest is Test, ERC1155Holder {
    User internal anon;
    User internal admin;
    User internal minter;
    address[] internal minters;
    ShowtimeMT internal mt;

    event UserAccessSet(address _user, string _access, bool _enabled);

    function setUp() public {
        anon = new User();
        admin = new User();
        minter = new User();
        minters = [
            address(new User()),
            address(new User()),
            address(new User()),
            address(new User()),
            address(new User())
        ];

        mt = new ShowtimeMT();
        mt.setAdmin(address(admin), true);
        mt.setMinter(address(minter), true);
    }

    // it non-minter should not be able to mint
    function testNotMintersCannotMint() public {
        vm.prank(address(anon));
        vm.expectRevert("AccessProtected: caller is not minter");

        mt.issueToken(address(this), 10, "some-hash", "0", address(0), 0);
    }

    // it owner should be able to set admin
    function testOwnerCanSetAdmin() public {
        assertTrue(!mt.isAdmin(address(anon)));

        vm.expectEmit(true, true, true, true);
        emit UserAccessSet(address(anon), "ADMIN", true);

        mt.setAdmin(address(anon), true);

        assertTrue(mt.isAdmin(address(anon)));
    }

    // it admin should be able to set minter
    function testAdminCanSetMinter() public {
        assertTrue(!mt.isMinter(address(anon)));

        vm.prank(address(admin));
        mt.setMinter(address(anon), true);
        emit UserAccessSet(address(anon), "MINTER", true);

        assertTrue(mt.isMinter(address(anon)));
    }

    // it admin should be able to set batch of minters
    function testAdminCanSetMinterBatch() public {
        for (uint256 i = 0; i < minters.length; i++) {
            assertTrue(!mt.isMinter(minters[i]));
        }

        vm.prank(address(admin));

        for (uint256 i = 0; i < minters.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit UserAccessSet(minters[i], "MINTER", true);
        }

        mt.setMinters(minters, true);

        for (uint256 i = 0; i < minters.length; i++) {
            assertTrue(mt.isMinter(minters[i]));
        }
    }

    // it admin should be able to revoke minter
    function testAdminCanRevokeMinter() public {
        assertTrue(mt.isMinter(address(minter)));

        vm.prank(address(admin));
        vm.expectEmit(true, true, true, true);
        emit UserAccessSet(address(minter), "MINTER", false);

        mt.setMinter(address(minter), false);

        assertTrue(!mt.isMinter(address(minter)));
    }

    // it admin should be able to revoke batch of minters
    function testAdminCanRevokeMinterBatch() public {
        vm.prank(address(admin));

        for (uint256 i = 0; i < minters.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit UserAccessSet(minters[i], "MINTER", false);
        }

        mt.setMinters(minters, false);

        for (uint256 i = 0; i < minters.length; i++) {
            assertTrue(!mt.isMinter(minters[i]));
        }
    }

    // it non-owner should not be able to set admin
    function testNonOwnerCannotSetAdmin() public {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(address(admin));
        mt.setAdmin(address(admin), true);
    }

    // it owner should be able to revoke admin
    function testOwnerCanRevokeAdmin() public {
        vm.expectEmit(true, true, true, true);
        emit UserAccessSet(address(admin), "ADMIN", false);

        mt.setAdmin(address(admin), false);

        assertTrue(!mt.isAdmin(address(admin)));
    }

    // it admin should be able to enable/disable minting for all
    function testAdminCanControlPublicMinting() public {
        vm.startPrank(address(admin));
        vm.expectEmit(true, true, true, true);
        emit UserAccessSet(address(0), "MINTER", true);

        mt.setPublicMinting(true);

        assertTrue(mt.publicMinting());

        vm.expectEmit(true, true, true, true);
        emit UserAccessSet(address(0), "MINTER", false);

        mt.setPublicMinting(false);

        assertTrue(!mt.publicMinting());
    }
}

contract ShowtimeMTMintingTest is Test, ERC1155Holder {
    User internal admin;
    ShowtimeMT internal mt;

    function setUp() public {
        admin = new User();

        mt = new ShowtimeMT();
        mt.setAdmin(address(admin), true);
    }

    // it minter should be able to mint
    function testMintersCanMint() public {
        mt.issueToken(address(admin), 10, "some-hash", "0", address(0), 0);
        assertEq(mt.balanceOf(address(admin), 1), 10);

        // assert no royalty
        (address receiver, uint256 royaltyAmount) = mt.royaltyInfo(1, 1 wei);
        assertEq(receiver, address(0));
        assertEq(royaltyAmount, 0);

        assertEq(mt.uri(1), "https://gateway.pinata.cloud/ipfs/some-hash");
    }

    // it minter should be able to batch mint
    function testMintersCanBatchMint() public {
        uint256[] memory tokenAmounts = new uint256[](5);
        string[] memory hashes = new string[](5);
        address[] memory addresses = new address[](5);
        uint256[] memory royalties = new uint256[](5);

        for (uint256 i = 0; i < 5; i++) {
            tokenAmounts[i] = i;
            hashes[i] = string(abi.encodePacked("hash-", i));
            addresses[i] = address(0);
            royalties[i] = 0;
        }

        uint256[] memory tokenIds = mt.issueTokenBatch(address(admin), tokenAmounts, hashes, "0", addresses, royalties);

        for (uint256 i = 0; i < 5; i++) {
            assertEq(mt.balanceOf(address(admin), tokenIds[i]), tokenAmounts[i]);

            // assert no royalty
            (address receiver, uint256 royaltyAmount) = mt.royaltyInfo(tokenIds[i], 1 wei);
            assertEq(receiver, address(0));
            assertEq(royaltyAmount, 0);

            assertEq(mt.uri(tokenIds[i]), string(abi.encodePacked("https://gateway.pinata.cloud/ipfs/", hashes[i])));
        }
    }

    // it should not be able to mint if public minting is disabled
    function testMintersCantMintIfMintingIsDisabled() public {
        vm.expectRevert("AccessProtected: caller is not minter");
        vm.prank(address(0x1));

        mt.issueToken(address(0x1), 10, "some-hash", "0", address(0), 0);
    }
}

contract ShowtimeMTBurningTest is Test, ERC1155Holder {
    ShowtimeMT internal mt;

    function setUp() public {
        mt = new ShowtimeMT();
    }

    // it holder should be able to burn
    function testHolderCanBurn() public {
        mt.issueToken(address(this), 10, "some-hash", "0", address(0), 0);
        assertEq(mt.balanceOf(address(this), 1), 10);

        mt.burn(address(this), 1, 10);
        assertEq(mt.balanceOf(address(this), 1), 0);
    }

    // it holder should be able to batch burn
    function testHolderCanBatchBurn() public {
        uint256[] memory tokenAmounts = new uint256[](5);
        string[] memory hashes = new string[](5);
        address[] memory addresses = new address[](5);
        uint256[] memory royalties = new uint256[](5);

        for (uint256 i = 0; i < 5; i++) {
            tokenAmounts[i] = i;
            hashes[i] = string(abi.encodePacked("hash-", i));
            addresses[i] = address(0);
            royalties[i] = 0;
        }
        uint256[] memory tokenIds = mt.issueTokenBatch(address(this), tokenAmounts, hashes, "0", addresses, royalties);

        for (uint256 i = 0; i < 5; i++) {
            assertEq(mt.balanceOf(address(this), tokenIds[i]), tokenAmounts[i]);
        }

        mt.burnBatch(address(this), tokenIds, tokenAmounts);

        for (uint256 i = 0; i < 5; i++) {
            assertEq(mt.balanceOf(address(this), tokenIds[i]), 0);
        }
    }

    // it can burn arbitrary amount
    function testArbitraryAmountsCanBeBurned() public {
        mt.issueToken(address(this), 10, "some-hash", "0", address(0), 0);
        assertEq(mt.balanceOf(address(this), 1), 10);

        mt.burn(address(this), 1, 5);
        assertEq(mt.balanceOf(address(this), 1), 5);
    }

    // it reverts of attempting to burn unowned tokens
    function testCannotBurnSomeonesTokens() public {
        mt.issueToken(address(0x1), 10, "some-hash", "0", address(0), 0);

        vm.expectRevert("ERC1155: caller is not token owner or approved");
        mt.burn(address(0x1), 1, 10);
    }

    // it reverts on attempting to batch burn unowned tokens
    function testCannotBatchBurnSomeonesTokens() public {
        uint256[] memory tokenAmounts = new uint256[](5);
        string[] memory hashes = new string[](5);
        address[] memory addresses = new address[](5);
        uint256[] memory royalties = new uint256[](5);

        for (uint256 i = 0; i < 5; i++) {
            tokenAmounts[i] = i;
            hashes[i] = string(abi.encodePacked("hash-", i));
            addresses[i] = address(0);
            royalties[i] = 0;
        }
        uint256[] memory tokenIds = mt.issueTokenBatch(address(0x1), tokenAmounts, hashes, "0", addresses, royalties);

        vm.expectRevert("ERC1155: caller is not token owner or approved");
        mt.burnBatch(address(0x1), tokenIds, tokenAmounts);
    }

    // it reverts on attempting to burn more than balance
    function testCannotBurnMoreThanOwned() public {
        mt.issueToken(address(this), 10, "some-hash", "0", address(0), 0);

        vm.expectRevert("ERC1155: burn amount exceeds balance");
        mt.burn(address(this), 1, 11);
    }
}

contract ShowtimeMTURITest is Test, ERC1155Holder {
    ShowtimeMT internal mt;
    uint256 internal tokenId;

    function setUp() public {
        mt = new ShowtimeMT();

        tokenId = mt.issueToken(address(this), 10, "some-hash", "0", address(0), 0);
    }

    // it should be able to get baseURI
    function testCanGetBaseURI() public {
        assertEq(mt.baseURI(), "https://gateway.pinata.cloud/ipfs/");
    }

    // it owner should be able to set baseURI
    function testOwnerCanSetBaseURI() public {
        mt.setBaseURI("https://gateway.test.com/ipfs/");

        assertEq(mt.baseURI(), "https://gateway.test.com/ipfs/");
    }

    // it should be able to get token URI
    function testCanGetTokenURI() public {
        assertEq(mt.uri(tokenId), "https://gateway.pinata.cloud/ipfs/some-hash");
    }
}

contract ShowtimeMTTransferTest is Test, ERC1155Holder {
    ShowtimeMT internal mt;
    uint256 internal tokenId;

    function setUp() public {
        mt = new ShowtimeMT();

        tokenId = mt.issueToken(address(this), 10, "some-hash", "0", address(0), 0);
    }

    // it nft-owner should be able to transfer amount
    function testCanTransfer() public {
        uint256 fromBalance = mt.balanceOf(address(this), tokenId);
        uint256 toBalance = mt.balanceOf(address(0x1), tokenId);

        mt.safeTransferFrom(address(this), address(0x1), tokenId, 1, "0");

        uint256 fromBalance_new = mt.balanceOf(address(this), tokenId);
        uint256 toBalance_new = mt.balanceOf(address(0x1), tokenId);
        assertEq(fromBalance_new, fromBalance - 1);
        assertEq(toBalance_new, toBalance + 1);
    }
}

contract ShowtimeMTRoyaltyTest is Test, ERC1155Holder {
    ShowtimeMT internal mt;

    function setUp() public {
        mt = new ShowtimeMT();
    }

    // it mints token with royalty
    function testMintsWithRoyalty() public {
        uint256 tokenId = mt.issueToken(address(this), 10, "some-hash", "0", address(0x1), 10_00);
        (address receiver, uint256 royaltyAmount) = mt.royaltyInfo(tokenId, 100); // 100 is sale price

        assertEq(receiver, address(0x1));
        assertEq(royaltyAmount, 10);
    }

    // it mints in batch with royalty
    function testBatchMintsWithRoyalty() public {
        uint256[] memory tokenAmounts = new uint256[](5);
        string[] memory hashes = new string[](5);
        address[] memory addresses = new address[](5);
        uint256[] memory royalties = new uint256[](5);

        for (uint256 i = 0; i < 5; i++) {
            tokenAmounts[i] = i;
            hashes[i] = string(abi.encodePacked("hash-", i));
            addresses[i] = address(0x1);
            royalties[i] = 500 * (i + 1);
        }
        uint256[] memory tokenIds = mt.issueTokenBatch(address(this), tokenAmounts, hashes, "0", addresses, royalties);
        for (uint256 i = 0; i < 5; i++) {
            (address receiver, uint256 royaltyAmount) = mt.royaltyInfo(tokenIds[i], 100);
            assertEq(receiver, address(0x1));
            assertEq(royaltyAmount, 5 * (i + 1));
        }
    }

    // it throws on % greater than 100%
    function testCannotHaveMoreThan100PercentRoyalty() public {
        vm.expectRevert("ERC2981Royalties: value too high");
        mt.issueToken(address(this), 10, "some-hash", "0", address(this), 101_00);
    }
}

contract ShowtimeMTERC165Test is Test, ERC1155Holder {
    ShowtimeMT internal mt;

    function setUp() public {
        mt = new ShowtimeMT();
    }

    // it supports interface IERC165
    function testIERC165Support() public {
        assertTrue(mt.supportsInterface(0x01ffc9a7));
    }

    // it supports interface IERC1155
    function testIERC1155Support() public {
        assertTrue(mt.supportsInterface(0xd9b67a26));
    }

    // it supports interface IERC2981
    function testIERC2981Support() public {
        assertTrue(mt.supportsInterface(0x2a55205a));
    }

    // it returns false for 0xffffffff
    function testReturnsFalseForFFF() public {
        assertTrue(!mt.supportsInterface(0xffffffff));
    }
}
