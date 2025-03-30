// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./DaoProxy.sol";
import "./DaoV1.sol";
import "./DaoV2.sol";

contract DaoDeploymentAndInteraction {
    DaoProxy public proxy;
    DaoV1 public logicV1;
    DaoV2 public logicV2;

    event ProxyDeployed(address proxyAddress);
    event UpgradeSuccess(address newImplementation);
    event BalanceSet(address member, uint256 balance);
    event ProposalCreated(uint256 proposalId);
    event VoteCast(address voter, uint256 proposalId, uint256 votes);

    function deploy() external returns (address) {
        logicV1 = new DaoV1();
        bytes memory initData = abi.encodeWithSignature("initialize()");
        proxy = new DaoProxy(address(logicV1), initData);
        emit ProxyDeployed(address(proxy));
        return address(proxy);
    }

    function interactWithV1() external returns (bool) {
        // Complete all operations in one function to reduce context switching
        // 1. Set voting weight
        DaoV1(address(proxy)).mockBalance(msg.sender, 100);
        emit BalanceSet(msg.sender, 100);

        // Verify balance
        uint256 balance = DaoV1(address(proxy)).memberBalances(msg.sender);
        require(balance == 100, "Balance not set correctly");

        // 2. Create proposal
        DaoV1(address(proxy)).createProposal("Proposal from V1");
        uint256 proposalId = DaoV1(address(proxy)).proposalCount() - 1;
        emit ProposalCreated(proposalId);

        // 3. Vote - pass the actual voter address
        DaoV1(address(proxy)).vote(proposalId, msg.sender);
        (,uint256 votes,,,) = DaoV1(address(proxy)).proposals(proposalId);
        require(votes == 100, "Vote not recorded correctly");
        emit VoteCast(msg.sender, proposalId, votes);

        // 4. Execute proposal
        DaoV1(address(proxy)).executeProposal(proposalId);

        // 5. Verify version
        string memory version = DaoV1(address(proxy)).getVersion();
        require(keccak256(bytes(version)) == keccak256(bytes("1.0.0")), "Wrong version");

        return true;
    }

    function upgradeToV2() external returns (address) {
        logicV2 = new DaoV2();
        DaoV1(address(proxy)).upgradeTo(address(logicV2));
        emit UpgradeSuccess(address(logicV2));
        return address(logicV2);
    }

    function interactWithV2() external returns (bool) {
        // Complete all operations in one function
        // 1. Set voting weight
        DaoV2(address(proxy)).mockBalance(msg.sender, 100);

        // 2. Create proposal
        DaoV2(address(proxy)).createProposal("Proposal from V2");
        uint256 proposalId = DaoV2(address(proxy)).proposalCount() - 1;

        // 3. Set as emergency proposal
        DaoV2(address(proxy)).setEmergencyProposal(proposalId);

        // 4. Vote - pass the actual voter address
        DaoV2(address(proxy)).vote(proposalId, msg.sender);

        // 5. Execute proposal
        DaoV2(address(proxy)).executeProposal(proposalId);

        // 6. Verify version
        string memory version = DaoV2(address(proxy)).getVersion();
        require(keccak256(bytes(version)) == keccak256(bytes("2.0.0")), "Wrong version");

        return true;
    }

    // Query functions
    function getProxyAddress() external view returns (address) {
        return address(proxy);
    }

    function getLogicV1Address() external view returns (address) {
        return address(logicV1);
    }

    function getLogicV2Address() external view returns (address) {
        return address(logicV2);
    }

    // Add a function to query voting power for debugging
    function checkVotingPower(address voter) external view returns (uint256) {
        return DaoV1(address(proxy)).memberBalances(voter);
    }
}