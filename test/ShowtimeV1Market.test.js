const ShowtimeMT = artifacts.require("ShowtimeMT");
const Token = artifacts.require("Token");
const ShowtimeV1Market = artifacts.require("ShowtimeV1Market");
const truffleAsserts = require("truffle-assertions");
const BN = require("bn.js");

// address(0)
const ZERO_ADDRESS = "0x".padEnd(42, "0");

const SaleCompletedEvent = "SaleCompleted";
const ListingCreatedEvent = "ListingCreated";
const ListingDeletedEvent = "ListingDeleted";
const RoyaltyPaidEvent = "RoyaltyPaid";

const AcceptedCurrencyChangedEvent = "AcceptedCurrencyChanged";
const RoyaltiesEnabledChangedEvent = "RoyaltiesEnabledChanged";
const MaxRoyaltiesUpdatedEvent = "MaxRoyaltiesUpdated";

// we expect an array of logs like this coming out of a transaction:
// {
//     logIndex: 1,
//     transactionIndex: 0,
//     transactionHash: '0xecd242b4de0d1b85e67aa1a91f54d4a826f1ff322701cbb814fc80d43be5f87f',
//     blockHash: '0x9f48f3711565ba1d32a2199e6fa0a447ba2a783193f1eb18894daffbd36db738',
//     blockNumber: 425,
//     address: '0x1dBaFfBF818ba9c09Fd0C7C19Ac510908A649DDf',
//     type: 'mined',
//     id: 'log_138b028a',
//     event: 'SaleCompleted',
//     args: [Result]
// }
//
// this function findFirst(logs, 'SaleCompleted') returns the args for that event
function findFirst(logs, eventName) {
    const eventNames = [];

    for (let i = 0; i < logs.length; i++) {
        const log = logs[i];
        eventNames.push(log.event);
        if (log.event === eventName) {
            return log.args;
        }
    }

    throw Error(`no '${eventName}' event found in ${eventNames}`);
}

async function getLog(tx, eventName) {
    const logs = (await tx).logs;
    return findFirst(logs, eventName);
}

contract("ERC1155 Sale Contract Tests", (accounts) => {
    let showtimeNFT,
        token,
        market,
        admin,
        alice,
        bob,
        tokenId0PctRoyalty,
        tokenId10PctRoyaltyToAlice,
        tokenId10PctRoyaltyToZeroAddress,
        tokenId100PctRoyaltyToAlice;

    const INITIAL_NFT_SUPPLY = 10;

    beforeEach(async () => {
        admin = accounts[0];
        alice = accounts[1];
        bob = accounts[2];

        // mint NFTs
        showtimeNFT = await ShowtimeMT.new();
        tokenId0PctRoyalty = (
            await showtimeNFT.issueToken(alice, INITIAL_NFT_SUPPLY, "some-hash", "0x0", ZERO_ADDRESS, 0)
        ).logs[0].args.id;
        tokenId10PctRoyaltyToAlice = (
            await showtimeNFT.issueToken(admin, INITIAL_NFT_SUPPLY, "some-hash", "0x0", alice, 10_00)
        ).logs[0].args.id; // 10% royalty
        tokenId10PctRoyaltyToZeroAddress = (
            await showtimeNFT.issueToken(admin, INITIAL_NFT_SUPPLY, "some-hash", "0x0", ZERO_ADDRESS, 10_00)
        ).logs[0].args.id; // 10% royalty
        tokenId100PctRoyaltyToAlice = (
            await showtimeNFT.issueToken(admin, INITIAL_NFT_SUPPLY, "some-hash", "0x0", alice, 100_00)
        ).logs[0].args.id; // 100% royalty

        // mint erc20s to bob
        token = await Token.new();
        await token.mint(2500, { from: bob });

        // approvals
        market = await ShowtimeV1Market.new(showtimeNFT.address, /* trustedForwarder */ ZERO_ADDRESS, [
            token.address,
        ]);
        await showtimeNFT.setApprovalForAll(market.address, true, { from: alice });
        await showtimeNFT.setApprovalForAll(market.address, true);
        await token.approve(market.address, 2500, { from: bob });
    });

    it("doesn't allow to deploy with incorrect constructor arguments", async () => {
        // fixes `base fee exceeds gas limit` error
        const defaults = ShowtimeV1Market.defaults({
            gas: 4712388,
            gasPrice: 100000000000,
        });

        await truffleAsserts.reverts(
            ShowtimeV1Market.new(alice, ZERO_ADDRESS, [token.address]),
            "must be contract address"
        );

        await truffleAsserts.reverts(
            ShowtimeV1Market.new(showtimeNFT.address, ZERO_ADDRESS, [ZERO_ADDRESS]),
            "_initialCurrencies must contain contract addresses"
        );
    });

    it("deploys with correct constructor arguments", async () => {
        assert.equal(await market.nft(), showtimeNFT.address);
        assert.equal(await market.acceptedCurrencies(token.address), true);
        assert.equal(await market.royaltiesEnabled(), true);
    });

    it("creates a new listing", async () => {
        // alice creates a sale
        const listing = await getLog(
            market.createSale(1, 5, 500, token.address, { from: alice }),
            ListingCreatedEvent
        );
        assert.equal(listing.listingId, 0);
        assert.equal(listing.seller, alice);
        assert.equal(listing.tokenId, 1);

        // alice still owns the NFTs
        assert.equal(await showtimeNFT.balanceOf(alice, 1), INITIAL_NFT_SUPPLY);

        const _sale = await market.listings(listing.listingId);
        assert.equal(_sale.tokenId, 1);
        assert.equal(_sale.quantity, 5);
        assert.equal(_sale.price, 500);
        assert.equal(_sale.seller, alice);
    });

    it("ensures that the seller owns the listed tokens", async () => {
        // alice does not own token 2
        assert.equal(await showtimeNFT.balanceOf(alice, 2), 0);

        await truffleAsserts.reverts(
            market.createSale(2, 5, 500, token.address, { from: alice }),
            "seller does not own listed quantity of tokens"
        );
    });

    it("ensures that the seller owns enough of the listed tokens", async () => {
        // alice owns INITIAL_NFT_SUPPLY of token 1
        assert.equal(await showtimeNFT.balanceOf(alice, 1), INITIAL_NFT_SUPPLY);

        await truffleAsserts.reverts(
            market.createSale(1, INITIAL_NFT_SUPPLY + 1, 500, token.address, { from: alice }),
            "seller does not own listed quantity of tokens"
        );
    });

    it("ensures that request from the buyer lines up with the listing", async () => {
        // alice creates a sale
        const listing = await getLog(
            market.createSale(1, 5, 10, token.address, { from: alice }),
            ListingCreatedEvent
        );

        await truffleAsserts.reverts(
            market.buy(
                listing.listingId,
                /* tokenId */ 424242424242,
                /* quantity */ 2,
                /* price */ 10,
                token.address,
                bob,
                { from: bob }
            ),
            "_tokenId does not match listing"
        );

        await truffleAsserts.reverts(
            market.buy(
                listing.listingId,
                /* tokenId */ 1,
                /* quantity */ 2,
                /* price */ 424242424242,
                token.address,
                bob,
                { from: bob }
            ),
            "_price does not match listing"
        );

        await truffleAsserts.reverts(
            market.buy(
                listing.listingId,
                /* tokenId */ 1,
                /* quantity */ 2,
                /* price */ 10,
                /* currency */ bob,
                bob,
                { from: bob }
            ),
            "_currency does not match listing"
        );
    });

    it("creates a new listing with price 0", async () => {
        // alice creates a sale
        const listing = await getLog(
            market.createSale(1, 5, 0, token.address, { from: alice }),
            ListingCreatedEvent
        );
        assert.equal(listing.listingId, 0);
        assert.equal(listing.seller, alice);
        assert.equal(listing.tokenId, 1);

        const bobsTokenBalanceBefore = await token.balanceOf(bob);
        await market.buy(
            listing.listingId,
            /* tokenId */ 1,
            /* quantity */ 2,
            /* price */ 0,
            token.address,
            bob,
            { from: bob }
        );

        assert.equal(await showtimeNFT.balanceOf(bob, listing.tokenId), 2);

        const bobsTokenBalanceAfter = await token.balanceOf(bob);
        assert(bobsTokenBalanceBefore.eq(bobsTokenBalanceAfter));
    });

    it("sellers can *not* buy from themselves", async () => {
        // alice creates a sale
        const listing = await getLog(
            market.createSale(1, 5, 500, token.address, { from: alice }),
            ListingCreatedEvent
        );

        // the listing exists and alice is the seller
        assert.equal((await market.listings(listing.listingId)).seller, alice);

        // alice still owns the NFTs
        assert.equal(await showtimeNFT.balanceOf(alice, listing.tokenId), INITIAL_NFT_SUPPLY);

        // alice can not initially complete the sale because she doesn't have the tokens to buy
        await truffleAsserts.reverts(
            market.buy(
                listing.listingId,
                /* tokenId */ 1,
                /* quantity */ 5,
                /* price */ 500,
                token.address,
                alice,
                { from: alice }
            ),
            "seller is not a valid receiver address"
        );
    });

    it("has enough tokens to buy", async () => {
        // alice creates the sale
        const listing = await getLog(
            market.createSale(1, 5, 500, token.address, { from: alice }),
            ListingCreatedEvent
        );

        // bob burns his tokens
        await token.transfer("0x000000000000000000000000000000000000dEaD", await token.balanceOf(bob), {
            from: bob,
        });

        // bob has no tokens now
        assert.equal(await token.balanceOf(bob), 0);

        // bob can no longer buy
        await truffleAsserts.reverts(
            market.buy(
                listing.listingId,
                /* tokenId */ 1,
                /* quantity */ 5,
                /* price */ 500,
                token.address,
                bob,
                { from: bob }
            )
        );
    });

    it("cannot cancel other seller's sale", async () => {
        const tx = await market.createSale(1, 5, 500, token.address, { from: alice });
        const { listingId } = tx.logs[0].args;

        // bob cannot cancel
        await truffleAsserts.reverts(market.cancelSale(listingId), "caller not seller");
    });

    it("cannot cancel not existent sale", async () => {
        await truffleAsserts.reverts(market.cancelSale(42), "listing doesn't exist");
    });

    it("allows seller to cancel their sale", async () => {
        // alice creates a sale
        const created = await getLog(
            market.createSale(1, 5, 500, token.address, { from: alice }),
            ListingCreatedEvent
        );

        // alice cancels her sale
        const deleted = await getLog(
            market.cancelSale(created.listingId, { from: alice }),
            ListingDeletedEvent
        );
        assert.equal(deleted.listingId, 0);
        assert.equal(deleted.seller, alice);

        const listing = await market.listings(deleted.listingId);
        assert.equal(listing.seller, ZERO_ADDRESS);
        assert.equal(listing.tokenId, 0);
        assert.equal(listing.quantity, 0);
        assert.equal(listing.price, 0);
        assert.equal(listing.currency, ZERO_ADDRESS);
    });

    it("cannot buy a cancelled sale", async () => {
        const tx = await market.createSale(1, 5, 500, token.address, { from: alice }); // alice create
        const { listingId } = tx.logs[0].args;
        await market.cancelSale(listingId, { from: alice }); // alice cancel
        await truffleAsserts.reverts(
            market.buy(listingId, /* tokenId */ 1, /* quantity */ 5, /* price */ 500, token.address, bob, {
                from: bob,
            }),
            "listing doesn't exist"
        );
    });

    it("completes a valid buy", async () => {
        // alice puts up 5 NFTs for sale
        const created = await getLog(
            market.createSale(1, 5, 500, token.address, { from: alice }),
            ListingCreatedEvent
        );

        // bob buys them
        const saleCompleted = await getLog(
            market.buy(
                created.listingId,
                /* tokenId */ 1,
                /* quantity */ 5,
                /* price */ 500,
                token.address,
                bob,
                { from: bob }
            ),
            SaleCompletedEvent
        );

        assert.equal(saleCompleted.listingId, 0);
        assert.equal(saleCompleted.seller, alice);
        assert.equal(saleCompleted.buyer, bob);
        assert.equal(saleCompleted.quantity, 5);

        const listing = await market.listings(saleCompleted.listingId);
        assert.equal(listing.seller, ZERO_ADDRESS);
        assert.equal(await showtimeNFT.balanceOf(alice, 1), 5); // 10 - 5
        assert.equal(await showtimeNFT.balanceOf(bob, 1), 5); // 0 + 5
    });

    it("can not buy for address 0", async () => {
        // alice creates a sale
        const created = await getLog(
            market.createSale(1, 5, 500, token.address, { from: alice }),
            ListingCreatedEvent
        );

        // bob attempts to buy
        await truffleAsserts.reverts(
            market.buy(
                created.listingId,
                /* tokenId */ 1,
                /* quantity */ 5,
                /* price */ 500,
                token.address,
                ZERO_ADDRESS,
                { from: bob }
            ),
            "_receiver cannot be address 0"
        );
    });

    it("allows buying for another user", async () => {
        // alice creates a sale
        const created = await getLog(
            market.createSale(1, 5, 500, token.address, { from: alice }),
            ListingCreatedEvent
        );

        // bob buys the sale for another user
        const saleCompleted = await getLog(
            market.buy(
                created.listingId,
                /* tokenId */ 1,
                /* quantity */ 5,
                /* price */ 500,
                token.address,
                /* receiver */ admin,
                { from: bob }
            ),
            SaleCompletedEvent
        );
        assert.equal(saleCompleted.listingId, 0);
        assert.equal(saleCompleted.seller, alice);
        assert.equal(saleCompleted.buyer, bob);
        assert.equal(saleCompleted.receiver, admin);
        assert.equal(saleCompleted.quantity, 5);

        const listing = await market.listings(saleCompleted.listingId);
        assert.equal(listing.seller, ZERO_ADDRESS);

        assert.equal(await showtimeNFT.balanceOf(alice, 1), 5); // 10 - 5
        assert.equal(await showtimeNFT.balanceOf(admin, 1), 5); // 0 + 5
    });

    it("buys specific quantity of tokenIds", async () => {
        // alice creates a sale
        const created = await getLog(
            market.createSale(1, 5, 500, token.address, { from: alice }),
            ListingCreatedEvent
        );

        // bob buys the sale: 2 tokens only out of 5
        const saleCompleted2 = await getLog(
            market.buy(
                created.listingId,
                /* tokenId */ 1,
                /* quantity */ 2,
                /* price */ 500,
                token.address,
                bob,
                { from: bob }
            ),
            SaleCompletedEvent
        );
        assert.equal(saleCompleted2.quantity, 2);

        // there should still be 3 left available
        const saleCompleted3 = await getLog(
            market.buy(
                created.listingId,
                /* tokenId */ 1,
                /* quantity */ 3,
                /* price */ 500,
                token.address,
                bob,
                { from: bob }
            ),
            SaleCompletedEvent
        );
        assert.equal(saleCompleted3.quantity, 3);
    });

    it("throws on attempting to buy more than available quantity", async () => {
        // alice lists 5 NFTs for sale
        const created = await getLog(
            market.createSale(1, 5, 500, token.address, { from: alice }),
            ListingCreatedEvent
        );

        // bob tries to buy 6 NFTs
        await truffleAsserts.reverts(
            market.buy(
                created.listingId,
                /* tokenId */ 1,
                /* quantity */ 6,
                /* price */ 500,
                token.address,
                bob,
                { from: bob }
            ),
            "required more than available quantity"
        );
    });

    it("throws on attempting to buy listed quantity that is no longer available", async () => {
        // alice creates a sale
        const created = await getLog(
            market.createSale(1, INITIAL_NFT_SUPPLY, 500, token.address, { from: alice }),
            ListingCreatedEvent
        );
        assert.equal((await market.listings(created.listingId)).seller, alice);

        // then she burns the NFTs except 1
        await showtimeNFT.burn(alice, 1, INITIAL_NFT_SUPPLY - 1, { from: alice });

        // bob tries to buy 2
        await truffleAsserts.reverts(
            market.buy(
                created.listingId,
                /* tokenId */ 1,
                /* quantity */ 2,
                /* price */ 500,
                token.address,
                bob,
                { from: bob }
            ),
            "required more than available quantity"
        );

        const actuallyAvailable = await market.availableForSale(created.listingId);
        assert.equal(actuallyAvailable, 1);

        // the listing is unchanged
        const listing = await market.listings(created.listingId);
        assert.equal(listing.quantity, INITIAL_NFT_SUPPLY);
    });

    it("completes a partial sale when required <= available < listed", async () => {
        // alice lists 5 NFTs for sale
        const created = await getLog(
            market.createSale(1, 5, 500, token.address, { from: alice }),
            ListingCreatedEvent
        );
        assert.equal((await market.listings(created.listingId)).seller, alice);

        // then she burns 8 NFTs
        await showtimeNFT.burn(alice, 1, 8, { from: alice });

        // there are still 2 available for sale
        assert.equal(await market.availableForSale(created.listingId), 2);

        // bob can buy 1
        const saleCompleted1 = await getLog(
            market.buy(
                created.listingId,
                /* tokenId */ 1,
                /* quantity */ 1,
                /* price */ 500,
                token.address,
                bob,
                { from: bob }
            ),
            SaleCompletedEvent
        );

        // there is still 1 available for sale
        assert.equal(await market.availableForSale(created.listingId), 1);

        // the listing has been updated to reflect the available quantity
        assert.equal((await market.listings(created.listingId)).quantity, 1);

        // bob buys the last one
        const saleCompleted2 = await getLog(
            market.buy(
                created.listingId,
                /* tokenId */ 1,
                /* quantity */ 1,
                /* price */ 500,
                token.address,
                bob,
                { from: bob }
            ),
            SaleCompletedEvent
        );

        // the listing no longer exists
        assert.equal((await market.listings(created.listingId)).seller, ZERO_ADDRESS);
    });

    it("completes a sale which has 10% royalties associated with it", async () => {
        // admin puts his tokenId on sale which has 10% royalty to alice
        await market.createSale(tokenId10PctRoyaltyToAlice, 5, 500, token.address);
        assert.equal(await token.balanceOf(alice), 0);
        const RoyaltyPaid = await getLog(
            market.buy(
                /* listingId */ 0,
                /* tokenId */ tokenId10PctRoyaltyToAlice,
                /* quantity */ 5,
                /* price */ 500,
                token.address,
                bob,
                { from: bob }
            ),
            RoyaltyPaidEvent
        );

        assert.equal(RoyaltyPaid.receiver, alice);
        assert.equal(RoyaltyPaid.amount, 250);
        assert.equal(await token.balanceOf(alice), 250); // received her 10%
        assert.equal(await token.balanceOf(admin), 2250); // price - royalty
    });

    it("completes a sale which has 10% royalties to the zero address associated with it", async () => {
        // admin puts his tokenId on sale which has 10% royalty to the zero address
        await market.createSale(tokenId10PctRoyaltyToZeroAddress, 5, 500, token.address);
        assert.equal(await token.balanceOf(alice), 0);

        // we ignore the royalty, everything goes to the seller
        truffleAsserts.eventNotEmitted(
            await market.buy(
                /* listingId */ 0,
                /* tokenId */ tokenId10PctRoyaltyToZeroAddress,
                /* quantity */ 5,
                /* price */ 500,
                token.address,
                bob,
                { from: bob }
            ),
            RoyaltyPaidEvent
        );
        assert.equal(await token.balanceOf(admin), 2500); // price
    });

    it("completes a sale which has 100% royalties associated with it, but royalties are capped at 50%", async () => {
        // admin puts 5 of their tokenId on sale which has 100% royalty to alice
        await market.createSale(tokenId100PctRoyaltyToAlice, 5, 500, token.address);
        assert.equal(await token.balanceOf(alice), 0);

        // bob buys 2 of them
        const RoyaltyPaid = await getLog(
            market.buy(
                /* listingId */ 0,
                /* tokenId */ tokenId100PctRoyaltyToAlice,
                /* quantity */ 2,
                /* price */ 500,
                token.address,
                bob,
                { from: bob }
            ),
            RoyaltyPaidEvent
        );

        assert.equal(RoyaltyPaid.receiver, alice);
        assert.equal(RoyaltyPaid.amount, 500);
        assert.equal(await token.balanceOf(alice), 500); // capped at 50%!
        assert.equal(await token.balanceOf(admin), 500); // price - royalty
    });

    it("permits only owner to update max royalties", async () => {
        await truffleAsserts.reverts(
            market.setMaxRoyalties(100, { from: bob }),
            "Ownable: caller is not the owner"
        );
    });

    it("does not permit to set maxRoyalties above 100%", async () => {
        await truffleAsserts.reverts(
            market.setMaxRoyalties(200_00),
            "maxRoyaltiesBasisPoints must be <= 100%"
        );
    });

    it("completes a sale which has 100% royalties associated with it when we lift the royalties cap", async () => {
        // admin puts 5 of their tokenId on sale which has 100% royalty to alice
        await market.createSale(tokenId100PctRoyaltyToAlice, 5, 500, token.address);

        // then we set the max royalties to 100%
        const royaltiesUpdatedEvent = await getLog(market.setMaxRoyalties(100_00), MaxRoyaltiesUpdatedEvent);
        assert.equal(royaltiesUpdatedEvent.account, admin);
        assert.equal(royaltiesUpdatedEvent.maxRoyaltiesBasisPoints, 100_00);

        const aliceBalanceBefore = await token.balanceOf(alice);
        const adminBalanceBefore = await token.balanceOf(admin);

        // bob buys 2 of them
        RoyaltyPaid = await getLog(
            market.buy(
                /* listingId */ 0,
                /* tokenId */ tokenId100PctRoyaltyToAlice,
                /* quantity */ 2,
                /* price */ 500,
                token.address,
                bob,
                { from: bob }
            ),
            RoyaltyPaidEvent
        );
        assert.equal(RoyaltyPaid.receiver, alice);
        assert.equal(RoyaltyPaid.amount, 1000);
        assert((await token.balanceOf(alice)).eq(aliceBalanceBefore.add(new BN(1000)))); // alice does get 100% of the sale
        assert((await token.balanceOf(admin)).eq(adminBalanceBefore)); // and admin gets nothing
    });

    it("no royalties are paid when we set the royalties cap at 0%", async () => {
        // admin puts 5 of their tokenId on sale which has 100% royalty to alice
        await market.createSale(tokenId100PctRoyaltyToAlice, 5, 500, token.address);

        // then we set the max royalties to 0%
        await market.setMaxRoyalties(0 * 100);

        const aliceBalanceBefore = await token.balanceOf(alice);
        const adminBalanceBefore = await token.balanceOf(admin);

        // bob buys 2 of them
        truffleAsserts.eventNotEmitted(
            await market.buy(
                /* listingId */ 0,
                /* tokenId */ tokenId100PctRoyaltyToAlice,
                /* quantity */ 2,
                /* price */ 500,
                token.address,
                bob,
                { from: bob }
            ),
            RoyaltyPaidEvent
        );

        assert((await token.balanceOf(alice)).eq(aliceBalanceBefore)); // alice gets no royalties
        assert((await token.balanceOf(admin)).eq(adminBalanceBefore.add(new BN(1000)))); // the seller gets 100% of the proceeds
    });

    it("permits only owner to turn off royalty on the contract", async () => {
        await truffleAsserts.reverts(market.setRoyaltiesEnabled(false, { from: alice }));
        assert.equal(await market.royaltiesEnabled(), true);

        const royaltiesEnabledEvent = await getLog(
            market.setRoyaltiesEnabled(false),
            RoyaltiesEnabledChangedEvent
        );

        assert.equal(royaltiesEnabledEvent.account, admin);
        assert.equal(royaltiesEnabledEvent.royaltiesEnabled, false);
        assert.equal(await market.royaltiesEnabled(), false);
    });

    it("pays no royalty when royalty is turned off", async () => {
        await market.setRoyaltiesEnabled(false);
        await market.createSale(2, 5, 500, token.address);
        assert.equal(await token.balanceOf(alice), 0);
        await market.buy(0, /* tokenId */ 2, /* quantity */ 5, /* price */ 500, token.address, bob, {
            from: bob,
        });
        assert.equal(await token.balanceOf(alice), 0); // received no royalty
        assert.equal(await token.balanceOf(admin), 2500);
    });

    it("permits only owner to pause and unpause the contract", async () => {
        await truffleAsserts.reverts(market.pause({ from: alice }), "Ownable: caller is not the owner");
        await market.pause();
        await truffleAsserts.reverts(market.unpause({ from: alice }), "Ownable: caller is not the owner");
        await market.unpause();
        assert.equal(await market.paused(), false);
    });

    it("can not create a listing when paused", async () => {
        await market.pause();
        await truffleAsserts.reverts(
            market.createSale(1, 5, 500, token.address, { from: alice }),
            "Pausable: paused"
        );
        await market.unpause();
    });

    it("can not buy when paused", async () => {
        await market.createSale(1, 5, 500, token.address, { from: alice });
        await market.pause();
        await truffleAsserts.reverts(
            market.buy(
                /* listingId */ 0,
                /* tokenId */ 1,
                /* quantity */ 5,
                /* price */ 500,
                token.address,
                bob,
                { from: bob }
            ),
            "Pausable: paused"
        );
        await market.unpause();

        // succeeds after unpausing
        await market.buy(
            /* listingId */ 0,
            /* tokenId */ 1,
            /* quantity */ 5,
            /* price */ 500,
            token.address,
            bob,
            { from: bob }
        );
    });

    it("can still cancel a listing when paused", async () => {
        await market.createSale(1, 5, 500, token.address, { from: alice });
        await market.cancelSale(0, { from: alice });
    });

    it("permits only owner to add accepted currencies", async () => {
        await truffleAsserts.reverts(
            market.setAcceptedCurrency(showtimeNFT.address, true, { from: alice }),
            "Ownable: caller is not the owner"
        );

        const event = await getLog(
            market.setAcceptedCurrency(showtimeNFT.address, true),
            AcceptedCurrencyChangedEvent
        );
        assert.equal(event.account, admin);
        assert.equal(event.currency, showtimeNFT.address);
        assert.equal(event.accepted, true);

        assert.equal(await market.acceptedCurrencies(showtimeNFT.address), true);
    });

    it("permits only owner to remove accepted currency", async () => {
        await market.setAcceptedCurrency(showtimeNFT.address, true);
        await truffleAsserts.reverts(
            market.setAcceptedCurrency(showtimeNFT.address, false, { from: alice }),
            "Ownable: caller is not the owner"
        );

        const event = await getLog(
            market.setAcceptedCurrency(showtimeNFT.address, false),
            AcceptedCurrencyChangedEvent
        );
        assert.equal(event.account, admin);
        assert.equal(event.currency, showtimeNFT.address);
        assert.equal(event.accepted, false);

        assert.equal(await market.acceptedCurrencies(showtimeNFT.address), false);
    });
});
