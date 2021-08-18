// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract ERC1155NFT is ERC1155("some-uri") {
    function mint(
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) external {
        _mint(msg.sender, _id, _amount, _data);
    }

    function mintBatch(
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) external {
        _mintBatch(msg.sender, _ids, _amounts, _data);
    }
}
