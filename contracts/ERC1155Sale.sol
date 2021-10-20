// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/ERC1155Receiver.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Ownable, Context } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { IERC2981 } from "./IERC2981.sol";
import { BaseRelayRecipient } from "./utils/BaseRelayRecipient.sol";

contract ERC1155Sale is Ownable, Pausable, ERC1155Receiver, BaseRelayRecipient {
    using SafeMath for uint256;
    using Address for address;

    IERC1155 public nft;

    struct Sale {
        uint256 tokenId;
        uint256 amount;
        uint256 price;
        address currency;
        address seller;
        bool isActive;
    }

    enum Royalty {
        OFF,
        ON
    } // making it support non ERC2981 compliant NFTs also
    Royalty public royalty;

    mapping(address => bool) public acceptedCurrencies;

    Sale[] public sales;

    modifier onlySeller(uint256 _saleId) {
        require(sales[_saleId].seller == _msgSender(), "caller not seller");
        _;
    }

    modifier isActive(uint256 _saleId) {
        require(sales[_saleId].isActive, "sale already cancelled or bought");
        _;
    }

    modifier saleExists(uint256 _saleId) {
        require(sales.length > _saleId, "sale doesn't exist");
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
        try nft.supportsInterface(0x2a55205a) returns (bool implementsERC2981) {
            if (implementsERC2981) {
                royalty = Royalty.ON;
            }
        } catch (bytes memory) {}
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
    /// @notice creates a new sale
    /// @param _amount the price for each of the amount in the listing
    function createSale(
        uint256 _tokenId,
        uint256 _amount,
        uint256 _price,
        address _currency
    ) external {
        require(acceptedCurrencies[_currency], "currency not accepted");
        nft.safeTransferFrom(_msgSender(), address(this), _tokenId, _amount, "");
        Sale memory sale = Sale({
            tokenId: _tokenId,
            amount: _amount,
            price: _price,
            currency: _currency,
            seller: _msgSender(),
            isActive: true
        });
        uint256 saleId = sales.length;
        sales.push(sale);

        emit New(saleId, _msgSender(), _tokenId);
    }

    /// @notice cancel an active sale
    function cancelSale(uint256 _saleId) external saleExists(_saleId) onlySeller(_saleId) isActive(_saleId) {
        Sale memory sale = sales[_saleId];
        // make sale invalid, and send seller his nft back
        sales[_saleId].isActive = false;
        nft.safeTransferFrom(address(this), sale.seller, sale.tokenId, sale.amount, "");

        emit Cancel(_saleId, _msgSender());
    }

    /**
     * Purhcase a sale
     * // TODO(karmacoma): based on this comment _whom=0x0 should send to _msgSender()
       // but it will actually attempt to transfer to 0x0 and fail
     * @param _whom if gifting, the recipient address, else address(0)
     */
    function buyFor(
        uint256 _saleId,
        uint256 _amount,
        address _whom
    ) external saleExists(_saleId) isActive(_saleId) whenNotPaused {
        Sale memory sale = sales[_saleId];
        require(_amount <= sale.amount, "required amount greater than available amount");
        sales[_saleId].amount -= _amount;
        if (sales[_saleId].amount == 0) {
            sales[_saleId].isActive = false;
        }

        uint256 price = sale.price.mul(_amount);
        IERC20 quoteToken = IERC20(sale.currency);
        quoteToken.transferFrom(_msgSender(), address(this), price);
        if (royalty == Royalty.ON) {
            // TODO(karmacoma): check that royaltyAmount < price?
            (address receiver, uint256 royaltyAmount) = _royaltyInfo(sale.tokenId, price);
            if (royaltyAmount > 0) {
                quoteToken.transfer(receiver, royaltyAmount);
                emit RoyaltyPaid(receiver, royaltyAmount);
                price = price.sub(royaltyAmount);
            }
        }
        quoteToken.transfer(sale.seller, price);
        nft.safeTransferFrom(address(this), _whom, sale.tokenId, _amount, "");

        emit Buy(_saleId, sale.seller, _whom, _amount);
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
    function royaltySwitch(Royalty _royalty) external onlyOwner {
        require(_royalty != royalty, "royalty already on the desired state");
        royalty = _royalty;
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
    /* solhint-disable no-unused-vars */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
    /* solhint-disable no-unused-vars */
}
