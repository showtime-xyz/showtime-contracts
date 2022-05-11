// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ClonesUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import { IEditionSingleMintable } from "@zoralabs/nft-editions-contracts/contracts/IEditionSingleMintable.sol";

import { MetaEditionMinter } from "./MetaEditionMinter.sol";
import { TimeCop } from "./TimeCop.sol";

contract MetaEditionMinterFactory {
    error NullAddress();

    address public immutable trustedForwarder;
    MetaEditionMinter public immutable minterImpl;
    TimeCop public immutable timeCop;

    constructor (address _trustedForwarder, address _timeCop) {
        if (_timeCop == address(0)) {
            revert NullAddress();
        }

        /// @dev we accept the null address for the trusted forwarder (meta-tx disabled)
        trustedForwarder = _trustedForwarder;
        timeCop = TimeCop(_timeCop);

        /// @dev this deploys and locks down the base implementation, which we will later deploy proxies to
        minterImpl = new MetaEditionMinter();
    }

    /// returns an initialized minimal proxy to the base MetaEditionMinter implementation
    function createMinter(IEditionSingleMintable _edition) public returns (MetaEditionMinter newMinter) {
        // deploy the minter for this edition
        newMinter = MetaEditionMinter(
            ClonesUpgradeable.cloneDeterministic(
                address(minterImpl),
                bytes32(uint256(uint160(address(_edition))))
            )
        );

        newMinter.initialize(trustedForwarder, _edition, timeCop);
    }

    function getMinterForEdition(address edition) public view returns (address) {
        return ClonesUpgradeable.predictDeterministicAddress(
            address(minterImpl),
            bytes32(uint256(uint160(edition)))
        );
    }
}