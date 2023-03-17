// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Script, console2} from "forge-std/Script.sol";

import {SingleBatchEdition} from "nft-editions/SingleBatchEdition.sol";

import {IShowtimeVerifier, Attestation, SignedAttestation} from "src/interfaces/IShowtimeVerifier.sol";
import {EditionFactory} from "src/editions/EditionFactory.sol";

contract SingleBatchEditions is Script {
    address public constant SHOWTIME_VERIFIER = 0x50C0017836517dc49C9EBC7615d8B322A0f91F67;

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(pk);
        console2.log("from address:", owner);
        vm.startBroadcast(pk);

        SingleBatchEdition editionImpl = new SingleBatchEdition{ salt: 0 }();
        console2.log("editionImpl:", address(editionImpl));

        EditionFactory factory = new EditionFactory{ salt: 0 }(SHOWTIME_VERIFIER);
        console2.log("factory:", address(factory));
    }
}
