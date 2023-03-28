// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Script, console2} from "forge-std/Script.sol";

import {SSTORE2} from "solmate/utils/SSTORE2.sol";
import {SingleBatchEdition} from "nft-editions/SingleBatchEdition.sol";
import {Addresses} from "nft-editions/utils/Addresses.sol";

import {ShowtimeVerifier} from "src/ShowtimeVerifier.sol";
import {IShowtimeVerifier, Attestation, SignedAttestation} from "src/interfaces/IShowtimeVerifier.sol";
import {EditionFactory, EditionData} from "src/editions/EditionFactory.sol";

import {ShowtimeVerifierFixture} from "test/fixtures/ShowtimeVerifierFixture.sol";

contract SingleBatchEditionDemo is Script, ShowtimeVerifierFixture {
    address internal constant SINGLE_BATCH_EDITION_IMPL = 0xC3fDd7ddd998f7D6696B682E05ea9B999B4b7194;
    address internal constant VERIFIER = 0x50C0017836517dc49C9EBC7615d8B322A0f91F67;

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(pk);
        console2.log("from address:", owner);

        vm.startBroadcast(pk);

        EditionFactory editionFactory = new EditionFactory(VERIFIER);

        address creator = 0x9cc97852491fBB3B63c539f6C20Eb24A1c76568f;

        Attestation memory creatorAttestation = Attestation({
            context: address(editionFactory),
            beneficiary: creator,
            validUntil: block.timestamp + 2 minutes,
            nonce: getVerifier().nonces(creator)
        });

        /// @dev addresses have to be sorted
        // bytes memory recipients = abi.encodePacked(
        //     0x03433830468d771A921314D75b9A1DeA53C165d7, // karmacoma.eth
        //     0x3CFa5Fe88512Db62e40d0F91b7E59af34C1b098f, // nishanbende.eth
        //     0x5969140066E0Efb3ee6e01710f319Bd8F19542C0, // alantoa.eth
        //     0xAee2B2414f6ddd7E19697de40d828CBCDdAbf27F, // axeldelafosse.eth
        //     0xCcDd7eCA13716F442F01d14DBEDB6C427cb86dFA, // delvaze.eth
        //     0xD3e9D60e4E4De615124D5239219F32946d10151D, // alexmasmej.eth
        //     0xF9984Db6A3bd7044f0d22c9008ddA296C0CC5468  // henryfontanier.eth
        // );

        // wow such benchmark
        bytes memory recipients = Addresses.make(1000);

        EditionData memory editionData = EditionData({
            // quotes will need to be escaped:
            name: unicode'"She gets visions" 👁️',
            // newlines will need to be escaped
            description: unicode"Playing in the background:\nKetto by Bonobo 🎶",
            animationUrl: "",
            imageUrl: "ipfs://QmSEBhh7A4JKjdRAVEwLGmfF5ckabAUnYVace9KjvyqMZj",
            royaltyBPS: 10_00,
            externalUrl: "https://showtime.xyz/nft/polygon/0x1D6378e337f49dA12eEf49Bd1D8de3a1720115f4/0",
            creatorName: "@AliceOnChain",
            tags: "art,limited-edition,time-limited"
        });

        SignedAttestation memory signedAttestation = signed(pk, creatorAttestation);

        address editionAddress = address(
            editionFactory.createEdition(
                SINGLE_BATCH_EDITION_IMPL,
                editionData,
                recipients,
                signedAttestation
            )
        );

        console2.log("Edition address:", editionAddress);

        vm.stopBroadcast();
    }

    function getVerifier() public pure override returns (ShowtimeVerifier) {
        return ShowtimeVerifier(VERIFIER);
    }

}
