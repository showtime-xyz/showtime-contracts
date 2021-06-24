const MT = artifacts.require("ShowtimeMT");
const truffleAssert = require("truffle-assertions");

contract("ShowtimeMT", async (accounts) => {
    describe("Access Tests", async () => {
        beforeEach(async () => {
            // Deploy MultiToken
            await MT.new();
            this.mt = await MT.deployed();
            // Set Admin
            this.mt.setAdmin(accounts[1], true);
        });
        it("non-admin should not be able to mint", async () => {
            const recepient = accounts[1];
            const amount = 10;
            const hash = "some-hash";
            const data = "0x00";
            await truffleAssert.reverts(
                this.mt.issueToken(recepient, amount, hash, data, { from: accounts[2] }),
                "AccessProtected: caller is not admin"
            );
        });
        it("owner should be able to set admin", async () => {
            const result = await this.mt.setAdmin(accounts[2], true);
            truffleAssert.eventEmitted(result, 'UserAccessSet');
            const isAdmin = await this.mt.isAdmin(accounts[2]);
            assert.equal(isAdmin, true);
        });
        it("admin should be able to set minter", async () => {
            const result = await this.mt.setMinter(accounts[3], true, { from: accounts[2] });
            truffleAssert.eventEmitted(result, 'UserAccessSet');
            const isMinter = await this.mt.isMinter(accounts[3]);
            assert.equal(isMinter, true);
        });
        it("admin should be able to revoke minter", async () => {
            const result = await this.mt.setMinter(accounts[3], false, { from: accounts[2] });
            truffleAssert.eventEmitted(result, 'UserAccessSet');
            const isMinter = await this.mt.isMinter(accounts[3]);
            assert.equal(isMinter, false);
        });
        it("non-owner should not be able to set admin", async () => {
            await truffleAssert.reverts(
                this.mt.setAdmin(accounts[1], true, { from: accounts[1] }),
                "Ownable: caller is not the owner"
            );
        });
        it("owner should be able to revoke admin", async () => {
            const result = await this.mt.setAdmin(accounts[1], false);
            truffleAssert.eventEmitted(result, 'UserAccessSet');
            const isAdmin = await this.mt.isAdmin(accounts[1]);
            assert.equal(isAdmin, false);
        });
    });
    describe("Minting Tests", async () => {
        beforeEach(async () => {
            // Deploy MultiToken
            await MT.new();
            this.mt = await MT.deployed();
        });
        it("minter should be able to mint", async () => {
            const recipient = accounts[1];
            const amount = 10;
            const hash = "some-hash";
            const data = "0x00";
            await this.mt.issueToken(recipient, amount, hash, data);
            const balance = await this.mt.balanceOf(recipient, 1);
            assert.equal(balance, amount);
            const URI = await this.mt.uri(1);
            assert.equal(URI, "https://gateway.pinata.cloud/ipfs/some-hash");
        });
    });
    describe("URI Tests", async () => {
        beforeEach(async () => {
            // Deploy MultiToken
            await MT.new();
            this.mt = await MT.deployed();
            // Issue MT
            const recipient = accounts[1];
            const amount = 10;
            const hash = "some-hash";
            const data = "0x00";
            await this.mt.issueToken(recipient, amount, hash, data);
        });
        it("should be able to get baseURI", async () => {
            const baseURI = await this.mt.baseURI();
            assert.equal(baseURI, "https://gateway.pinata.cloud/ipfs/");
        });
        it("owner should be able to set baseURI", async () => {
            const _baseURI = "https://gateway.test.com/ipfs/";
            await this.mt.setBaseURI(_baseURI);
            const baseURI = await this.mt.baseURI();
            assert.equal(baseURI, _baseURI);
        });
        it("should be able to get token URI", async () => {
            const URI = await this.mt.uri(1);
            assert.equal(URI, "https://gateway.test.com/ipfs/some-hash");
        });
    });
    describe("Transfer Tests", async () => {
        beforeEach(async () => {
            // Deploy MultiToken
            await MT.new();
            this.mt = await MT.deployed();
            // Issue MT
            const recipient = accounts[1];
            const amount = 10;
            const hash = "some-hash";
            const data = "0x00";
            await this.mt.issueToken(recipient, amount, hash, data);
        });
        it("nft-owner should be able to transfer amount", async () => {
            const from = accounts[1];
            const to = accounts[2];
            const id = 1;
            const amount = 1;
            const data = "0x00";
            const fromBalance = await this.mt.balanceOf(from, id);
            const toBalance = await this.mt.balanceOf(to, id);
            await this.mt.safeTransferFrom(from, to, id, amount, data, { from });
            const fromBalance_new = await this.mt.balanceOf(from, id);
            const toBalance_new = await this.mt.balanceOf(to, id);
            assert.equal(BigInt(fromBalance_new), BigInt(fromBalance - amount));
            assert.equal(BigInt(toBalance_new), BigInt(toBalance + amount));
        });
    });
})