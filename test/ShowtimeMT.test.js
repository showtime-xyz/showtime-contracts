const MT = artifacts.require("ShowtimeMT");
const truffleAssert = require("truffle-assertions");

contract("ShowtimeMT", async (accounts) => {
    let mt;
    describe("Access Tests", async () => {
        beforeEach(async () => {
            // Deploy MultiToken
            mt = await MT.new()
            // Set Admin
            mt.setAdmin(accounts[1], true);
            // Set Minter
            mt.setAdmin(accounts[2], true);
        });
        it("non-admin should not be able to mint", async () => {
            const recepient = accounts[1];
            const amount = 10;
            const hash = "some-hash";
            const data = "0x00";
            await truffleAssert.reverts(
                mt.issueToken(recepient, amount, hash, data, { from: accounts[3] }),
                "AccessProtected: caller is not minter"
            );
        });
        it("owner should be able to set admin", async () => {
            const result = await mt.setAdmin(accounts[3], true);
            truffleAssert.eventEmitted(result, 'UserAccessSet');
            const isAdmin = await mt.isAdmin(accounts[3]);
            assert.equal(isAdmin, true);
        });
        it("admin should be able to set minter", async () => {
            const result = await mt.setMinter(accounts[3], true, { from: accounts[1] });
            truffleAssert.eventEmitted(result, 'UserAccessSet');
            const isMinter = await mt.isMinter(accounts[3]);
            assert.equal(isMinter, true);
        });
        it("admin should be able to revoke minter", async () => {
            const result = await mt.setMinter(accounts[2], false, { from: accounts[1] });
            truffleAssert.eventEmitted(result, 'UserAccessSet');
            const isMinter = await mt.isMinter(accounts[2]);
            assert.equal(isMinter, false);
        });
        it("non-owner should not be able to set admin", async () => {
            await truffleAssert.reverts(
                mt.setAdmin(accounts[1], true, { from: accounts[1] }),
                "Ownable: caller is not the owner"
            );
        });
        it("owner should be able to revoke admin", async () => {
            const result = await mt.setAdmin(accounts[1], false);
            truffleAssert.eventEmitted(result, 'UserAccessSet');
            const isAdmin = await mt.isAdmin(accounts[1]);
            assert.equal(isAdmin, false);
        });
    });
    describe("Minting Tests", async () => {
        beforeEach(async () => {
            // Deploy MultiToken
            mt = await MT.new();
        });
        it("minter should be able to mint", async () => {
            const recipient = accounts[1];
            const amount = 10;
            const hash = "some-hash";
            const data = "0x00";
            await mt.issueToken(recipient, amount, hash, data);
            const balance = await mt.balanceOf(recipient, 1);
            assert.equal(balance, amount);
            const URI = await mt.uri(1);
            assert.equal(URI, "https://gateway.pinata.cloud/ipfs/some-hash");
        });
        it("minter should be able to batch mint", async () => {
            const recipient = accounts[1];
            const amounts = [];
            const hashes = [];
            const data = "0x00";
            const iterations = 3;
            for (var i = 0; i < iterations; i++) {
                amounts.push(Math.floor(Math.random() * 10));
                hashes.push("some-hash-" + i);
            }
            const result = await mt.issueTokenBatch(recipient, amounts, hashes, data);
            const tokenIds = result.receipt.logs[0].args.ids;
            const tokenAmounts = result.receipt.logs[0].args.values;
            for (var i = 0; i < iterations; i++) {
                const balance = await mt.balanceOf(recipient, tokenIds[i]);
                assert.equal(balance.toString(), tokenAmounts[i]);
                const URI = await mt.uri(tokenIds[i]);
                assert.equal(URI, "https://gateway.pinata.cloud/ipfs/some-hash-" + i);
            }
        });
    });
    describe("URI Tests", async () => {
        beforeEach(async () => {
            // Deploy MultiToken
            mt = await MT.new();
            // Issue MT
            const recipient = accounts[1];
            const amount = 10;
            const hash = "some-hash";
            const data = "0x00";
            await mt.issueToken(recipient, amount, hash, data);
        });
        it("should be able to get baseURI", async () => {
            const baseURI = await mt.baseURI();
            assert.equal(baseURI, "https://gateway.pinata.cloud/ipfs/");
        });
        it("owner should be able to set baseURI", async () => {
            const _baseURI = "https://gateway.test.com/ipfs/";
            await mt.setBaseURI(_baseURI);
            const baseURI = await mt.baseURI();
            assert.equal(baseURI, _baseURI);
        });
        it("should be able to get token URI", async () => {
            const URI = await mt.uri(1);
            assert.equal(URI, "https://gateway.pinata.cloud/ipfs/some-hash");
        });
    });
    describe("Transfer Tests", async () => {
        beforeEach(async () => {
            // Deploy MultiToken
            mt = await MT.new();
            // Issue MT
            const recipient = accounts[1];
            const amount = 10;
            const hash = "some-hash";
            const data = "0x00";
            await mt.issueToken(recipient, amount, hash, data);
        });
        it("nft-owner should be able to transfer amount", async () => {
            const from = accounts[1];
            const to = accounts[2];
            const id = 1;
            const amount = 1;
            const data = "0x00";
            const fromBalance = await mt.balanceOf(from, id);
            const toBalance = await mt.balanceOf(to, id);
            await mt.safeTransferFrom(from, to, id, amount, data, { from });
            const fromBalance_new = await mt.balanceOf(from, id);
            const toBalance_new = await mt.balanceOf(to, id);
            assert.equal(BigInt(fromBalance_new), BigInt(fromBalance - amount));
            assert.equal(BigInt(toBalance_new), BigInt(toBalance + amount));
        });
    });
})