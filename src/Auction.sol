// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "./EnglishAuctionNFT.sol";

contract Auction is Ownable2Step, ReentrancyGuard, Pausable {
    EnglishAuctionNFT public nftContract;

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     *
     * Store auction data in a struct containing:
     *
     * NFT token ID
     * Seller address
     * Starting price
     * Current highest bid (starts at 0)
     * Current highest bidder (starts at address(0))
     * Auction end time (block.timestamp + duration)
     * Minimum bid increment
     * Status (active/ended/cancelled)
     */
    struct AuctionData {
        uint256 tokenId;
        address seller;
        uint256 startingPrice;
        uint256 highestBid;
        address highestBidder;
        uint256 duration;
        uint256 startTime;
        uint256 endTime;
        uint256 minimumBidIncrement;
        bool ended;
    }
    //we use this to store the amount of money that is pending to be returned to the bidder after being outbid
    mapping(address => uint256) public pendingReturns;
    //we use this to store the auctions
    mapping(uint256 => AuctionData) public auctions;

    event AuctionCreated(uint256 indexed tokenId, uint256 startingPrice, uint256 duration, uint256 minimumBidIncrement);
    event AuctionBid(uint256 indexed tokenId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed tokenId, address indexed winner, uint256 amount);
    event AuctionCancelled(uint256 indexed tokenId);

    function setNFTContract(address nftAddress) external onlyOwner {
        nftContract = EnglishAuctionNFT(nftAddress);
    }

    function createAuction(
        string memory tokenURI,
        uint256 startingPrice,
        uint256 duration,
        uint256 minimumBidIncrement
    ) external onlyOwner {
        // This will work because Auction contract is authorized
        uint256 tokenId = nftContract.mint(address(this), tokenURI);
        // ... rest of auction logic
        AuctionData memory auction = AuctionData({
            tokenId: tokenId,
            seller: msg.sender,
            startingPrice: startingPrice,
            highestBid: startingPrice,
            highestBidder: address(0),
            duration: duration,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            minimumBidIncrement: minimumBidIncrement,
            ended: false
        });
        auctions[tokenId] = auction;
        emit AuctionCreated(tokenId, startingPrice, duration, minimumBidIncrement);
    }

    function placeBid(uint256 tokenId) external payable {
        AuctionData storage auction = auctions[tokenId];
        //check that auction exists
        require(auction.endTime != 0, "Auction does not exist");
        require(!auction.ended, "Auction has ended");
        require(block.timestamp < auction.endTime, "Auction has ended");
        require(msg.value >= auction.highestBid + auction.minimumBidIncrement, "Bid too low");
        //if bid is withing the 10 minute period before the endTime, extend the auction by 10 minutes
        if (block.timestamp > auction.endTime - 600) {
            auction.endTime += 600;
        }
        //note this is not a safe approach
        // if (auction.highestBidder != address(0)) {
        //     payable(auction.highestBidder).transfer(auction.highestBid);
        // }
        pendingReturns[auction.highestBidder] = auction.highestBid;
        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;
        emit AuctionBid(tokenId, msg.sender, msg.value);
    }

    function endAuction(uint256 tokenId) external onlyOwner {}

    function cancelAuction(uint256 tokenId) external onlyOwner {}

    function withdrawPendingReturns() external nonReentrant {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No pending returns");
        pendingReturns[msg.sender] = 0;
        //use low level call
        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }

    function withdrawFunds() external onlyOwner {}

    //getter functions
    function getAuction(uint256 tokenId) external view returns (AuctionData memory) {
        return auctions[tokenId];
    }

    function getHighestBid(uint256 tokenId) external view returns (uint256) {
        return auctions[tokenId].highestBid;
    }

    function getHighestBidder(uint256 tokenId) external view returns (address) {
        return auctions[tokenId].highestBidder;
    }

    function getAuctionStatus(uint256 tokenId) external view returns (bool) {
        return auctions[tokenId].ended;
    }

    function getAuctionEndTime(uint256 tokenId) external view returns (uint256) {
        return auctions[tokenId].endTime;
    }

    function getAuctionStartTime(uint256 tokenId) external view returns (uint256) {
        return auctions[tokenId].startTime;
    }

    function getRemainingTime(uint256 tokenId) external view returns (uint256) {
        return auctions[tokenId].endTime - block.timestamp;
    }
}
