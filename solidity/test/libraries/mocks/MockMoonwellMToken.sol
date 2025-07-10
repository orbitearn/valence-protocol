// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {IMoonwellMToken} from "../../../src/libraries/interfaces/moonwell/IMoonwellMToken.sol";
import {IERC20} from "forge-std/src/interfaces/IERC20.sol";

/**
 * @title MockMoonwellMToken
 * @dev Mock implementation of Moonwell mToken for testing purposes
 */
contract MockMoonwellMToken is IMoonwellMToken {
    address public immutable underlyingAsset;
    address public immutable comptrollerAddress;
    
    mapping(address => uint256) public balances;
    mapping(address => uint256) public borrowBalances;
    mapping(address => mapping(address => uint256)) public allowances;
    
    uint256 public totalSupply_;
    uint256 public totalBorrows_;
    uint256 public totalReserves_;
    uint256 public exchangeRate_ = 1e18; // 1:1 initially
    uint256 public supplyRate_ = 0.05e18; // 5% per block
    uint256 public borrowRate_ = 0.08e18; // 8% per block
    uint256 public utilizationRate_ = 0.6e18; // 60%
    
    uint8 public constant decimals_ = 18;
    string public constant name_ = "Mock mToken";
    string public constant symbol_ = "mMOCK";

    constructor(address _underlying, address _comptroller) {
        underlyingAsset = _underlying;
        comptrollerAddress = _comptroller;
    }

    function mint(uint256 mintAmount) external returns (uint256) {
        require(mintAmount > 0, "Mint amount must be greater than 0");
        
        // Transfer underlying from caller
        IERC20(underlyingAsset).transferFrom(msg.sender, address(this), mintAmount);
        
        // Calculate mTokens to mint based on exchange rate
        uint256 mTokensToMint = (mintAmount * 1e18) / exchangeRate_;
        
        // Mint mTokens to caller
        balances[msg.sender] += mTokensToMint;
        totalSupply_ += mTokensToMint;
        
        return mTokensToMint;
    }

    function mintFor(address minter, uint256 mintAmount) external returns (uint256) {
        require(mintAmount > 0, "Mint amount must be greater than 0");
        
        // Transfer underlying from caller
        IERC20(underlyingAsset).transferFrom(msg.sender, address(this), mintAmount);
        
        // Calculate mTokens to mint based on exchange rate
        uint256 mTokensToMint = (mintAmount * 1e18) / exchangeRate_;
        
        // Mint mTokens to minter
        balances[minter] += mTokensToMint;
        totalSupply_ += mTokensToMint;
        
        return mTokensToMint;
    }

    function redeem(uint256 redeemTokens) external returns (uint256) {
        require(redeemTokens > 0, "Redeem amount must be greater than 0");
        require(balances[msg.sender] >= redeemTokens, "Insufficient mToken balance");
        
        // Calculate underlying to redeem
        uint256 underlyingToRedeem = (redeemTokens * exchangeRate_) / 1e18;
        
        // Burn mTokens
        balances[msg.sender] -= redeemTokens;
        totalSupply_ -= redeemTokens;
        
        // Transfer underlying to caller
        IERC20(underlyingAsset).transfer(msg.sender, underlyingToRedeem);
        
        return underlyingToRedeem;
    }

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256) {
        require(redeemAmount > 0, "Redeem amount must be greater than 0");
        
        // Calculate mTokens to burn
        uint256 mTokensToBurn = (redeemAmount * 1e18) / exchangeRate_;
        require(balances[msg.sender] >= mTokensToBurn, "Insufficient mToken balance");
        
        // Burn mTokens
        balances[msg.sender] -= mTokensToBurn;
        totalSupply_ -= mTokensToBurn;
        
        // Transfer underlying to caller
        IERC20(underlyingAsset).transfer(msg.sender, redeemAmount);
        
        return mTokensToBurn;
    }

    function borrow(uint256 borrowAmount) external returns (uint256) {
        require(borrowAmount > 0, "Borrow amount must be greater than 0");
        
        // Add to borrow balance
        borrowBalances[msg.sender] += borrowAmount;
        totalBorrows_ += borrowAmount;
        
        // Transfer underlying to caller
        IERC20(underlyingAsset).transfer(msg.sender, borrowAmount);
        
        return borrowAmount;
    }

    function repayBorrow(uint256 repayAmount) external returns (uint256) {
        require(repayAmount > 0, "Repay amount must be greater than 0");
        
        // Transfer underlying from caller
        IERC20(underlyingAsset).transferFrom(msg.sender, address(this), repayAmount);
        
        // Reduce borrow balance
        uint256 currentBorrow = borrowBalances[msg.sender];
        uint256 actualRepay = repayAmount > currentBorrow ? currentBorrow : repayAmount;
        
        borrowBalances[msg.sender] -= actualRepay;
        totalBorrows_ -= actualRepay;
        
        return actualRepay;
    }

    function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256) {
        require(repayAmount > 0, "Repay amount must be greater than 0");
        
        // Transfer underlying from caller
        IERC20(underlyingAsset).transferFrom(msg.sender, address(this), repayAmount);
        
        // Reduce borrow balance
        uint256 currentBorrow = borrowBalances[borrower];
        uint256 actualRepay = repayAmount > currentBorrow ? currentBorrow : repayAmount;
        
        borrowBalances[borrower] -= actualRepay;
        totalBorrows_ -= actualRepay;
        
        return actualRepay;
    }

    function transfer(address dst, uint256 amount) external returns (bool) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        balances[msg.sender] -= amount;
        balances[dst] += amount;
        
        return true;
    }

    function transferFrom(address src, address dst, uint256 amount) external returns (bool) {
        require(balances[src] >= amount, "Insufficient balance");
        require(allowances[src][msg.sender] >= amount, "Insufficient allowance");
        
        balances[src] -= amount;
        balances[dst] += amount;
        allowances[src][msg.sender] -= amount;
        
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowances[msg.sender][spender] = amount;
        return true;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function borrowBalanceStored(address account) external view returns (uint256) {
        return borrowBalances[account];
    }

    function borrowBalanceCurrent(address account) external returns (uint256) {
        return borrowBalances[account];
    }

    function exchangeRateStored() external view returns (uint256) {
        return exchangeRate_;
    }

    function exchangeRateCurrent() external returns (uint256) {
        return exchangeRate_;
    }

    function underlying() external view returns (address) {
        return underlyingAsset;
    }

    function totalSupply() external view returns (uint256) {
        return totalSupply_;
    }

    function totalBorrows() external view returns (uint256) {
        return totalBorrows_;
    }

    function totalReserves() external view returns (uint256) {
        return totalReserves_;
    }

    function supplyRatePerBlock() external view returns (uint256) {
        return supplyRate_;
    }

    function borrowRatePerBlock() external view returns (uint256) {
        return borrowRate_;
    }

    function utilizationRate() external view returns (uint256) {
        return utilizationRate_;
    }

    function comptroller() external view returns (address) {
        return comptrollerAddress;
    }

    function decimals() external pure returns (uint8) {
        return decimals_;
    }

    function name() external pure returns (string memory) {
        return name_;
    }

    function symbol() external pure returns (string memory) {
        return symbol_;
    }

    // Mock functions for testing
    function setExchangeRate(uint256 newRate) external {
        exchangeRate_ = newRate;
    }

    function setSupplyRate(uint256 newRate) external {
        supplyRate_ = newRate;
    }

    function setBorrowRate(uint256 newRate) external {
        borrowRate_ = newRate;
    }

    function setUtilizationRate(uint256 newRate) external {
        utilizationRate_ = newRate;
    }

    function setBorrowBalance(address account, uint256 balance) external {
        borrowBalances[account] = balance;
    }
} 