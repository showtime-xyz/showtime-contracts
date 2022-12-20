#!/usr/bin/env python3

import json
import sys

from web3 import Web3

abi = """
[
  {
    "inputs": [
      {
        "internalType": "string",
        "name": "name",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "description",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "animationUrl",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "imageUrl",
        "type": "string"
      },
      {
        "internalType": "uint256",
        "name": "editionSize",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "royaltyBPS",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "mintPeriodSeconds",
        "type": "uint256"
      },
      {
        "internalType": "string",
        "name": "externalUrl",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "creatorName",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "tags",
        "type": "string"
      },
      {
        "internalType": "bool",
        "name": "enableOpenseaOperatorFiltering",
        "type": "bool"
      },
      {
        "components": [
          {
            "components": [
              {
                "internalType": "address",
                "name": "beneficiary",
                "type": "address"
              },
              {
                "internalType": "address",
                "name": "context",
                "type": "address"
              },
              {
                "internalType": "uint256",
                "name": "nonce",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "validUntil",
                "type": "uint256"
              }
            ],
            "internalType": "struct Attestation",
            "name": "attestation",
            "type": "tuple"
          },
          {
            "internalType": "bytes",
            "name": "signature",
            "type": "bytes"
          }
        ],
        "internalType": "struct SignedAttestation",
        "name": "signedAttestation",
        "type": "tuple"
      }
    ],
    "name": "createEdition",
    "outputs": [
      {
        "internalType": "contract IEdition",
        "name": "edition",
        "type": "address"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  }

]
"""

input_data = sys.argv[1] if (len(sys.argv) > 1) else sys.stdin.read().strip()
contract_function, decoded_args = (
    Web3().eth.contract(abi=abi).decode_function_input(input_data)
)
print(json.dumps(decoded_args, indent=2, default=lambda x: Web3.toHex(x)))
