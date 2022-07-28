#!/usr/bin/env python3

import json
import os
import secrets
import time

from web3 import Web3
from web3.exceptions import ContractLogicError
from eth_account.messages import encode_structured_data
from eth_account.account import Account

KEYFILE_NAME = "keyfile.json"
KEYFILE_PASSWORD = "hunter2"
VERIFIER_MUMBAI_ADDRESS = "0xefb210C93388F50b4611664C97b12f61c2c04F7f"


def load_keyfile():
    if not os.path.exists(KEYFILE_NAME):
        return None

    with open(KEYFILE_NAME) as f:
        keyfile_json = json.load(f)
        key_bytes = Account.decrypt(keyfile_json, KEYFILE_PASSWORD)
        return Account.from_key(key_bytes)


def create_keyfile():
    account = Account.create(extra_entropy=secrets.token_bytes(32))
    with open(KEYFILE_NAME, "w") as f:
        keyfile_json = account.encrypt(KEYFILE_PASSWORD)
        json.dump(keyfile_json, f)

    return account


def get_verifier_abi():
    return [
        {
            "inputs": [
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
                            "name": "signedAt",
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
            "name": "verify",
            "outputs": [
                {
                    "internalType": "bool",
                    "name": "",
                    "type": "bool"
                }
            ],
            "stateMutability": "view",
            "type": "function"
        }
    ]


def main():
    account = load_keyfile()
    if account is None:
        print("No keyfile found, creating one")
        account = create_keyfile()

    print("Loaded account with address", account.address)

    structured_data = {
        "domain": {
            "chainId": 80001,  # mumbai
            "name": 'showtime.xyz',
            "verifyingContract": VERIFIER_MUMBAI_ADDRESS,
            "version": 'v1',
        },

        "types":  {
            "EIP712Domain": [
                {"name": 'name', "type": 'string'},
                {"name": 'version', "type": 'string'},
                {"name": 'chainId', "type": 'uint256'},
                {"name": 'verifyingContract', "type": 'address'},
            ],
            "Attestation": [
                {"name": 'beneficiary', "type": 'address'},
                {"name": 'context', "type": 'address'},
                {"name": 'signedAt', "type": 'uint256'},
                {"name": 'validUntil', "type": 'uint256'},
            ]
        },

        "primaryType": "Attestation",
        "message": {
            "beneficiary": "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC",
            "context": "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC",
            "signedAt": int(time.time()) - 5,
            "validUntil": int(time.time()) + 120,
        }
    }

    signable_message = encode_structured_data(structured_data)
    signed_message = account.sign_message(signable_message)

    w3 = Web3(Web3.HTTPProvider("https://matic-mumbai.chainstacklabs.com"))
    verifier = w3.eth.contract(
        address=VERIFIER_MUMBAI_ADDRESS, abi=get_verifier_abi())

    print("Verifying attestation:")
    print(structured_data["message"])

    print("With signature:")
    print(signed_message)

    print("Result:")
    attestation = tuple((structured_data["message"][x] for x in ('beneficiary', 'context', 'signedAt', 'validUntil')))

    try:
        print(verifier.functions.verify(attestation, signed_message.signature).call())
    except ContractLogicError as e:
        print("Error:", e)

if __name__ == '__main__':
    main()
