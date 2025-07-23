// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {IPendleMarket} from "../../../src/libraries/interfaces/pendle/IPendleMarket.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";

contract MockPendleMarket is IPendleMarket {
    mapping(uint256 => MockERC20) public ptTokens; // maturity => PT token
    MockERC20 public underlying;
    mapping(address => mapping(uint256 => uint256)) public ptBalances; // user => maturity => PT balance
    mapping(address => uint256) public underlyingBalances;

    constructor(address _underlying) {
        underlying = MockERC20(_underlying);
    }

    function setPTToken(uint256 maturity, address ptToken) external {
        ptTokens[maturity] = MockERC20(ptToken);
    }

    function mintPT(address asset, uint256 amount, uint256 maturity, address to) external override returns (uint256 ptAmount) {
        require(asset == address(underlying), "Invalid asset");
        require(address(ptTokens[maturity]) != address(0), "PT not set");
        // Simulate minting 1:1
        underlying.transferFrom(msg.sender, address(this), amount);
        ptTokens[maturity].mint(to, amount);
        ptBalances[to][maturity] += amount;
        return amount;
    }

    function redeemPT(address pt, uint256 amount, uint256 maturity, address to) external override returns (uint256 underlyingAmount) {
        require(address(ptTokens[maturity]) == pt, "Invalid PT");
        // Simulate redeeming 1:1
        ptTokens[maturity].transferFrom(msg.sender, address(this), amount);
        ptTokens[maturity].burn(address(this), amount);
        underlying.mint(to, amount);
        // Remove or guard this line to avoid underflow
        // if (ptBalances[msg.sender][maturity] >= amount) {
        //     ptBalances[msg.sender][maturity] -= amount;
        // }
        return amount;
    }
} 