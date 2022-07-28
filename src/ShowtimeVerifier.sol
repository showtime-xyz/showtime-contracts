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
    constructor(address _owner) EIP712("showtime.xyz", "v1") Ownable() {
        transferOwnership(_owner);
    }

    modifier onlyAdmin() {
        if (msg.sender != owner() && msg.sender != signerManager) {
            revert Unauthorized();
        }
        _;
    }

    function domainSeparator() public view returns(bytes32) {
        return _domainSeparatorV4();
    }

    /*//////////////////////////////////////////////////////////////
                            VERIFICATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function encode(Attestation memory attestation) public pure returns (bytes memory) {
        return abi.encode(
            attestation.beneficiary,
            attestation.context,
            attestation.signedAt,
            attestation.validUntil
        );
    }

    /// @notice Verifies the given attestation
    /// @notice Attestations contain no nonces, so it is up to the calling contract to ensure replay-safety
    /// @param attestation the attestation to verify
    /// @param signature the signature of the attestation
    /// @return true if the attestation is valid, reverts otherwise
    function verify(Attestation calldata attestation, bytes calldata signature) external view override returns (bool) {
        uint256 signedAt = attestation.signedAt;
        uint256 validUntil = attestation.validUntil;

        if (signedAt > block.timestamp) {
            revert TemporalAnomaly();
        }

        if (block.timestamp > validUntil) {
            revert Expired();
        }

        if ((validUntil - signedAt) > MAX_ATTESTATION_VALIDITY_SECONDS) {
            revert DeadlineTooLong();
        }

        // what we want is EIP712 encoding, not ABI encoding
        return verify(REQUEST_TYPE_HASH, encode(attestation), signature);
    }


    /// @notice Verifies arbitrary typed data
    /// @dev see https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct
    /// @param typeHash the EIP712 type hash for the struct data to be verified
    /// @param encodedData the EIP712-encoded struct data to be verified (32 bytes long members, hashed dynamic types)
    /// @param signature the signature of the hashed struct
    /// @return true if the signature is valid, reverts otherwise
    function verify(bytes32 typeHash, bytes memory encodedData, bytes calldata signature) public view returns (bool) {
        bytes32 structHash = keccak256(abi.encodePacked(typeHash, encodedData));
        bytes32 digest = _hashTypedDataV4(structHash);
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

        // TODO: emit event
    }

    /// Registers an authorized signer
    /// @param signer the new signer to register
    /// @param validityDays how long the signer will be valid starting from the moment of registration
    function registerSigner(address signer, uint256 validityDays) external override onlyAdmin {
        if (validityDays > MAX_SIGNER_VALIDITY_DAYS) {
            revert DeadlineTooLong();
        }

        signerValidity[signer] = block.timestamp + validityDays * 24 * 60 * 60;

        // TODO: emit event
    }

    /// Remove an authorized signer
    function revokeSigner(address signer) external override onlyAdmin {
        signerValidity[signer] = 0;

        // TODO: emit event
    }
}
