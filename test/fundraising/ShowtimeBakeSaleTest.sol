// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";

import {ShowtimeMT} from "src/ShowtimeMT.sol";
import {ShowtimeV1Market} from "src/ShowtimeV1Market.sol";
import {ShowtimeBakeSale} from "src/fundraising/ShowtimeBakeSale.sol";

import {TestToken} from "test/TestToken.sol";

contract User is ERC1155Holder {}

contract ShowtimeBakeSaleTest is Test, ERC1155Holder {
    uint256 internal constant INITIAL_NFT_SUPPLY = 1000;
    address internal constant BURN_ADDRESS = address(0xdEaD);
    address internal constant FORWARDER_ADDRESS = BURN_ADDRESS;

    User internal bob = new User();
    User internal alice = new User();
    User internal charity = new User();
    TestToken internal token;
    ShowtimeMT internal showtimeNFT;
    ShowtimeV1Market internal market;

    address[] internal justCharityPayees = [address(charity)];
    uint256[] internal just100Shares = [100];

    ShowtimeBakeSale internal charitySeller;

    uint256 internal tokenId0PctRoyalty;
    uint256 internal tokenId10PctRoyaltyToAlice;
    uint256 internal tokenId100PctRoyaltyToAlice;
    uint256 internal tokenId10PctRoyaltyToZeroAddress;

    event ListingCreated(uint256 indexed listingId, address indexed seller, uint256 indexed tokenId);
    event ListingDeleted(uint256 indexed listingId, address indexed seller);
    event SaleCompleted(
        uint256 indexed listingId, address indexed seller, address indexed buyer, address receiver, uint256 quantity
    );
    event RoyaltyPaid(address indexed receiver, IERC20 currency, uint256 amount);
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    function setUp() public {
        // mint NFTs
        showtimeNFT = new ShowtimeMT();
        tokenId0PctRoyalty = showtimeNFT.issueToken(address(alice), INITIAL_NFT_SUPPLY, "some-hash", "0", address(0), 0); // 0% royalties
        tokenId10PctRoyaltyToAlice =
            showtimeNFT.issueToken(address(alice), INITIAL_NFT_SUPPLY, "some-hash", "0", address(alice), 10_00); // 10% royalties
        tokenId100PctRoyaltyToAlice =
            showtimeNFT.issueToken(address(alice), INITIAL_NFT_SUPPLY, "some-hash", "0", address(alice), 100_00); // 100% royalties

        // mint erc20s to bob
        token = new TestToken();
        vm.prank(address(bob));
        token.mint(0xffffffff);

        address[] memory tokens = new address[](1);
        tokens[0] = address(token);

        // approvals
        market = new ShowtimeV1Market(address(showtimeNFT), FORWARDER_ADDRESS, tokens);
        vm.prank(address(bob));
        token.approve(address(market), type(uint256).max);

        // deploy the normal splitter with 100% to charity
        charitySeller = new ShowtimeBakeSale(address(showtimeNFT), address(market), justCharityPayees, just100Shares);
    }

    function testDeploySalesContractWithNoPayees() public {
        vm.expectRevert("PaymentSplitter: no payees");

        address[] memory payees = new address[](0);
        uint256[] memory shares = new uint256[](0);

        new ShowtimeBakeSale(address(showtimeNFT), address(market), payees, shares);
    }

    function testDeploySalesContractWithBadShares() public {
        vm.expectRevert("PaymentSplitter: shares are 0");

        address[] memory payees = new address[](1);
        payees[0] = address(bob);

        uint256[] memory shares = new uint256[](1);
        shares[0] = 0;

        new ShowtimeBakeSale(address(showtimeNFT), address(market), payees, shares);
    }

    function testDeploySalesContractWithPayeesSharesMismatch() public {
        vm.expectRevert("PaymentSplitter: payees and shares length mismatch");

        address[] memory payees = new address[](2);
        payees[0] = address(alice);
        payees[1] = address(bob);

        uint256[] memory shares = new uint256[](1);
        shares[0] = 100;

        new ShowtimeBakeSale(address(showtimeNFT), address(market), payees, shares);
    }

    function testDeploySalesContractWithDuplicatePayees() public {
        vm.expectRevert("PaymentSplitter: account already has shares");

        address[] memory payees = new address[](2);
        payees[0] = address(bob);
        payees[1] = address(bob);

        uint256[] memory shares = new uint256[](2);
        shares[0] = 50;
        shares[1] = 50;

        new ShowtimeBakeSale(address(showtimeNFT), address(market), payees, shares);
    }

    function testOnlyOwnerCanCreateSales() public {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(address(alice));
        charitySeller.createSale(2, 2, 2, address(token));
    }

    function testOnlyOwnerCanCancelSales() public {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(address(alice));
        charitySeller.cancelSale(0);
    }

    function testOnlyOwnerCanWithdraw() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(alice));
        charitySeller.withdraw(42, address(alice));
    }

    function testHappyPathEndToEnd(uint16 price, uint8 quantity) public {
        uint256 tokenId = tokenId10PctRoyaltyToAlice;

        // when alice transfers her NFTs to the charitySeller
        vm.prank(address(alice));
        showtimeNFT.safeTransferFrom(address(alice), address(charitySeller), tokenId, INITIAL_NFT_SUPPLY, "");

        // then we see the balance of the charitySeller reflected
        assertEq(INITIAL_NFT_SUPPLY, showtimeNFT.balanceOf(address(charitySeller), tokenId));

        // when the charitySeller puts the NFT up for sale
        uint256 listingId = charitySeller.createSale(tokenId, INITIAL_NFT_SUPPLY, price, address(token));

        // then we see the expected supply available for purchase
        assertEq(market.availableForSale(listingId), INITIAL_NFT_SUPPLY);

        if (quantity == 0) {
            // we can't purchase 0, it will throw `NullQuantity()`
            return;
        }

        // when bob purchases an NFT
        vm.expectEmit(true, true, true, true);
        emit SaleCompleted(listingId, address(charitySeller), address(bob), address(bob), quantity);

        vm.prank(address(bob));
        market.buy(listingId, tokenId, quantity, price, address(token), address(bob));

        // then we see the balances reflected
        uint256 salePrice = uint256(quantity) * uint256(price);
        uint256 royalties = salePrice / 10;
        uint256 saleProceeds = salePrice - royalties;
        uint256 remainingSupply = INITIAL_NFT_SUPPLY - quantity;
        assertEq(quantity, showtimeNFT.balanceOf(address(bob), tokenId));
        assertEq(remainingSupply, showtimeNFT.balanceOf(address(charitySeller), tokenId));
        assertEq(saleProceeds, token.balanceOf(address(charitySeller)));
        assertEq(royalties, token.balanceOf(address(alice)));

        if (price == 0) {
            // nothing to release, it will throw `account is not due payment`
            return;
        }

        // when someone calls release (could be anyone, so let's randomly pick bob)
        vm.prank(address(bob));
        charitySeller.release(token, address(charity));

        // then we see the balance of the sales contract going to the charity
        assertEq(0, token.balanceOf(address(charitySeller)));
        assertEq(saleProceeds, token.balanceOf(address(charity)));

        // when the deployer cancels the sale, then the listing really is deleted
        vm.expectEmit(true, true, true, true);
        emit ListingDeleted(listingId, address(charitySeller));
        charitySeller.cancelSale(listingId);

        // when the deployer burns the remaining supply
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(charitySeller), address(charitySeller), address(alice), tokenId, remainingSupply);
        charitySeller.withdraw(tokenId, address(alice));

        // then the transfer really happened
        assertEq(0, showtimeNFT.balanceOf(address(charitySeller), tokenId));
        assertEq(remainingSupply, showtimeNFT.balanceOf(address(alice), tokenId));
    }
}
