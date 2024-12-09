// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";

contract BlocEstateEth {
    //
    mapping(uint256 auctionId => Bid[] bid) private s_bidFromUser;
    mapping(uint256 auctionId => mapping(address user => uint256 bidAmount))
        private s_userBidAmount;

    error MustBeGreaterThanHighestPrice();
    error AuctionWinnerCannotWithdrawEth();
    error OnlyOwnerCanWithdraw();
    error NonExistingBidder();
    error TransferFailed();
    error AuctionNotStartedYet();
    error AuctionNotClosedYet();
    error InvalidField();

    event NewAuctionRegistered(
        uint256 indexed auctionId,
        address indexed seller
    );
    event TransferSuccessfully(
        uint256 indexed auctionId,
        address indexed user,
        uint256 indexed bidAmount
    );
    event BidPlacedSuccessfully(
        uint256 indexed auctionId,
        address indexed user,
        uint256 indexed bidAmount
    );

    struct Auction {
        uint256 id;
        address seller;
        uint256 startPrice;
        uint256 openTimestamp;
        uint256 closeTimestamp;
    }
    struct Bid {
        address user;
        uint256 bidAmount;
        uint256 timestamp;
    }

    Auction[] private s_auctionList;

    modifier checkBidAmount(uint256 _auctionId, uint256 _bidAmount) {
        uint256 totalBid = _getTotalBid(_auctionId);
        uint256 startPrice = s_auctionList[_auctionId].startPrice;
        uint256 highestPrice = totalBid > 0
            ? _getAuctionHighestBid(_auctionId, totalBid).bidAmount
            : startPrice;
        if (_bidAmount <= highestPrice) {
            revert MustBeGreaterThanHighestPrice();
        }
        _;
    }

    modifier checkRecipientNotAWinner(uint256 _auctionId, address _user) {
        uint256 totalBid = _getTotalBid(_auctionId);
        address highestBidder = _getAuctionHighestBid(_auctionId, totalBid)
            .user;
        if (highestBidder == _user) {
            revert AuctionWinnerCannotWithdrawEth();
        }
        _;
    }

    modifier checkExistingBidder(uint256 _auctionId, address _user) {
        if (s_userBidAmount[_auctionId][_user] == 0) {
            revert NonExistingBidder();
        }
        _;
    }

    modifier checkAuctionAlreadyOpen(uint256 _auctionId) {
        if (s_auctionList[_auctionId].openTimestamp < block.timestamp) {
            revert AuctionNotStartedYet();
        }
        _;
    }

    modifier checkAuctionAlreadyEnded(uint256 _auctionId) {
        if (s_auctionList[_auctionId].closeTimestamp > block.timestamp) {
            revert AuctionNotClosedYet();
        }
        _;
    }

    modifier checkOwnership(uint256 _auctionId, address _user) {
        address owner = s_auctionList[_auctionId].seller;
        if (owner != _user) {
            revert OnlyOwnerCanWithdraw();
        }
        _;
    }

    modifier checkAuctionInput(
        uint256 _startPrice,
        uint256 _openTimestamp,
        uint256 _closeTimestamp
    ) {
        if (
            _startPrice <= 0 ||
            _openTimestamp <= 0 ||
            _closeTimestamp <= 0 ||
            _closeTimestamp <= block.timestamp ||
            _openTimestamp >= _closeTimestamp
        ) {
            revert InvalidField();
        }
        _;
    }

    // done
    function registerAuction(
        uint256 _startPrice,
        uint256 _openTimestamp,
        uint256 _closeTimestamp
    ) external checkAuctionInput(_startPrice, _openTimestamp, _closeTimestamp) {
        _addNewAuctionData(_startPrice, _openTimestamp, _closeTimestamp);
    }

    // done
    function bidRealEstate(
        uint256 _auctionId
    )
        external
        payable
        checkAuctionAlreadyOpen(_auctionId)
        checkBidAmount(_auctionId, msg.value)
    {
        _checkBidAmountStatus(_auctionId, msg.sender, msg.value);
    }

    // done
    function refundToBidder(
        uint256 _auctionId
    )
        external
        checkExistingBidder(_auctionId, msg.sender)
        checkAuctionAlreadyEnded(_auctionId)
        checkRecipientNotAWinner(_auctionId, msg.sender)
    {
        _transferToUser(_auctionId, msg.sender, msg.sender);
    }

    function withdrawWinnerEth(
        uint256 _auctionId
    )
        external
        checkOwnership(_auctionId, msg.sender)
        checkAuctionAlreadyEnded(_auctionId)
    {
        _withdrawToOwnerAccount(_auctionId, msg.sender);
    }

    function getAuctionList() external view returns (Auction[] memory) {
        return s_auctionList;
    }

    function getAuctionBidders(
        uint256 _auctionId
    ) external view returns (Bid[] memory) {
        return s_bidFromUser[_auctionId];
    }

    function _addNewAuctionData(
        uint256 _startPrice,
        uint256 _openTimestamp,
        uint256 _closeTimestamp
    ) private {
        s_auctionList.push(
            Auction({
                id: s_auctionList.length,
                seller: msg.sender,
                startPrice: _startPrice,
                openTimestamp: _openTimestamp,
                closeTimestamp: _closeTimestamp
            })
        );
        emit NewAuctionRegistered(s_auctionList.length - 1, msg.sender);
    }

    function _checkBidAmountStatus(
        uint256 _auctionId,
        address _user,
        uint256 _bidAmount
    ) private {
        Bid memory newBid = Bid({
            user: msg.sender,
            bidAmount: msg.value,
            timestamp: block.timestamp
        });
        s_bidFromUser[_auctionId].push(newBid);
        s_userBidAmount[_auctionId][_user] += _bidAmount;
        emit BidPlacedSuccessfully(_auctionId, msg.sender, msg.value);
    }

    function _transferToUser(
        uint256 _auctionId,
        address _from,
        address _to
    ) private {
        uint256 refundValue = s_userBidAmount[_auctionId][_from];
        address payable recipient = payable(_to);
        bool transferStatus = recipient.send(refundValue);
        if (transferStatus) {
            s_userBidAmount[_auctionId][_from] = 0;
            emit TransferSuccessfully(_auctionId, _to, refundValue);
        } else {
            revert TransferFailed();
        }
    }

    function _withdrawToOwnerAccount(
        uint256 _auctionId,
        address _owner
    ) private {
        uint256 totalBid = _getTotalBid(_auctionId);
        address winner = _getAuctionHighestBid(_auctionId, totalBid).user;
        _transferToUser(_auctionId, winner, _owner);
    }

    function _getTotalBid(
        uint256 _auctionId
    ) private view returns (uint256 totalBid) {
        return s_bidFromUser[_auctionId].length;
    }

    function _getAuctionHighestBid(
        uint256 _auctionId,
        uint256 _totalBid
    ) private view returns (Bid memory bid) {
        return s_bidFromUser[_auctionId][_totalBid - 1];
    }
    //
}
