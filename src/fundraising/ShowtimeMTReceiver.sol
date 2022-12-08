// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import {ERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";

contract ShowtimeMTReceiver is ERC1155Receiver {
    address public immutable showtimeMT;

    error UnexpectedERC1155Transfer(address _nftContract, uint256 id);
    error UnexpectedERC1155BatchTransfer(address _nftContract, uint256[] ids);

    constructor(address _showtimeMT) {
        showtimeMT = _showtimeMT;
    }

    /// Accept transfers from ShowtimeMT
    function onERC1155Received(
        address, /* operator */
        address, /* from */
        uint256 id,
        uint256, /* value */
        bytes calldata /* data */
    ) external view override returns (bytes4) {
        if (msg.sender != showtimeMT) {
            revert UnexpectedERC1155Transfer(msg.sender, id);
        }
        return this.onERC1155Received.selector;
    }

    /// Accept batch transfers from ShowtimeMT
    function onERC1155BatchReceived(
        address, /* operator */
        address, /* from */
        uint256[] calldata ids,
        uint256[] calldata, /* values */
        bytes calldata /* data */
    ) external view override returns (bytes4) {
        if (msg.sender != showtimeMT) {
            revert UnexpectedERC1155BatchTransfer(msg.sender, ids);
        }
        return this.onERC1155BatchReceived.selector;
    }
}
