import json
import os
import sys

from web3 import Web3

from chains import mumbai, polygon

active_chain = polygon


def load_abi():
    # get the base dir of this file
    base_dir = os.path.dirname(os.path.abspath(__file__))
    abi_json = os.path.join(base_dir, "abi", "Multicall3.json")

    with open(abi_json) as f:
        return json.load(f)


def main():
    w3 = Web3(Web3.HTTPProvider(active_chain.rpcUrl))

    # all hail https://github.com/mds1/multicall
    multicall3 = w3.eth.contract(
        address="0xcA11bde05977b3631167028862bE2a173976CA11",
        abi=load_abi()
    )

    if len(sys.argv) < 2:
        print("Usage: python3 bin/edition-sold-out.py <editionAddress>")
        sys.exit(1)

    editionAddress = sys.argv[1]

    blockNumber, bytes_returndata = multicall3.functions.aggregate([
        [
            editionAddress,
            "0xf4ed0f46",  # editionSize()
        ],
        [
            editionAddress,
            "0x18160ddd",  # totalSupply()
        ]
    ]).call()

    editionSize = w3.toInt(primitive=bytes_returndata[0])
    totalSupply = w3.toInt(primitive=bytes_returndata[1])
    soldOut = editionSize > 0 and totalSupply >= editionSize

    print("editionSize", editionSize)
    print("totalSupply", totalSupply)
    print("soldOut", soldOut)


if __name__ == "__main__":
    main()
