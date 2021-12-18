const { exec } = require("shelljs");
const assert = require("assert");
require("dotenv").config();

const ShowtimeMT = artifacts.require("ShowtimeMT");
const ShowtimeV1Market = artifacts.require("ShowtimeV1Market");

const MUMBAI_TEST_TOKEN = "0xd404017A401ff7EF65E7689630eCa288E23d67a1";
const MUMBAI_WMATIC = "0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889";
const MUMBAI_WETH = "0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa";

// https://docs.polygon.technology/docs/develop/network-details/mapped-tokens
const POLYGON_MAINNET_PoS_USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const POLYGON_MAINNET_PoS_WETH = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619";
const POLYGON_MAINNET_PoS_DAI = "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063";
const POLYGON_MAINNET_WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";

const POLYGON_MULTISIG = "0x8C929a803A5Aae8B0F8fB9df0217332cBD7C6cB5";

// see https://docs.biconomy.io/misc/contract-addresses
const POLYGON_BICONOMY_FORWARDER = "0x86C80a8aa58e0A4fa09A69624c31Ab2a6CAD56b8";

const networkConfigs = {
    development: {
        showtimeMTAddress: undefined,
        trustedForwarderAddress: "0x000000000000000000000000000000000000dEaD",
        initialCurrencies: [],
    },

    mumbai_testnet: {
        showtimeMTAddress: "0x09F3a26302e1c45f0d78Be5D592f52b6fca43811",
        initialCurrencies: [MUMBAI_TEST_TOKEN, MUMBAI_WMATIC, MUMBAI_WETH],
        ownerAddress: null,
        trustedForwarderAddress: "0x9399BB24DBB5C4b782C70c2969F58716Ebbd6a3b",
    },

    matic_mainnet: {
        showtimeMTAddress: "0x8A13628dD5D600Ca1E8bF9DBc685B735f615Cb90",
        initialCurrencies: [
            POLYGON_MAINNET_PoS_WETH,
            POLYGON_MAINNET_PoS_DAI,
            POLYGON_MAINNET_PoS_USDC,
            // we don't use WMATIC anymore because it doesn't do permit()
            // POLYGON_MAINNET_WMATIC,
        ],

        // for the staging deployment, we want to keep the deployment address as the owner
        ownerAddress: POLYGON_MULTISIG,

        trustedForwarderAddress: POLYGON_BICONOMY_FORWARDER,
    },
};

module.exports = async function (deployer, network, accounts) {
    const networkConfig = networkConfigs[network];
    assert(networkConfig !== undefined);

    if (networkConfig.showtimeMTAddress === undefined) {
        await deployer.deploy(ShowtimeMT);
        const deployedShowtimeMT = await ShowtimeMT.deployed();
        networkConfig.showtimeMTAddress = deployedShowtimeMT.address;
    }

    if (network !== "development") {
        console.log(`Using ETH_FROM: ${process.env.ETH_FROM}`);
        assert(process.env.ETH_FROM != undefined);
    }

    console.log(
        `ShowtimeV1Market.new(${networkConfig.showtimeMTAddress}, ${networkConfig.trustedForwarderAddress}, ${networkConfig.initialCurrencies})`
    );

    const market = await ShowtimeV1Market.new(
        networkConfig.showtimeMTAddress,
        networkConfig.trustedForwarderAddress,
        networkConfig.initialCurrencies,
        {
            overwrite: true,
        }
    );

    console.log({
        ShowtimeMT: networkConfig.showtimeMTAddress,
        ShowtimeV1Market: market.address,
    });

    if (network !== "development") {
        if (networkConfig.ownerAddress === null) {
            console.log("no owner address defined, skipping ownership transfer");
        } else {
            console.log(`market.transferOwnership(${networkConfig.ownerAddress})`);
            await market.transferOwnership(networkConfig.ownerAddress);
        }

        await verify("ShowtimeV1Market", market.address, network);
    }
};

function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

function verify(name, address, network) {
    // give some time to Polygonscan to realize that a contract was deployed
    console.log("Verifying on polygonscan.com in 15s...");
    await sleep(15000);
    console.log(`npx truffle run verify ShowtimeV1Market@${address} --network ${network}`);

    return new Promise((resolve, reject) => {
        exec(`npx truffle run verify ${name}@${address} --network ${network}`, (code, stdout, stderr) => {
            if (code !== 0) reject(stderr);
            resolve(stdout);
        });
    });
}
