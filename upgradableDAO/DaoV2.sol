// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./DaoV1.sol";

contract DaoV2 is DaoV1 {
    // Add: minimum voting period for proposals
    uint256 public constant MINIMUM_VOTING_PERIOD = 2 days;
    
    // Add: proposal creation timestamp
    mapping(uint256 => uint256) public proposalCreationTime;
    
    // Add: emergency status for proposals
    mapping(uint256 => bool) public isEmergency;

    function createProposal(string memory description) external override {
        Proposal memory p = Proposal(description, 0, false, false, msg.sender);
        proposals[proposalCount] = p;
        proposalCreationTime[proposalCount] = block.timestamp;
        proposalCount++;
    }

    function executeProposal(uint256 proposalId) external override {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Already executed");
        
        if (!isEmergency[proposalId]) {
            require(
                block.timestamp >= proposalCreationTime[proposalId] + MINIMUM_VOTING_PERIOD,
                "Voting period not ended"
            );
        }
        
        require(proposal.votes >= totalBalance / 2, "Insufficient votes");
        proposal.ispass = true;
        proposal.executed = true;
    }

    // Add: set proposal as emergency
    function setEmergencyProposal(uint256 proposalId) external onlyOwner {
        require(proposalId < proposalCount, "Invalid proposal");
        isEmergency[proposalId] = true;
    }

    function getVersion() external pure override returns (string memory) {
        return "2.0.0";
    }
}