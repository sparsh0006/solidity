// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title BasicNFT
 * @dev A simple NFT contract with minting functionality
 */
contract BasicNFT is ERC721Enumerable, Ownable {

    using Strings for uint256;
    string private _baseTokenURI;
    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.05 ether;
    uint256 public maxMintAmount = 5;
    bool public paused = false;

    /**
     * @dev Constructor initializes the contract with a name and symbol
     * @param _name Name of the NFT collection
     * @param _symbol Symbol of the NFT collection
     * @param initialOwner Address of the initial owner
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address initialOwner
    ) ERC721(_name, _symbol) Ownable(initialOwner) {}

    /**
     * @dev Modifier to check if contract is not paused
     */
    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    /**
     * @dev Mint function for users to mint NFTs
     * @param _mintAmount Number of NFTs to mint
     */
    function mint(uint256 _mintAmount) public payable whenNotPaused {
        require(_mintAmount > 0 && _mintAmount <= maxMintAmount, "Invalid mint amount");
        require(totalSupply() + _mintAmount <= maxSupply, "Max supply exceeded");
        require(msg.value >= mintPrice * _mintAmount, "Insufficient funds");

        for (uint256 i = 1; i <= _mintAmount; i++) {
            uint256 tokenId = totalSupply() + 1;
            _safeMint(msg.sender, tokenId);
        }
    }

    /**
     * @dev Owner can mint NFTs without paying
     * @param _to Recipient address
     * @param _mintAmount Number of NFTs to mint
     */
    function ownerMint(address _to, uint256 _mintAmount) public onlyOwner {
        require(totalSupply() + _mintAmount <= maxSupply, "Max supply exceeded");

        for (uint256 i = 1; i <= _mintAmount; i++) {
            uint256 tokenId = totalSupply() + 1;
            _safeMint(_to, tokenId);
        }
    }

    /**
     * @dev Sets the base URI for token metadata
     * @param baseURI New base URI
     */
    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    /**
     * @dev Sets the mint price
     * @param _mintPrice New mint price
     */
    function setMintPrice(uint256 _mintPrice) public onlyOwner {
        mintPrice = _mintPrice;
    }

    /**
     * @dev Sets the maximum mint amount per transaction
     * @param _maxMintAmount New max mint amount
     */
    function setMaxMintAmount(uint256 _maxMintAmount) public onlyOwner {
        maxMintAmount = _maxMintAmount;
    }

    /**
     * @dev Pauses or unpauses the contract
     * @param _paused New paused state
     */
    function setPaused(bool _paused) public onlyOwner {
        paused = _paused;
    }

    /**
     * @dev Allows owner to withdraw funds from the contract
     */
    function withdraw() public onlyOwner {
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    /**
     * @dev Returns the base URI for token metadata
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Returns the URI for a given token ID
     * @param tokenId Token ID to get URI for
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");
        
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 
            ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json"))
            : "";
    }
}