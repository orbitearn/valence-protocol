// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

/**
 * @title IMoonwellMToken
 * @dev Interface for Moonwell Finance mToken contract
 * @notice This interface provides the core functions needed to interact with Moonwell Finance mToken markets
 */
interface IMoonwellMToken {
    /**
     * @notice Mint mTokens by supplying underlying asset
     * @param mintAmount The amount of underlying asset to supply
     * @return The actual amount of mTokens minted
     */
    function mint(uint256 mintAmount) external returns (uint256);

    /**
     * @notice Mint mTokens by supplying underlying asset for a specific account
     * @param minter The account to mint for
     * @param mintAmount The amount of underlying asset to supply
     * @return The actual amount of mTokens minted
     */
    function mintFor(address minter, uint256 mintAmount) external returns (uint256);

    /**
     * @notice Redeem mTokens for underlying asset
     * @param redeemTokens The number of mTokens to redeem
     * @return The actual amount of underlying asset redeemed
     */
    function redeem(uint256 redeemTokens) external returns (uint256);

    /**
     * @notice Redeem underlying asset by burning mTokens
     * @param redeemAmount The amount of underlying asset to redeem
     * @return The actual number of mTokens burned
     */
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    /**
     * @notice Borrow underlying asset
     * @param borrowAmount The amount of underlying asset to borrow
     * @return The actual amount borrowed
     */
    function borrow(uint256 borrowAmount) external returns (uint256);

    /**
     * @notice Repay borrowed underlying asset
     * @param repayAmount The amount of underlying asset to repay
     * @return The actual amount repaid
     */
    function repayBorrow(uint256 repayAmount) external returns (uint256);

    /**
     * @notice Repay borrowed underlying asset for a specific borrower
     * @param borrower The account to repay for
     * @param repayAmount The amount of underlying asset to repay
     * @return The actual amount repaid
     */
    function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);

    /**
     * @notice Transfer mTokens to another account
     * @param dst The destination account
     * @param amount The amount of mTokens to transfer
     * @return True if successful
     */
    function transfer(address dst, uint256 amount) external returns (bool);

    /**
     * @notice Transfer mTokens from one account to another
     * @param src The source account
     * @param dst The destination account
     * @param amount The amount of mTokens to transfer
     * @return True if successful
     */
    function transferFrom(address src, address dst, uint256 amount) external returns (bool);

    /**
     * @notice Approve another account to spend mTokens
     * @param spender The account to approve
     * @param amount The amount to approve
     * @return True if successful
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @notice Get the balance of mTokens for an account
     * @param account The account address
     * @return The balance of mTokens
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice Get the borrow balance for an account
     * @param account The account address
     * @return The borrow balance
     */
    function borrowBalanceStored(address account) external view returns (uint256);

    /**
     * @notice Get the current borrow balance for an account
     * @param account The account address
     * @return The current borrow balance
     */
    function borrowBalanceCurrent(address account) external returns (uint256);

    /**
     * @notice Get the exchange rate between mTokens and underlying
     * @return The exchange rate (scaled by 1e18)
     */
    function exchangeRateStored() external view returns (uint256);

    /**
     * @notice Get the current exchange rate between mTokens and underlying
     * @return The current exchange rate (scaled by 1e18)
     */
    function exchangeRateCurrent() external returns (uint256);

    /**
     * @notice Get the underlying asset address
     * @return The underlying asset address
     */
    function underlying() external view returns (address);

    /**
     * @notice Get the total supply of mTokens
     * @return The total supply
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Get the total borrows
     * @return The total borrows
     */
    function totalBorrows() external view returns (uint256);

    /**
     * @notice Get the total reserves
     * @return The total reserves
     */
    function totalReserves() external view returns (uint256);

    /**
     * @notice Get the supply rate per block
     * @return The supply rate per block (scaled by 1e18)
     */
    function supplyRatePerBlock() external view returns (uint256);

    /**
     * @notice Get the borrow rate per block
     * @return The borrow rate per block (scaled by 1e18)
     */
    function borrowRatePerBlock() external view returns (uint256);

    /**
     * @notice Get the utilization rate
     * @return The utilization rate (scaled by 1e18)
     */
    function utilizationRate() external view returns (uint256);

    /**
     * @notice Get the comptroller address
     * @return The comptroller address
     */
    function comptroller() external view returns (address);

    /**
     * @notice Get the decimals of the mToken
     * @return The number of decimals
     */
    function decimals() external view returns (uint8);

    /**
     * @notice Get the name of the mToken
     * @return The name
     */
    function name() external view returns (string memory);

    /**
     * @notice Get the symbol of the mToken
     * @return The symbol
     */
    function symbol() external view returns (string memory);
} 