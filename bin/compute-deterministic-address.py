#!/usr/bin/env python3

import sys

from web3 import Web3

edition_impl_addr = "0x0aE678AaCAbfd47957D104E5c3812AddCd1620b6"
gated_edition_creator_addr = "0xE069D5a9f0A6d882e1D96101350a1A27D4967037"

# returns a hexstr
def get_edition_id(
    creator_addr: str, name: str, animation_url: str, image_url: str
) -> str:
    return Web3.keccak(
        hexstr=creator_addr[2:]
        + Web3.toHex(text=name)[2:]
        + Web3.toHex(text=animation_url)[2:]
        + Web3.toHex(text=image_url)[2:]
    ).hex()


def compute_deterministic_address(
    edition_creator_addr: str, edition_id_hexstr: str
) -> str:
    # https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/proxy/ClonesUpgradeable.sol#L61
    bytecode = (
        "3d602d80600a3d3981f3363d3d373d3d3d363d73"
        + edition_impl_addr[2:]
        + "5af43d82803e903d91602b57fd5bf3"
    )

    addr_hexstr = Web3.keccak(
        hexstr=(
            "ff"
            + edition_creator_addr[2:]
            + edition_id_hexstr[2:]
            + Web3.keccak(hexstr=bytecode).hex()[2:]
        )
    ).hex()

    return Web3.toChecksumAddress(addr_hexstr[-40:])


def main():
    creator_addr = sys.argv[1]
    name = sys.argv[2]
    animation_url = sys.argv[3]
    image_url = sys.argv[4]

    edition_id = get_edition_id(creator_addr, name, animation_url, image_url)

    print(compute_deterministic_address(gated_edition_creator_addr, edition_id))


if __name__ == "__main__":
    main()
