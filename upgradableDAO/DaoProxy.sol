// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts@4.9.3/proxy/ERC1967/ERC1967Proxy.sol";

contract DaoProxy is ERC1967Proxy {
    constructor(address _logic, bytes memory _data) ERC1967Proxy(_logic, _data) {}

    function implementation() external view returns (address) {
        return _implementation();
    }
}