// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { Script, console2 } from "forge-std/Script.sol";

import { Edition } from "nft-editions/Edition.sol";

import { IShowtimeVerifier } from "src/interfaces/IShowtimeVerifier.sol";
import { GatedEditionCreator } from "src/editions/GatedEditionCreator.sol";
import { GatedEditionMinter } from "src/editions/GatedEditionMinter.sol";

contract GatedEditions is Script {
    address public constant SHOWTIME_VERIFIER = 0x50C0017836517dc49C9EBC7615d8B322A0f91F67;

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(pk);
        console2.log("from address:", owner);
        vm.startBroadcast(pk);

        Edition editionImpl = new Edition{ salt: 0 }();
        console2.log("editionImpl:", address(editionImpl));

        GatedEditionMinter minter = new GatedEditionMinter{ salt: 0 }(IShowtimeVerifier(SHOWTIME_VERIFIER));
        console2.log("minter:", address(minter));

        GatedEditionCreator creator = new GatedEditionCreator{ salt: 0 }(address(editionImpl), address(minter));
        console2.log("creator:", address(creator));
    }
}
