// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EnglishAuctionNFT is ERC721, ERC721URIStorage, Ownable {
    uint256 private _tokenIdCounter;
    address public auctionContract;

    event NFTMinted(address indexed to, uint256 indexed tokenId, string tokenURI);

    modifier onlyAuctionContract() {
        _onlyAuctionContract();
        _;
    }

    constructor(address initialOwner) ERC721("EnglishAuctionNFT", "EANFT") Ownable(initialOwner) {}

    function setAuctionContract(address auctionContractAddress) external onlyOwner {
        auctionContract = auctionContractAddress;
    }

    function mint(address to, string memory uri) external onlyAuctionContract returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;

        _mint(to, tokenId);
        _setTokenURI(tokenId, uri);

        emit NFTMinted(to, tokenId, uri);
        return tokenId;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    //modifier functions to reduce code size
    function _onlyAuctionContract() internal {
        require(msg.sender == auctionContract, "EnglishAuctionNFT: Only auction contract can call this function");
    }
}
