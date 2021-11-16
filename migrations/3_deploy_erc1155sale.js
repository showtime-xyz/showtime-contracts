const { exec } = require("shelljs");
const assert = require("assert");

const ShowtimeMT = artifacts.require("ShowtimeMT");
const ERC1155Sale = artifacts.require("ERC1155Sale");

const MUMBAI_TEST_TOKEN = "0xd404017a401ff7ef65e7689630eca288e23d67a1";

// https://docs.polygon.technology/docs/develop/network-details/mapped-tokens
const POLYGON_MAINNET_PoS_USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const POLYGON_MAINNET_PoS_WETH = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619";
const POLYGON_MAINNET_PoS_DAI = "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063";

const networkConfigs = {
    development: {
        showtimeMTAddress: undefined,
        initialCurrencies: [],
    },

    mumbai_testnet: {
        showtimeMTAddress: "0x09F3a26302e1c45f0d78Be5D592f52b6fca43811",
        initialCurrencies: [MUMBAI_TEST_TOKEN],
        ownerAddress: null,
        trustedForwarderAddress: "0x9399BB24DBB5C4b782C70c2969F58716Ebbd6a3b",
    },

    matic_mainnet: {
        showtimeMTAddress: "0x8A13628dD5D600Ca1E8bF9DBc685B735f615Cb90",
        initialCurrencies: [POLYGON_MAINNET_PoS_WETH, POLYGON_MAINNET_PoS_DAI, POLYGON_MAINNET_PoS_USDC],
        ownerAddress: 0x0c7f6405bf7299a9ebdccfd6841feac6c91e5541,
        trustedForwarderAddress: "0x86C80a8aa58e0A4fa09A69624c31Ab2a6CAD56b8",
    },
};

module.exports = async function (deployer, network) {
    const networkConfig = networkConfigs[network];
    assert(networkConfig !== undefined);

    if (network == "development") {
        await deployer.deploy(ShowtimeMT);
        const deployedShowtimeMT = await ShowtimeMT.deployed();
        networkConfig.showtimeMTAddress = deployedShowtimeMT.address;
    }

    console.log(`ERC1155Sale.new(${networkConfig.showtimeMTAddress}, ${networkConfig.initialCurrencies})`);
    const sale = await ERC1155Sale.new(networkConfig.showtimeMTAddress, networkConfig.initialCurrencies, {
        overwrite: false,
    });

    console.log({
        ShowtimeMT: networkConfig.showtimeMTAddress,
        ERC1155Sale: sale.address,
    });

    if (network !== "development") {
        await networkConfig.initialCurrencies.forEach((currencyAddress) => {
            console.log(`sale.setAcceptedCurrency(${currencyAddress})`);
            sale.setAcceptedCurrency(currencyAddress);
        });

        console.log(`sale.setTrustedForwarder(${networkConfig.trustedForwarderAddress})`);
        await sale.setTrustedForwarder(networkConfig.trustedForwarderAddress);

        if (networkConfig.ownerAddress === null) {
            console.log("no owner address defined, skipping ownership transfer");
        } else {
            console.log(`sale.transferOwnership(${networkConfig.ownerAddress})`);
            await sale.transferOwnership(networkConfig.ownerAddress);
        }

        console.log("Verifying on polygonscan.com:");
        console.log(`npx truffle run verify ERC1155Sale@${sale.address} --network ${network}`);
        await verify("ERC1155Sale", sale.address, network);
    }
};

function verify(name, address, network) {
    return new Promise((resolve, reject) => {
        exec(`npx truffle run verify ${name}@${address} --network ${network}`, (code, stdout, stderr) => {
            if (code !== 0) reject(stderr);
            resolve(stdout);
        });
    });
}
