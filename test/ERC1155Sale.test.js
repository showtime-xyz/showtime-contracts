const MT = artifacts.require("ShowtimeMT");
const Token = artifacts.require("Token");
const ERC1155Sale = artifacts.require("ERC1155Sale");
const truffleAsserts = require("truffle-assertions");

// address(0)
const ZERO_ADDRESS = "0x".padEnd(42, "0");

// TODO: test sale with price == 0
// TODO: test self-sale
contract("ERC1155 Sale Contract Tests", (accounts) => {
    let mt,
        token,
        sale,
        admin,
        alice,
        bob,
        tokenId0PctRoyalty,
        tokenId10PctRoyaltyToAlice,
        tokenId10PctRoyaltyToZeroAddress,
        tokenId100PctRoyaltyToAlice;

    beforeEach(async () => {
        admin = accounts[0];
        alice = accounts[1];
        bob = accounts[2];

        // mint tokens
        mt = await MT.new();
        tokenId0PctRoyalty = (await mt.issueToken(alice, 10, "some-hash", "0x0", ZERO_ADDRESS, 0)).logs[0]
            .args.id;
        tokenId10PctRoyaltyToAlice = (await mt.issueToken(admin, 10, "some-hash", "0x0", alice, 10_00))
            .logs[0].args.id; // 10% royalty
        tokenId10PctRoyaltyToZeroAddress = (
            await mt.issueToken(admin, 10, "some-hash", "0x0", ZERO_ADDRESS, 10_00)
        ).logs[0].args.id; // 10% royalty
        tokenId100PctRoyaltyToAlice = (await mt.issueToken(admin, 10, "some-hash", "0x0", alice, 100_00))
            .logs[0].args.id; // 100% royalty

        // mint erc20s to bob
        token = await Token.new();
        await token.mint(2500, { from: bob });

        // approvals
        sale = await ERC1155Sale.new(mt.address, [token.address]);
        await mt.setApprovalForAll(sale.address, true, { from: alice });
        await mt.setApprovalForAll(sale.address, true);
        await token.approve(sale.address, 2500, { from: bob });
    });

    it("doesn't allow to deploy with incorrect constructor arguments", async () => {
        await truffleAsserts.reverts(ERC1155Sale.new(alice, [token.address]), "must be contract address");
        await truffleAsserts.reverts(
            ERC1155Sale.new(mt.address, [ZERO_ADDRESS]),
            "_initialCurrencies must contain contract addresses"
        );
    });

    it("deploys with correct constructor arguments", async () => {
        assert.equal(await sale.nft(), mt.address);
        assert.equal(await sale.acceptedCurrencies(token.address), true);
        assert.equal(await sale.royaltiesEnabled(), true);
    });

    it("creates a new sale", async () => {
        // alice creates a sale
        // `New` is the event emitted when creating a new sale
        const { args: New } = (await sale.createSale(1, 5, 500, token.address, { from: alice })).logs[0];
        assert.equal(New.saleId, 0);
        assert.equal(New.seller, alice);
        assert.equal(New.tokenId, 1);
        assert.equal(await mt.balanceOf(alice, 1), 5); // 10 - 5
        const _sale = await sale.listings(New.saleId);
        assert.equal(_sale.tokenId, 1);
        assert.equal(_sale.amount, 5);
        assert.equal(_sale.price, 500);
        assert.equal(_sale.seller, alice);
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
        assert.equal(_sale.amount, 0);
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
        assert.equal(Buy.amount, 5);
        const _sale = await sale.listings(Buy.saleId);
        assert.equal(_sale.seller, ZERO_ADDRESS);
        assert.equal(await mt.balanceOf(alice, 1), 5); // 10 - 5
        assert.equal(await mt.balanceOf(bob, 1), 5); // 0 + 5
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
        assert.equal(Buy.amount, 5);

        const _sale = await sale.listings(Buy.saleId);
        assert.equal(_sale.seller, ZERO_ADDRESS);

        assert.equal(await mt.balanceOf(alice, 1), 5); // 10 - 5
        assert.equal(await mt.balanceOf(admin, 1), 5); // 0 + 5
    });

    it("buys specific amount of tokenIds", async () => {
        // alice creates a sale
        const { args: New } = (await sale.createSale(1, 5, 500, token.address, { from: alice })).logs[0];
        // bob buys the sale: 2 tokens only out of 5
        const { args: Buy1 } = (await sale.buyFor(New.saleId, 2, bob, { from: bob })).logs[0];
        assert.equal(Buy1.amount, 2);
        // there should still be 3 left available
        const { args: Buy2 } = (await sale.buyFor(New.saleId, 3, bob, { from: bob })).logs[0];
        assert.equal(Buy2.amount, 3);
    });

    it("throws on attempting to buy more than available amount", async () => {
        // alice creates a sale
        const { args: New } = (await sale.createSale(1, 5, 500, token.address, { from: alice })).logs[0];
        // bob buys the sale: tries to buy 6 tokens
        await truffleAsserts.reverts(
            sale.buyFor(New.saleId, 6, bob, { from: bob }),
            "required amount greater than available amount"
        );
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
            sale.setAcceptedCurrency(mt.address, { from: alice }),
            "Ownable: caller is not the owner"
        );
        await sale.setAcceptedCurrency(mt.address);
        assert.equal(await sale.acceptedCurrencies(mt.address), true);
    });

    it("permits only owner to remove accepted currency", async () => {
        await sale.setAcceptedCurrency(mt.address);
        await truffleAsserts.reverts(
            sale.removeAcceptedCurrency(mt.address, { from: alice }),
            "Ownable: caller is not the owner"
        );
        await sale.removeAcceptedCurrency(mt.address);
        assert.equal(await sale.acceptedCurrencies(mt.address), false);
    });
});
