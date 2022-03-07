// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { PaymentSplitter } from "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import { ShowtimeMTReceiver } from "./ShowtimeMTReceiver.sol";

interface IShowtimeV1Market {
    function createSale(
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _price,
        address _currency
    ) external returns (uint256 listingId);

    function cancelSale(uint256 _listingId) external;
}

/// This contract acts as a delegate for listings on the showtime.io marketplace.
/// It allows trustless sales for 3rd parties such as charities.
///
/// Usage:
/// 1. deploy a copy of this contract with the appropriate payees and shares. The payees are immutable and auditable by anyone.
/// 2. anybody can mint a Showtime NFT with the royalties recipient set to the address of this contract
/// 3. the minter transfers (some or all of the editions of) the Showtime NFT to this contract
/// 4. the deployer of the contract calls `createSale`
/// 5. (optional) the deployer calls `renounceOwnership()`, proving that the listing and the remaining supply will be permanently left untouched
/// 6. proceeds from primary sales will accrue in this contract (and secondary sales if it the NFTs use it as the royalties recipient address)
/// 7. anybody can call `release(IERC20 token, address account)` to disperse the funds to the recipients
contract ShowtimeBakeSale is PaymentSplitter, ShowtimeMTReceiver, Ownable {
    IERC1155 public immutable showtimeMT;
    IShowtimeV1Market public immutable showtimeMarket;

    constructor(
        address _showtimeMT,
        address _showtimeMarket,
        address[] memory payees,
        uint256[] memory shares_
    ) PaymentSplitter(payees, shares_) ShowtimeMTReceiver(address(_showtimeMT)) {
        showtimeMT = IERC1155(_showtimeMT);
        showtimeMarket = IShowtimeV1Market(_showtimeMarket);

        IERC1155(_showtimeMT).setApprovalForAll(address(_showtimeMarket), true);
    }

    function createSale(
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _price,
        address _currency
    ) external onlyOwner returns (uint256 listingId) {
        listingId = showtimeMarket.createSale(_tokenId, _quantity, _price, _currency);
    }

    function cancelSale(uint256 listingId) external onlyOwner {
        showtimeMarket.cancelSale(listingId);
    }

    function withdraw(uint256 _tokenId, address to) external onlyOwner {
        uint howMany = showtimeMT.balanceOf(address(this), _tokenId);
        showtimeMT.safeTransferFrom(address(this), to, _tokenId, howMany, "");
    }
}
