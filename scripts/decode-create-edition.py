#!/usr/bin/env python3

import json
import sys

from web3 import Web3

abi = '''
[
  {
    "inputs": [
      { "internalType": "string", "name": "_name", "type": "string" },
      { "internalType": "string", "name": "_symbol", "type": "string" },
      { "internalType": "string", "name": "_description", "type": "string" },
      { "internalType": "string", "name": "_animationUrl", "type": "string" },
      {
        "internalType": "bytes32",
        "name": "_animationHash",
        "type": "bytes32"
      },
      { "internalType": "string", "name": "_imageUrl", "type": "string" },
      { "internalType": "bytes32", "name": "_imageHash", "type": "bytes32" },
      { "internalType": "uint256", "name": "_editionSize", "type": "uint256" },
      { "internalType": "uint256", "name": "_royaltyBPS", "type": "uint256" },
      {
        "internalType": "uint256",
        "name": "_claimWindowDurationSeconds",
        "type": "uint256"
      }
    ],
    "name": "createEdition",
    "outputs": [
      { "internalType": "address", "name": "", "type": "address" },
      { "internalType": "address", "name": "", "type": "address" }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]
'''

input_data = sys.argv[1] if (len(sys.argv) > 1) else sys.stdin.read().strip()
contract_function, decoded_args = Web3().eth.contract(abi=abi).decode_function_input(input_data)
print(json.dumps(decoded_args, indent=2, default=lambda x: Web3.toHex(x)))
