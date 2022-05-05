# Showtime Contracts

This repository contains the Solidity Smart Contracts for the Showtime NFT and its Marketplace.

[![Foundry tests](https://github.com/showtime-xyz/smart-contracts-private/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/showtime-xyz/smart-contracts-private/actions/workflows/ci.yml)

## Design

### ShowtimeMT.sol

`ShowtimeMT` is the NFT contract used on the Showtime platform, it is an ERC1155 that implements ERC2981 royalties.

It uses [BiconomyForwarder](https://docs.biconomy.io/misc/contract-addresses) (`0x86C80a8aa58e0A4fa09A69624c31Ab2a6CAD56b8`) as the trusted forwarder for EIP-2771 meta-transactions. Meta-transactions enable gas-less transactions (from the end user's point of view):

-   a user wants to create an NFT
-   the app can prompt users to sign a message with the appropriate parameters
-   this message is sent to the Biconomy API
-   the `BiconomyForwarder` contract then interacts with `ShowtimeMT` on behalf of the end user
-   `ShowtimeMT` calls `BaseRelayRecipient._msgSender()` to get the address of the end user, `msg.sender` would return the address of the `BiconomyForwarder`

### ShowtimeV1Market.sol

`ShowtimeV1Market` is the marketplace for Showtime NFTs.

Users can either interact with the contract directly or through meta-transactions using the `BiconomyForwarder` method described above.

Users can:

-   list a given amount of a token id for sale for a specific number of ERC20 tokens
-   cancel a listing
-   complete a sale (swap ERC20 tokens for the NFT listed for sale). If royalties are enabled, the corresponding portion of the ERC20 payment is transferred to the royalties recipient. Currently, we would expect this to be the creator of the NFT on Showtime.

Note: sales can be partial, e.g. if N tokens are for sale in a particular listing, the buyer can purchase M tokens where `M <= N`. The listing is then updated to reflect that there are now only `N - M` tokens left for sale.

The owner can:

-   pause the contract, which effectively prevents the completion of sales
-   add or remove ERC20 contract addresses that can be used to buy and sell NFTs
-   turn royalty payments on and off

Some limitations:

-   it is hardcoded to only support a single `ShowtimeMT` contract
-   it only supports transactions in a configurable list of ERC20 tokens, no native currency
-   it only supports buying and selling at a fixed price, no auctions
-   listings don't have an expiration date
-   the owner has no control over NFTs or any other balance owned by the `ShowtimeV1Market` contract


## Getting started

-   Clone the repository

-   Install dependencies

```sh
yarn install
```

### Configure project

-   Copy `.example.env` to `.env`

```sh
cp .example.env .env
```

-   Configure the appropriate values in `.env`

## Compile

```
forge build
```

## Run tests

```sh
forge test
```

-   Run a single test file

```sh
forge test --match-contract ShowtimeV1MarketTest
```

-   Run a single test:

```sh
forge test --match-test testCannotBuyWhenPaused
```

## Deploy smart contracts with hardhat

### on hardhat local network

```sh
npx hardhat deploy
```

### on Mumbai Testnet

```sh
npx hardhat deploy --network mumbai
```

### on Polygon Mainnet

```sh
npx hardhat deploy --network polygon
```

### Choosing the deployment address

In `hardhat.config.ts`, see `namedAccounts.deployer`

Docs for named accounts: https://github.com/wighawag/hardhat-deploy#1-namedaccounts-ability-to-name-addresses

### Verify a deployed contract

```sh
# will attempt to verify all the contracts tracked under deployments/<network>
npx hardhat --network mumbai etherscan-verify
```

## Existing Deployments

### Mumbai

| Contract                      | Commit        | Address                                           | Comment                           |
| ----------------              | -------       | ------------------------------------------        | --------------------------------  |
| **ShowtimeMT**                | **0e4e654**   | **0x09F3a26302e1c45f0d78Be5D592f52b6fca43811**    |                                   |
| ShowtimeV1Market              | 0af4eae       | 0x3225125E0a853ac1326d0d589e7a4dec10bd6479        | after 1st market-improvements PR  |
| ShowtimeV1Market              | e35192f       | 0x05D400564b7d65F1F89ec6deC55752f58EfA9F5E        | non-escrow version                |
| **ShowtimeV1Market**          | **e3027cd**   | **0xB38a0Ed9d60CEa911E43DBbEC205cd3ddE0C51B6**    | **crowdsourced feedback**         |
| ShowtimeSplitterSeller        | 2ddb539       | 0x21494B31025259bBc3B61aB41478005b4505e05D        | v1 test                           |
| ShowtimeSplitterSeller        | 142fa9c       | **0xB38a0Ed9d60CEa911E43DBbEC205cd3ddE0C51B6**    | v2 test, after cleanup            |
| ShowtimeForwarder             | 3aa1bf9e      | **0x50c001c88b59dc3b833E0F062EfC2271CE88Cb89**    |                                   |

### Polygon Mainnet

| Contract                      | Commit        | Address                                           | Comment                           |
| ----------------              | -------       | ------------------------------------------        | --------------------------------  |
| **ShowtimeMT**                | **0e4e654**   | **0x8A13628dD5D600Ca1E8bF9DBc685B735f615Cb90**    | **Live in the app**               |
| ShowtimeV1Market              | e35192f       | 0x05D400564b7d65F1F89ec6deC55752f58EfA9F5E        | non-escrow version                |
| **ShowtimeV1Market**          | **bee01b1**   | **0x022F3C027572FE1b321ba7a7844ab77aC4193650**    | **live in the app**               |
| ShowtimeBakeSale              | 3a41e76       | **0x3a99ea152Dd2eAcc8E95aDdFb943e714Db9ECC22**    | showtime.io/ukraine               |


## Showtime Forwarder

Has the default request type registered:

```
ForwardRequest(
    address from,
    address to,
    uint256 value,
    uint256 gas,
    uint256 nonce,
    bytes data,
    uint256 validUntilTime)
```

Registered domain:
- name: showtime.io
- version: 1
- domain hash on mumbai: `0x5e5b00964aa6fad690fa48928347690e3f9a4ce056e98a45c10dd839e9aa77e7`

## Troubleshooting

Getting this failure when deploying:

```
Error: error:0308010C:digital envelope routines::unsupported
    at new Hash (node:internal/crypto/hash:67:19)
    at Object.createHash (node:crypto:130:10)
```

Seems to be an issue in node v17, workaround suggested in https://github.com/Snapmaker/Luban/issues/1250 is

    export NODE_OPTIONS=--openssl-legacy-provider

