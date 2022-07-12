// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { EIP712, ECDSA } from "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

import { IShowtimeVerifier, Attestation } from "./interfaces/IShowtimeVerifier.sol";

contract ShowtimeVerifier is Ownable, EIP712, IShowtimeVerifier {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    bytes public constant requestType =
        "Attestation(address beneficiary,address context,uint256 signedAt,uint256 validUntil)";

    bytes32 public constant REQUEST_TYPE_HASH = keccak256(requestType);

    uint256 public constant MAX_ATTESTATION_VALIDITY_SECONDS = 5 * 60;

    uint256 public constant MAX_SIGNER_VALIDITY_DAYS = 365;

    /*//////////////////////////////////////////////////////////////
                            MUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address => uint256) public signerValidity;

    address public signerManager;

    /*//////////////////////////////////////////////////////////////
                            MISE EN BOUCHE
    //////////////////////////////////////////////////////////////*/
    constructor() EIP712("showtime.xyz", "v1") Ownable() {
        // no-op
    }

    modifier onlyAdmin() {
        if (msg.sender != owner() && msg.sender != signerManager) {
            revert Unauthorized();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            VERIFICATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Verifies the given attestation
    /// @notice Attestations contain no nonces, so it is up to the calling contract to ensure replay-safety
    /// @param attestation the attestation to verify
    /// @param signature the signature of the attestation
    /// @return true if the attestation is valid, reverts otherwise
    function verify(Attestation calldata attestation, bytes calldata signature) external view override returns (bool) {
        uint256 signedAt = attestation.signedAt;
        uint256 validUntil = attestation.validUntil;

        /// we want to enforce the following invariant:
        ///     signedAt <= block.timestamp <= validUntil
        if (signedAt > block.timestamp) {
            revert TemporalAnomaly();
        }

        if (block.timestamp > validUntil) {
            revert Expired();
        }

        if ((validUntil - signedAt) > MAX_ATTESTATION_VALIDITY_SECONDS) {
            revert DeadlineTooLong();
        }

        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(REQUEST_TYPE_HASH, attestation)));
        address signer = ECDSA.recover(digest, signature);
        uint256 signerExpirationTimestamp = signerValidity[signer];

        if (signerExpirationTimestamp == 0) {
            revert UnknownSigner(signer);
        }

        if (block.timestamp > signerExpirationTimestamp) {
            revert SignerExpired(signer);
        }

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        SIGNER MANAGEMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// Delegates the signer management to another address
    /// @param _signerManager the address that will be authorized to add and remove signers (use address 0 to disable)
    function setSignerManager(address _signerManager) external override onlyOwner {
        signerManager = _signerManager;
    }

    /// Registers an authorized signer
    /// @param signer the new signer to register
    /// @param validityDays how long the signer will be valid starting from the moment of registration
    function registerSigner(address signer, uint256 validityDays) external override onlyAdmin {
        if (validityDays > MAX_SIGNER_VALIDITY_DAYS) {
            revert DeadlineTooLong();
        }

        signerValidity[signer] = block.timestamp + validityDays * 24 * 60 * 60;
    }

    /// Remove an authorized signer
    function revokeSigner(address signer) external override onlyAdmin {
        signerValidity[signer] = 0;
    }
}
