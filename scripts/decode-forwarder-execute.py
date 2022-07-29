#!/usr/bin/env python3

import json
import sys

from web3 import Web3

abi = '''
[
  {
    "inputs": [
      {
        "components": [
          { "internalType": "address", "name": "from", "type": "address" },
          { "internalType": "address", "name": "to", "type": "address" },
          { "internalType": "uint256", "name": "value", "type": "uint256" },
          { "internalType": "uint256", "name": "gas", "type": "uint256" },
          { "internalType": "uint256", "name": "nonce", "type": "uint256" },
          { "internalType": "bytes", "name": "data", "type": "bytes" },
          {
            "internalType": "uint256",
            "name": "validUntilTime",
            "type": "uint256"
          }
        ],
        "internalType": "struct IForwarder.ForwardRequest",
        "name": "req",
        "type": "tuple"
      },
      {
        "internalType": "bytes32",
        "name": "domainSeparator",
        "type": "bytes32"
      },
      {
        "internalType": "bytes32",
        "name": "requestTypeHash",
        "type": "bytes32"
      },
      { "internalType": "bytes", "name": "suffixData", "type": "bytes" },
      { "internalType": "bytes", "name": "sig", "type": "bytes" }
    ],
    "name": "execute",
    "outputs": [
      { "internalType": "bool", "name": "success", "type": "bool" },
      { "internalType": "bytes", "name": "ret", "type": "bytes" }
    ],
    "stateMutability": "payable",
    "type": "function"
  }
]
'''

input_data = sys.argv[1] if (len(sys.argv) > 1) else sys.stdin.read().strip()
contract_function, decoded_args = Web3().eth.contract(abi=abi).decode_function_input(input_data)
print(json.dumps(decoded_args, indent=2, default=lambda x: Web3.toHex(x)))
