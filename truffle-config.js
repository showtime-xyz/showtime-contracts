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
                    // privateKeys: [process.env.PRIVATE_KEY],
                    mnemonic: process.env.MNEMONIC,
                    providerOrUrl: `https://polygon-mumbai.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
                    // addressIndex: 0,
                }),
            network_id: 80001,
            confirmations: 1,
            timeoutBlocks: 200,
            skipDryRun: false,
            from: "0x74Eb6F5384c91989B231e714334067591DAaE300",
        },
        matic_mainnet: {
            provider: () =>
                new HDWalletProvider({
                    // privateKeys: [process.env.PRIVATE_KEY],
                    mnemonic: process.env.MNEMONIC,
                    providerOrUrl: `https://polygon-mainnet.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
                    addressIndex: 0,
                }),
            network_id: "137",
            from: "0xCC6440b74a95b5506B096A79c9D7Bd070E54E9Eb",
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
