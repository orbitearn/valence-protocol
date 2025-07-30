// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {IEulerMarkets} from "../../src/libraries/interfaces/euler/IEulerMarkets.sol";

contract MockEulerMarkets is IEulerMarkets {
    // Mock balances for testing
    mapping(address => mapping(uint256 => mapping(address => uint256))) public override balanceOf;
    mapping(address => mapping(uint256 => mapping(address => uint256))) public override borrowBalance;
    mapping(address => uint256) public override totalSupply;
    mapping(address => uint256) public override totalBorrow;
    mapping(address => uint256) public override supplyRate;
    mapping(address => uint256) public override borrowRate;
    mapping(address => bool) public override isListed;
    mapping(address => address) public override underlyingToEToken;
    mapping(address => address) public override underlyingToDToken;

    // Mock functions for testing
    function supply(uint256 subAccountId, address asset, uint256 amount) external override {
        // Mock implementation - just update balances
        balanceOf[msg.sender][subAccountId][asset] += amount;
        totalSupply[asset] += amount;
    }

    function supplyFrom(uint256 subAccountId, address asset, uint256 amount, address from) external override {
        // Mock implementation - just update balances
        balanceOf[from][subAccountId][asset] += amount;
        totalSupply[asset] += amount;
    }

    function withdraw(uint256 subAccountId, address asset, uint256 amount) external override {
        // Mock implementation - just update balances
        balanceOf[msg.sender][subAccountId][asset] -= amount;
        totalSupply[asset] -= amount;
    }

    function withdrawTo(uint256 subAccountId, address asset, uint256 amount, address to) external override {
        // Mock implementation - just update balances
        balanceOf[msg.sender][subAccountId][asset] -= amount;
        totalSupply[asset] -= amount;
    }

    function borrow(uint256 subAccountId, address asset, uint256 amount) external override {
        // Mock implementation - just update balances
        borrowBalance[msg.sender][subAccountId][asset] += amount;
        totalBorrow[asset] += amount;
    }

    function repay(uint256 subAccountId, address asset, uint256 amount) external override {
        // Mock implementation - just update balances
        borrowBalance[msg.sender][subAccountId][asset] -= amount;
        totalBorrow[asset] -= amount;
    }

    function repayFrom(uint256 subAccountId, address asset, uint256 amount, address from) external override {
        // Mock implementation - just update balances
        borrowBalance[from][subAccountId][asset] -= amount;
        totalBorrow[asset] -= amount;
    }

    // Helper functions for testing
    function setBalance(address account, uint256 subAccountId, address asset, uint256 amount) external {
        balanceOf[account][subAccountId][asset] = amount;
    }

    function setBorrowBalance(address account, uint256 subAccountId, address asset, uint256 amount) external {
        borrowBalance[account][subAccountId][asset] = amount;
    }

    function setSupplyRate(address asset, uint256 rate) external {
        supplyRate[asset] = rate;
    }

    function setBorrowRate(address asset, uint256 rate) external {
        borrowRate[asset] = rate;
    }

    function setListed(address asset, bool listed) external {
        isListed[asset] = listed;
    }

    function setEToken(address underlying, address eToken) external {
        underlyingToEToken[underlying] = eToken;
    }

    function setDToken(address underlying, address dToken) external {
        underlyingToDToken[underlying] = dToken;
    }

    // Implement missing interface functions with mock implementations
    function eTokenToUnderlying(address eToken) external view override returns (address) {
        // Mock implementation - return a default address
        return address(0);
    }
}
