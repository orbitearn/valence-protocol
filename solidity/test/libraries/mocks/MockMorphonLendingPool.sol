// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {IERC20} from "forge-std/src/interfaces/IERC20.sol";
import {IMorphonLendingPool} from "../../../src/libraries/interfaces/morphon/IMorphonLendingPool.sol";

/**
 * @title MockMorphonLendingPool
 * @dev Mock implementation of Morphon Finance Lending Pool for testing purposes
 */
contract MockMorphonLendingPool is IMorphonLendingPool {
    // Mapping to track mToken balances: asset => user => balance
    mapping(address => mapping(address => uint256)) public mTokenBalances;
    
    // Mapping to track borrow balances: asset => user => balance
    mapping(address => mapping(address => uint256)) public borrowBalances;
    
    // Mapping to track mToken addresses: asset => mToken
    mapping(address => address) public mTokenAddresses;
    
    // Mapping to track total debt per user
    mapping(address => uint256) public totalDebt;
    
    // Mock mToken contract address
    address public mockMToken;
    
    // Address of the output account (set by the test)
    address public outputAccount;

    // Allow test to set the output account
    function setOutputAccount(address _outputAccount) external {
        outputAccount = _outputAccount;
    }

    constructor() {
        mockMToken = address(this);
    }
    
    /**
     * @notice Mock supply function
     */
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external {
        // Transfer assets from caller to this contract (simulating supply)
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        
        // Mint mTokens to the onBehalfOf address
        mTokenBalances[asset][onBehalfOf] += amount;
        
        // Set mToken address for this asset
        mTokenAddresses[asset] = mockMToken;
    }
    
    /**
     * @notice Mock withdraw function
     */
    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        require(mTokenBalances[asset][outputAccount] >= amount, "Insufficient mToken balance");
        
        // Burn mTokens from output account
        mTokenBalances[asset][outputAccount] -= amount;
        
        // Transfer underlying assets to the specified address
        IERC20(asset).transfer(to, amount);
        
        return amount;
    }
    
    /**
     * @notice Mock borrow function
     */
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external {
        require(interestRateMode == 1 || interestRateMode == 2, "Invalid interest rate mode");
        
        // Increase borrow balance for the user
        borrowBalances[asset][onBehalfOf] += amount;
        totalDebt[onBehalfOf] += amount;
        
        // Transfer borrowed assets to the user
        IERC20(asset).transfer(onBehalfOf, amount);
    }
    
    /**
     * @notice Mock repay function
     */
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) external returns (uint256) {
        require(interestRateMode == 1 || interestRateMode == 2, "Invalid interest rate mode");
        require(borrowBalances[asset][onBehalfOf] >= amount, "Insufficient borrow balance");
        
        // Transfer assets from caller to this contract
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        
        // Decrease borrow balance for the user
        borrowBalances[asset][onBehalfOf] -= amount;
        totalDebt[onBehalfOf] -= amount;
        
        return amount;
    }
    
    /**
     * @notice Mock balanceOf function
     */
    function balanceOf(address asset, address user) external view returns (uint256) {
        return mTokenBalances[asset][user];
    }
    
    /**
     * @notice Mock borrowBalanceOf function
     */
    function borrowBalanceOf(address asset, address user) external view returns (uint256) {
        return borrowBalances[asset][user];
    }
} 