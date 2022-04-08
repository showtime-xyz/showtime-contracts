/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import type {
  ShowtimeMTReceiver,
  ShowtimeMTReceiverInterface,
} from "../ShowtimeMTReceiver";

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "_showtimeMT",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_nftContract",
        type: "address",
      },
      {
        internalType: "uint256[]",
        name: "ids",
        type: "uint256[]",
      },
    ],
    name: "UnexpectedERC1155BatchTransfer",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_nftContract",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
    ],
    name: "UnexpectedERC1155Transfer",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "uint256[]",
        name: "ids",
        type: "uint256[]",
      },
      {
        internalType: "uint256[]",
        name: "",
        type: "uint256[]",
      },
      {
        internalType: "bytes",
        name: "",
        type: "bytes",
      },
    ],
    name: "onERC1155BatchReceived",
    outputs: [
      {
        internalType: "bytes4",
        name: "",
        type: "bytes4",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
      {
        internalType: "bytes",
        name: "",
        type: "bytes",
      },
    ],
    name: "onERC1155Received",
    outputs: [
      {
        internalType: "bytes4",
        name: "",
        type: "bytes4",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "showtimeMT",
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
  {
    inputs: [
      {
        internalType: "bytes4",
        name: "interfaceId",
        type: "bytes4",
      },
    ],
    name: "supportsInterface",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
];

const _bytecode =
  "0x60a060405234801561001057600080fd5b5060405161052338038061052383398101604081905261002f91610044565b60601b6001600160601b031916608052610074565b60006020828403121561005657600080fd5b81516001600160a01b038116811461006d57600080fd5b9392505050565b60805160601c61048461009f6000396000818160bd0152818161013b01526101aa01526104846000f3fe608060405234801561001057600080fd5b506004361061004c5760003560e01c806301ffc9a714610051578063bc197c8114610079578063f23a6e61146100a5578063f40dc537146100b8575b600080fd5b61006461005f3660046103e1565b6100f7565b60405190151581526020015b60405180910390f35b61008c6100873660046102ae565b61012e565b6040516001600160e01b03199091168152602001610070565b61008c6100b3366004610369565b61019d565b6100df7f000000000000000000000000000000000000000000000000000000000000000081565b6040516001600160a01b039091168152602001610070565b60006001600160e01b03198216630271189760e51b148061012857506301ffc9a760e01b6001600160e01b03198316145b92915050565b6000336001600160a01b037f000000000000000000000000000000000000000000000000000000000000000016146101885733878760405163ca6b346b60e01b815260040161017f93929190610412565b60405180910390fd5b5063bc197c8160e01b98975050505050505050565b6000336001600160a01b037f000000000000000000000000000000000000000000000000000000000000000016146101f15760405163448a84cd60e11b81523360048201526024810186905260440161017f565b5063f23a6e6160e01b9695505050505050565b80356001600160a01b038116811461021b57600080fd5b919050565b60008083601f84011261023257600080fd5b50813567ffffffffffffffff81111561024a57600080fd5b6020830191508360208260051b850101111561026557600080fd5b9250929050565b60008083601f84011261027e57600080fd5b50813567ffffffffffffffff81111561029657600080fd5b60208301915083602082850101111561026557600080fd5b60008060008060008060008060a0898b0312156102ca57600080fd5b6102d389610204565b97506102e160208a01610204565b9650604089013567ffffffffffffffff808211156102fe57600080fd5b61030a8c838d01610220565b909850965060608b013591508082111561032357600080fd5b61032f8c838d01610220565b909650945060808b013591508082111561034857600080fd5b506103558b828c0161026c565b999c989b5096995094979396929594505050565b60008060008060008060a0878903121561038257600080fd5b61038b87610204565b955061039960208801610204565b94506040870135935060608701359250608087013567ffffffffffffffff8111156103c357600080fd5b6103cf89828a0161026c565b979a9699509497509295939492505050565b6000602082840312156103f357600080fd5b81356001600160e01b03198116811461040b57600080fd5b9392505050565b6001600160a01b03841681526040602082015281604082015260007f07ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff83111561045a57600080fd5b8260051b808560608501376000920160600191825250939250505056fea164736f6c6343000807000a";

type ShowtimeMTReceiverConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: ShowtimeMTReceiverConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class ShowtimeMTReceiver__factory extends ContractFactory {
  constructor(...args: ShowtimeMTReceiverConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
    this.contractName = "ShowtimeMTReceiver";
  }

  deploy(
    _showtimeMT: string,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ShowtimeMTReceiver> {
    return super.deploy(
      _showtimeMT,
      overrides || {}
    ) as Promise<ShowtimeMTReceiver>;
  }
  getDeployTransaction(
    _showtimeMT: string,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(_showtimeMT, overrides || {});
  }
  attach(address: string): ShowtimeMTReceiver {
    return super.attach(address) as ShowtimeMTReceiver;
  }
  connect(signer: Signer): ShowtimeMTReceiver__factory {
    return super.connect(signer) as ShowtimeMTReceiver__factory;
  }
  static readonly contractName: "ShowtimeMTReceiver";
  public readonly contractName: "ShowtimeMTReceiver";
  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): ShowtimeMTReceiverInterface {
    return new utils.Interface(_abi) as ShowtimeMTReceiverInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): ShowtimeMTReceiver {
    return new Contract(address, _abi, signerOrProvider) as ShowtimeMTReceiver;
  }
}
