// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

struct Attestation {
    address beneficiary;
    address context;
    uint256 signedAt;
    uint256 validUntil;
}

interface IShowtimeVerifier {
    error DeadlineTooLong();
    error Expired();
    error NullAddress();
    error SignerExpired(address signer);
    error TemporalAnomaly();
    error Unauthorized();
    error UnknownSigner(address signer);

    event SignerAdded(address signer, uint256 validUntil);
    event SignerRevoked(address signer);
    event SignerManagerUpdated(address newSignerManager);

    function verify(Attestation calldata attestation, bytes calldata signature) external view returns (bool);
    function setSignerManager(address _signerManager) external;
    function registerSigner(address signer, uint256 validityDays) external;
    function revokeSigner(address signer) external;
}
