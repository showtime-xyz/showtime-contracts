# Showtime Contracts
<img alt="Solidity" src="https://img.shields.io/badge/Solidity-e6e6e6?style=for-the-badge&logo=solidity&logoColor=black"/> <img alt="Javascript" src="https://img.shields.io/badge/JavaScript-323330?style=for-the-badge&logo=javascript&logoColor=F7DF1E"/>

This repository contains the Solidity Smart Contracts for the Showtime NFT Marketplace.

## Prerequisites
- git
- npm
- truffle
- Ganache (optional)

## Getting started
- Clone the repository
```sh
git clone https://github.com/nonceblox/showtime-contracts
```
- Navigate to `showtime-contracts` directory
```sh
cd showtime-contracts
```
- Install dependencies
```sh
npm install
```

### Configure project
- Copy `.example.env` to `.env`
```sh
cp .example.env .env
```
- Add the infura project id & deployer private key to the `.env`

## Run tests
- Start ganache
- Run Tests
```sh
npm test
```

## Deploy smart contracts

### on Ganche
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
