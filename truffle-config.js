const HDWalletProvider = require("@truffle/hdwallet-provider")
require("dotenv").config()

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
                    privateKeys: [process.env.PRIVATE_KEY],
                    providerOrUrl: "https://rpc-mumbai.maticvigil.com/",
                }),
            network_id: 80001,
            confirmations: 1,
            timeoutBlocks: 200,
            skipDryRun: true,
        },
        matic_mainnet: {
            provider: () =>
                new HDWalletProvider({
                    privateKeys: [process.env.PRIVATE_KEY],
                    providerOrUrl: `https://rpc-mainnet.maticvigil.com/v1/${process.env.MATIC_VIGIL_APP_ID}`,
                    addressIndex: 0,
                }),
            network_id: "137",
        },
        rinkeby: {
            provider: () =>
                new HDWalletProvider({
                    privateKeys: [process.env.PRIVATE_KEY],
                    providerOrUrl: `https://rinkeby.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
                }),
            network_id: "4",
        },
    },
    solc: {
        optimizer: {
            enabled: true,
            runs: 200,
        },
    },
    compilers: {
        solc: {
            version: "0.6.12",
        },
    },
    // plugins: ["truffle-plugin-verify"],
    // api_keys: {
    //     polygonscan: process.env.POLYGONSCAN_API_KEY,
    // },
}
