// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { PaymentSplitter } from "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { ERC1155Burnable } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

import { ShowtimeV1Market } from "../ShowtimeV1Market.sol";
import { ShowtimeMTReceiver } from "./ShowtimeMTReceiver.sol";

/// This contract acts as a delegate for listings on the showtime.io marketplace.
/// It allows trustless sales for 3rd parties such as charities.
///
/// Usage:
/// 1. deploy a copy of this contract with the appropriate payees and shares. The payees are immutable and auditable by anyone.
/// 2. anybody can mint a Showtime NFT with the royalties recipient set to the address of this contract
/// 3. (optional) the minter can verify what currencies are configured and the corresponding minimum sale price
/// 4. the minter transfers (some or all of the editions of) the Showtime NFT to this contract
/// 5. the deployer of the contract calls `createSale`
/// 6. (optional) the deployer calls `renounceOwnership()`, proving that the listing and the remaining supply will be permanently left untouched
/// 7. proceeds from primary sales and secondary sales will accrue in this contract
/// 8. anybody can call `release(IERC20 token, address account)` to disperse the funds to the recipients
contract ShowtimeSplitterSeller is PaymentSplitter, ShowtimeMTReceiver, Ownable {
    /// Immutable storage
    IERC1155 public immutable showtimeMT;
    ShowtimeV1Market public immutable showtimeMarket;

    /// Mutable storage
    mapping(address => uint256) public minPriceByCurrency;

    /// Errors
    error MustConfigureCurrencies();
    error MinPricesCurrenciesLengthMismatch();
    error InvalidMinPrice();
    error InvalidCurrency();
    error CurrencyNotConfigured();
    error PriceTooLow();

    event MinPriceSet(address currency, uint256 minPrice);

    constructor(
        address _showtimeMT,
        ShowtimeV1Market _showtimeMarket,
        address[] memory _currencies,
        uint256[] memory _minPrices,
        address[] memory _payees,
        uint256[] memory _shares
    ) PaymentSplitter(_payees, _shares) ShowtimeMTReceiver(_showtimeMT) {
        // configure the min price by currency
        uint256 length = _currencies.length;
        if (length == 0) {
            revert MustConfigureCurrencies();
        }
        if (length != _minPrices.length) {
            revert MinPricesCurrenciesLengthMismatch();
        }

        for (uint256 i = 0; i < length; i++) {
            address currency = _currencies[i];
            if (currency == address(0)) {
                revert InvalidCurrency();
            }

            uint256 minPrice = _minPrices[i];
            if (minPrice == 0) {
                revert InvalidMinPrice();
            }

            minPriceByCurrency[currency] = minPrice;
            emit MinPriceSet(currency, minPrice);
        }

        // configure the NFT and market
        showtimeMT = IERC1155(_showtimeMT);
        showtimeMarket = _showtimeMarket;

        IERC1155(_showtimeMT).setApprovalForAll(address(_showtimeMarket), true);
    }

    function createSale(
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _price,
        address _currency
    ) external onlyOwner returns (uint256 listingId) {
        uint256 minPrice = minPriceByCurrency[_currency];
        if (minPrice == 0) {
            revert CurrencyNotConfigured();
        }
        if (_price < minPrice) {
            revert PriceTooLow();
        }

        listingId = showtimeMarket.createSale(_tokenId, _quantity, _price, _currency);
    }

    function cancelSale(uint256 listingId) external onlyOwner {
        showtimeMarket.cancelSale(listingId);
    }

    /// @notice by design, the NFTs transferred to this contract can not be withdrawn
    ///         so that the minter does not need to trust the contract deployer
    function burn(uint256 _tokenId) external onlyOwner {
        ERC1155Burnable(address(showtimeMT)).burn(
            address(this),
            _tokenId,
            showtimeMT.balanceOf(address(this), _tokenId)
        );
    }
}
