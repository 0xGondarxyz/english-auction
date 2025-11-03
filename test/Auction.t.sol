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

    function test_auctionEnds() public {
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

    function test_thereCanBeParallelAuctions() public {
        //create auction
        vm.startPrank(owner);
        auction.createAuction("tokenURI", 1 ether, 60 minutes, 0.1 ether);
        vm.stopPrank();

        //create another auction
        vm.startPrank(owner);
        auction.createAuction("tokenURI", 5 ether, 60 minutes, 0.1 ether);
        vm.stopPrank();

        //bidder1 bids for auction id 0
        vm.startPrank(bidder1);
        auction.placeBid{value: 1.1 ether}(0);
        vm.stopPrank();

        //bidder2 bids for auction id 0
        vm.startPrank(bidder2);
        auction.placeBid{value: 2.1 ether}(0);
        vm.stopPrank();

        //bidder1 bids for auction id 1
        vm.startPrank(bidder1);
        auction.placeBid{value: 5.2 ether}(1);
        vm.stopPrank();
    }

    function test_endAuctionNoBids() public {
        //create auction
        vm.startPrank(owner);
        auction.createAuction("tokenURI", 1 ether, 60 minutes, 0.1 ether);
        vm.stopPrank();

        //warp 60 minutes
        vm.warp(block.timestamp + 60 minutes);

        //end auction
        vm.startPrank(owner);
        auction.endAuction(0);
        vm.stopPrank();

        //assert auction ended (returns boolean), 0 is the auction id, do not confuse with enums, we're not using enums
        assert(auction.getAuctionStatus(0));

        //nft is burned
        //non existent token error
        vm.expectRevert("ERC721NonexistentToken(0)");
        nft.ownerOf(0);
    }

    function test_endAuctionFailsIfTimeHasNotPassed() public {
        //create auction
        vm.startPrank(owner);
        auction.createAuction("tokenURI", 1 ether, 60 minutes, 0.1 ether);
        vm.stopPrank();

        //warp 50 minutes
        vm.warp(block.timestamp + 50 minutes);

        //end auction
        vm.startPrank(owner);
        vm.expectRevert("Auction has not ended");
        auction.endAuction(0);
        vm.stopPrank();
    }

    function test_cancelAuctionIfNoBids() public {
        //create auction
        vm.startPrank(owner);
        auction.createAuction("tokenURI", 1 ether, 60 minutes, 0.1 ether);
        vm.stopPrank();

        //cancel auction
        vm.startPrank(owner);
        auction.cancelAuction(0);
        vm.stopPrank();

        //assert auction ended (returns boolean), 0 is the auction id, do not confuse with enums, we're not using enums
        assert(auction.getAuctionStatus(0));

        //nft is burned
        //non existent token error
        vm.expectRevert("ERC721NonexistentToken(0)");
        nft.ownerOf(0);
    }

    function test_cancelAuctionFailsIfThereAreBids() public {
        //create auction
        vm.startPrank(owner);
        auction.createAuction("tokenURI", 1 ether, 60 minutes, 0.1 ether);
        vm.stopPrank();

        //bidder1 bids
        vm.startPrank(bidder1);
        auction.placeBid{value: 1.1 ether}(0);
        vm.stopPrank();

        //cancel auction
        vm.startPrank(owner);
        vm.expectRevert("Auction has bidders already");
        auction.cancelAuction(0);
        vm.stopPrank();
    }

    function test_withdrawPendingReturns() public {
        //create auction
        vm.startPrank(owner);
        auction.createAuction("tokenURI", 1 ether, 60 minutes, 0.1 ether);
        vm.stopPrank();

        //bidder1 bids
        vm.startPrank(bidder1);
        auction.placeBid{value: 1.1 ether}(0);
        vm.stopPrank();

        //get bidder 1 balance
        uint256 bidder1Balance = bidder1.balance;

        //bidder2 bids
        vm.startPrank(bidder2);
        auction.placeBid{value: 1.2 ether}(0);
        vm.stopPrank();

        //bidder2 can't withdraw
        vm.startPrank(bidder2);
        vm.expectRevert("Highest bidder cannot withdraw");
        auction.withdrawPendingReturns(0);
        vm.stopPrank();

        //bidder1 withdraws
        vm.startPrank(bidder1);
        auction.withdrawPendingReturns(0);
        vm.stopPrank();

        //get bidder 1 balance after withdraw
        uint256 bidder1BalanceAfterWithdraw = bidder1.balance;

        //assert bidder 1 balance is higher
        assert(bidder1BalanceAfterWithdraw == bidder1Balance + 1.1 ether);
    }

    function test_multipleAuctionBidding() public {
        //create auction
        vm.startPrank(owner);
        auction.createAuction("tokenURI", 1 ether, 60 minutes, 0.1 ether);
        vm.stopPrank();

        //create another auction
        vm.startPrank(owner);
        auction.createAuction("tokenURI", 5 ether, 60 minutes, 0.1 ether);
        vm.stopPrank();

        //get bidders balances
        uint256 bidder1Balance = bidder1.balance;
        uint256 bidder2Balance = bidder2.balance;

        //bidder1 bids for auction id 0
        vm.startPrank(bidder1);
        auction.placeBid{value: 1.1 ether}(0);
        vm.stopPrank();

        //bidder2 bids for auction id 0
        vm.startPrank(bidder2);
        auction.placeBid{value: 2.1 ether}(0);
        vm.stopPrank();

        //bidder1 bids for auction id 1
        vm.startPrank(bidder1);
        auction.placeBid{value: 5.2 ether}(1);
        vm.stopPrank();

        //bidder2 bids for auction id 1
        vm.startPrank(bidder2);
        auction.placeBid{value: 6.2 ether}(1);
        vm.stopPrank();

        //bidder1 withdraws from auction id 0
        vm.startPrank(bidder1);
        auction.withdrawPendingReturns(0);
        vm.stopPrank();

        //get bidder 1 balance after withdraw
        uint256 bidder1BalanceAfterWithdraw = bidder1.balance;

        //assert bidder 1 balance only decreased by his bid amount to auction id 1
        //i.e. he got his bid amount back from the previous auction id of 0
        assert(bidder1BalanceAfterWithdraw == bidder1Balance - 5.2 ether);
    }

    function test_endAuction() public {
        //create auction
        vm.startPrank(owner);
        auction.createAuction("tokenURI", 1 ether, 60 minutes, 0.1 ether);
        vm.stopPrank();
        //get owner balance
        uint256 ownerBalance = owner.balance;

        //bidder1 bids
        vm.startPrank(bidder1);
        auction.placeBid{value: 1.1 ether}(0);
        vm.stopPrank();

        //bidder2 bids
        vm.startPrank(bidder2);
        auction.placeBid{value: 1.2 ether}(0);
        vm.stopPrank();

        vm.warp(block.timestamp + 60 minutes);

        //end auction
        vm.startPrank(owner);
        auction.endAuction(0);
        vm.stopPrank();

        //assert auction ended (returns boolean), 0 is the auction id, do not confuse with enums, we're not using enums
        assert(auction.getAuctionStatus(0));

        //assert owner balance is higher
        assert(owner.balance == ownerBalance + 1.2 ether);
    }
}

