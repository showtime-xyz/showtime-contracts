// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Ownable, Context } from "@openzeppelin/contracts/access/Ownable.sol";
import { Math } from "@openzeppelin/contracts/math/Math.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { IERC2981 } from "./IERC2981.sol";
import { BaseRelayRecipient } from "./utils/BaseRelayRecipient.sol";

contract ERC1155Sale is Ownable, Pausable, BaseRelayRecipient {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Address for address;

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    IERC1155 public nft;

    struct Listing {
        uint256 tokenId;
        uint256 quantity;
        uint256 price;
        IERC20 currency;
        address seller;
    }

    // making it support non ERC2981 compliant NFTs also
    bool public royaltiesEnabled;

    /// @notice the cap on royalties, configurable and enforced during the sale
    /// @notice 50% by default
    uint256 public maxRoyaltiesBasisPoints = 50_00;

    mapping(address => bool) public acceptedCurrencies;

    /// @dev maps a listing id to the corresponding listing
    mapping(uint256 => Listing) public listings;

    uint256 listingCounter;

    modifier onlySeller(uint256 _id) {
        require(listings[_id].seller == _msgSender(), "caller not seller");
        _;
    }

    modifier listingExists(uint256 _id) {
        require(listings[_id].seller != address(0), "listing doesn't exist");
        _;
    }

    event New(uint256 indexed saleId, address indexed seller, uint256 indexed tokenId);
    event Cancel(uint256 indexed saleId, address indexed seller);
    event Buy(uint256 indexed saleId, address indexed seller, address indexed buyer, uint256 quantity);
    event Deleted(uint256 indexed saleId, address indexed seller);
    event RoyaltyPaid(address indexed receiver, uint256 amount);

    constructor(address _nft, address[] memory _initialCurrencies) public {
        require(_nft.isContract(), "must be contract address");
        for (uint256 i = 0; i < _initialCurrencies.length; i++) {
            require(_initialCurrencies[i].isContract(), "_initialCurrencies must contain contract addresses");
            acceptedCurrencies[_initialCurrencies[i]] = true;
        }

        nft = IERC1155(_nft);

        // is royalty standard compliant? if so turn royalties on
        royaltiesEnabled = nft.supportsInterface(_INTERFACE_ID_ERC2981);
    }

    /**
     * Set Trusted Forwarder
     *
     * @param _trustedForwarder - Trusted Forwarder address
     */
    function setTrustedForwarder(address _trustedForwarder) external onlyOwner {
        trustedForwarder = _trustedForwarder;
    }

    /// @notice `setApprovalForAll` before calling
    /// @notice creates a new Listing
    /// @param _quantity the number of tokens to be listed
    /// @param _price the price per token
    function createSale(
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _price,
        address _currency
    ) external whenNotPaused returns (uint256 listingId) {
        require(acceptedCurrencies[_currency], "currency not accepted");
        require(_quantity > 0, "quantity must be greater than 0");

        Listing memory listing = Listing({
            tokenId: _tokenId,
            quantity: _quantity,
            price: _price,
            currency: IERC20(_currency),
            seller: _msgSender()
        });

        listingId = listingCounter;
        listings[listingId] = listing;
        listingCounter++;

        emit New(listingId, _msgSender(), _tokenId);
    }

    /// @notice cancel an active sale
    function cancelSale(uint256 _listingId) external listingExists(_listingId) onlySeller(_listingId) {
        delete listings[_listingId];

        emit Cancel(_listingId, _msgSender());
    }

    /// @notice the seller may own fewer NFTs than the listed quantity
    function availableForSale(uint256 _listingId) public view listingExists(_listingId) returns (uint256) {
        Listing memory listing = listings[_listingId];
        return Math.min(nft.balanceOf(listing.seller, listing.tokenId), listing.quantity);
    }

    /// @notice Complete a sale
    /// @param _quantity the number of tokens to purchase
    /// @param _whom the recipient address
    function buyFor(
        uint256 _listingId,
        uint256 _quantity,
        address _whom
    ) external listingExists(_listingId) whenNotPaused {
        require(_whom != address(0), "invalid _whom address");

        Listing memory listing = listings[_listingId];
        uint256 availableQuantity = availableForSale(_listingId);
        require(_quantity <= availableQuantity, "required more than available quantity");

        uint256 price = listing.price.mul(_quantity);

        // we let the transaction complete even if the currency is no longer accepted
        // in order to avoid stuck listings
        IERC20 currency = listing.currency;
        if (royaltiesEnabled) {
            (address receiver, uint256 royaltyAmount) = _royaltyInfo(listing.tokenId, price);

            // we ignore royalties to address 0, otherwise the transfer would fail
            // and it would result in NFTs that are impossible to sell
            if (receiver != address(0) && royaltyAmount > 0) {
                royaltyAmount = capRoyalties(price, royaltyAmount);
                require(royaltyAmount <= price, "royalty amount too big");

                emit RoyaltyPaid(receiver, royaltyAmount);
                price = price.sub(royaltyAmount);

                currency.safeTransferFrom(_msgSender(), receiver, royaltyAmount);
            }
        }

        // update the listing with the remaining quantity, or delete it if everything has been sold
        if (_quantity == availableQuantity) {
            delete listings[_listingId];
            emit Deleted(_listingId, listing.seller);
        } else {
            listings[_listingId].quantity = availableQuantity.sub(_quantity);
        }

        emit Buy(_listingId, listing.seller, _whom, _quantity);

        // transfer $price $currency from the buyer to the seller
        currency.safeTransferFrom(_msgSender(), listing.seller, price);

        // transfer the NFTs from the seller to the buyer
        nft.safeTransferFrom(listing.seller, _whom, listing.tokenId, _quantity, "");
    }

    /**
     * returns the message sender
     */
    function _msgSender() internal view override(Context, BaseRelayRecipient) returns (address payable) {
        return BaseRelayRecipient._msgSender();
    }

    //
    // PRIVATE FUNCTIONS
    //

    function _royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        private
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        (receiver, royaltyAmount) = IERC2981(address(nft)).royaltyInfo(_tokenId, _salePrice);
    }

    function capRoyalties(uint256 salePrice, uint256 royaltyAmount) private view returns (uint256) {
        uint256 maxRoyaltiesAmount = salePrice.mul(maxRoyaltiesBasisPoints).div(100_00);
        return Math.min(maxRoyaltiesAmount, royaltyAmount);
    }

    //
    // CONTRACT SETTINGS
    //

    /// @notice switch royalty payments on/off
    function royaltySwitch(bool enabled) external onlyOwner {
        require(royaltiesEnabled != enabled, "royalty already on the desired state");
        royaltiesEnabled = enabled;
    }

    function setMaxRoyalties(uint256 _maxRoyaltiesBasisPoints) external onlyOwner {
        require(maxRoyaltiesBasisPoints < 100_00, "maxRoyaltiesBasisPoints must be less than 100%");
        maxRoyaltiesBasisPoints = _maxRoyaltiesBasisPoints;
    }

    /// @notice add a currency from the accepted currency list
    function setAcceptedCurrency(address _currency) external onlyOwner {
        require(_currency.isContract(), "_currency != contract address");
        acceptedCurrencies[_currency] = true;
    }

    /// @notice remove a currency from the accepted currency list
    function removeAcceptedCurrency(address _currency) external onlyOwner {
        require(acceptedCurrencies[_currency], "currency does not exist");
        acceptedCurrencies[_currency] = false;
    }

    /// @notice pause the contract
    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    /// @notice unpause the contract
    function unpause() external whenPaused onlyOwner {
        _unpause();
    }
}
