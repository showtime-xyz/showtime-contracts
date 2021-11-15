# Showtime Contracts

<img alt="Solidity" src="https://img.shields.io/badge/Solidity-e6e6e6?style=for-the-badge&logo=solidity&logoColor=black"/> <img alt="Javascript" src="https://img.shields.io/badge/JavaScript-323330?style=for-the-badge&logo=javascript&logoColor=F7DF1E"/>

This repository contains the Solidity Smart Contracts for the Showtime NFT Marketplace.

## Prerequisites

-   git
-   npm
-   truffle
-   Ganache (optional)

## Getting started

-   Clone the repository

```sh
git clone https://github.com/nonceblox/showtime-contracts
```

-   Navigate to `showtime-contracts` directory

```sh
cd showtime-contracts
```

-   Install dependencies

```sh
npm install
```

### Configure project

-   Copy `.example.env` to `.env`

```sh
cp .example.env .env
```

-   Add the matic vigil app ID & deployer private key to the `.env`

## Run tests

-   Start ganache
-   Run Tests

```sh
npm test
```

-   Run a single test file

```sh
npm test test/ERC1155Sale.test.js
```

-   Run a single test:

```js
it.only("does a thing", ...);
```

## Deploy smart contracts

### on Ganache

```sh
npm run deploy:ganache
```

### on Mumbai Testnet

```sh
npm run deploy:mumbai_testnet
```

### on Polygon Mainnet

```sh
npm run deploy:polygon_mainnet
```

## Existing Deployments

### Mumbai

| Contract    | Commit  | Address                                    | Comment                          |
| ----------- | ------- | ------------------------------------------ | -------------------------------- |
| ShowtimeMT  | 0e4e654 | 0x09F3a26302e1c45f0d78Be5D592f52b6fca43811 |                                  |
| ERC1155Sale | 0af4eae | 0x3225125E0a853ac1326d0d589e7a4dec10bd6479 | after 1st market-improvements PR |

### Polygon Mainnet

| Contract   | Commit  | Address                                    | Comment         |
| ---------- | ------- | ------------------------------------------ | --------------- |
| ShowtimeMT | 0e4e654 | 0x8A13628dD5D600Ca1E8bF9DBc685B735f615Cb90 | Live in the app |

## Troubleshooting

Getting this failure when deploying:

```
Error: error:0308010C:digital envelope routines::unsupported
    at new Hash (node:internal/crypto/hash:67:19)
    at Object.createHash (node:crypto:130:10)
```

Seems to be an issue in node v17, workaround suggested in https://github.com/Snapmaker/Luban/issues/1250 is

    export NODE_OPTIONS=--openssl-legacy-provider

### Running a single migration file

Edit the command in `package.json`, for instance to run only the `2_deploy_mt.js` migration:

    truffle migrate -f 2 --to 2
