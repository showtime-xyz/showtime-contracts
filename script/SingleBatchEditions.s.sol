// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Script, console2} from "forge-std/Script.sol";

import {SingleBatchEdition} from "nft-editions/SingleBatchEdition.sol";

import {IShowtimeVerifier, Attestation, SignedAttestation} from "src/interfaces/IShowtimeVerifier.sol";
import {SingleBatchEditionCreator} from "src/editions/SingleBatchEditionCreator.sol";
import {SingleBatchEditionMinter} from "src/editions/SingleBatchEditionMinter.sol";

contract SingleBatchEditions is Script {
    address public constant SHOWTIME_VERIFIER = 0x50C0017836517dc49C9EBC7615d8B322A0f91F67;

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(pk);
        console2.log("from address:", owner);
        vm.startBroadcast(pk);

        SingleBatchEdition editionImpl = new SingleBatchEdition{ salt: 0 }();
        console2.log("editionImpl:", address(editionImpl));

        SingleBatchEditionMinter minter = new SingleBatchEditionMinter{ salt: 0 }(IShowtimeVerifier(SHOWTIME_VERIFIER));
        console2.log("minter:", address(minter));

        SingleBatchEditionCreator creator = new SingleBatchEditionCreator{ salt: 0 }(address(editionImpl), address(minter));
        console2.log("creator:", address(creator));
    }
}
