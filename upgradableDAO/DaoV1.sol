// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable@4.9.3/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable@4.9.3/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@4.9.3/proxy/utils/UUPSUpgradeable.sol";

contract DaoV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    struct Proposal {
        string description;
        uint256 votes;
        bool executed;
        bool ispass;
        address creator;
    }

    mapping(address => uint256) public memberBalances;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => mapping(uint256 => bool)) private memberVotes;
    uint256 public proposalCount;
    uint256 public totalBalance;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        proposalCount = 0;
        totalBalance = 0;
    }

    // Implement authorization check required by UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    modifier onlyOnce(uint256 proposalId) {
        require(!memberVotes[tx.origin][proposalId], "Already voted");
        _;
    }

    function createProposal(string memory description) external virtual {
        Proposal memory p = Proposal(description, 0, false, false, msg.sender);
        proposals[proposalCount] = p;
        proposalCount++;
    }

    function vote(uint256 proposalId, address voter) external onlyOnce(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Already executed");
        uint256 memberBalance = memberBalances[voter];
        require(memberBalance > 0, "No voting power");

        proposal.votes += memberBalance;
        memberVotes[voter][proposalId] = true;
    }

    function executeProposal(uint256 proposalId) external virtual {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Already executed");
        require(proposal.votes >= totalBalance / 2, "Insufficient votes");
        proposal.ispass = true;
        proposal.executed = true;
    }

    function mockBalance(address memberAddress, uint256 balance) external {
        totalBalance -= memberBalances[memberAddress];
        memberBalances[memberAddress] = balance;
        totalBalance += balance;
    }

    function getVersion() external pure virtual returns (string memory) {
        return "1.0.0";
    }
}