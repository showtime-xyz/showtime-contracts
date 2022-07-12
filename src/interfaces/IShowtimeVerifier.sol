// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IShowtimeVerifier {
    struct Attestation {
        address beneficiary;
        address context;
        uint256 signedAt;
        uint256 validUntil;
    }

    error DeadlineTooLong();
    error Expired();
    error NullAddress();
    error SignerExpired(address signer);
    error TemporalAnomaly();
    error Unauthorized();
    error UnknownSigner(address signer);

    function verify(Attestation calldata attestation, bytes calldata signature) external view returns (bool);
    function setSignerManager(address _signerManager) external;
    function registerSigner(address signer, uint256 validityDays) external;
    function revokeSigner(address signer) external;
}
