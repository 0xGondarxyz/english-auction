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
        vm.startPrank(owner);
        nft = new EnglishAuctionNFT();
        auction = new Auction(address(nft));
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
}

