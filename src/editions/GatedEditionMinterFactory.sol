// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ClonesUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import { IEditionSingleMintable } from "@zoralabs/nft-editions-contracts/contracts/IEditionSingleMintable.sol";

import { IShowtimeVerifier } from "src/interfaces/IShowtimeVerifier.sol";

import { GatedEditionMinter } from "./GatedEditionMinter.sol";
import { TimeCop } from "./TimeCop.sol";


contract GatedEditionMinterFactory {
    error NullAddress();

    IShowtimeVerifier public immutable showtimeVerifier;
    GatedEditionMinter public immutable minterImpl;
    TimeCop public immutable timeCop;

    constructor (IShowtimeVerifier _showtimeVerifier, address _timeCop) {
        if (_timeCop == address(0) || address(_showtimeVerifier) == address(0)){
            revert NullAddress();
        }

        showtimeVerifier = _showtimeVerifier;
        timeCop = TimeCop(_timeCop);

        /// @dev this deploys and locks down the base implementation, which we will later deploy proxies to
        minterImpl = new GatedEditionMinter();
    }

    /// returns an initialized minimal proxy to the base GatedEditionMinter implementation
    function createMinter(IEditionSingleMintable _edition) public returns (GatedEditionMinter newMinter) {
        // deploy the minter for this edition
        newMinter = GatedEditionMinter(
            ClonesUpgradeable.cloneDeterministic(
                address(minterImpl),
                bytes32(uint256(uint160(address(_edition))))
            )
        );

        newMinter.initialize(showtimeVerifier, _edition, timeCop);
    }

    function getMinterForEdition(address edition) public view returns (address) {
        return ClonesUpgradeable.predictDeterministicAddress(
            address(minterImpl),
            bytes32(uint256(uint160(edition)))
        );
    }
}