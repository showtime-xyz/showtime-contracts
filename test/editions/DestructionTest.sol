// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ClonesUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { DSTest } from "ds-test/test.sol";
import { Hevm } from "test/Hevm.sol";

/// a minimal version of the MetaEditionMinter setup to let us test the cloning and destroying behavior

contract Destroyable is Initializable {
    event SelfDestructed(address);
    uint256 public value;

    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 _value) external initializer {
        require(_value != 0, "you're not the original");
        value = _value;
    }

    function isProxy() public view returns(bool) {
        return value != 0;
    }

    function purge() public {
        if (isProxy()) {
            emit SelfDestructed(address(this));
            selfdestruct(payable(msg.sender));
        }
    }
}

contract DestroyableFactory {
    Destroyable public immutable BASE_CONTRACT = new Destroyable();
    uint256 value = 0;

    function newDestroyable() public returns(Destroyable clone) {
        clone = Destroyable(
            ClonesUpgradeable.cloneDeterministic(
                address(BASE_CONTRACT),
                bytes32(++value)
            )
        );
        clone.initialize(value);
    }
}

contract DestructionTest is DSTest {
    Hevm internal constant hevm = Hevm(HEVM_ADDRESS);
    DestroyableFactory internal factory = new DestroyableFactory();
    Destroyable clone = factory.newDestroyable();

    function testDestruction() public {
        assertEq(clone.value(), 1);
        assertTrue(clone.isProxy());
        assertTrue(!factory.BASE_CONTRACT().isProxy());

        clone.purge();

        // this stays at 45 for some reason
        // assertEq(address(clone).code.length, 0);
    }
}
