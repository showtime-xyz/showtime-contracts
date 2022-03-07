// from https://github.com/paulrberg/solidity-template/blob/main/hardhat.config.ts @ 2186ed4

import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "hardhat-deploy";

import "./tasks/accounts";
import "./tasks/deploy";

import { resolve } from "path";

import { config as dotenvConfig } from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import { NetworkUserConfig } from "hardhat/types";

dotenvConfig({ path: resolve(__dirname, "./.env") });

// Ensure that we have all the environment variables we need.
const mnemonic: string | undefined = process.env.MNEMONIC;
if (!mnemonic) {
  throw new Error("Please set your MNEMONIC in a .env file");
}

const infuraApiKey: string | undefined = process.env.INFURA_API_KEY;
if (!infuraApiKey) {
  throw new Error("Please set your INFURA_API_KEY in a .env file");
}

const polygonScanApiKey: string | undefined = process.env.POLYGONSCAN_API_KEY;
if (!polygonScanApiKey) {
  console.warn("WARN: Please set your POLYGONSCAN_API_KEY in a .env file")
} else {
  console.log("Using PolygonScan API key:", polygonScanApiKey);
}

const chainIds = {
  arbitrumOne: 42161,
  avalanche: 43114,
  bsc: 56,
  goerli: 5,
  hardhat: 31337,
  kovan: 42,
  mainnet: 1,
  optimism: 10,
  polygon: 137,
  mumbai: 80001,
  rinkeby: 4,
  ropsten: 3,
};

function getChainConfig(network: keyof typeof chainIds): NetworkUserConfig {
  const infuraMapping: {[key: string]: any} = {
    polygon: "polygon-mainnet",
    mumbai: "polygon-mumbai",
  };
  const infuraSubdomain: string = infuraMapping[network] || network;
  const url: string = "https://" + infuraSubdomain + ".infura.io/v3/" + infuraApiKey;
  return {
    accounts: {
      count: 10,
      mnemonic,
      path: "m/44'/60'/0'/0",
    },
    chainId: chainIds[network],
    url,
  };
}

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  etherscan: {
    // apiKey: {
    //   arbitrumOne: process.env.ARBSCAN_API_KEY,
    //   avalanche: process.env.SNOWTRACE_API_KEY,
    //   bsc: process.env.BSCSCAN_API_KEY,
    //   goerli: process.env.ETHERSCAN_API_KEY,
    //   kovan: process.env.ETHERSCAN_API_KEY,
    //   mainnet: process.env.ETHERSCAN_API_KEY,
    //   optimisticEthereum: process.env.OPTIMISM_API_KEY,
    //   polygon: polygonScanApiKey,
    //   polygonMumbai: polygonScanApiKey,
    //   rinkeby: process.env.ETHERSCAN_API_KEY,
    //   ropsten: process.env.ETHERSCAN_API_KEY,
    // },
    apiKey: polygonScanApiKey
  },
  gasReporter: {
    currency: "USD",
    enabled: process.env.REPORT_GAS ? true : false,
    excludeContracts: [],
    src: "./src",
  },
  networks: {
    hardhat: {
      accounts: {
        mnemonic,
      },
      chainId: chainIds.hardhat,
    },
    arbitrumOne: getChainConfig("arbitrumOne"),
    avalanche: getChainConfig("avalanche"),
    bsc: getChainConfig("bsc"),
    goerli: getChainConfig("goerli"),
    kovan: getChainConfig("kovan"),
    mainnet: getChainConfig("mainnet"),
    optimism: getChainConfig("optimism"),
    polygon: getChainConfig("polygon"),
    mumbai: getChainConfig("mumbai"),
    rinkeby: getChainConfig("rinkeby"),
    ropsten: getChainConfig("ropsten"),
  },
  paths: {
    artifacts: "./out",
    cache: "./cache",
    sources: "./src",
    tests: "./test",
  },
  solidity: {
    version: "0.8.7",
    settings: {
      metadata: {
        // Not including the metadata hash
        // https://github.com/paulrberg/solidity-template/issues/31
        bytecodeHash: "none",
      },
      // Disable the optimizer when debugging
      // https://hardhat.org/hardhat-network/#solidity-optimizer-support
      optimizer: {
        enabled: true,
        runs: 800,
      },
    },
  },
  typechain: {
    outDir: "src/types",
    target: "ethers-v5",
  },
  namedAccounts: {
    deployer: {
      "mumbai": process.env.ETH_FROM_MUMBAI || "0x0000000000000000000000000000000000000000",
      "polygon": process.env.ETH_FROM_POLYGON || "0x0000000000000000000000000000000000000000",
    },
    ukraineDAO:{
        default: "0x633b7218644b83D57d90e7299039ebAb19698e9C"
    }
}
};

export default config;