const MT = artifacts.require("ShowtimeMT");
const truffleAssert = require("truffle-assertions");

contract("ShowtimeMT", async (accounts) => {
    let mt;
    describe("Access Tests", async () => {
        beforeEach(async () => {
            // Deploy MultiToken
            mt = await MT.new();
            // Set Admin
            await mt.setAdmin(accounts[1], true);
            // Set Minter
            await mt.setMinter(accounts[2], true);
        });
        it("non-minter should not be able to mint", async () => {
            const recepient = accounts[1];
            const amount = 10;
            const hash = "some-hash";
            const data = "0x00";
            const royaltyRecipient = "0x".padEnd(42, "0");
            const royaltyPercent = 0; // 0 % means no royalty being set
            await truffleAssert.reverts(
                mt.issueToken(
                    recepient,
                    amount,
                    hash,
                    data,
                    royaltyRecipient,
                    royaltyPercent,
                    { from: accounts[3] }
                ),
                "AccessProtected: caller is not minter"
            );
        });
        it("owner should be able to set admin", async () => {
            const result = await mt.setAdmin(accounts[3], true);
            truffleAssert.eventEmitted(result, "UserAccessSet");
            const isAdmin = await mt.isAdmin(accounts[3]);
            assert.equal(isAdmin, true);
        });
        it("admin should be able to set minter", async () => {
            const result = await mt.setMinter(accounts[3], true, {
                from: accounts[1],
            });
            truffleAssert.eventEmitted(result, "UserAccessSet");
            const isMinter = await mt.isMinter(accounts[3]);
            assert.equal(isMinter, true);
        });
        it("admin should be able to set batch of minters", async () => {
            const minters = accounts.slice(3, 8);
            const result = await mt.setMinters(minters, true, {
                from: accounts[1],
            });
            truffleAssert.eventEmitted(result, "UserAccessSet");
            for (var i = 0; i < minters.length; i++) {
                const minter = minters[i];
                const isMinter = await mt.isMinter(minter);
                assert.equal(isMinter, true);
            }
        });
        it("admin should be able to revoke minter", async () => {
            const result = await mt.setMinter(accounts[2], false, {
                from: accounts[1],
            });
            truffleAssert.eventEmitted(result, "UserAccessSet");
            const isMinter = await mt.isMinter(accounts[2]);
            assert.equal(isMinter, false);
        });
        it("admin should be able to revoke batch of minters", async () => {
            const minters = accounts.slice(3, 8);
            const result = await mt.setMinters(minters, false, {
                from: accounts[1],
            });
            truffleAssert.eventEmitted(result, "UserAccessSet");
            for (var i = 0; i < minters.length; i++) {
                const minter = minters[i];
                const isMinter = await mt.isMinter(minter);
                assert.equal(isMinter, false);
            }
        });
        it("non-owner should not be able to set admin", async () => {
            await truffleAssert.reverts(
                mt.setAdmin(accounts[1], true, { from: accounts[1] }),
                "Ownable: caller is not the owner"
            );
        });
        it("owner should be able to revoke admin", async () => {
            const result = await mt.setAdmin(accounts[1], false);
            truffleAssert.eventEmitted(result, "UserAccessSet");
            const isAdmin = await mt.isAdmin(accounts[1]);
            assert.equal(isAdmin, false);
        });
        it("admin should be able to enable/disable minting for all", async () => {
            const enable_result = await mt.setPublicMinting(true, {
                from: accounts[1],
            });
            truffleAssert.eventEmitted(enable_result, "UserAccessSet");
            const enable_publicMinting = await mt.publicMinting();
            assert.equal(enable_publicMinting, true);
            const disable_result = await mt.setPublicMinting(false, {
                from: accounts[1],
            });
            truffleAssert.eventEmitted(disable_result, "UserAccessSet");
            const disable_publicMinting = await mt.publicMinting();
            assert.equal(disable_publicMinting, false);
        });
    });
    describe("Minting Tests", async () => {
        beforeEach(async () => {
            // Deploy MultiToken
            mt = await MT.new();
            // Set Admin
            await mt.setAdmin(accounts[1], true);
        });
        it("minter should be able to mint", async () => {
            const recipient = accounts[1];
            const amount = 10;
            const hash = "some-hash";
            const data = "0x00";
            const royaltyRecipient = "0x".padEnd(42, "0"); // "0x0000..."
            const royaltyPercent = 0; // 0 % means no royalty being set
            await mt.issueToken(
                recipient,
                amount,
                hash,
                data,
                royaltyRecipient,
                royaltyPercent
            );
            const balance = await mt.balanceOf(recipient, 1);
            assert.equal(balance, amount);

            // assert no royalty
            const { receiver, royaltyAmount } = await mt.royaltyInfo(
                1,
                web3.utils.toWei("1")
            );
            assert.equal(receiver, "0x".padEnd(42, "0"));
            assert.equal(royaltyAmount, 0);

            const URI = await mt.uri(1);
            assert.equal(URI, "https://gateway.pinata.cloud/ipfs/some-hash");
        });
        it("minter should be able to batch mint", async () => {
            const recipient = accounts[1];
            const amounts = [];
            const hashes = [];
            const data = "0x00";
            const royaltyRecipients = [];
            const royaltyPercents = [];
            const iterations = 3;
            for (var i = 0; i < iterations; i++) {
                amounts.push(Math.floor(Math.random() * 10));
                royaltyRecipients.push("0x".padEnd(42, "0"));
                royaltyPercents.push(0);
                hashes.push("some-hash-" + i);
            }
            const result = await mt.issueTokenBatch(
                recipient,
                amounts,
                hashes,
                data,
                royaltyRecipients,
                royaltyPercents
            );
            const tokenIds = result.receipt.logs[0].args.ids;
            const tokenAmounts = result.receipt.logs[0].args.values;
            for (var i = 0; i < iterations; i++) {
                const balance = await mt.balanceOf(recipient, tokenIds[i]);
                assert.equal(balance.toString(), tokenAmounts[i]);

                // assert no royalty
                const { receiver, royaltyAmount } = await mt.royaltyInfo(
                    tokenIds[i],
                    web3.utils.toWei("1")
                );
                assert.equal(receiver, "0x".padEnd(42, "0"));
                assert.equal(royaltyAmount, 0);

                const URI = await mt.uri(tokenIds[i]);
                assert.equal(
                    URI,
                    "https://gateway.pinata.cloud/ipfs/some-hash-" + i
                );
            }
        });
        it("should be able to mint if public minting is enabled", async () => {
            await mt.setPublicMinting(true, { from: accounts[1] });
            const recipient = accounts[1];
            const amount = 10;
            const hash = "some-hash";
            const data = "0x00";
            const royaltyRecipient = "0x".padEnd(42, "0");
            const royaltyPercent = 0; // 0 % means no royalty being set
            await mt.issueToken(
                recipient,
                amount,
                hash,
                data,
                royaltyRecipient,
                royaltyPercent,
                { from: accounts[4] }
            );
            const balance = await mt.balanceOf(recipient, 1);
            assert.equal(balance, amount);

            // assert no royalty set
            const { receiver, royaltyAmount } = await mt.royaltyInfo(
                1,
                web3.utils.toWei("1")
            );
            assert.equal(receiver, "0x".padEnd(42, "0"));
            assert.equal(royaltyAmount, 0);

            const URI = await mt.uri(1);
            assert.equal(URI, "https://gateway.pinata.cloud/ipfs/some-hash");
        });
    });
    describe("Burning tests", () => {
        beforeEach(async () => {
            // Deploy MultiToken
            mt = await MT.new();
        });
        it("holder should be able to burn", async () => {
            const recipient = accounts[1];
            const amount = 10;
            const hash = "some-hash";
            const data = "0x00";
            const royaltyRecipient = "0x".padEnd(42, "0"); // "0x0000..."
            const royaltyPercent = 0; // 0 % means no royalty being set
            await mt.issueToken(
                recipient,
                amount,
                hash,
                data,
                royaltyRecipient,
                royaltyPercent
            );
            let balance = await mt.balanceOf(recipient, 1);
            assert.equal(balance, amount);
            await mt.burn(recipient, 1, amount, { from: recipient });
            // burning
            balance = await mt.balanceOf(recipient, 1);
            // no balance after burning
            assert.equal(balance.toString(), 0);
        });
        it("holder should be able to batch burn", async () => {
            const recipient = accounts[1];
            const amounts = [];
            const hashes = [];
            const data = "0x00";
            const royaltyRecipients = [];
            const royaltyPercents = [];
            const iterations = 3;
            for (var i = 0; i < iterations; i++) {
                amounts.push(Math.floor(Math.random() * 10));
                royaltyRecipients.push("0x".padEnd(42, "0"));
                royaltyPercents.push(0);
                hashes.push("some-hash-" + i);
            }
            const result = await mt.issueTokenBatch(
                recipient,
                amounts,
                hashes,
                data,
                royaltyRecipients,
                royaltyPercents
            );
            const tokenIds = result.receipt.logs[0].args.ids;
            const tokenAmounts = result.receipt.logs[0].args.values;
            for (let i = 0; i < iterations; i++) {
                const balance = await mt.balanceOf(recipient, tokenIds[i]);
                assert.equal(balance.toString(), tokenAmounts[i]);
            }
            await mt.burnBatch(recipient, tokenIds, tokenAmounts, {
                from: recipient,
            });
            for (let i = 0; i < iterations; i++) {
                const balance = await mt.balanceOf(recipient, tokenIds[i]);
                assert.equal(balance.toString(), 0);
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
            const royaltyRecipient = "0x".padEnd(42, "0");
            const royaltyPercent = 0; // 0 % means no royalty being set
            await mt.issueToken(
                recipient,
                amount,
                hash,
                data,
                royaltyRecipient,
                royaltyPercent
            );
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
            const royaltyRecipient = "0x".padEnd(42, "0");
            const royaltyPercent = 0; // 0 % means no royalty being set
            await mt.issueToken(
                recipient,
                amount,
                hash,
                data,
                royaltyRecipient,
                royaltyPercent
            );
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
    describe("Royalty tests", function () {
        beforeEach(async function () {
            // Deploy MultiToken
            mt = await MT.new();
        });
        it("mints token with royalty", async function () {
            const recipient = accounts[1];
            const amount = 1;
            const hash = "some-hash";
            const data = "0x00";
            const royaltyRecipient = accounts[2];
            const royaltyPercent = 1000; // 10% royalty
            await mt.issueToken(
                recipient,
                amount,
                hash,
                data,
                royaltyRecipient,
                royaltyPercent
            );
            const { receiver, royaltyAmount } = await mt.royaltyInfo(1, 100); // 100 is sale price
            assert.equal(receiver, accounts[2]);
            assert.equal(royaltyAmount.toString(), 10);
        });
        it("mints in batch with royalty", async function () {
            const recipient = accounts[1];
            const amounts = [];
            const hashes = [];
            const data = "0x00";
            const royaltyRecipients = [];
            const royaltyPercents = [];
            const iterations = 10;
            for (let i = 0; i < iterations; i++) {
                amounts.push(Math.floor(Math.random() * 10));
                hashes.push("some-hash-" + i);
                royaltyRecipients.push(accounts[i]);
                royaltyPercents.push(500 * (i + 1)); // [500: 5%, 1000: 10%, 1500:15%...]
            }
            const result = await mt.issueTokenBatch(
                recipient,
                amounts,
                hashes,
                data,
                royaltyRecipients,
                royaltyPercents
            );
            const tokenIds = result.receipt.logs[0].args.ids;
            for (i = 0; i < iterations; i++) {
                const { receiver, royaltyAmount } = await mt.royaltyInfo(
                    tokenIds[i],
                    100
                );
                assert.equal(receiver, accounts[i]);
                assert.equal(royaltyAmount.toString(), 5 * (i + 1));
            }
        });
        it("throws on % greater than 100%", async function () {
            const recipient = accounts[1];
            const amount = 1;
            const hash = "some-hash";
            const data = "0x00";
            const royaltyRecipient = accounts[2];
            const royaltyPercent = 100001; // > 100% royalty
            await truffleAssert.reverts(
                mt.issueToken(
                    recipient,
                    amount,
                    hash,
                    data,
                    royaltyRecipient,
                    royaltyPercent
                ),
                "ERC2981Royalties: value too high"
            );
        });
    });
    describe("ERC165 support tests", function () {
        beforeEach(async function () {
            // Deploy MultiToken
            mt = await MT.new();
        });

        it("supports interface IERC165", async function () {
            const supported = await mt.supportsInterface("0x01ffc9a7");
            assert.equal(supported, true);
        });
        it("supports IERC1155", async function () {
            const supported = await mt.supportsInterface("0xd9b67a26");
            assert.equal(supported, true);
        });
        it("supports IERC2981", async function () {
            const supported = await mt.supportsInterface("0x2a55205a");
            assert.equal(supported, true);
        });
        it("returns false for 0xffffffff", async function () {
            const supported = await mt.supportsInterface("0xffffffff");
            assert.equal(supported, false);
        });
    });
});
