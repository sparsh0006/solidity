// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

/**
 * @title FrogRace for Solidity 0.7.6
 * @dev A simple frog racing game where players bet on frogs
 */
contract FrogRace {
    // Basic parameters
    uint8 public constant NUM_FROGS = 5;
    address public owner;
    bool public gameActive;
    uint8 public winningFrog;
    uint256 public nonce; // Added to make randomness less predictable
    
    // Simple mappings for bets
    mapping(address => uint8) public playerBets;
    mapping(uint8 => uint256) public frogTotalBets;
    
    // Events
    event BetPlaced(address player, uint8 frogId, uint256 amount);
    event GameStarted();
    event GameEnded(uint8 winningFrog);
    
    constructor() {
        owner = msg.sender;
        gameActive = false;
        winningFrog = 0;
        nonce = 0; // Initialize nonce
    }
    
    // Modifier for owner-only functions
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    // Start game
    function startGame() external onlyOwner {
        gameActive = true;
        winningFrog = 0;
        emit GameStarted();
    }
    
    // Place bet
    function placeBet(uint8 frogId) external payable {
        require(gameActive, "Game not active");
        require(frogId > 0 && frogId <= NUM_FROGS, "Invalid frog ID");
        require(msg.value > 0, "Bet amount must be > 0");
        
        playerBets[msg.sender] = frogId;
        frogTotalBets[frogId] += msg.value;
        
        emit BetPlaced(msg.sender, frogId, msg.value);
    }
    
    // End game and determine winner
    function endGame() external onlyOwner {
        require(gameActive, "Game not active");
        
        // Modified pseudo-random number generation
        uint256 randomValue = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            blockhash(block.number - 1),
            nonce,
            msg.sender
        )));
        
        nonce++; // Increment nonce for next call
        winningFrog = uint8((randomValue % NUM_FROGS) + 1);
        gameActive = false;
        
        emit GameEnded(winningFrog);
    }
    
    // Claim winnings
    function claimWinnings() external {
        require(!gameActive, "Game still active");
        require(winningFrog > 0, "No winner determined");
        require(playerBets[msg.sender] == winningFrog, "You didn't bet on the winner");
        
        // Simple withdrawal - winner gets their bet back plus a share of the total pool
        uint256 winnings = address(this).balance;
        
        // Reset player's bet
        playerBets[msg.sender] = 0;
        
        // Transfer winnings
        msg.sender.transfer(winnings);
    }
    
    // Only for emergencies - owner can withdraw all funds
    function emergencyWithdraw() external onlyOwner {
        msg.sender.transfer(address(this).balance);
    }
}