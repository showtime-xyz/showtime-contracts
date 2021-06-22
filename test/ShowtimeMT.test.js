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
            truffleAssert.eventEmitted(result, 'AdminAccessSet');
            const isAdmin = await this.mt.isAdmin(accounts[2]);
            assert.equal(isAdmin, true);
        });
        it("non-owner should not be able to set admin", async () => {
            await truffleAssert.reverts(
                this.mt.setAdmin(accounts[1], true, { from: accounts[1] }),
                "Ownable: caller is not the owner"
            );
        });
        it("owner should be able to revoke admin", async () => {
            const result = await this.mt.setAdmin(accounts[1], false);
            truffleAssert.eventEmitted(result, 'AdminAccessSet');
            const isAdmin = await this.mt.isAdmin(accounts[1]);
            assert.equal(isAdmin, false);
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
})