// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Logic Contract V1
contract UUPSLogicV1 {
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
		
    // Initialization
    function initialize() external initializer {
        value = "init";
    }

    function setValue() public {
        value = "v1";
    }

    // Upgrade the logic contract
    function upgrade(address _newImplementation) external {
        require(msg.sender == admin, "Only admin can upgrade");
        implementation = _newImplementation;
    }
}

// Logic Contract V2
contract UUPSLogicV2 {
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
		
    // Initialization
    function initialize() external initializer {
        value = "init";
    }

    function setValue() public {
        value = "v2";
    }

    // Upgrade the logic contract
    function upgrade(address _newImplementation) external {
        require(msg.sender == admin, "Only admin can upgrade");
        implementation = _newImplementation;
    }
}

// Universal Upgrade Proxy Contract
contract UniversalUpgradeProxy {
    address public implementation; // Address of the logic contract
    address public admin;          // Address of the admin
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
}