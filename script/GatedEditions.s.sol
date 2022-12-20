// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Script, console2} from "forge-std/Script.sol";

import {Edition} from "nft-editions/Edition.sol";

import {IShowtimeVerifier} from "src/interfaces/IShowtimeVerifier.sol";
import {GatedEditionCreator} from "src/editions/GatedEditionCreator.sol";
import {GatedEditionMinter} from "src/editions/GatedEditionMinter.sol";

contract GatedEditions is Script {
    address public constant SHOWTIME_VERIFIER = 0x50C0017836517dc49C9EBC7615d8B322A0f91F67;

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(pk);
        console2.log("from address:", owner);
        vm.startBroadcast(pk);

        bytes32 salt = bytes32(uint256(101));

        Edition editionImpl = new Edition{ salt: salt }();
        console2.log("editionImpl:", address(editionImpl));

        GatedEditionMinter minter = new GatedEditionMinter{ salt: salt }(IShowtimeVerifier(SHOWTIME_VERIFIER));
        console2.log("GatedEditionMinter:", address(minter));

        GatedEditionCreator creator = new GatedEditionCreator{ salt: salt }(address(editionImpl), address(minter));
        console2.log("GatedEditionCreator:", address(creator));
    }
}
