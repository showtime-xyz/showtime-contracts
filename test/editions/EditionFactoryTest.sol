// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {SingleBatchEdition} from "nft-editions/SingleBatchEdition.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import "nft-editions/interfaces/Errors.sol";

import {EditionFactory, EditionData} from "src/editions/EditionFactory.sol";
import {EditionFactoryFixture} from "test/fixtures/EditionFactoryFixture.sol";
import {ShowtimeVerifierFixture} from "test/fixtures/ShowtimeVerifierFixture.sol";
import "src/editions/interfaces/Errors.sol";

contract EditionFactoryTest is Test, ShowtimeVerifierFixture, EditionFactoryFixture {

    function setUp() public {
        __EditionFactoryFixture_setUp();
    }

    function test_createEdition_nullEditionImplReverts() public {
        EditionData memory editionData = DEFAULT_EDITION_DATA;
        editionData.editionImpl = address(0);

        uint256 editionId = editionFactory.getEditionId(editionData, creator);

        vm.expectRevert(NullAddress.selector);
        editionFactory.getEditionAtId(editionData.editionImpl, editionId);
    }
}
