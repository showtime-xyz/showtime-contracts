// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {Test} from "forge-std/Test.sol";

import {ShowtimeMT} from "src/ShowtimeMT.sol";
import {ShowtimeV1Market, IERC20} from "src/ShowtimeV1Market.sol";

import {TestToken} from "test/TestToken.sol";

contract User is ERC1155Holder {}

contract ShowtimeV1MarketTest is Test, ERC1155Holder {
    uint256 constant INITIAL_NFT_SUPPLY = 10;
    address constant BURN_ADDRESS = address(0xdEaD);
    address constant FORWARDER_ADDRESS = BURN_ADDRESS;

    User internal bob;
    User internal alice;
    TestToken internal token;
    ShowtimeMT internal showtimeNFT;
    ShowtimeV1Market internal market;

    uint256 tokenId0PctRoyalty;
    uint256 tokenId10PctRoyaltyToAlice;
    uint256 tokenId100PctRoyaltyToAlice;
    uint256 tokenId10PctRoyaltyToZeroAddress;

    event ListingCreated(uint256 indexed listingId, address indexed seller, uint256 indexed tokenId);
    event ListingDeleted(uint256 indexed listingId, address indexed seller);
    event SaleCompleted(
        uint256 indexed listingId, address indexed seller, address indexed buyer, address receiver, uint256 quantity
    );
    event RoyaltyPaid(address indexed receiver, IERC20 currency, uint256 amount);
    event MaxRoyaltiesUpdated(address indexed account, uint256 maxRoyaltiesBasisPoints);
    event RoyaltiesEnabledChanged(address indexed account, bool royaltiesEnabled);
    event AcceptedCurrencyChanged(address indexed account, address currency, bool accepted);

    function setUp() public {
        alice = new User();
        bob = new User();

        // mint NFTs
        showtimeNFT = new ShowtimeMT();
        tokenId0PctRoyalty = showtimeNFT.issueToken(address(alice), INITIAL_NFT_SUPPLY, "some-hash", "0", address(0), 0);
        tokenId10PctRoyaltyToAlice =
            showtimeNFT.issueToken(address(this), INITIAL_NFT_SUPPLY, "some-hash", "0", address(alice), 10_00); // 10% royalty
        tokenId10PctRoyaltyToZeroAddress =
            showtimeNFT.issueToken(address(this), INITIAL_NFT_SUPPLY, "some-hash", "0", address(0), 10_00); // 10% royalty
        tokenId100PctRoyaltyToAlice =
            showtimeNFT.issueToken(address(this), INITIAL_NFT_SUPPLY, "some-hash", "0", address(alice), 100_00); // 100% royalty

        // mint erc20s to bob
        token = new TestToken();
        vm.prank(address(bob));
        token.mint(2500);

        address[] memory tokens = new address[](1);
        tokens[0] = address(token);

        // approvals
        market = new ShowtimeV1Market(address(showtimeNFT), FORWARDER_ADDRESS, tokens);
        showtimeNFT.setApprovalForAll(address(market), true);
        vm.prank(address(alice));
        showtimeNFT.setApprovalForAll(address(market), true);
        vm.prank(address(bob));
        token.approve(address(market), 2500);
    }

    // it doesn't allow to deploy with incorrect constructor arguments
    function testIncorrectConstructorArguments() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(token);

        try new ShowtimeV1Market(address(0x1), FORWARDER_ADDRESS, tokens) {
            emit log("Call did not revert");
            fail();
        } catch (bytes memory revertMsg) {
            assertEq(bytes32(revertMsg), bytes32(abi.encodeWithSignature("NotContractAddress(address)", address(0x1))));
        }

        try new ShowtimeV1Market(address(showtimeNFT), address(0), tokens) {
            emit log("Call did not revert");
            fail();
        } catch (bytes memory revertMsg) {
            assertEq(bytes32(revertMsg), bytes32(abi.encodeWithSignature("NullAddress()")));
        }

        tokens[0] = address(0);

        try new ShowtimeV1Market(address(showtimeNFT), FORWARDER_ADDRESS, tokens) {
            emit log("Call did not revert");
            fail();
        } catch (bytes memory revertMsg) {
            assertEq(bytes32(revertMsg), bytes32(abi.encodeWithSignature("NotContractAddress(address)", address(0x1))));
        }
    }

    // it deploys with correct constructor arguments"
    function testCorrectConstructorArguments() public {
        assertEq(address(market.nft()), address(showtimeNFT));
        assertTrue(market.acceptedCurrencies(address(token)));
        assertTrue(market.royaltiesEnabled());
    }

    // it creates a new listing
    function testCanCreateListing() public {
        vm.expectEmit(true, true, true, true);
        emit ListingCreated(0, address(alice), 1);

        // alice creates a sale
        vm.prank(address(alice));
        uint256 listingId = market.createSale(1, 5, 500, address(token));

        // alice still owns the NFTs
        assertEq(showtimeNFT.balanceOf(address(alice), 1), INITIAL_NFT_SUPPLY);

        (uint256 tokenId, uint256 quantity, uint256 price, IERC20 currency, address seller) = market.listings(listingId);

        assertEq(tokenId, 1);
        assertEq(quantity, 5);
        assertEq(price, 500);
        assertEq(address(currency), address(token));
        assertEq(seller, address(alice));
    }

    // it ensures that the seller owns the listed tokens
    function testSellerOwnsTokens() public {
        // alice does not own token 2
        assertEq(showtimeNFT.balanceOf(address(alice), 2), 0);

        vm.expectRevert(abi.encodeWithSignature("SellerDoesNotOwnToken(uint256,uint256)", 2, 5));
        vm.prank(address(alice));
        market.createSale(2, 5, 500, address(token));
    }

    // it ensures that the listing is in an accepted currency
    function testListingUsesAcceptedCurrenciesOnly() public {
        vm.expectRevert(abi.encodeWithSignature("CurrencyNotAccepted(address)", address(showtimeNFT)));

        vm.prank(address(alice));
        market.createSale(1, 5, 500, address(showtimeNFT));
    }

    // it ensures that the seller owns enough of the listed tokens
    function testSellerOwnsListedTokens() public {
        // alice owns INITIAL_NFT_SUPPLY of token 1
        assertEq(showtimeNFT.balanceOf(address(alice), 1), INITIAL_NFT_SUPPLY);

        vm.expectRevert(abi.encodeWithSignature("SellerDoesNotOwnToken(uint256,uint256)", 1, INITIAL_NFT_SUPPLY + 1));

        vm.prank(address(alice));

        market.createSale(1, INITIAL_NFT_SUPPLY + 1, 500, address(token));
    }

    // it ensures that request from the buyer lines up with the listing
    function testBuyerRequestMatchesListing() public {
        // alice creates a sale
        vm.prank(address(alice));
        uint256 listingId = market.createSale(1, 5, 10, address(token));

        vm.startPrank(address(bob));

        vm.expectRevert(abi.encodeWithSignature("TokenIdMismatch(uint256)", 1));
        market.buy(listingId, 424242424242, 2, 10, address(token), address(bob));

        vm.expectRevert(abi.encodeWithSignature("PriceMismatch(uint256)", 10));
        market.buy(listingId, 1, 2, 424242424242, address(token), address(bob));

        vm.expectRevert(abi.encodeWithSignature("CurrencyMismatch(address)", address(token)));
        market.buy(listingId, 1, 2, 10, address(bob), address(bob));
    }

    // it creates a new listing with price 0
    function testCreateFreeListing() public {
        // alice creates a sale
        vm.prank(address(alice));
        uint256 listingId = market.createSale(1, 5, 0, address(token));

        (uint256 tokenId,,,, address seller) = market.listings(listingId);

        assertEq(listingId, 0);
        assertEq(seller, address(alice));
        assertEq(tokenId, 1);

        uint256 bobsTokenBalanceBefore = token.balanceOf(address(bob));

        vm.prank(address(bob));
        market.buy(listingId, 1, 2, 0, address(token), address(bob));

        assertEq(showtimeNFT.balanceOf(address(bob), tokenId), 2);

        uint256 bobsTokenBalanceAfter = token.balanceOf(address(bob));
        assertEq(bobsTokenBalanceBefore, bobsTokenBalanceAfter);
    }

    // sellers can *not* buy from themselves
    function testSellersCannotSelfBuy() public {
        // alice creates a sale
        vm.startPrank(address(alice));
        uint256 listingId = market.createSale(1, 5, 500, address(token));

        (uint256 tokenId,,,, address seller) = market.listings(listingId);

        // the listing exists and alice is the seller
        assertEq(seller, address(alice));

        // alice still owns the NFTs
        assertEq(showtimeNFT.balanceOf(address(alice), tokenId), INITIAL_NFT_SUPPLY);

        // alice can not initially complete the sale because she doesn't have the tokens to buy
        vm.expectRevert(abi.encodeWithSignature("CanNotSellToSelf()"));
        market.buy(listingId, 1, 5, 500, address(token), address(alice));
    }

    // it has enough tokens to buy
    function testChecksBuyerCanPay() public {
        // alice creates the sale
        vm.prank(address(alice));
        uint256 listingId = market.createSale(1, 5, 500, address(token));

        // bob burns his tokens
        vm.startPrank(address(bob));
        token.transfer(BURN_ADDRESS, token.balanceOf(address(bob)));

        // bob has no tokens now
        assertEq(token.balanceOf(address(bob)), 0);

        // bob can no longer buy
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        market.buy(listingId, 1, 5, 500, address(token), address(bob));
    }

    // it cannot cancel other seller's sale
    function testCannotCancelSomeonesSale() public {
        vm.prank(address(alice));
        uint256 listingId = market.createSale(1, 5, 500, address(token));

        // bob cannot cancel
        vm.prank(address(bob));

        vm.expectRevert(abi.encodeWithSignature("NotListingSeller(uint256)", listingId));
        market.cancelSale(listingId);
    }

    // it cannot cancel non existent sale
    function testCannotCancelNonExistentSale() public {
        vm.expectRevert(abi.encodeWithSignature("ListingDoesNotExist(uint256)", 42));

        market.cancelSale(42);
    }

    // it allows seller to cancel their sale
    function testSellerCanCancelSale() public {
        // alice creates a sale
        vm.startPrank(address(alice));
        uint256 listingId = market.createSale(1, 5, 500, address(token));

        // alice cancels her sale
        vm.expectEmit(true, true, true, true);
        emit ListingDeleted(listingId, address(alice));
        market.cancelSale(listingId);

        (uint256 tokenId, uint256 quantity, uint256 price, IERC20 currency, address seller) = market.listings(listingId);

        assertEq(seller, address(0));
        assertEq(tokenId, 0);
        assertEq(quantity, 0);
        assertEq(price, 0);
        assertEq(address(currency), address(0));
    }

    // it cannot buy a cancelled sale
    function testCannotBuyCancelledSale() public {
        vm.startPrank(address(alice));
        uint256 listingId = market.createSale(1, 5, 500, address(token)); // alice create
        market.cancelSale(listingId); // alice cancel
        vm.stopPrank();

        vm.prank(address(bob));
        vm.expectRevert(abi.encodeWithSignature("ListingDoesNotExist(uint256)", listingId));
        market.buy(listingId, 1, 5, 500, address(token), address(bob));
    }

    // it completes a valid buy
    function testCanBuy() public {
        // alice puts up 5 NFTs for sale
        vm.prank(address(alice));
        uint256 listingId = market.createSale(1, 5, 500, address(token));

        // bob buys them
        vm.prank(address(bob));
        vm.expectEmit(true, true, true, true);
        emit SaleCompleted(listingId, address(alice), address(bob), address(bob), 5);
        market.buy(listingId, 1, 5, 500, address(token), address(bob));

        (,,,, address seller) = market.listings(listingId);
        assertEq(seller, address(0));
        assertEq(showtimeNFT.balanceOf(address(alice), 1), 5); // 10 - 5
        assertEq(showtimeNFT.balanceOf(address(bob), 1), 5); // 0 + 5
    }

    // it can not buy for address 0
    function testCannotBuyForBurnAddress() public {
        // alice creates a sale
        vm.prank(address(alice));
        uint256 listingId = market.createSale(1, 5, 500, address(token));

        vm.expectRevert(abi.encodeWithSignature("NullAddress()"));
        market.buy(listingId, 1, 5, 500, address(token), address(0));
    }

    // it allows buying for another user
    function testCanBuyForSomeoneElse() public {
        // alice creates a sale
        vm.prank(address(alice));
        uint256 listingId = market.createSale(1, 5, 500, address(token));

        // bob buys the sale for another user
        vm.prank(address(bob));
        vm.expectEmit(true, true, true, true);
        emit SaleCompleted(listingId, address(alice), address(bob), address(this), 5);
        market.buy(listingId, 1, 5, 500, address(token), address(this));

        (,,,, address seller) = market.listings(listingId);
        assertEq(seller, address(0));

        assertEq(showtimeNFT.balanceOf(address(alice), 1), 5); // 10 - 5
        assertEq(showtimeNFT.balanceOf(address(this), 1), 5); // 0 + 5
    }

    // it buys specific quantity of tokenIds
    function testBuySpecificQuantities() public {
        // alice creates a sale
        vm.prank(address(alice));
        uint256 listingId = market.createSale(1, 5, 500, address(token));

        // bob buys the sale: 2 tokens only out of 5
        vm.startPrank(address(bob));
        vm.expectEmit(true, true, true, true);
        emit SaleCompleted(listingId, address(alice), address(bob), address(bob), 2);
        market.buy(listingId, 1, 2, 500, address(token), address(bob));

        // there should still be 3 left available
        vm.expectEmit(true, true, true, true);
        emit SaleCompleted(listingId, address(alice), address(bob), address(bob), 3);
        market.buy(listingId, 1, 3, 500, address(token), address(bob));
    }

    // it throws on attempting to buy 0"
    function testCannotBuy0Tokens() public {
        // alice lists 5 NFTs for sale
        vm.prank(address(alice));
        uint256 listingId = market.createSale(1, 5, 500, address(token));

        // bob tries to buy 0 NFTs
        vm.expectRevert(abi.encodeWithSignature("NullQuantity()"));
        market.buy(listingId, 1, 0, 500, address(token), address(bob));
    }

    // it throws on attempting to buy more than available quantity
    function testCannotBuyMoreThanListed() public {
        // alice lists 5 NFTs for sale
        vm.prank(address(alice));
        uint256 listingId = market.createSale(1, 5, 500, address(token));

        // bob tries to buy 6 NFTs
        vm.prank(address(bob));
        vm.expectRevert(abi.encodeWithSignature("AvailableQuantityInsuficient(uint256)", 5));
        market.buy(listingId, 1, 6, 500, address(token), address(bob));
    }

    // it throws on attempting to buy listed quantity that is no longer available
    function testCannotBuyMoreThanAvailable() public {
        // alice creates a sale
        vm.startPrank(address(alice));
        uint256 listingId = market.createSale(1, INITIAL_NFT_SUPPLY, 500, address(token));

        // then she burns the NFTs except 1
        showtimeNFT.burn(address(alice), 1, INITIAL_NFT_SUPPLY - 1);
        vm.stopPrank();

        // bob tries to buy 2
        vm.prank(address(bob));
        vm.expectRevert(abi.encodeWithSignature("AvailableQuantityInsuficient(uint256)", 1));

        market.buy(listingId, 1, 2, 500, address(token), address(bob));

        uint256 actuallyAvailable = market.availableForSale(listingId);
        assertEq(actuallyAvailable, 1);

        // the listing is unchanged
        (, uint256 quantity,,,) = market.listings(listingId);
        assertEq(quantity, INITIAL_NFT_SUPPLY);
    }

    // it completes a partial sale when required <= available < listed
    function testCanCompletePartialSale() public {
        // alice lists 5 NFTs for sale
        vm.startPrank(address(alice));
        uint256 listingId = market.createSale(1, 5, 500, address(token));

        // then she burns 8 NFTs
        showtimeNFT.burn(address(alice), 1, 8);

        // there are still 2 available for sale
        assertEq(market.availableForSale(listingId), 2);

        vm.stopPrank();

        // bob can buy 1
        vm.startPrank(address(bob));
        market.buy(listingId, 1, 1, 500, address(token), address(bob));

        // there is still 1 available for sale
        assertEq(market.availableForSale(listingId), 1);

        // the listing has been updated to reflect the available quantity
        (, uint256 quantity,,,) = market.listings(listingId);
        assertEq(quantity, 1);

        // bob buys the last one
        market.buy(listingId, 1, 1, 500, address(token), address(bob));

        // the listing no longer exists
        (,,,, address seller) = market.listings(listingId);
        assertEq(seller, address(0));
    }

    // it completes a sale which has 10% royalties associated with it
    function testCanCompleteSaleWithRoyalties() public {
        // admin puts his tokenId on sale which has 10% royalty to alice
        market.createSale(tokenId10PctRoyaltyToAlice, 5, 500, address(token));
        assertEq(token.balanceOf(address(alice)), 0);

        vm.prank(address(bob));
        vm.expectEmit(true, true, true, true);
        emit RoyaltyPaid(address(alice), token, 250);
        market.buy(0, tokenId10PctRoyaltyToAlice, 5, 500, address(token), address(bob));

        assertEq(token.balanceOf(address(alice)), 250); // received her 10%
        assertEq(token.balanceOf(address(this)), 2250); // price - royalty
    }

    // it completes a sale which has 10% royalties to the zero address associated with it
    function testCanCompleteSaleWithZeroAddressRoyalties() public {
        // admin puts his tokenId on sale which has 10% royalty to the zero address
        market.createSale(tokenId10PctRoyaltyToZeroAddress, 5, 500, address(token));
        assertEq(token.balanceOf(address(alice)), 0);

        // we ignore the royalty, everything goes to the seller
        vm.prank(address(bob));
        market.buy(0, tokenId10PctRoyaltyToZeroAddress, 5, 500, address(token), address(bob));
        assertEq(token.balanceOf(address(this)), 2500); // price
    }

    // it completes a sale which has 100% royalties associated with it, but royalties are capped at 50%
    function testCanCompleteSaleWithCappedRoyalties() public {
        // admin puts 5 of their tokenId on sale which has 100% royalty to alice
        market.createSale(tokenId100PctRoyaltyToAlice, 5, 500, address(token));
        assertEq(token.balanceOf(address(alice)), 0);

        // bob buys 2 of them
        vm.prank(address(bob));
        vm.expectEmit(true, true, true, true);
        emit RoyaltyPaid(address(alice), token, 500);
        market.buy(0, tokenId100PctRoyaltyToAlice, 2, 500, address(token), address(bob));

        assertEq(token.balanceOf(address(alice)), 500); // capped at 50%!
        assertEq(token.balanceOf(address(this)), 500); // price - royalty
    }

    // it permits only owner to update max royalties
    function testOnlyOwnerCanUpdateRoyaltyCap() public {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(address(bob));
        market.setMaxRoyalties(100);
    }

    // it does not permit to set maxRoyalties above 100%
    function testCannotCapRoyaltiesOver100Percent() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidMaxRoyalties()"));

        market.setMaxRoyalties(200_00);
    }

    // it completes a sale which has 100% royalties associated with it when we lift the royalties cap
    function testCanCompleteAFullRoyaltySaleIfNoCap() public {
        // admin puts 5 of their tokenId on sale which has 100% royalty to alice
        market.createSale(tokenId100PctRoyaltyToAlice, 5, 500, address(token));

        // then we set the max royalties to 100%
        vm.expectEmit(true, true, true, true);
        emit MaxRoyaltiesUpdated(address(this), 100_00);
        market.setMaxRoyalties(100_00);

        uint256 aliceBalanceBefore = token.balanceOf(address(alice));
        uint256 adminBalanceBefore = token.balanceOf(address(this));

        // bob buys 2 of them
        vm.prank(address(bob));
        vm.expectEmit(true, true, true, true);
        emit RoyaltyPaid(address(alice), token, 1000);
        market.buy(0, tokenId100PctRoyaltyToAlice, 2, 500, address(token), address(bob));

        assertEq(token.balanceOf(address(alice)), aliceBalanceBefore + 1000); // alice does get 100% of the sale
        assertEq(token.balanceOf(address(this)), adminBalanceBefore); // and admin gets nothing
    }

    // it no royalties are paid when we set the royalties cap at 0%
    function testCanDisableRoyaltiesBySettingCapTo0() public {
        // admin puts 5 of their tokenId on sale which has 100% royalty to alice
        market.createSale(tokenId100PctRoyaltyToAlice, 5, 500, address(token));

        // then we set the max royalties to 0%
        market.setMaxRoyalties(0);

        uint256 aliceBalanceBefore = token.balanceOf(address(alice));
        uint256 adminBalanceBefore = token.balanceOf(address(this));

        // bob buys 2 of them
        vm.prank(address(bob));
        market.buy(0, tokenId100PctRoyaltyToAlice, 2, 500, address(token), address(bob));

        assertEq(token.balanceOf(address(alice)), aliceBalanceBefore); // alice gets no royalties
        assertEq(token.balanceOf(address(this)), adminBalanceBefore + 1000); // the seller gets 100% of the proceeds
    }

    // it permits only owner to turn off royalty on the contract
    function testOnlyOwnerCanDisableRoyalties() public {
        vm.prank(address(alice));
        vm.expectRevert("Ownable: caller is not the owner");
        market.setRoyaltiesEnabled(false);
        assertTrue(market.royaltiesEnabled());

        vm.expectEmit(true, true, true, true);
        emit RoyaltiesEnabledChanged(address(this), false);
        market.setRoyaltiesEnabled(false);

        assertTrue(!market.royaltiesEnabled());
    }

    // it pays no royalty when royalty is turned off
    function testNoRoyaltiesArePaidWhenDisabled() public {
        market.setRoyaltiesEnabled(false);
        market.createSale(2, 5, 500, address(token));
        assertEq(token.balanceOf(address(alice)), 0);

        vm.prank(address(bob));
        market.buy(0, 2, 5, 500, address(token), address(bob));

        assertEq(token.balanceOf(address(alice)), 0); // received no royalty
        assertEq(token.balanceOf(address(this)), 2500);
    }

    // it permits only owner to pause and unpause the contract
    function testOnlyOwnerCanPauseAndUnpause() public {
        assertTrue(!market.paused());

        vm.prank(address(alice));
        vm.expectRevert("Ownable: caller is not the owner");
        market.pause();
        assertTrue(!market.paused());

        market.pause();
        assertTrue(market.paused());

        vm.prank(address(alice));
        vm.expectRevert("Ownable: caller is not the owner");
        market.unpause();
        assertTrue(market.paused());

        market.unpause();
        assertTrue(!market.paused());
    }

    // it can not create a listing when paused
    function testCannotCreateListingWhenPaused() public {
        market.pause();

        vm.expectRevert("Pausable: paused");
        vm.prank(address(alice));
        market.createSale(1, 5, 500, address(token));
    }

    // it can not buy when paused
    function testCannotBuyWhenPaused() public {
        vm.prank(address(alice));
        market.createSale(1, 5, 500, address(token));

        market.pause();

        vm.prank(address(bob));
        vm.expectRevert("Pausable: paused");
        market.buy(0, 1, 5, 500, address(token), address(bob));

        market.unpause();

        // succeeds after unpausing
        vm.prank(address(bob));
        market.buy(0, 1, 5, 500, address(token), address(bob));
    }

    // it can still cancel a listing when paused
    function testCanCancelWhenPaused() public {
        vm.prank(address(alice));
        market.createSale(1, 5, 500, address(token));

        market.pause();

        vm.prank(address(alice));
        market.cancelSale(0);
    }

    // it permits only owner to add accepted currencies
    function testOnlyOwnerCanAddCurrencies() public {
        assertTrue(!market.acceptedCurrencies(address(showtimeNFT)));

        vm.prank(address(alice));
        vm.expectRevert("Ownable: caller is not the owner");
        market.setAcceptedCurrency(address(showtimeNFT), true);

        vm.expectEmit(true, true, true, true);
        emit AcceptedCurrencyChanged(address(this), address(showtimeNFT), true);
        market.setAcceptedCurrency(address(showtimeNFT), true);

        assertTrue(market.acceptedCurrencies(address(showtimeNFT)));
    }

    // it permits only owner to remove accepted currency
    function testOnlyOwnerCanRemoveCurrencies() public {
        market.setAcceptedCurrency(address(showtimeNFT), true);

        vm.prank(address(alice));
        vm.expectRevert("Ownable: caller is not the owner");
        market.setAcceptedCurrency(address(showtimeNFT), false);

        vm.expectEmit(true, true, true, true);
        emit AcceptedCurrencyChanged(address(this), address(showtimeNFT), false);
        market.setAcceptedCurrency(address(showtimeNFT), false);

        assertTrue(!market.acceptedCurrencies(address(showtimeNFT)));
    }
}
