/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import type {
  SharedNFTLogic,
  SharedNFTLogicInterface,
} from "../SharedNFTLogic";

const _abi = [
  {
    inputs: [
      {
        internalType: "bytes",
        name: "unencoded",
        type: "bytes",
      },
    ],
    name: "base64Encode",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "name",
        type: "string",
      },
      {
        internalType: "string",
        name: "description",
        type: "string",
      },
      {
        internalType: "string",
        name: "imageUrl",
        type: "string",
      },
      {
        internalType: "string",
        name: "animationUrl",
        type: "string",
      },
      {
        internalType: "uint256",
        name: "tokenOfEdition",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "editionSize",
        type: "uint256",
      },
    ],
    name: "createMetadataEdition",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "name",
        type: "string",
      },
      {
        internalType: "string",
        name: "description",
        type: "string",
      },
      {
        internalType: "string",
        name: "mediaData",
        type: "string",
      },
      {
        internalType: "uint256",
        name: "tokenOfEdition",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "editionSize",
        type: "uint256",
      },
    ],
    name: "createMetadataJSON",
    outputs: [
      {
        internalType: "bytes",
        name: "",
        type: "bytes",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes",
        name: "json",
        type: "bytes",
      },
    ],
    name: "encodeMetadataJSON",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "numberToString",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "imageUrl",
        type: "string",
      },
      {
        internalType: "string",
        name: "animationUrl",
        type: "string",
      },
      {
        internalType: "uint256",
        name: "tokenOfEdition",
        type: "uint256",
      },
    ],
    name: "tokenMediaData",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
];

const _bytecode =
  "0x608060405234801561001057600080fd5b50610d25806100206000396000f3fe608060405234801561001057600080fd5b50600436106100725760003560e01c8063d5fb1b1911610050578063d5fb1b19146100c6578063df30dba0146100d9578063eb111ab6146100ec57600080fd5b8063170dc6601461007757806358464f30146100a0578063d01fde8c146100b3575b600080fd5b61008a6100853660046107e2565b6100ff565b6040516100979190610bac565b60405180910390f35b61008a6100ae3660046106db565b610110565b61008a6100c13660046105d3565b61018c565b61008a6100d43660046105d3565b6101bd565b61008a6100e736600461061c565b6101c8565b61008a6100fa366004610775565b610200565b606061010a826102b9565b92915050565b606080821561014457610122836100ff565b6040516020016101329190610b0a565b60405160208183030381529060405290505b8661014e856100ff565b82888861015a896100ff565b8c604051602001610171979695949392919061096a565b60405160208183030381529060405291505095945050505050565b6060610197826101bd565b6040516020016101a79190610ac5565b6040516020818303038152906040529050919050565b606061010a826103d7565b606060006101d7868686610200565b905060006101e88989848888610110565b90506101f38161018c565b9998505050505050505050565b825182516060911580159115159082906102175750805b1561025b5785610226856100ff565b86610230876100ff565b60405160200161024394939291906108a8565b604051602081830303815290604052925050506102b2565b811561027c578561026b856100ff565b604051602001610243929190610843565b801561029d578461028c856100ff565b604051602001610243929190610b33565b60405180602001604052806000815250925050505b9392505050565b6060816102dd5750506040805180820190915260018152600360fc1b602082015290565b8160005b811561030757806102f181610c51565b91506103009050600a83610bd7565b91506102e1565b60008167ffffffffffffffff81111561032257610322610cc2565b6040519080825280601f01601f19166020018201604052801561034c576020820181803683370190505b5090505b84156103cf57610361600183610c0a565b915061036e600a86610c6c565b610379906030610bbf565b60f81b81838151811061038e5761038e610cac565b60200101907effffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916908160001a9053506103c8600a86610bd7565b9450610350565b949350505050565b60608151600014156103f757505060408051602081019091526000815290565b6000604051806060016040528060408152602001610cd960409139905060006003845160026104269190610bbf565b6104309190610bd7565b61043b906004610beb565b9050600061044a826020610bbf565b67ffffffffffffffff81111561046257610462610cc2565b6040519080825280601f01601f19166020018201604052801561048c576020820181803683370190505b509050818152600183018586518101602084015b818310156104f8576003830192508251603f8160121c168501518253600182019150603f81600c1c168501518253600182019150603f8160061c168501518253600182019150603f81168501518253506001016104a0565b60038951066001811461051257600281146105235761052f565b613d3d60f01b60011983015261052f565b603d60f81b6000198301525b509398975050505050505050565b600067ffffffffffffffff8084111561055857610558610cc2565b604051601f8501601f19908116603f0116810190828211818310171561058057610580610cc2565b8160405280935085815286868601111561059957600080fd5b858560208301376000602087830101525050509392505050565b600082601f8301126105c457600080fd5b6102b28383356020850161053d565b6000602082840312156105e557600080fd5b813567ffffffffffffffff8111156105fc57600080fd5b8201601f8101841361060d57600080fd5b6103cf8482356020840161053d565b60008060008060008060c0878903121561063557600080fd5b863567ffffffffffffffff8082111561064d57600080fd5b6106598a838b016105b3565b9750602089013591508082111561066f57600080fd5b61067b8a838b016105b3565b9650604089013591508082111561069157600080fd5b61069d8a838b016105b3565b955060608901359150808211156106b357600080fd5b506106c089828a016105b3565b9350506080870135915060a087013590509295509295509295565b600080600080600060a086880312156106f357600080fd5b853567ffffffffffffffff8082111561070b57600080fd5b61071789838a016105b3565b9650602088013591508082111561072d57600080fd5b61073989838a016105b3565b9550604088013591508082111561074f57600080fd5b5061075c888289016105b3565b9598949750949560608101359550608001359392505050565b60008060006060848603121561078a57600080fd5b833567ffffffffffffffff808211156107a257600080fd5b6107ae878388016105b3565b945060208601359150808211156107c457600080fd5b506107d1868287016105b3565b925050604084013590509250925092565b6000602082840312156107f457600080fd5b5035919050565b60008151808452610813816020860160208601610c21565b601f01601f19169290920160200192915050565b60008151610839818560208601610c21565b9290920192915050565b6834b6b0b3b2911d101160b91b815260008351610867816009850160208801610c21565b633f69643d60e01b600991840191820152835161088b81600d840160208801610c21565b631116101160e11b600d9290910191820152601101949350505050565b6834b6b0b3b2911d101160b91b8152600085516108cc816009850160208a01610c21565b8083019050633f69643d60e01b80600983015286516108f281600d850160208b01610c21565b7f222c2022616e696d6174696f6e5f75726c223a20220000000000000000000000600d93909101928301528551610930816022850160208a01610c21565b6022920191820152835161094b816026840160208801610c21565b631116101160e11b60269290910191820152602a019695505050505050565b7f7b226e616d65223a2022000000000000000000000000000000000000000000008152600088516109a281600a850160208d01610c21565b600160fd1b600a9184019182015288516109c381600b840160208d01610c21565b88519101906109d981600b840160208c01610c21565b631116101160e11b600b929091019182018190527f6465736372697074696f6e223a20220000000000000000000000000000000000600f8301528751610a2681601e850160208c01610c21565b601e920191820152610ab7610aa8610aa2610a79610a73610a4a602287018c610827565b7f70726f70657274696573223a207b226e756d626572223a200000000000000000815260180190565b89610827565b7f2c20226e616d65223a20220000000000000000000000000000000000000000008152600b0190565b86610827565b62227d7d60e81b815260030190565b9a9950505050505050505050565b7f646174613a6170706c69636174696f6e2f6a736f6e3b6261736536342c000000815260008251610afd81601d850160208701610c21565b91909101601d0192915050565b602f60f81b815260008251610b26816001850160208701610c21565b9190910160010192915050565b7f616e696d6174696f6e5f75726c223a2022000000000000000000000000000000815260008351610b6b816011850160208801610c21565b633f69643d60e01b6011918401918201528351610b8f816015840160208801610c21565b631116101160e11b60159290910191820152601901949350505050565b6020815260006102b260208301846107fb565b60008219821115610bd257610bd2610c80565b500190565b600082610be657610be6610c96565b500490565b6000816000190483118215151615610c0557610c05610c80565b500290565b600082821015610c1c57610c1c610c80565b500390565b60005b83811015610c3c578181015183820152602001610c24565b83811115610c4b576000848401525b50505050565b6000600019821415610c6557610c65610c80565b5060010190565b600082610c7b57610c7b610c96565b500690565b634e487b7160e01b600052601160045260246000fd5b634e487b7160e01b600052601260045260246000fd5b634e487b7160e01b600052603260045260246000fd5b634e487b7160e01b600052604160045260246000fdfe4142434445464748494a4b4c4d4e4f505152535455565758595a6162636465666768696a6b6c6d6e6f707172737475767778797a303132333435363738392b2fa164736f6c6343000807000a";

type SharedNFTLogicConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: SharedNFTLogicConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class SharedNFTLogic__factory extends ContractFactory {
  constructor(...args: SharedNFTLogicConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
    this.contractName = "SharedNFTLogic";
  }

  deploy(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<SharedNFTLogic> {
    return super.deploy(overrides || {}) as Promise<SharedNFTLogic>;
  }
  getDeployTransaction(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  attach(address: string): SharedNFTLogic {
    return super.attach(address) as SharedNFTLogic;
  }
  connect(signer: Signer): SharedNFTLogic__factory {
    return super.connect(signer) as SharedNFTLogic__factory;
  }
  static readonly contractName: "SharedNFTLogic";
  public readonly contractName: "SharedNFTLogic";
  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): SharedNFTLogicInterface {
    return new utils.Interface(_abi) as SharedNFTLogicInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): SharedNFTLogic {
    return new Contract(address, _abi, signerOrProvider) as SharedNFTLogic;
  }
}