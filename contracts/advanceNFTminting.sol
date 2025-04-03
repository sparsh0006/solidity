// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title AdvancedNFT
 * @dev An NFT contract with whitelist, presale, and public sale functionality
 */
contract AdvancedNFT is ERC721URIStorage, ERC721Burnable, AccessControl, ReentrancyGuard {
    // Roles for access control
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // Sale phases
    enum SalePhase { PAUSED, WHITELIST, PRESALE, PUBLIC }
    SalePhase public currentPhase = SalePhase.PAUSED;
    
    // Pricing and supply
    uint256 public whitelistPrice = 0.03 ether;
    uint256 public presalePrice = 0.05 ether;
    uint256 public publicPrice = 0.08 ether;
    uint256 public maxSupply = 10000;
    uint256 public maxPerWallet = 3;
    uint256 public maxPerTransaction = 5;
    
    // Whitelist
    bytes32 public whitelistMerkleRoot;
    mapping(address => uint256) public whitelistMinted;
    
    // Presale
    mapping(address => bool) public presaleEligible;
    mapping(address => uint256) public presaleMinted;
    
    // Tracking
    uint256 private _tokenIdCounter = 0;
    mapping(address => uint256) public totalMinted;
    
    // Metadata
    string private _baseTokenURI;
    
    // Royalties
    address public royaltyReceiver;
    uint256 public royaltyPercentage = 500; // 5% (out of 10000)
    
    /**
     * @dev Constructor
     * @param name Collection name
     * @param symbol Collection symbol
     */
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        royaltyReceiver = msg.sender;
    }
    
    /**
     * @dev Whitelist mint function
     * @param quantity Number of NFTs to mint
     * @param merkleProof Proof of whitelist inclusion
     */
    function whitelistMint(uint256 quantity, bytes32[] calldata merkleProof) 
        external 
        payable 
        nonReentrant 
    {
        require(currentPhase == SalePhase.WHITELIST, "Whitelist sale not active");
        require(quantity > 0 && quantity <= maxPerTransaction, "Invalid quantity");
        require(whitelistMinted[msg.sender] + quantity <= maxPerWallet, "Exceeds wallet limit");
        require(_tokenIdCounter + quantity <= maxSupply, "Exceeds max supply");
        require(msg.value >= whitelistPrice * quantity, "Insufficient payment");
        
        // Verify merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(merkleProof, whitelistMerkleRoot, leaf), "Invalid proof");
        
        whitelistMinted[msg.sender] += quantity;
        totalMinted[msg.sender] += quantity;
        
        for (uint256 i = 0; i < quantity; i++) {
            _mintToken(msg.sender);
        }
    }
    
    /**
     * @dev Presale mint function
     * @param quantity Number of NFTs to mint
     */
    function presaleMint(uint256 quantity) 
        external 
        payable 
        nonReentrant 
    {
        require(currentPhase == SalePhase.PRESALE, "Presale not active");
        require(presaleEligible[msg.sender], "Not eligible for presale");
        require(quantity > 0 && quantity <= maxPerTransaction, "Invalid quantity");
        require(presaleMinted[msg.sender] + quantity <= maxPerWallet, "Exceeds wallet limit");
        require(_tokenIdCounter + quantity <= maxSupply, "Exceeds max supply");
        require(msg.value >= presalePrice * quantity, "Insufficient payment");
        
        presaleMinted[msg.sender] += quantity;
        totalMinted[msg.sender] += quantity;
        
        for (uint256 i = 0; i < quantity; i++) {
            _mintToken(msg.sender);
        }
    }
    
    /**
     * @dev Public mint function
     * @param quantity Number of NFTs to mint
     */
    function publicMint(uint256 quantity) 
        external 
        payable 
        nonReentrant 
    {
        require(currentPhase == SalePhase.PUBLIC, "Public sale not active");
        require(quantity > 0 && quantity <= maxPerTransaction, "Invalid quantity");
        require(totalMinted[msg.sender] + quantity <= maxPerWallet, "Exceeds wallet limit");
        require(_tokenIdCounter + quantity <= maxSupply, "Exceeds max supply");
        require(msg.value >= publicPrice * quantity, "Insufficient payment");
        
        totalMinted[msg.sender] += quantity;
        
        for (uint256 i = 0; i < quantity; i++) {
            _mintToken(msg.sender);
        }
    }
    
    /**
     * @dev Admin mint function
     * @param to Recipient address
     * @param quantity Number of NFTs to mint
     */
    function adminMint(address to, uint256 quantity) 
        external 
        onlyRole(MINTER_ROLE) 
    {
        require(quantity > 0, "Invalid quantity");
        require(_tokenIdCounter + quantity <= maxSupply, "Exceeds max supply");
        
        for (uint256 i = 0; i < quantity; i++) {
            _mintToken(to);
        }
    }
    
    /**
     * @dev Internal mint helper
     * @param to Recipient address
     */
    function _mintToken(address to) private {
        _tokenIdCounter++;
        _safeMint(to, _tokenIdCounter);
    }
    
    /**
     * @dev Set token URI for a specific token
     * @param tokenId Token ID
     * @param uri Token URI
     */
    function setTokenURI(uint256 tokenId, string memory uri) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        _setTokenURI(tokenId, uri);
    }
    
    /**
     * @dev Set base URI for all tokens
     * @param baseURI New base URI
     */
    function setBaseURI(string memory baseURI) external onlyRole(ADMIN_ROLE) {
        _baseTokenURI = baseURI;
    }
    
    /**
     * @dev Set the current sale phase
     * @param phase New sale phase
     */
    function setSalePhase(SalePhase phase) external onlyRole(ADMIN_ROLE) {
        currentPhase = phase;
    }
    
    /**
     * @dev Set whitelist merkle root
     * @param merkleRoot New merkle root
     */
    function setWhitelistMerkleRoot(bytes32 merkleRoot) external onlyRole(ADMIN_ROLE) {
        whitelistMerkleRoot = merkleRoot;
    }
    
    /**
     * @dev Set presale eligibility for addresses
     * @param addresses Array of addresses
     * @param eligible Eligibility status
     */
    function setPresaleEligibility(address[] calldata addresses, bool eligible) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        for (uint256 i = 0; i < addresses.length; i++) {
            presaleEligible[addresses[i]] = eligible;
        }
    }
    
    /**
     * @dev Set prices for different sale phases
     * @param whitelist Whitelist price
     * @param presale Presale price
     * @param public Public price
     */
    function setPrices(uint256 whitelist, uint256 presale, uint256 public_) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        whitelistPrice = whitelist;
        presalePrice = presale;
        publicPrice = public_;
    }
    
    /**
     * @dev Set max per wallet limit
     * @param max New max per wallet
     */
    function setMaxPerWallet(uint256 max) external onlyRole(ADMIN_ROLE) {
        maxPerWallet = max;
    }
    
    /**
     * @dev Set max per transaction limit
     * @param max New max per transaction
     */
    function setMaxPerTransaction(uint256 max) external onlyRole(ADMIN_ROLE) {
        maxPerTransaction = max;
    }
    
    /**
     * @dev Set max supply
     * @param max New max supply
     */
    function setMaxSupply(uint256 max) external onlyRole(ADMIN_ROLE) {
        require(max >= _tokenIdCounter, "Cannot be less than current supply");
        maxSupply = max;
    }
    
    /**
     * @dev Set royalty information
     * @param receiver Royalty receiver address
     * @param percentage Royalty percentage (out of 10000)
     */
    function setRoyaltyInfo(address receiver, uint256 percentage) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(percentage <= 1000, "Cannot exceed 10%");
        royaltyReceiver = receiver;
        royaltyPercentage = percentage;
    }
    
    /**
     * @dev EIP-2981 royalty standard implementation
     * @param tokenId Token ID
     * @param salePrice Sale price
     * @return receiver Royalty receiver
     * @return royaltyAmount Royalty amount
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice) 
        external 
        view 
        returns (address receiver, uint256 royaltyAmount) 
    {
        require(_exists(tokenId), "Nonexistent token");
        return (royaltyReceiver, (salePrice * royaltyPercentage) / 10000);
    }
    
    /**
     * @dev Withdraw funds from contract
     */
    function withdraw() external onlyRole(ADMIN_ROLE) nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Withdrawal failed");
    }
    
    /**
     * @dev Base URI for computing tokenURI
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
    
    /**
     * @dev Required override for AccessControl
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    /**
     * @dev Required override for ERC721URIStorage
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}