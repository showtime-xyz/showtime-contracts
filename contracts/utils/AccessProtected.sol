// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

abstract contract AccessProtected is Context, Ownable {
    mapping(address => bool) private _admins; // user address => admin? mapping
    mapping(address => bool) private _minters; // user address => minter? mapping

    event UserAccessSet(address _user, string _access, bool _enabled);

    /**
     * @notice Set Admin Access
     *
     * @param admin - Address of Minter
     * @param enabled - Enable/Disable Admin Access
     */
    function setAdmin(address admin, bool enabled) external onlyOwner {
        _admins[admin] = enabled;
        emit UserAccessSet(admin, "ADMIN", enabled);
    }

    /**
     * @notice Set Minter Access
     *
     * @param minter - Address of Minter
     * @param enabled - Enable/Disable Admin Access
     */
    function setMinter(address minter, bool enabled) external onlyAdmin {
        _minters[minter] = enabled;
        emit UserAccessSet(minter, "MINTER", enabled);
    }

    /**
     * @notice Check Admin Access
     *
     * @param admin - Address of Admin
     * @return whether minter has access
     */
    function isAdmin(address admin) public view returns (bool) {
        return _admins[admin];
    }

    /**
     * @notice Check Minter Access
     *
     * @param minter - Address of minter
     * @return whether minter has access
     */
    function isMinter(address minter) public view returns (bool) {
        return _minters[minter];
    }

    /**
     * Throws if called by any account other than the Admin/Owner.
     */
    modifier onlyAdmin() {
        require(
            _admins[_msgSender()] || _msgSender() == owner(),
            "AccessProtected: caller is not admin"
        );
        _;
    }

    /**
     * Throws if called by any account other than the Minter/Admin/Owner.
     */
    modifier onlyMinter() {
        require(
            _minters[_msgSender()] ||
                _admins[_msgSender()] ||
                _msgSender() == owner(),
            "AccessProtected: caller is not minter"
        );
        _;
    }
}
