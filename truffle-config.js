const HDWalletProvider = require("@truffle/hdwallet-provider");
require("dotenv").config();

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*" // Match any network id
    },
    test: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*" // Match any network id
    },
    mumbai_testnet: {
      provider: () =>
        new HDWalletProvider({
          privateKeys: [process.env.PRIVATE_KEY],
          providerOrUrl: `https://rpc-mumbai.maticvigil.com`,
          addressIndex: 0
        }),
      network_id: "80001",
    },
    matic_mainnet: {
      provider: () =>
        new HDWalletProvider({
          privateKeys: [process.env.PRIVATE_KEY],
          providerOrUrl: `https://rpc-mainnet.maticvigil.com/v1/${process.env.MATIC_VIGIL_APP_ID}`,
          addressIndex: 0
        }),
      network_id: "137",
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  },
  compilers: {
    solc: {
      version: "0.6.12"
    }
  }
}