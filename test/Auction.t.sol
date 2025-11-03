// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Auction} from "../src/Auction.sol";
import {EnglishAuctionNFT} from "../src/EnglishAuctionNFT.sol";
// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AuctionTest is Test {
    Auction auction;
    EnglishAuctionNFT nft;

    address public owner = makeAddr("owner");
    address public bidder1 = makeAddr("bidder1");
    address public bidder2 = makeAddr("bidder2");
    address public bidder3 = makeAddr("bidder3");

    function setUp() public {
        nft = new EnglishAuctionNFT(owner);
        auction = new Auction(owner);

        vm.startPrank(owner);
        auction.setNFTContract(address(nft));
        nft.setAuctionContract(address(auction));
        vm.stopPrank();

        //deal 100 eth to bidders
        vm.deal(bidder1, 100 ether);
        vm.deal(bidder2, 100 ether);
        vm.deal(bidder3, 100 ether);
    }

    function testCreateAuction() public {
        vm.startPrank(owner);
        auction.createAuction("tokenURI", 1 ether, 10 minutes, 0.1 ether);
        vm.stopPrank();
    }

    function test_onlyOwnerCanCreateAuction() public {
        vm.startPrank(bidder1);
        vm.expectRevert();
        auction.createAuction("tokenURI", 1 ether, 10 minutes, 0.1 ether);
        vm.stopPrank();
    }

    function test_onlyAuctionContractCanMintNFT() public {
        vm.startPrank(owner);
        vm.expectRevert();
        nft.mint(owner, "tokenURI");
        vm.stopPrank();
    }

    function test_usersCanBid() public {
        //create auction
        vm.startPrank(owner);
        auction.createAuction("tokenURI", 1 ether, 60 minutes, 0.1 ether);
        vm.stopPrank();
        //bid
        vm.startPrank(bidder1);
        //should fail with Bid too low
        vm.expectRevert("Bid too low");
        auction.placeBid{value: 1 ether}(0);
        //this should pass fine
        auction.placeBid{value: 1.1 ether}(0);
        vm.stopPrank();
    }

    function test_multipleUsersBid() public {
        //create auction
        vm.startPrank(owner);
        auction.createAuction("tokenURI", 1 ether, 60 minutes, 0.1 ether);
        vm.stopPrank();
        //bid
        vm.startPrank(bidder1);
        auction.placeBid{value: 1.1 ether}(0);
        vm.stopPrank();
        //bid
        vm.startPrank(bidder2);
        auction.placeBid{value: 1.2 ether}(0);
        vm.stopPrank();
        //bid
        vm.startPrank(bidder3);
        //should fail with Bid too low
        vm.expectRevert("Bid too low");
        auction.placeBid{value: 1.2 ether}(0);
        //this should pass fine
        auction.placeBid{value: 1.3 ether}(0);
        vm.stopPrank();
    }

    function test_cannotBidToNonexistentAuction() public {
        vm.startPrank(bidder1);
        vm.expectRevert("Auction does not exist");
        auction.placeBid{value: 1 ether}(0);
        vm.stopPrank();
    }

    function test_cannotBidToWrongID() public {
        //create auction
        vm.startPrank(owner);
        auction.createAuction("tokenURI", 1 ether, 60 minutes, 0.1 ether);
        vm.stopPrank();
        //bid
        vm.startPrank(bidder1);
        vm.expectRevert("Auction does not exist");
        auction.placeBid{value: 1.1 ether}(1);
        vm.stopPrank();
    }

    function test_biddingLastMinuteExtendsAuctionEndTime() public {
        //create auction
        vm.startPrank(owner);
        auction.createAuction("tokenURI", 1 ether, 60 minutes, 0.1 ether);
        vm.stopPrank();
        //bid
        vm.startPrank(bidder1);
        auction.placeBid{value: 1.1 ether}(0);
        vm.stopPrank();

        //get auction end time
        uint256 endTime = auction.getAuctionEndTime(0);
        console.log("End time: ", endTime);

        //wait for 59 minutes
        vm.warp(block.timestamp + 59 minutes);
        //bid
        vm.startPrank(bidder2);
        auction.placeBid{value: 1.2 ether}(0);
        vm.stopPrank();

        //get auction end time extended
        uint256 endTimeExtended = auction.getAuctionEndTime(0);
        console.log("End time extended: ", endTimeExtended);

        assert(endTimeExtended > endTime);
        assert(endTimeExtended == endTime + 10 minutes);
    }

    function test_ownerCanEndAuctionAtAnyTime() public {
        //create auction
        vm.startPrank(owner);
        auction.createAuction("tokenURI", 1 ether, 60 minutes, 0.1 ether);
        vm.stopPrank();

        //bidder1 bids
        vm.startPrank(bidder1);
        auction.placeBid{value: 1.1 ether}(0);
        vm.stopPrank();

        //warp 60 minutes
        vm.warp(block.timestamp + 60 minutes);
        //end auction
        vm.startPrank(owner);
        auction.endAuction(0);
        vm.stopPrank();

        //assert auction ended (returns boolean), 0 is the auction id, do not confuse with enums, we're not using enums
        assert(auction.getAuctionStatus(0));

        //bidder can't bid now
        vm.startPrank(bidder2);
        vm.expectRevert("Auction has ended");
        auction.placeBid{value: 1.2 ether}(0);
        vm.stopPrank();
    }

    function test_winnerClaimNFT() public {
        //create auction
        vm.startPrank(owner);
        auction.createAuction("tokenURI", 1 ether, 60 minutes, 0.1 ether);
        vm.stopPrank();

        //bidder1 bids
        vm.startPrank(bidder1);
        auction.placeBid{value: 1.1 ether}(0);
        vm.stopPrank();

        //warp 20 minutes
        vm.warp(block.timestamp + 20 minutes);

        //bidder 2 bids
        vm.startPrank(bidder2);
        auction.placeBid{value: 1.2 ether}(0);
        vm.stopPrank();

        //warp 50 minutes, which will mean the auction will end
        vm.warp(block.timestamp + 50 minutes);

        //end auction
        vm.startPrank(owner);
        auction.endAuction(0);
        vm.stopPrank();

        //assert auction ended (returns boolean), 0 is the auction id, do not confuse with enums, we're not using enums
        assert(auction.getAuctionStatus(0));

        //bidder1 cannot claim NFT
        vm.startPrank(bidder1);
        vm.expectRevert("Not the highest bidder");
        auction.claimNFT(0);
        vm.stopPrank();

        //bidder 2 claims NFT
        vm.startPrank(bidder2);
        auction.claimNFT(0);
        vm.stopPrank();

        //assert bidder 2 owns NFT
        assert(nft.ownerOf(0) == bidder2);
    }
}

