/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import type {
  ShowtimeForwarderTest,
  ShowtimeForwarderTestInterface,
} from "../ShowtimeForwarderTest";

const _abi = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    name: "log",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "log_address",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "bytes",
        name: "",
        type: "bytes",
      },
    ],
    name: "log_bytes",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    name: "log_bytes32",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "int256",
        name: "",
        type: "int256",
      },
    ],
    name: "log_int",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "key",
        type: "string",
      },
      {
        indexed: false,
        internalType: "address",
        name: "val",
        type: "address",
      },
    ],
    name: "log_named_address",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "key",
        type: "string",
      },
      {
        indexed: false,
        internalType: "bytes",
        name: "val",
        type: "bytes",
      },
    ],
    name: "log_named_bytes",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "key",
        type: "string",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "val",
        type: "bytes32",
      },
    ],
    name: "log_named_bytes32",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "key",
        type: "string",
      },
      {
        indexed: false,
        internalType: "int256",
        name: "val",
        type: "int256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "decimals",
        type: "uint256",
      },
    ],
    name: "log_named_decimal_int",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "key",
        type: "string",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "val",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "decimals",
        type: "uint256",
      },
    ],
    name: "log_named_decimal_uint",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "key",
        type: "string",
      },
      {
        indexed: false,
        internalType: "int256",
        name: "val",
        type: "int256",
      },
    ],
    name: "log_named_int",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "key",
        type: "string",
      },
      {
        indexed: false,
        internalType: "string",
        name: "val",
        type: "string",
      },
    ],
    name: "log_named_string",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "key",
        type: "string",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "val",
        type: "uint256",
      },
    ],
    name: "log_named_uint",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    name: "log_string",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "log_uint",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "bytes",
        name: "",
        type: "bytes",
      },
    ],
    name: "logs",
    type: "event",
  },
  {
    inputs: [],
    name: "IS_TEST",
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
  {
    inputs: [],
    name: "failed",
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
  {
    inputs: [],
    name: "setUp",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "testForward",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const _bytecode =
  "0x608060408190526000805460ff1916600117905561001c906100d3565b604051809103906000f080158015610038573d6000803e3d6000fd5b506000805462010000600160b01b031916620100006001600160a01b0393841681029190911791829055604051910490911690610074906100e0565b6001600160a01b039091168152602001604051809103906000f0801580156100a0573d6000803e3d6000fd5b50600180546001600160a01b0319166001600160a01b03929092169190911790553480156100cd57600080fd5b506100ed565b6116328061082883390190565b61087080611e5a83390190565b61072c806100fc6000396000f3fe608060405234801561001057600080fd5b506004361061004c5760003560e01c80630a9254e414610051578063167a5b9714610053578063ba414fa61461005b578063fa7626d414610081575b600080fd5b005b61005161008e565b60005461006d90610100900460ff1681565b604051901515815260200160405180910390f35b60005461006d9060ff1681565b60008054604051632d0335ab60e01b815273de5e327ce4e7c1b64a757aab8f2e699585977a346004820152620100009091046001600160a01b031690632d0335ab9060240160206040518083038186803b1580156100eb57600080fd5b505afa1580156100ff573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061012391906105a9565b90507f41304facd9323d75b11bcdd609cb38effffdb05710f7caf0e9b16c6d9d709f506040516101849060208082526019908201527f666f727761726465722e6765744e6f6e63652866726f6d293a00000000000000604082015260600190565b60405180910390a16040518181527f2cab9790510fd8bdfbd2115288db33fec66691d476efc5427cfd4c09693017559060200160405180910390a160405160206024820152600560448201527f68656c6c6f000000000000000000000000000000000000000000000000000000606482015260009060840160408051808303601f190181529181526020820180516315606f9360e11b7bffffffffffffffffffffffffffffffffffffffffffffffffffffffff9091161790526000548151634e3da2c960e11b81526004810192909252600b60448301527f73686f7774696d652e696f00000000000000000000000000000000000000000060648301526080602483015260016084830152603160f81b60a4830152919250620100009091046001600160a01b031690639c7b45929060c401600060405180830381600087803b1580156102d057600080fd5b505af11580156102e4573d6000803e3d6000fd5b50506040805160e081018252600081830181905273de5e327ce4e7c1b64a757aab8f2e699585977a3482526001546001600160a01b03166020808401919091526127106060840152608080840189905260a084018890526401cace077160c085015284518083018652838152855191820190955260418082527f746c83c5f7c38efbe7f186eb35eecdf1703391727880dc0b6999e50c81eb243497507fb91ae508e6f0e8e33913dec60d2fdcb39fe037ce56198c70a7927d7cd813fd96965093949390916106df908301396000805460405163e024dc7f60e01b81529293509091620100009091046001600160a01b03169063e024dc7f906103f29087908a908a90899089906004016105ee565b600060405180830381600087803b15801561040c57600080fd5b505af1158015610420573d6000803e3d6000fd5b505050506040513d6000823e601f3d908101601f1916820160405261044891908101906104e1565b5090506104548161045e565b5050505050505050565b806104de577f41304facd9323d75b11bcdd609cb38effffdb05710f7caf0e9b16c6d9d709f506040516104c29060208082526017908201527f4572726f723a20417373657274696f6e204661696c6564000000000000000000604082015260600190565b60405180910390a16104de6000805461ff001916610100179055565b50565b600080604083850312156104f457600080fd5b8251801515811461050457600080fd5b602084015190925067ffffffffffffffff8082111561052257600080fd5b818501915085601f83011261053657600080fd5b815181811115610548576105486106c8565b604051601f8201601f19908116603f01168101908382118183101715610570576105706106c8565b8160405282815288602084870101111561058957600080fd5b61059a836020830160208801610698565b80955050505050509250929050565b6000602082840312156105bb57600080fd5b5051919050565b600081518084526105da816020860160208601610698565b601f01601f19169290920160200192915050565b60a0815260006001600160a01b038088511660a08401528060208901511660c084015250604087015160e08301526060870151610100830152608087015161012083015260a087015160e061014084015261064d6101808401826105c2565b905060c0880151610160840152866020840152856040840152828103606084015261067881866105c2565b9050828103608084015261068c81856105c2565b98975050505050505050565b60005b838110156106b357818101518382015260200161069b565b838111156106c2576000848401525b50505050565b634e487b7160e01b600052604160045260246000fdfe317b4500265b302c2dbf937bbe7e5c31531aadbd8e6997bf00e234bd5c9b92fb5a3f1d8706dddc09d7e5b1b84bc28056d2c305e21427613a31f07381424b1d9c1ca164736f6c6343000807000a60806040523480156200001157600080fd5b5060006040518060a0016040528060618152602001620015d160619139604051602001620000409190620000c8565b60408051601f1981840301815291905290506200005d8162000064565b5062000174565b8051602080830191909120600081815291829052604091829020805460ff19166001179055905181907f64d6bce64323458c44643c51fe45113efc882082f7b7fd5f09f0d69d2eedb20290620000bc9085906200010c565b60405180910390a25050565b6e08cdee4eec2e4c8a4cae2eacae6e85608b1b815260008251620000f481600f85016020870162000141565b602960f81b600f939091019283015250601001919050565b60208152600082518060208401526200012d81604085016020870162000141565b601f01601f19169190910160400192915050565b60005b838110156200015e57818101518382015260200162000144565b838111156200016e576000848401525b50505050565b61144d80620001846000396000f3fe6080604052600436106100c05760003560e01c8063ad9f99c711610074578063d9210be51161004e578063d9210be51461021e578063e024dc7f1461023e578063e2b62f2d1461025f57600080fd5b8063ad9f99c7146101b9578063c3f28abd146101d9578063c722f177146101ee57600080fd5b806321fe98df116100a557806321fe98df146101235780632d0335ab146101535780639c7b45921461019757600080fd5b806301ffc9a7146100cc578063066a310c1461010157600080fd5b366100c757005b600080fd5b3480156100d857600080fd5b506100ec6100e7366004610f73565b61027f565b60405190151581526020015b60405180910390f35b34801561010d57600080fd5b506101166102b6565b6040516100f8919061124d565b34801561012f57600080fd5b506100ec61013e366004610f5a565b60006020819052908152604090205460ff1681565b34801561015f57600080fd5b5061018961016e366004610f2a565b6001600160a01b031660009081526002602052604090205490565b6040519081526020016100f8565b3480156101a357600080fd5b506101b76101b2366004610f9d565b6102d2565b005b3480156101c557600080fd5b506101b76101d4366004611009565b6103c9565b3480156101e557600080fd5b506101166103ea565b3480156101fa57600080fd5b506100ec610209366004610f5a565b60016020526000908152604090205460ff1681565b34801561022a57600080fd5b506101b7610239366004610f9d565b610406565b61025161024c366004611009565b610541565b6040516100f892919061122a565b34801561026b57600080fd5b5061011661027a3660046110b1565b610769565b60006001600160e01b031982166309788f9960e21b14806102b057506301ffc9a760e01b6001600160e01b03198316145b92915050565b6040518060a001604052806061815260200161138e6061913981565b600046905060006040518060800160405280605281526020016113ef60529139805190602001208686604051610309929190611186565b60405180910390208585604051610321929190611186565b6040805191829003822060208301949094528101919091526060810191909152608081018390523060a082015260c00160408051601f198184030181528282528051602080830191909120600081815260019283905293909320805460ff1916909117905592509081907f4bc68689cbe89a4a6333a3ab0a70093874da3e5bfb71e93102027f3f073687d8906103b890859061124d565b60405180910390a250505050505050565b6103d287610803565b6103e18787878787878761088a565b50505050505050565b6040518060800160405280605281526020016113ef6052913981565b60005b838110156104ec57600085858381811061042557610425611377565b909101357fff0000000000000000000000000000000000000000000000000000000000000016915050600560fb1b81148015906104885750602960f81b7fff00000000000000000000000000000000000000000000000000000000000000821614155b6104d95760405162461bcd60e51b815260206004820152601560248201527f4657443a20696e76616c696420747970656e616d65000000000000000000000060448201526064015b60405180910390fd5b50806104e481611330565b915050610409565b50600084846040518060a001604052806061815260200161138e6061913985856040516020016105209594939291906111d8565b604051602081830303815290604052905061053a81610a52565b5050505050565b600060606105548989898989898961088a565b61055d89610ab4565b60c089013515806105715750428960c00135115b6105bd5760405162461bcd60e51b815260206004820152601460248201527f4657443a2072657175657374206578706972656400000000000000000000000060448201526064016104d0565b600060408a0135156105ce5750619c405b60006105dd60a08c018c611260565b6105ea60208e018e610f2a565b6040516020016105fc93929190611196565b60408051601f19818403018152919052905061061c8260608d01356112a7565b60405a61062a90603f6112e1565b61063491906112bf565b10156106825760405162461bcd60e51b815260206004820152601560248201527f4657443a20696e73756666696369656e7420676173000000000000000000000060448201526064016104d0565b61069260408c0160208d01610f2a565b6001600160a01b03168b606001358c60400135836040516106b391906111bc565b600060405180830381858888f193505050503d80600081146106f1576040519150601f19603f3d011682016040523d82523d6000602084013e6106f6565b606091505b50909450925060408b01351580159061070f5750600047115b1561075b5761072160208c018c610f2a565b6001600160a01b03166108fc479081150290604051600060405180830381858888f19350505050158015610759573d6000803e3d6000fd5b505b505097509795505050505050565b6060836107796020870187610f2a565b6001600160a01b03166107926040880160208901610f2a565b6001600160a01b03166040880135606089013560808a01356107b760a08c018c611260565b6040516107c5929190611186565b6040519081900381206107ea9796959493929160c08e0135908c908c90602001611134565b6040516020818303038152906040529050949350505050565b6080810135600260006108196020850185610f2a565b6001600160a01b03166001600160a01b0316815260200190815260200160002054146108875760405162461bcd60e51b815260206004820152601360248201527f4657443a206e6f6e6365206d69736d617463680000000000000000000000000060448201526064016104d0565b50565b60008681526001602052604090205460ff166108e85760405162461bcd60e51b815260206004820152601d60248201527f4657443a20756e7265676973746572656420646f6d61696e207365702e00000060448201526064016104d0565b60008581526020819052604090205460ff166109465760405162461bcd60e51b815260206004820152601a60248201527f4657443a20756e7265676973746572656420747970656861736800000000000060448201526064016104d0565b60008661095589888888610769565b805160209182012060405161098193920161190160f01b81526002810192909252602282015260420190565b60408051601f19818403018152919052805160209182012091506109a790890189610f2a565b6001600160a01b03166109f284848080601f0160208091040260200160405190810160405280939291908181526020018383808284376000920191909152508693925050610b429050565b6001600160a01b031614610a485760405162461bcd60e51b815260206004820152601760248201527f4657443a207369676e6174757265206d69736d6174636800000000000000000060448201526064016104d0565b5050505050505050565b8051602080830191909120600081815291829052604091829020805460ff19166001179055905181907f64d6bce64323458c44643c51fe45113efc882082f7b7fd5f09f0d69d2eedb20290610aa890859061124d565b60405180910390a25050565b608081013560026000610aca6020850185610f2a565b6001600160a01b0316815260208101919091526040016000908120805491610af183611330565b91905055146108875760405162461bcd60e51b815260206004820152601360248201527f4657443a206e6f6e6365206d69736d617463680000000000000000000000000060448201526064016104d0565b6000806000610b518585610b66565b91509150610b5e81610bd6565b509392505050565b600080825160411415610b9d5760208301516040840151606085015160001a610b9187828585610d91565b94509450505050610bcf565b825160401415610bc75760208301516040840151610bbc868383610e7e565b935093505050610bcf565b506000905060025b9250929050565b6000816004811115610bea57610bea611361565b1415610bf35750565b6001816004811115610c0757610c07611361565b1415610c555760405162461bcd60e51b815260206004820152601860248201527f45434453413a20696e76616c6964207369676e6174757265000000000000000060448201526064016104d0565b6002816004811115610c6957610c69611361565b1415610cb75760405162461bcd60e51b815260206004820152601f60248201527f45434453413a20696e76616c6964207369676e6174757265206c656e6774680060448201526064016104d0565b6003816004811115610ccb57610ccb611361565b1415610d245760405162461bcd60e51b815260206004820152602260248201527f45434453413a20696e76616c6964207369676e6174757265202773272076616c604482015261756560f01b60648201526084016104d0565b6004816004811115610d3857610d38611361565b14156108875760405162461bcd60e51b815260206004820152602260248201527f45434453413a20696e76616c6964207369676e6174757265202776272076616c604482015261756560f01b60648201526084016104d0565b6000807f7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0831115610dc85750600090506003610e75565b8460ff16601b14158015610de057508460ff16601c14155b15610df15750600090506004610e75565b6040805160008082526020820180845289905260ff881692820192909252606081018690526080810185905260019060a0016020604051602081039080840390855afa158015610e45573d6000803e3d6000fd5b5050604051601f1901519150506001600160a01b038116610e6e57600060019250925050610e75565b9150600090505b94509492505050565b6000807f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff831681610eb460ff86901c601b6112a7565b9050610ec287828885610d91565b935093505050935093915050565b60008083601f840112610ee257600080fd5b50813567ffffffffffffffff811115610efa57600080fd5b602083019150836020828501011115610bcf57600080fd5b600060e08284031215610f2457600080fd5b50919050565b600060208284031215610f3c57600080fd5b81356001600160a01b0381168114610f5357600080fd5b9392505050565b600060208284031215610f6c57600080fd5b5035919050565b600060208284031215610f8557600080fd5b81356001600160e01b031981168114610f5357600080fd5b60008060008060408587031215610fb357600080fd5b843567ffffffffffffffff80821115610fcb57600080fd5b610fd788838901610ed0565b90965094506020870135915080821115610ff057600080fd5b50610ffd87828801610ed0565b95989497509550505050565b600080600080600080600060a0888a03121561102457600080fd5b873567ffffffffffffffff8082111561103c57600080fd5b6110488b838c01610f12565b985060208a0135975060408a0135965060608a013591508082111561106c57600080fd5b6110788b838c01610ed0565b909650945060808a013591508082111561109157600080fd5b5061109e8a828b01610ed0565b989b979a50959850939692959293505050565b600080600080606085870312156110c757600080fd5b843567ffffffffffffffff808211156110df57600080fd5b6110eb88838901610f12565b9550602087013594506040870135915080821115610ff057600080fd5b60008151808452611120816020860160208601611300565b601f01601f19169290920160200192915050565b8a81528960208201528860408201528760608201528660808201528560a08201528460c08201528360e082015260006101008385828501376000929093019092019081529a9950505050505050505050565b8183823760009101908152919050565b8284823760609190911b6bffffffffffffffffffffffff19169101908152601401919050565b600082516111ce818460208701611300565b9190910192915050565b84868237600085820160008152600560fb1b815285516111ff816001840160208a01611300565b600b60fa1b600192909101918201528385600283013760009301600201928352509095945050505050565b82151581526040602082015260006112456040830184611108565b949350505050565b602081526000610f536020830184611108565b6000808335601e1984360301811261127757600080fd5b83018035915067ffffffffffffffff82111561129257600080fd5b602001915036819003821315610bcf57600080fd5b600082198211156112ba576112ba61134b565b500190565b6000826112dc57634e487b7160e01b600052601260045260246000fd5b500490565b60008160001904831182151516156112fb576112fb61134b565b500290565b60005b8381101561131b578181015183820152602001611303565b8381111561132a576000848401525b50505050565b60006000198214156113445761134461134b565b5060010190565b634e487b7160e01b600052601160045260246000fd5b634e487b7160e01b600052602160045260246000fd5b634e487b7160e01b600052603260045260246000fdfe616464726573732066726f6d2c6164647265737320746f2c75696e743235362076616c75652c75696e74323536206761732c75696e74323536206e6f6e63652c627974657320646174612c75696e743235362076616c6964556e74696c54696d65454950373132446f6d61696e28737472696e67206e616d652c737472696e672076657273696f6e2c75696e7432353620636861696e49642c6164647265737320766572696679696e67436f6e747261637429a164736f6c6343000807000a616464726573732066726f6d2c6164647265737320746f2c75696e743235362076616c75652c75696e74323536206761732c75696e74323536206e6f6e63652c627974657320646174612c75696e743235362076616c6964556e74696c54696d6560c0604052601c60808190527f322e322e332b6f70656e67736e2e746573742e726563697069656e740000000060a090815261003e916001919061008b565b5034801561004b57600080fd5b5060405161087038038061087083398101604081905261006a91610124565b600080546001600160a01b0319166001600160a01b0383161790555061018f565b82805461009790610154565b90600052602060002090601f0160209004810192826100b957600085556100ff565b82601f106100d257805160ff19168380011785556100ff565b828001600101855582156100ff579182015b828111156100ff5782518255916020019190600101906100e4565b5061010b92915061010f565b5090565b5b8082111561010b5760008155600101610110565b60006020828403121561013657600080fd5b81516001600160a01b038116811461014d57600080fd5b9392505050565b600181811c9082168061016857607f821691505b6020821081141561018957634e487b7160e01b600052602260045260246000fd5b50919050565b6106d28061019e6000396000f3fe60806040526004361061007f5760003560e01c8063a26388bb1161004e578063a26388bb1461012a578063b6ffacf71461013f578063bf9587261461016c578063ce1b815f1461018157600080fd5b80632ac0df261461008b578063486ff0cd146100ad578063572b6c05146100d85780637a27578d1461011757600080fd5b3661008657005b600080fd5b34801561009757600080fd5b506100ab6100a6366004610491565b61019f565b005b3480156100b957600080fd5b506100c26101f0565b6040516100cf91906105a8565b60405180910390f35b3480156100e457600080fd5b506101076100f3366004610461565b6000546001600160a01b0391821691161490565b60405190151581526020016100cf565b6100ab610125366004610542565b61027e565b34801561013657600080fd5b506100ab6102d5565b34801561014b57600080fd5b5061015461038a565b6040516001600160a01b0390911681526020016100cf565b34801561017857600080fd5b506100c2610399565b34801561018d57600080fd5b506000546001600160a01b0316610154565b7f855af3b0567c81711540539ad042ef5a2a20d47d9d86ababf362a8e47058b5ef816101c96103dd565b6101d161042d565b33326040516101e5969594939291906105bb565b60405180910390a150565b600180546101fd90610674565b80601f016020809104026020016040519081016040528092919081815260200182805461022990610674565b80156102765780601f1061024b57610100808354040283529160200191610276565b820191906000526020600020905b81548152906001019060200180831161025957829003601f168201915b505050505081565b8034146102d25760405162461bcd60e51b815260206004820152601460248201527f6469646e277420726563656976652076616c756500000000000000000000000060448201526064015b60405180910390fd5b50565b30156103235760405162461bcd60e51b815260206004820152600b60248201527f616c77617973206661696c00000000000000000000000000000000000000000060448201526064016102c9565b7f3f110cf99894407239c5fa1bf0523ea12b54ef6eb3e88be600b6a7f0ff76eb0e604051610380906020808252818101527f696620796f7520736565207468697320726576657274206661696c65642e2e2e604082015260600190565b60405180910390a1565b600061039461042d565b905090565b60606103a36103dd565b8080601f01602080910402602001604051908101604052809392919081815260200183838082843760009201919091525092949350505050565b366000601482108015906103fb57506000546001600160a01b031633145b15610424576000803661040f60148261064f565b9261041c93929190610625565b915091509091565b50600091369150565b60006014361080159061044a57506000546001600160a01b031633145b1561045c575060131936013560601c90565b503390565b60006020828403121561047357600080fd5b81356001600160a01b038116811461048a57600080fd5b9392505050565b6000602082840312156104a357600080fd5b813567ffffffffffffffff808211156104bb57600080fd5b818401915084601f8301126104cf57600080fd5b8135818111156104e1576104e16106af565b604051601f8201601f19908116603f01168101908382118183101715610509576105096106af565b8160405282815287602084870101111561052257600080fd5b826020860160208301376000928101602001929092525095945050505050565b60006020828403121561055457600080fd5b5035919050565b6000815180845260005b8181101561058157602081850181015186830182015201610565565b81811115610593576000602083870101525b50601f01601f19169290920160200192915050565b60208152600061048a602083018461055b565b60a0815260006105ce60a083018961055b565b8281036020840152868152868860208301376000602088830101526020601f19601f8901168201019150506001600160a01b0380861660408401528085166060840152808416608084015250979650505050505050565b6000808585111561063557600080fd5b8386111561064257600080fd5b5050820193919092039150565b60008282101561066f57634e487b7160e01b600052601160045260246000fd5b500390565b600181811c9082168061068857607f821691505b602082108114156106a957634e487b7160e01b600052602260045260246000fd5b50919050565b634e487b7160e01b600052604160045260246000fdfea164736f6c6343000807000a";

type ShowtimeForwarderTestConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: ShowtimeForwarderTestConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class ShowtimeForwarderTest__factory extends ContractFactory {
  constructor(...args: ShowtimeForwarderTestConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
    this.contractName = "ShowtimeForwarderTest";
  }

  deploy(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ShowtimeForwarderTest> {
    return super.deploy(overrides || {}) as Promise<ShowtimeForwarderTest>;
  }
  getDeployTransaction(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  attach(address: string): ShowtimeForwarderTest {
    return super.attach(address) as ShowtimeForwarderTest;
  }
  connect(signer: Signer): ShowtimeForwarderTest__factory {
    return super.connect(signer) as ShowtimeForwarderTest__factory;
  }
  static readonly contractName: "ShowtimeForwarderTest";
  public readonly contractName: "ShowtimeForwarderTest";
  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): ShowtimeForwarderTestInterface {
    return new utils.Interface(_abi) as ShowtimeForwarderTestInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): ShowtimeForwarderTest {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as ShowtimeForwarderTest;
  }
}