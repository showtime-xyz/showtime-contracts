const HDWalletProvider = require("@truffle/hdwallet-provider");
require("dotenv").config();

module.exports = {
    networks: {
        development: {
            host: "127.0.0.1", // Localhost (default: none)
            port: 8545, // Standard Ethereum port (default: none)
            network_id: "*",
        },
        mumbai_testnet: {
            provider: () =>
                new HDWalletProvider({
                    mnemonic: process.env.MNEMONIC,
                    providerOrUrl: `https://polygon-mumbai.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
                }),
            network_id: 80001,
            confirmations: 1,
            timeoutBlocks: 200,
            skipDryRun: false,
            from: process.env.ETH_FROM,
        },
        matic_mainnet: {
            provider: () =>
                new HDWalletProvider({
                    mnemonic: process.env.MNEMONIC,
                    providerOrUrl: `https://polygon-mainnet.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
                    addressIndex: 0,
                }),
            network_id: "137",
            from: process.env.ETH_FROM,
        },
    },
    solc: {
        optimizer: {
            enabled: true,
            runs: 1000000,
        },
    },
    compilers: {
        solc: {
            version: "0.8.7",
        },
    },
    plugins: ["truffle-plugin-verify"],
    api_keys: {
        polygonscan: process.env.EXPLORER_API_KEY || "",
    },
};
