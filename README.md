# English Auction NFT System

A Solidity smart contract system implementing an English (ascending price) auction for NFTs with automatic minting, bidding extensions, and secure fund withdrawal mechanisms.

## Overview

This system consists of two interconnected contracts:

- **EnglishAuctionNFT**: ERC721 NFT contract that mints tokens exclusively for auctions
- **Auction**: Main auction management contract handling bidding, settlements, and NFT transfers

## Core Logic

### Auction Lifecycle

1. **Creation** (Owner only)

   - Owner calls `createAuction()` with metadata URI, starting price, duration, and bid increment
   - NFT is automatically minted to the Auction contract
   - Auction begins immediately

2. **Bidding**

   - Users call `placeBid()` with ETH value meeting minimum requirements
   - Each bid must exceed `highestBid + minimumBidIncrement`
   - **Anti-sniping**: Bids in the final 10 minutes extend auction by 10 minutes
   - Previous highest bidder's funds move to `pendingReturns` (pull-over-push pattern)

3. **Ending**

   - Anyone can call `endAuction()` after `endTime` passes
   - If no bids: NFT is burned
   - If bids exist: ETH transfers to seller, NFT remains claimable

4. **NFT Claim**

   - Winner calls `claimNFT()` to receive the NFT after auction ends

5. **Cancellation** (Owner only)
   - Only possible if no bids placed yet
   - Burns the NFT

## Contract Structure

### Key State Variables

```solidity
mapping(uint256 => AuctionData) public auctions;  // tokenId => auction details
mapping(address => mapping(uint256 => uint256)) public pendingReturns;  // bidder => tokenId => amount
```

### AuctionData Struct

- `tokenId`, `seller`, pricing info (`startingPrice`, `highestBid`, `highestBidder`)
- Timing (`startTime`, `endTime`, `duration`)
- `minimumBidIncrement`, `ended` flag

## Important Design Patterns

### ✅ Security Features

- **ReentrancyGuard**: Prevents reentrancy attacks on bid/withdraw functions
- **Pull Payment Pattern**: Outbid users withdraw their own funds via `withdrawPendingReturns()`
- **Pausable**: Owner can pause bidding/claiming in emergencies
- **Ownable2Step**: Safe ownership transfer mechanism
- **Low-level calls**: Uses `.call{value}()` for ETH transfers with success checks

### ⚠️ Important Gotchas

1. **Centralization Risk**: Only owner can create auctions (no permissionless listing)

2. **Gas-Intensive Anti-Sniping**: The 10-minute extension can be triggered repeatedly, potentially extending auctions indefinitely if competitive bidding continues

3. **NFT Stuck Until Claimed**: Winner must manually call `claimNFT()` - NFT doesn't auto-transfer in `endAuction()`

4. **Burn on No-Bids**: If no one bids, the NFT is permanently destroyed (no recovery)

5. **Two-Step Setup Required**:

```solidity
   // Must call both in correct order:
   nftContract.setAuctionContract(auctionAddress);
   auction.setNFTContract(nftAddress);
```

6. **Withdrawal Restriction**: Current highest bidder cannot withdraw their pending returns (locked until outbid)

7. **Underflow Protection**: `getRemainingTime()` returns 0 after auction ends to prevent underflow

## Dependencies

- OpenZeppelin v4.x+
  - ERC721 (NFT standard)
  - Ownable/Ownable2Step (access control)
  - ReentrancyGuard (reentrancy protection)
  - Pausable (emergency stops)

## Usage Flow

```
1. Deploy EnglishAuctionNFT(owner)
2. Deploy Auction(owner)
3. Link contracts via setAuctionContract() and setNFTContract()
4. Owner creates auction → NFT minted
5. Users place bids → outbid amounts move to pendingReturns
6. Time expires → anyone calls endAuction() → seller gets ETH
7. Winner calls claimNFT() → receives NFT
8. Outbid users call withdrawPendingReturns() → get refunds
```

## Events

All major actions emit events for off-chain tracking:

- `AuctionCreated`, `AuctionBid`, `AuctionEnded`, `AuctionCancelled`
- `pendingReturnWithdrawn`, `NFTMinted`
