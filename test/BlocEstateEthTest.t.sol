// SPDX-License-Identifier : MIT

pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {BlocEstateEthScript} from "../script/BlocEstateEthScript.s.sol";
import {BlocEstateEth} from "../src/BlocEstateEth.sol";

contract BlocEstateEthTest is Test {
    //
    BlocEstateEthScript blocEstateEthScript;
    BlocEstateEth blocEstateEth;

    address private constant BOB = address(1);
    address private constant ALICE = address(2);

    modifier registerNewBidder(
        address _creator,
        uint256 _startPrice,
        uint256 _openTimestamp,
        uint256 _closeTimestamp
    ) {
        vm.startPrank(_creator);
        blocEstateEth.registerAuction(
            _startPrice,
            _openTimestamp,
            _closeTimestamp
        );
        vm.stopPrank();
        _;
    }

    modifier addNewBidder(
        address _bidder,
        uint256 _auctionId,
        uint256 _amount
    ) {
        hoax(_bidder, _amount);
        blocEstateEth.bidRealEstate{value: _amount}(_auctionId);
        _;
    }

    function setUp() public {
        blocEstateEthScript = new BlocEstateEthScript();
        blocEstateEth = blocEstateEthScript.run();
    }

    function testSuccessfullyRegisterNewAuction()
        public
        registerNewBidder(
            BOB,
            2 ether,
            block.timestamp,
            block.timestamp + 1 minutes
        )
    {
        uint256 actualAuctionTotal = blocEstateEth.getAuctionList().length;
        uint256 expectAuctionTotal = 1;

        assertEq(actualAuctionTotal, expectAuctionTotal);
    }

    function testSuccessfullyPlaceABid()
        public
        registerNewBidder(
            BOB,
            1 ether,
            block.timestamp,
            block.timestamp + 1 minutes
        )
        addNewBidder(ALICE, 0, 2 ether)
    {
        uint256 actualTotalBid = blocEstateEth.getAuctionBidders(0).length;
        uint256 expectTotalBid = 1;

        uint256 actualBidderBalance = address(ALICE).balance;
        uint256 expectBidderBalance = 0 ether;

        uint256 actualSmartContractBalance = address(blocEstateEth).balance;
        uint256 expectSmartContractBalance = 1 ether;

        uint256 actualCreatorBalance = address(BOB).balance;
        uint256 expectCreatorBalance = 0 ether;

        assertEq(actualTotalBid, expectTotalBid);
        assertEq(actualBidderBalance, expectBidderBalance);
        // assertEq(actualSmartContractBalance, expectSmartContractBalance);
        assertEq(actualCreatorBalance, expectCreatorBalance);
    }

    function testSuccessfullyRefundToBidder() public {}

    //
}
