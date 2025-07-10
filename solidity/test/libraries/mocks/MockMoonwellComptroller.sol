// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {IMoonwellComptroller} from "../../../src/libraries/interfaces/moonwell/IMoonwellComptroller.sol";

/**
 * @title MockMoonwellComptroller
 * @dev Mock implementation of Moonwell Comptroller for testing purposes
 */
contract MockMoonwellComptroller is IMoonwellComptroller {
    mapping(address => address[]) public accountMarkets;
    mapping(address => mapping(address => bool)) public accountMembership;
    mapping(address => bool) public listedMarkets;
    
    uint256 public constant CLOSE_FACTOR_MANTISSA = 0.5e18; // 50%
    uint256 public constant LIQUIDATION_INCENTIVE_MANTISSA = 1.08e18; // 8% incentive
    address public constant ORACLE_ADDRESS = address(0x1234567890123456789012345678901234567890);
    address public constant PAUSE_GUARDIAN = address(0x0987654321098765432109876543210987654321);
    
    mapping(address => bool) public mintPaused;
    mapping(address => bool) public borrowPaused;

    constructor() {
        // Initialize with some default markets
        listedMarkets[address(0x1)] = true;
        listedMarkets[address(0x2)] = true;
        listedMarkets[address(0x3)] = true;
    }

    function enterMarkets(address[] calldata mTokens) external returns (uint256[] memory) {
        uint256[] memory results = new uint256[](mTokens.length);
        
        for (uint256 i = 0; i < mTokens.length; i++) {
            if (listedMarkets[mTokens[i]]) {
                if (!accountMembership[msg.sender][mTokens[i]]) {
                    accountMarkets[msg.sender].push(mTokens[i]);
                    accountMembership[msg.sender][mTokens[i]] = true;
                }
                results[i] = 0; // Success
            } else {
                results[i] = 1; // Market not listed
            }
        }
        
        return results;
    }

    function exitMarket(address mTokenAddress) external returns (uint256) {
        if (accountMembership[msg.sender][mTokenAddress]) {
            // Remove from membership
            accountMembership[msg.sender][mTokenAddress] = false;
            
            // Remove from account markets array
            address[] storage markets = accountMarkets[msg.sender];
            for (uint256 i = 0; i < markets.length; i++) {
                if (markets[i] == mTokenAddress) {
                    markets[i] = markets[markets.length - 1];
                    markets.pop();
                    break;
                }
            }
            
            return 0; // Success
        }
        return 1; // Not a member
    }

    function getAssetsIn(address account) external view returns (address[] memory) {
        return accountMarkets[account];
    }

    function checkMembership(address account, address mToken) external view returns (bool) {
        return accountMembership[account][mToken];
    }

    function getAccountLiquidity(address account) external pure returns (uint256, uint256, uint256) {
        // Mock values: 1000 collateral, 500 borrow, 2 markets
        return (1000e18, 500e18, 2);
    }

    function closeFactorMantissa() external pure returns (uint256) {
        return CLOSE_FACTOR_MANTISSA;
    }

    function liquidationIncentiveMantissa() external pure returns (uint256) {
        return LIQUIDATION_INCENTIVE_MANTISSA;
    }

    function isMarketListed(address mToken) external view returns (bool) {
        return listedMarkets[mToken];
    }

    function oracle() external pure returns (address) {
        return ORACLE_ADDRESS;
    }

    function pauseGuardian() external pure returns (address) {
        return PAUSE_GUARDIAN;
    }

    function mintGuardianPaused(address mToken) external view returns (bool) {
        return mintPaused[mToken];
    }

    function borrowGuardianPaused(address mToken) external view returns (bool) {
        return borrowPaused[mToken];
    }

    // Mock functions for testing
    function setMarketListed(address mToken, bool listed) external {
        listedMarkets[mToken] = listed;
    }

    function setMintPaused(address mToken, bool paused) external {
        mintPaused[mToken] = paused;
    }

    function setBorrowPaused(address mToken, bool paused) external {
        borrowPaused[mToken] = paused;
    }
} 