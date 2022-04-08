/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import { Provider } from "@ethersproject/providers";
import type {
  IEditionSingleMintable,
  IEditionSingleMintableInterface,
} from "../IEditionSingleMintable";

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
    ],
    name: "mintEdition",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address[]",
        name: "to",
        type: "address[]",
      },
    ],
    name: "mintEditions",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "numberCanMint",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "owner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
];

export class IEditionSingleMintable__factory {
  static readonly abi = _abi;
  static createInterface(): IEditionSingleMintableInterface {
    return new utils.Interface(_abi) as IEditionSingleMintableInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): IEditionSingleMintable {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as IEditionSingleMintable;
  }
}
