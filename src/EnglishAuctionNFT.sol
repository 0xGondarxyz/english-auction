// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {Auction} from "./Auction.sol";

contract EnglishAuctionNFT is ERC721, ERC721URIStorage, Ownable {
    // using Counters for Counters.Counter;

    uint256 private _tokenIdCounter;
    Auction public auctionContract;

    event NFTMinted(address indexed to, uint256 indexed tokenId, string tokenURI);

    modifier onlyAuctionContract() {
        require(
            msg.sender == address(auctionContract), "EnglishAuctionNFT: Only auction contract can call this function"
        );
        _;
    }

    constructor(address initialOwner, address _auctionContract)
        ERC721("EnglishAuctionNFT", "EANFT")
        Ownable(initialOwner)
    {
        auctionContract = Auction(_auctionContract);
    }

    function mint(address to, string memory tokenURI) external onlyAuctionContract returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _mint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);

        emit NFTMinted(to, tokenId, tokenURI);
        return tokenId;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        //only auction contract or the owner of the NFT can burn the NFT
        require(
            msg.sender == address(auctionContract) || msg.sender == ownerOf(tokenId),
            "EnglishAuctionNFT: Only auction contract or the owner of the NFT can burn the NFT"
        );
        super._burn(tokenId);
    }
}
