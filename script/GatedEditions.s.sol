// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Script, console2} from "forge-std/Script.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";

import {Edition} from "nft-editions/Edition.sol";

import {IShowtimeVerifier} from "src/interfaces/IShowtimeVerifier.sol";
import {GatedEditionCreator} from "src/editions/GatedEditionCreator.sol";
import {GatedEditionMinter} from "src/editions/GatedEditionMinter.sol";

import {Create2Helper} from "./utils/Create2Helper.sol";

contract GatedEditions is Script, Create2Helper, StdAssertions {
    address public constant SHOWTIME_VERIFIER = 0x50C0017836517dc49C9EBC7615d8B322A0f91F67;

    bytes32 internal editionSalt =
        bytes32(uint256(100277974188778523905287350549323846627034129457250519405536622108661885373861));
    bytes32 internal minterSalt =
        bytes32(uint256(62059840843379373827285484069185299402157293444054464217434116307594828541326));
    bytes32 internal creatorSalt =
        bytes32(uint256(49878374740187518875513948233179854588023069277032562717373590206714954727220));

    function _log(string memory s, bytes32 v) public view {
        console2.log(s);
        console2.logBytes32(v);
    }

    function _checkPrefix(address addr) public {
        assertEq(uint256(uint160(addr)) >> 136, 0x50c001);
    }

    function initcode() public {
        bytes32 editionInitCodeHash = initCodeHashNoConstructorArgs(type(Edition).creationCode);
        _log("Edition initCodeHash:", editionInitCodeHash);
        address editionAddr = computeCreate2Address(editionSalt, editionInitCodeHash);
        _checkPrefix(editionAddr);

        bytes32 minterInitCodeHash = initCodeHash(type(GatedEditionMinter).creationCode, abi.encode(SHOWTIME_VERIFIER));
        _log("GatedEditionMinter initCodeHash:", minterInitCodeHash);
        address minterAddr = computeCreate2Address(minterSalt, minterInitCodeHash);
        _checkPrefix(minterAddr);

        bytes32 creatorInitCodeHash =
            initCodeHash(type(GatedEditionCreator).creationCode, abi.encode(editionAddr, minterAddr));
        _log("GatedEditionCreator initCodeHash:", creatorInitCodeHash);
        address creatorAddr = computeCreate2Address(creatorSalt, creatorInitCodeHash);
        _checkPrefix(creatorAddr);
    }

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(pk);
        console2.log("from address:", owner);
        vm.startBroadcast(pk);

        Edition editionImpl = new Edition{ salt: editionSalt }();
        console2.log("Edition impl:", address(editionImpl));

        GatedEditionMinter minter = new GatedEditionMinter{ salt: minterSalt }(IShowtimeVerifier(SHOWTIME_VERIFIER));
        console2.log("GatedEditionMinter:", address(minter));

        GatedEditionCreator creator =
            new GatedEditionCreator{ salt: creatorSalt }(address(editionImpl), address(minter));
        console2.log("GatedEditionCreator:", address(creator));
    }
}
