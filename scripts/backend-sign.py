#!/usr/bin/env python3

import json
import os
import secrets
import time

from web3 import Web3
from web3.exceptions import ContractLogicError
from eth_account.messages import encode_structured_data
from eth_account.account import Account
from dataclasses import dataclass


@dataclass
class ChainConfig:
    chainId: int
    name: str
    rpcUrl: str
    verifierAddress: str


mumbai = ChainConfig(
    chainId=80001,
    name="mumbai",
    rpcUrl="https://matic-mumbai.chainstacklabs.com",
    # formerly "0xE5eC1D79E0AF57C57AAeE8D64cDCDf52493b8711"
    verifierAddress="0x50C0017836517dc49C9EBC7615d8B322A0f91F67")

polygon = ChainConfig(
    chainId=137,
    name="polygon",
    rpcUrl="https://polygon-rpc.com",
    verifierAddress="0x50C0017836517dc49C9EBC7615d8B322A0f91F67")

active_chain = polygon

KEYFILE_NAME = "keyfile.json"
KEYFILE_PASSWORD = "hunter2"


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
                    "internalType": "address",
                    "name": "",
                    "type": "address"
                }
            ],
            "name": "nonces",
            "outputs": [
                {
                    "internalType": "uint256",
                    "name": "",
                    "type": "uint256"
                }
            ],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [
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
    print(
        f"Verifying on {active_chain.name} against {active_chain.verifierAddress}")

    w3 = Web3(Web3.HTTPProvider(active_chain.rpcUrl))
    verifier = w3.eth.contract(
        address=active_chain.verifierAddress, abi=get_verifier_abi())

    beneficiary = "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
    nonce = verifier.functions.nonces(beneficiary).call()

    structured_data = {
        "domain": {
            "chainId": active_chain.chainId,
            "name": 'showtime.xyz',
            "verifyingContract": active_chain.verifierAddress,
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
                {"name": 'nonce', "type": 'uint256'},
                {"name": 'validUntil', "type": 'uint256'},
            ]
        },

        "primaryType": "Attestation",
        "message": {
            "beneficiary": beneficiary,
            "context": "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC",
            "nonce": nonce,
            "validUntil": int(time.time()) + 120,
        }
    }

    signable_message = encode_structured_data(structured_data)
    signed_message = account.sign_message(signable_message)

    print("Verifying attestation:")
    print(structured_data["message"])

    print("With signature:")
    print(signed_message)

    print("Result:")
    attestation = tuple((structured_data["message"][x] for x in (
        'beneficiary', 'context', 'nonce', 'validUntil')))

    try:
        print(verifier.functions.verify(
            [
                attestation,
                signed_message.signature
            ]).call())
    except ContractLogicError as e:
        print("Error:", e)


if __name__ == '__main__':
    main()
