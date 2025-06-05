// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {IERC20} from "forge-std/src/interfaces/IERC20.sol";

contract MockCompoundV3Market {
    address public baseToken;
    
    // Track supplied amounts for testing
    mapping(address => uint256) public suppliedAmounts;
    
    constructor(address _baseToken) {
        baseToken = _baseToken;
    }
    
    // Implement the supply function that matches CometMainInterface signature
    function supply(address asset, uint amount) external {
        // Transfer tokens from sender to this contract
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        
        // Track the supplied amount
        suppliedAmounts[msg.sender] += amount;
    }
    
    // Helper function to check supplied amounts in tests
    function getSuppliedAmount(address account) external view returns (uint256) {
        return suppliedAmounts[account];
    }
}
