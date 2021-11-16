const ShowtimeMT = artifacts.require("ShowtimeMT");
const Token = artifacts.require("Token");
const ERC1155Sale = artifacts.require("ERC1155Sale");
const truffleAsserts = require("truffle-assertions");

// address(0)
const ZERO_ADDRESS = "0x".padEnd(42, "0");

contract("ERC1155 Sale Contract Tests", (accounts) => {
    let showtimeNFT,
        token,
        sale,
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
        sale = await ERC1155Sale.new(showtimeNFT.address, [token.address]);
        await showtimeNFT.setApprovalForAll(sale.address, true, { from: alice });
        await showtimeNFT.setApprovalForAll(sale.address, true);
        await token.approve(sale.address, 2500, { from: bob });
    });

    it("doesn't allow to deploy with incorrect constructor arguments", async () => {
        await truffleAsserts.reverts(ERC1155Sale.new(alice, [token.address]), "must be contract address");
        await truffleAsserts.reverts(
            ERC1155Sale.new(showtimeNFT.address, [ZERO_ADDRESS]),
            "_initialCurrencies must contain contract addresses"
        );
    });

    it("deploys with correct constructor arguments", async () => {
        assert.equal(await sale.nft(), showtimeNFT.address);
        assert.equal(await sale.acceptedCurrencies(token.address), true);
        assert.equal(await sale.royaltiesEnabled(), true);
    });

    it("creates a new listing", async () => {
        // alice creates a sale
        // `New` is the event emitted when creating a new sale
        const { args: New } = (await sale.createSale(1, 5, 500, token.address, { from: alice })).logs[0];
        assert.equal(New.saleId, 0);
        assert.equal(New.seller, alice);
        assert.equal(New.tokenId, 1);

        // alice still owns the NFTs
        assert.equal(await showtimeNFT.balanceOf(alice, 1), INITIAL_NFT_SUPPLY);

        const _sale = await sale.listings(New.saleId);
        assert.equal(_sale.tokenId, 1);
        assert.equal(_sale.quantity, 5);
        assert.equal(_sale.price, 500);
        assert.equal(_sale.seller, alice);
    });

    it("creates a new listing with price 0", async () => {
        // alice creates a sale
        const { args: New } = (await sale.createSale(1, 5, 0, token.address, { from: alice })).logs[0];
        assert.equal(New.saleId, 0);
        assert.equal(New.seller, alice);
        assert.equal(New.tokenId, 1);

        const bobsTokenBalanceBefore = await token.balanceOf(bob);
        await sale.buyFor(New.saleId, /* quantity */ 2, bob, { from: bob });

        assert.equal(await showtimeNFT.balanceOf(bob, New.tokenId), 2);

        const bobsTokenBalanceAfter = await token.balanceOf(bob);
        assert(bobsTokenBalanceBefore.eq(bobsTokenBalanceAfter));
    });

    it("sellers can buy from themselves", async () => {
        // alice creates a sale
        const { args: New } = (await sale.createSale(1, 5, 500, token.address, { from: alice })).logs[0];

        // the listing exists and alice is the seller
        assert.equal((await sale.listings(New.saleId)).seller, alice);

        // alice still owns the NFTs
        assert.equal(await showtimeNFT.balanceOf(alice, New.tokenId), INITIAL_NFT_SUPPLY);

        // alice can not initially complete the sale because she doesn't have the tokens to buy
        await truffleAsserts.reverts(
            sale.buyFor(New.saleId, /* quantity */ 5, alice, { from: alice }),
            "ERC20: transfer amount exceeds balance"
        );

        // mint the tokens
        await token.mint(2500, { from: alice });
        await token.approve(sale.address, 2500, { from: alice });
        const alicesTokenBalanceBefore = await token.balanceOf(alice);

        await sale.buyFor(New.saleId, /* quantity */ 5, alice, { from: alice });

        // she still owns the NFTs
        assert.equal(await showtimeNFT.balanceOf(alice, New.tokenId), INITIAL_NFT_SUPPLY);

        // and also the tokens used for the purchase
        assert((await token.balanceOf(alice)).eq(alicesTokenBalanceBefore));

        // the listing does not exist anymore
        assert.equal((await sale.listings(New.saleId)).seller, ZERO_ADDRESS);
    });

    it("has enough tokens to buy", async () => {
        // alice creates the sale
        const { args: New } = (await sale.createSale(1, 5, 500, token.address, { from: alice })).logs[0];

        // bob burns his tokens
        await token.transfer("0x000000000000000000000000000000000000dead", await token.balanceOf(bob), {
            from: bob,
        });

        // bob has no tokens now
        assert.equal(await token.balanceOf(bob), 0);

        // bob can no longer buy
        await truffleAsserts.reverts(sale.buyFor(New.saleId, 5, bob, { from: bob }));
    });

    it("cannot cancel other seller's sale", async () => {
        const tx = await sale.createSale(1, 5, 500, token.address, { from: alice });
        const { saleId } = tx.logs[0].args;
        // bob cannot cancel
        await truffleAsserts.reverts(sale.cancelSale(saleId), "caller not seller");
    });

    it("cannot cancel not existent sale", async () => {
        await truffleAsserts.reverts(sale.cancelSale(42), "listing doesn't exist");
    });

    it("allows seller to cancel their sale", async () => {
        // alice creates a sale
        const { args: New } = (await sale.createSale(1, 5, 500, token.address, { from: alice })).logs[0];
        // alice cancels her sale
        const { args: Cancel } = (await sale.cancelSale(New.saleId, { from: alice })).logs[0];
        assert.equal(Cancel.saleId, 0);
        assert.equal(Cancel.seller, alice);

        const _sale = await sale.listings(Cancel.saleId);
        assert.equal(_sale.seller, ZERO_ADDRESS);
        assert.equal(_sale.tokenId, 0);
        assert.equal(_sale.quantity, 0);
        assert.equal(_sale.price, 0);
        assert.equal(_sale.currency, ZERO_ADDRESS);
    });

    it("cannot buy a cancelled sale", async () => {
        const tx = await sale.createSale(1, 5, 500, token.address, { from: alice }); // alice create
        const { saleId } = tx.logs[0].args;
        await sale.cancelSale(saleId, { from: alice }); // alice cancel
        await truffleAsserts.reverts(sale.buyFor(saleId, 5, admin), "listing doesn't exist");
    });

    it("completes a valid buy", async () => {
        // alice creates a sale
        const { args: New } = (await sale.createSale(1, 5, 500, token.address, { from: alice })).logs[0];

        // bob buys the sale
        const { args: Buy } = (await sale.buyFor(New.saleId, 5, bob, { from: bob })).logs[0];
        assert.equal(Buy.saleId, 0);
        assert.equal(Buy.seller, alice);
        assert.equal(Buy.buyer, bob);
        assert.equal(Buy.quantity, 5);

        const _sale = await sale.listings(Buy.saleId);
        assert.equal(_sale.seller, ZERO_ADDRESS);
        assert.equal(await showtimeNFT.balanceOf(alice, 1), 5); // 10 - 5
        assert.equal(await showtimeNFT.balanceOf(bob, 1), 5); // 0 + 5
    });

    it("can not buy for address 0", async () => {
        // alice creates a sale
        const { args: New } = (await sale.createSale(1, 5, 500, token.address, { from: alice })).logs[0];
        // bob attempts to buy
        await truffleAsserts.reverts(
            sale.buyFor(New.saleId, 5, ZERO_ADDRESS, { from: bob }),
            "invalid _whom address"
        );
    });

    it("buys for another user", async () => {
        // alice creates a sale
        const { args: New } = (await sale.createSale(1, 5, 500, token.address, { from: alice })).logs[0];
        // bob buys the sale
        const { args: Buy } = (await sale.buyFor(New.saleId, 5, admin, { from: bob })).logs[0];
        assert.equal(Buy.saleId, 0);
        assert.equal(Buy.seller, alice);
        assert.equal(Buy.buyer, admin);
        assert.equal(Buy.quantity, 5);

        const _sale = await sale.listings(Buy.saleId);
        assert.equal(_sale.seller, ZERO_ADDRESS);

        assert.equal(await showtimeNFT.balanceOf(alice, 1), 5); // 10 - 5
        assert.equal(await showtimeNFT.balanceOf(admin, 1), 5); // 0 + 5
    });

    it("buys specific quantity of tokenIds", async () => {
        // alice creates a sale
        const { args: New } = (await sale.createSale(1, 5, 500, token.address, { from: alice })).logs[0];
        // bob buys the sale: 2 tokens only out of 5
        const { args: Buy1 } = (await sale.buyFor(New.saleId, 2, bob, { from: bob })).logs[0];
        assert.equal(Buy1.quantity, 2);
        // there should still be 3 left available
        const { args: Buy2 } = (await sale.buyFor(New.saleId, 3, bob, { from: bob })).logs[0];
        assert.equal(Buy2.quantity, 3);
    });

    it("throws on attempting to buy more than available quantity", async () => {
        // alice lists 5 NFTs for sale
        const { args: New } = (await sale.createSale(1, 5, 500, token.address, { from: alice })).logs[0];

        // bob tries to buy 6 NFTs
        await truffleAsserts.reverts(
            sale.buyFor(New.saleId, 6, bob, { from: bob }),
            "required more than available quantity"
        );
    });

    it("throws on attempting to buy listed quantity that is no longer available", async () => {
        // alice creates a sale
        const { args: New } = (await sale.createSale(1, 5, 500, token.address, { from: alice })).logs[0];
        assert.equal((await sale.listings(New.saleId)).seller, alice);

        // then she burns the NFTs
        await showtimeNFT.burn(alice, 1, INITIAL_NFT_SUPPLY, { from: alice });

        // the sale can not be completed
        await truffleAsserts.reverts(
            sale.buyFor(New.saleId, 1, bob),
            "required more than available quantity"
        );
    });

    it("completes a partial sale when required <= available < listed", async () => {
        // alice lists 5 NFTs for sale
        const { args: New } = (await sale.createSale(1, 5, 500, token.address, { from: alice })).logs[0];
        assert.equal((await sale.listings(New.saleId)).seller, alice);

        // then she burns 8 NFTs
        await showtimeNFT.burn(alice, 1, 8, { from: alice });

        // there are still 2 available for sale
        assert.equal(await sale.availableForSale(New.saleId), 2);

        // bob can buy 1
        const { args: Buy1 } = (await sale.buyFor(New.saleId, 1, bob, { from: bob })).logs[0];

        // there is still 1 available for sale
        assert.equal(await sale.availableForSale(New.saleId), 1);

        // the listing has been updated to reflect the available quantity
        assert.equal((await sale.listings(New.saleId)).quantity, 1);

        // bob buys the last one
        const { args: Buy2 } = (await sale.buyFor(New.saleId, 1, bob, { from: bob })).logs[0];

        // the listing no longer exists
        assert.equal((await sale.listings(New.saleId)).seller, ZERO_ADDRESS);
    });

    it("completes a sale which has 10% royalties associated with it", async () => {
        // admin puts his tokenId on sale which has 10% royalty to alice
        await sale.createSale(tokenId10PctRoyaltyToAlice, 5, 500, token.address);
        assert.equal(await token.balanceOf(alice), 0);
        const { args: RoyaltyPaid } = (await sale.buyFor(0, 5, bob, { from: bob })).logs[0];
        assert.equal(RoyaltyPaid.receiver, alice);
        assert.equal(RoyaltyPaid.amount, 250);
        assert.equal(await token.balanceOf(alice), 250); // received her 10%
        assert.equal(await token.balanceOf(admin), 2250); // price - royalty
    });

    it("completes a sale which has 10% royalties to the zero address associated with it", async () => {
        // admin puts his tokenId on sale which has 10% royalty to the zero address
        await sale.createSale(tokenId10PctRoyaltyToZeroAddress, 5, 500, token.address);
        assert.equal(await token.balanceOf(alice), 0);

        // we ignore the royalty, everything goes to the seller
        truffleAsserts.eventNotEmitted(await sale.buyFor(0, 5, bob, { from: bob }), "RoyaltyPaid");
        assert.equal(await token.balanceOf(admin), 2500); // price
    });

    it("completes a sale which has 100% royalties associated with it", async () => {
        // admin puts his tokenId on sale which has 100% royalty to alice
        await sale.createSale(tokenId100PctRoyaltyToAlice, 5, 500, token.address);
        assert.equal(await token.balanceOf(alice), 0);
        const { args: RoyaltyPaid } = (await sale.buyFor(0, 5, bob, { from: bob })).logs[0];
        assert.equal(RoyaltyPaid.receiver, alice);
        assert.equal(RoyaltyPaid.amount, 2500);
        assert.equal(await token.balanceOf(alice), 2500); // received her 100%
        assert.equal(await token.balanceOf(admin), 0); // price - royalty
    });

    it("permits only owner to turn off royalty on the contract", async () => {
        await truffleAsserts.reverts(sale.royaltySwitch(false, { from: alice }));
        assert.equal(await sale.royaltiesEnabled(), true);
        await sale.royaltySwitch(false);
        assert.equal(await sale.royaltiesEnabled(), false);
    });

    it("pays no royalty when royalty is turned off", async () => {
        await sale.royaltySwitch(false);
        await truffleAsserts.reverts(sale.royaltySwitch(false), "royalty already on the desired state");
        await sale.createSale(2, 5, 500, token.address);
        assert.equal(await token.balanceOf(alice), 0);
        await sale.buyFor(0, 5, bob, { from: bob });
        assert.equal(await token.balanceOf(alice), 0); // received no royalty
        assert.equal(await token.balanceOf(admin), 2500);
    });

    it("permits only owner to pause and unpause the contract", async () => {
        await truffleAsserts.reverts(sale.pause({ from: alice }), "Ownable: caller is not the owner");
        await sale.pause();
        await truffleAsserts.reverts(sale.unpause({ from: alice }), "Ownable: caller is not the owner");
        await sale.unpause();
        assert.equal(await sale.paused(), false);
    });

    it("can not create a listing when paused", async () => {
        await sale.pause();
        await truffleAsserts.reverts(sale.createSale(1, 5, 500, token.address, { from: alice }));
        await sale.unpause();
    });

    it("can not buy when paused", async () => {
        await sale.createSale(1, 5, 500, token.address, { from: alice });
        await sale.pause();
        await truffleAsserts.reverts(sale.buyFor(0, 5, bob, { from: bob }), "Pausable: paused");
        await sale.unpause();
        await sale.buyFor(0, 5, bob, { from: bob });
    });

    it("can still cancel a listing when paused", async () => {
        await sale.createSale(1, 5, 500, token.address, { from: alice });
        await sale.cancelSale(0, { from: alice });
    });

    it("permits only owner to add accepted currencies", async () => {
        await truffleAsserts.reverts(
            sale.setAcceptedCurrency(showtimeNFT.address, { from: alice }),
            "Ownable: caller is not the owner"
        );
        await sale.setAcceptedCurrency(showtimeNFT.address);
        assert.equal(await sale.acceptedCurrencies(showtimeNFT.address), true);
    });

    it("permits only owner to remove accepted currency", async () => {
        await sale.setAcceptedCurrency(showtimeNFT.address);
        await truffleAsserts.reverts(
            sale.removeAcceptedCurrency(showtimeNFT.address, { from: alice }),
            "Ownable: caller is not the owner"
        );
        await sale.removeAcceptedCurrency(showtimeNFT.address);
        assert.equal(await sale.acceptedCurrencies(showtimeNFT.address), false);
    });
});
