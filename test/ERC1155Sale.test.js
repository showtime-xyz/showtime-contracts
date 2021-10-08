const MT = artifacts.require("ShowtimeMT");
const Token = artifacts.require("Token");
const ERC1155Sale = artifacts.require("ERC1155Sale");
const truffleAsserts = require("truffle-assertions");

// address(0)
const ZERO_ADDRESS = "0x".padEnd(42, "0");

contract("ERC1155 Sale Contract Tests", (accounts) => {
    let mt, token, sale, admin, alice, bob;
    beforeEach(async () => {
        admin = accounts[0];
        alice = accounts[1];
        bob = accounts[2];
        // mint tokens
        mt = await MT.new();
        await mt.issueToken(alice, 10, "some-hash", "0x0", "0x".padEnd(42, "0"), 0);
        await mt.issueToken(admin, 10, "some-hash", "0x0", alice, 1000); // 10% royalty
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
        assert.equal(await sale.royalty(), 1);
    });
    it("creates a new sale", async () => {
        // alice creates a sale
        // `New` is the event emitted when creating a new sale
        const { args: New } = (await sale.createSale(1, 5, 500, token.address, { from: alice })).logs[0];
        assert.equal(New.saleId, 0);
        assert.equal(New.seller, alice);
        assert.equal(New.tokenId, 1);
        assert.equal(await mt.balanceOf(alice, 1), 5); // 10 - 5
        const _sale = await sale.sales(New.saleId);
        assert.equal(_sale.tokenId, 1);
        assert.equal(_sale.amount, 5);
        assert.equal(_sale.price, 500);
        assert.equal(_sale.seller, alice);
        assert.equal(_sale.isActive, true);
    });
    it("cannot cancel other seller's sale", async () => {
        const tx = await sale.createSale(1, 5, 500, token.address, { from: alice });
        const { saleId } = tx.logs[0].args;
        // bob cannot cancel
        await truffleAsserts.reverts(sale.cancelSale(saleId), "caller not seller");
    });
    it("cannot cancel not existent sale", async () => {
        await truffleAsserts.reverts(sale.cancelSale(42), "sale doesn't exist");
    });
    it("allows seller to cancel their sale", async () => {
        // alice cancels a sale
        const { args: New } = (await sale.createSale(1, 5, 500, token.address, { from: alice })).logs[0];
        // alice cancels her sale
        const { args: Cancel } = (await sale.cancelSale(New.saleId, { from: alice })).logs[0];
        assert.equal(Cancel.saleId, 0);
        assert.equal(Cancel.seller, alice);
        const _sale = await sale.sales(Cancel.saleId);
        assert.equal(_sale.isActive, false);
    });
    it("cannot buy a cancelled sale", async () => {
        const tx = await sale.createSale(1, 5, 500, token.address, { from: alice }); // alice create
        const { saleId } = tx.logs[0].args;
        await sale.cancelSale(saleId, { from: alice }); // alice cancel
        await truffleAsserts.reverts(sale.buy(saleId, 5), "sale already cancelled or bought");
    });
    it("buys a valid sale", async () => {
        // alice creates a sale
        const { args: New } = (await sale.createSale(1, 5, 500, token.address, { from: alice })).logs[0];
        // bob buys the sale
        const { args: Buy } = (await sale.buy(New.saleId, 5, { from: bob })).logs[0];
        assert.equal(Buy.saleId, 0);
        assert.equal(Buy.seller, alice);
        assert.equal(Buy.buyer, bob);
        assert.equal(Buy.amount, 5);
        const _sale = await sale.sales(Buy.saleId);
        assert.equal(_sale.isActive, false);
        assert.equal(await mt.balanceOf(alice, 1), 5); // 10 - 5
        assert.equal(await mt.balanceOf(bob, 1), 5); // 0 + 5
    });
    it("buys specific amount of tokenIds from the sale", async () => {
        // alice creates a sale
        const { args: New } = (await sale.createSale(1, 5, 500, token.address, { from: alice })).logs[0];
        // bob buys the sale: 2 tokens only out of 5
        const { args: Buy1 } = (await sale.buy(New.saleId, 2, { from: bob })).logs[0];
        assert.equal(Buy1.amount, 2);
        // there should still be 3 left available
        const { args: Buy2 } = (await sale.buy(New.saleId, 3, { from: bob })).logs[0];
        assert.equal(Buy2.amount, 3);
    });
    it("throws on attempting to buy more than available amount", async () => {
        // alice creates a sale
        const { args: New } = (await sale.createSale(1, 5, 500, token.address, { from: alice })).logs[0];
        // bob buys the sale: tries to buy 6 tokens
        await truffleAsserts.reverts(
            sale.buy(New.saleId, 6, { from: bob }),
            "required amount greater than available amount"
        );
    });
    it("buys a sale which has royalty associated with it", async () => {
        // admin puts his tokenId on sale which has 10% royalty to alice
        await sale.createSale(2, 5, 500, token.address);
        assert.equal(await token.balanceOf(alice), 0);
        const { args: RoyaltyPaid } = (await sale.buy(0, 5, { from: bob })).logs[0];
        assert.equal(RoyaltyPaid.receiver, alice);
        assert.equal(RoyaltyPaid.amount, 250);
        assert.equal(await token.balanceOf(alice), 250); // received her 10%
        assert.equal(await token.balanceOf(admin), 2250); // price - royalty
    });
    it("permits only owner to turn off royalty on the contract", async () => {
        await truffleAsserts.reverts(sale.royaltySwitch(0, { from: alice }));
        assert.equal(await sale.royalty(), 1);
        await sale.royaltySwitch(0);
        assert.equal(await sale.royalty(), 0);
    });
    it("pays no royalty when royalty is turned off", async () => {
        await sale.royaltySwitch(0);
        await truffleAsserts.reverts(sale.royaltySwitch(0), "royalty already on the desired state");
        await sale.createSale(2, 5, 500, token.address);
        assert.equal(await token.balanceOf(alice), 0);
        await sale.buy(0, 5, { from: bob });
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
    it("doesnt function when paused", async () => {
        await sale.createSale(1, 5, 500, token.address, { from: alice });
        await sale.pause();
        await truffleAsserts.reverts(sale.buy(0, 5, { from: bob }), "Pausable: paused");
        await sale.unpause();
        await sale.buy(0, 5, { from: bob });
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
    it("permits only owner to set min sell price", async () => {
        await truffleAsserts.reverts(
            sale.setMinSellPrice(500, { from: alice }),
            "Ownable: caller is not the owner"
        );
        await sale.setMinSellPrice(500);
    });
    it("does not create sale if price below min sell price", async () => {
        await sale.setMinSellPrice(500);
        await truffleAsserts.reverts(
            sale.createSale(1, 5, 400, token.address, { from: alice }),
            "price must be greater then min sell price"
        );
        await sale.createSale(1, 5, 500, token.address, { from: alice });
    });
});
