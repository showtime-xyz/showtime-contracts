const NFT = artifacts.require("ERC1155NFT")
const Token = artifacts.require("Token")
const ERC1155Sale = artifacts.require("ERC1155Sale")
const truffleAsserts = require("truffle-assertions")
const expect = require("chai").expect

contract("ERC1155 Sale Contract Tests", (accounts) => {
    let nft, token, sale, admin, alice, bob
    beforeEach(async () => {
        admin = accounts[0]
        alice = accounts[1]
        bob = accounts[2]
        // mint 10 of id 1
        nft = await NFT.new()
        await nft.mint(1, 10, "0x0", { from: alice })
        // mint erc20s
        token = await Token.new()
        await token.mint(500, { from: bob })
        // approve the sale contract
        sale = await ERC1155Sale.new(nft.address, token.address)
        await nft.setApprovalForAll(sale.address, true, { from: alice })
        await token.approve(sale.address, 500, { from: bob })
    })
    it("deploys correctly", async () => {
        // should revert on non contract address
        await truffleAsserts.reverts(ERC1155Sale.new(alice, bob), "must be contract address")
        expect(await sale.nft()).eq(nft.address)
        expect(await sale.quoteToken()).eq(token.address)
    })

    it("creates a new sale", async () => {
        // alice creates a sale
        const { args: New } = (await sale.createSale(1, 5, 500, { from: alice })).logs[0]
        expect(New.saleId.toString()).eq("0")
        expect(New.seller).eq(alice)
        expect(New.tokenId.toString()).eq("1")
        expect((await nft.balanceOf(alice, 1)).toString()).eq("5") // 10 - 5
        const res = await sale.sales(New.saleId.toString())
        expect(res.tokenId.toString()).eq("1")
        expect(res.amount.toString()).eq("5")
        expect(res.price.toString()).eq("500")
        expect(res.seller).eq(alice)
        expect(res.isActive).to.be.true
    })
    it("cancels a sale", async () => {
        // alice creates and cancels a sale
        const { args: New } = (await sale.createSale(1, 5, 500, { from: alice })).logs[0]
        const { args: Cancel } = (await sale.cancelSale(New.saleId.toString(), { from: alice })).logs[0]
        expect(Cancel.saleId.toString()).eq("0")
        expect(Cancel.seller).eq(alice)
        const res = await sale.sales(0)
        expect(res.isActive).to.be.false
    })
    it("buys a sale", async () => {
        // alice creates a sale and bob buys the sale
        const { args: New } = (await sale.createSale(1, 5, 500, { from: alice })).logs[0]
        const { args: Buy } = (await sale.buy(New.saleId.toString(), { from: bob })).logs[0]
        expect(Buy.saleId.toString()).eq("0")
        expect(Buy.seller).eq(alice)
        expect(Buy.buyer).eq(bob)
        const res = await sale.sales(Buy.saleId.toString())
        expect(res.isActive).to.be.false
        expect((await nft.balanceOf(bob, 1)).toString()).eq("5")
    })
    it("only owner can pause and unpause", async () => {
        await truffleAsserts.reverts(sale.pause({ from: alice }), "Ownable: caller is not the owner")
        await sale.pause()
        await truffleAsserts.reverts(sale.unpause({ from: alice }), "Ownable: caller is not the owner")
        await sale.unpause()
        expect(await sale.paused()).to.be.false
    })
    it("doesnt function when paused", async () => {
        await sale.pause()
        await truffleAsserts.reverts(sale.createSale(1, 5, 500, { from: alice }), "Pausable: paused")
        await sale.unpause()
        await sale.createSale(1, 5, 500, { from: alice })
        await sale.pause()
        await truffleAsserts.reverts(sale.buy(0, { from: bob }), "Pausable: paused")
        await sale.unpause()
        await sale.buy(0, { from: bob })
    })
})
