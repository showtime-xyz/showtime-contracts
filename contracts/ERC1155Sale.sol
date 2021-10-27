// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/Counters.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { ERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/ERC1155Receiver.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Ownable, Context } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { IERC2981 } from "./IERC2981.sol";
import { BaseRelayRecipient } from "./utils/BaseRelayRecipient.sol";

contract ERC1155Sale is Ownable, Pausable, ERC1155Receiver, BaseRelayRecipient {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Address for address;

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    IERC1155 public nft;

    struct Listing {
        uint256 tokenId;
        uint256 amount;
        uint256 price;
        address currency;
        address seller;
    }

    // making it support non ERC2981 compliant NFTs also
    bool public royaltiesEnabled;

    mapping(address => bool) public acceptedCurrencies;

    /// @dev maps a listing id to the corresponding listing
    mapping(uint256 => Listing) public listings;

    Counters.Counter counter;

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
    event Buy(uint256 indexed saleId, address indexed seller, address indexed buyer, uint256 amount);
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
    /// @param _amount the price for each of the amount in the listing
    function createSale(
        uint256 _tokenId,
        uint256 _amount,
        uint256 _price,
        address _currency
    ) external returns (uint256 listingId) {
        require(acceptedCurrencies[_currency], "currency not accepted");

        nft.safeTransferFrom(_msgSender(), address(this), _tokenId, _amount, "");

        Listing memory listing = Listing({
            tokenId: _tokenId,
            amount: _amount,
            price: _price,
            currency: _currency,
            seller: _msgSender()
        });

        listingId = counter.current();
        listings[listingId] = listing;

        counter.increment();

        emit New(listingId, _msgSender(), _tokenId);
    }

    /// @notice cancel an active sale
    function cancelSale(uint256 _listingId) external listingExists(_listingId) onlySeller(_listingId) {
        Listing memory listing = listings[_listingId];

        delete listings[_listingId];

        emit Cancel(_listingId, _msgSender());

        nft.safeTransferFrom(address(this), listing.seller, listing.tokenId, listing.amount, "");
    }

    /// @notice Complete a sale
    /// @param _whom the recipient address
    function buyFor(
        uint256 _listingId,
        uint256 _amount,
        address _whom
    ) external listingExists(_listingId) whenNotPaused {
        require(_whom != address(0), "invalid _whom address");

        Listing memory listing = listings[_listingId];
        require(_amount <= listing.amount, "required amount greater than available amount");

        uint256 price = listing.price.mul(_amount);

        // we let the transaction complete even if the currency is no longer accepted
        // in order to avoid stuck listings
        IERC20 quoteToken = IERC20(listing.currency);
        if (royaltiesEnabled) {
            (address receiver, uint256 royaltyAmount) = _royaltyInfo(listing.tokenId, price);

            // we ignore royalties to address 0, otherwise the transfer would fail
            // and it would result in NFTs that are impossible to sell
            if (receiver != address(0) && royaltyAmount > 0) {
                require(royaltyAmount <= price, "royalty amount too big");

                emit RoyaltyPaid(receiver, royaltyAmount);
                price = price.sub(royaltyAmount);

                quoteToken.safeTransferFrom(_msgSender(), receiver, royaltyAmount);
            }
        }

        // update the amount in the listing or delete it if everything has been sold
        if (_amount == listing.amount) {
            delete listings[_listingId];
        } else {
            listings[_listingId].amount -= _amount;
        }

        emit Buy(_listingId, listing.seller, _whom, _amount);

        // perform the exchange
        quoteToken.safeTransferFrom(_msgSender(), listing.seller, price);
        nft.safeTransferFrom(address(this), _whom, listing.tokenId, _amount, "");
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

    //
    // CONTRACT SETTINGS
    //

    /// @notice switch royalty payments on/off
    function royaltySwitch(bool enabled) external onlyOwner {
        require(royaltiesEnabled != enabled, "royalty already on the desired state");
        royaltiesEnabled = enabled;
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

    //
    // IMPLEMENT ERC1155 RECEIVER
    //
    function onERC1155Received(
        address, // operator
        address, // from
        uint256, // id
        uint256, // value
        bytes calldata // data
    ) external override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address, // operator
        address, // from
        uint256[] calldata, // ids
        uint256[] calldata, // values
        bytes calldata // data
    ) external override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
