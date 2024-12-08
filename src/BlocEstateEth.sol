// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

contract BlocEstateEth {
    // 
    uint256 private s_auctionTotal;

    mapping(uint256 auctionId => address seller) private s_seller;
    mapping(uint256 auctionId => mapping(address user => uint256 amount)) private s_bidAmountFromUser;

    error InsufficientBalance();
    error NonExistingBidder();
    error RefundFailed();

    event RefundSuccessfully(uint256 indexed auctionId, address indexed user, uint256 indexed bidAmount);
    event NewSellerRegistered(uint256 indexed auctionId, address indexed seller);
    event BidPlacedSuccessfully(uint256 indexed auctionId, address indexed user, uint256 indexed bidAmount);

    modifier checkBalance(address _user, uint256 _bidAmount) {
        if (address(_user).balance < _bidAmount) {
            revert InsufficientBalance();
        }
        _;
    }

    modifier checkExistingBidder(uint256 _auctionId, address _user) {
        if (s_bidAmountFromUser[_auctionId][_user] == 0) {
            revert NonExistingBidder();
        }
        _;
    }

    function registerSellerAddress() external {
        s_seller[s_auctionTotal] = msg.sender;
        s_auctionTotal++;
        emit NewSellerRegistered(s_auctionTotal--, msg.sender);
    }

    function bidRealEstate(uint256 _auctionId) payable external checkBalance(msg.sender, msg.value) {
        s_bidAmountFromUser[_auctionId][msg.sender] += msg.value;
        emit BidPlacedSuccessfully(_auctionId, msg.sender, msg.value);
    }

    function refundToBidder(uint256 _auctionId) external checkExistingBidder(_auctionId, msg.sender) {
        uint256 refundValue = s_bidAmountFromUser[_auctionId][msg.sender];
        address payable recipient = payable(msg.sender);
        bool transferStatus = recipient.send(refundValue);
        if (transferStatus) {
            emit RefundSuccessfully(_auctionId, msg.sender, refundValue);
        } 
        else {
            revert RefundFailed();
        }
    }
    //
}
