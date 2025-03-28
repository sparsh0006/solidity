// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Logic Contract V1
contract LogicV1 {
    // State variables
    address public implementation;
    address public admin;
    string public value;
    bool private initialized;

    // Ensure the initializer can only be executed once
    modifier initializer() {
        require(!initialized, "Already initialized");
        _;
        initialized = true;
    }

    function initialize() external initializer {
        value = "init";
    }

    function setValue() public {
        value = "v1";
    }
}

// Logic Contract V2
contract LogicV2 {
    // State variables
    address public implementation;
    address public admin;
    string public value;
    bool private initialized;

    // Ensure the initializer can only be executed once
    modifier initializer() {
        require(!initialized, "Already initialized");
        initialized = true;
        _;
    }

    function initialize() external initializer {
        value = "init";
    }

    function setValue() public {
        value = "v2";
    }
}

// Proxy Contract
contract SimpleUpgradableProxy {
    address public implementation; // Logic contract address
    address public admin;          // Admin address
    string public value;           // Data value
    
    constructor(address _implementation) {
        implementation = _implementation;
        admin = msg.sender;
    }

    // Fallback function to forward calls to the logic contract
    fallback() external payable {
        (bool success, bytes memory data) = implementation.delegatecall(msg.data);
        require(success, "Delegatecall failed");
    }
    
    // Upgrade the logic contract
    function upgrade(address _newImplementation) external {
        require(msg.sender == admin, "Only admin can upgrade");
        implementation = _newImplementation;
    }
}