// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

interface IPendleMarket {
    function mintPT(address asset, uint256 amount, uint256 maturity, address to) external returns (uint256 ptAmount);
    function redeemPT(address pt, uint256 amount, uint256 maturity, address to)
        external
        returns (uint256 underlyingAmount);
}
