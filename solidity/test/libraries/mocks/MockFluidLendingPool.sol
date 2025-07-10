// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {IERC20} from "forge-std/src/interfaces/IERC20.sol";
import {IFluidLendingPool} from "../../../src/libraries/interfaces/fluid/IFluidLendingPool.sol";

/**
 * @title MockFluidLendingPool
 * @dev Mock implementation of Fluid Finance Lending Pool for testing purposes
 */
contract MockFluidLendingPool is IFluidLendingPool {
    // Mapping to track fToken balances: asset => user => balance
    mapping(address => mapping(address => uint256)) public fTokenBalances;
    
    // Mapping to track borrow balances: asset => user => balance
    mapping(address => mapping(address => uint256)) public borrowBalances;
    
    // Mapping to track fToken addresses: asset => fToken
    mapping(address => address) public fTokenAddresses;
    
    // Mapping to track total debt per user
    mapping(address => uint256) public totalDebt;
    
    // Mock fToken contract address
    address public mockFToken;
    
    // Address of the output account (set by the test)
    address public outputAccount;

    // Allow test to set the output account
    function setOutputAccount(address _outputAccount) external {
        outputAccount = _outputAccount;
    }

    constructor() {
        mockFToken = address(this);
    }
    
    /**
     * @notice Mock supply function
     */
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external {
        // Transfer assets from caller to this contract (simulating supply)
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        
        // Mint fTokens to the onBehalfOf address
        fTokenBalances[asset][onBehalfOf] += amount;
        
        // Set fToken address for this asset
        fTokenAddresses[asset] = mockFToken;
    }
    
    /**
     * @notice Mock withdraw function
     */
    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        // Always burn fTokens from the outputAccount (set by the test)
        require(fTokenBalances[asset][outputAccount] >= amount, "Insufficient fToken balance");
        fTokenBalances[asset][outputAccount] -= amount;
        IERC20(asset).transfer(to, amount);
        return amount;
    }
    
    /**
     * @notice Mock borrow function
     */
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external {
        require(interestRateMode == 1 || interestRateMode == 2, "Invalid interest rate mode");
        
        // Increase borrow balance
        borrowBalances[asset][onBehalfOf] += amount;
        totalDebt[onBehalfOf] += amount;
        
        // Transfer borrowed assets to the onBehalfOf address
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
        
        // Decrease borrow balance
        borrowBalances[asset][onBehalfOf] -= amount;
        totalDebt[onBehalfOf] -= amount;
        
        return amount;
    }
    
    /**
     * @notice Get fToken balance for a specific asset and user
     */
    function balanceOf(address asset, address user) external view returns (uint256) {
        return fTokenBalances[asset][user];
    }
    
    /**
     * @notice Get borrow balance for a specific asset and user
     */
    function borrowBalanceOf(address asset, address user) external view returns (uint256) {
        return borrowBalances[asset][user];
    }
    
    /**
     * @notice Get fToken address for a specific asset
     */
    function getReserveData(address asset) external view returns (address fTokenAddress) {
        return fTokenAddresses[asset];
    }
    
    /**
     * @notice Check if a user has any debt
     */
    function hasDebt(address user) external view returns (bool) {
        return totalDebt[user] > 0;
    }
    
    /**
     * @notice Get total debt for a user
     */
    function getTotalDebt(address user) external view returns (uint256) {
        return totalDebt[user];
    }
    
    /**
     * @notice Mock function to mint underlying tokens for testing
     */
    function mintUnderlying(address asset, uint256 amount) external {
        // This is a mock function to provide underlying tokens for testing
        // In a real scenario, this would be handled by the actual token contract
    }
} 