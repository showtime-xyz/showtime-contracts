/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import { Provider } from "@ethersproject/providers";
import type {
  IShowtimeV1Market,
  IShowtimeV1MarketInterface,
} from "../IShowtimeV1Market";

const _abi = [
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_listingId",
        type: "uint256",
      },
    ],
    name: "cancelSale",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_tokenId",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_quantity",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_price",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "_currency",
        type: "address",
      },
    ],
    name: "createSale",
    outputs: [
      {
        internalType: "uint256",
        name: "listingId",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
];

export class IShowtimeV1Market__factory {
  static readonly abi = _abi;
  static createInterface(): IShowtimeV1MarketInterface {
    return new utils.Interface(_abi) as IShowtimeV1MarketInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): IShowtimeV1Market {
    return new Contract(address, _abi, signerOrProvider) as IShowtimeV1Market;
  }
}