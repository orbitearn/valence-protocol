// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

/**
 * @title IEulerMarkets
 * @dev Interface for Euler Finance Markets contract
 * @notice This interface provides the core functions needed to interact with Euler Finance lending protocol
 */
interface IEulerMarkets {
    /**
     * @notice Supply an asset to Euler Finance
     * @param subAccountId The sub-account ID (0 for primary account)
     * @param asset The asset to supply
     * @param amount The amount to supply
     */
    function supply(uint256 subAccountId, address asset, uint256 amount) external;

    /**
     * @notice Supply an asset to Euler Finance for a specific account
     * @param subAccountId The sub-account ID (0 for primary account)
     * @param asset The asset to supply
     * @param amount The amount to supply
     * @param from The account to supply from
     */
    function supplyFrom(uint256 subAccountId, address asset, uint256 amount, address from) external;

    /**
     * @notice Withdraw an asset from Euler Finance
     * @param subAccountId The sub-account ID (0 for primary account)
     * @param asset The asset to withdraw
     * @param amount The amount to withdraw
     */
    function withdraw(uint256 subAccountId, address asset, uint256 amount) external;

    /**
     * @notice Withdraw an asset from Euler Finance to a specific account
     * @param subAccountId The sub-account ID (0 for primary account)
     * @param asset The asset to withdraw
     * @param amount The amount to withdraw
     * @param to The account to withdraw to
     */
    function withdrawTo(uint256 subAccountId, address asset, uint256 amount, address to) external;

    /**
     * @notice Borrow an asset from Euler Finance
     * @param subAccountId The sub-account ID (0 for primary account)
     * @param asset The asset to borrow
     * @param amount The amount to borrow
     */
    function borrow(uint256 subAccountId, address asset, uint256 amount) external;

    /**
     * @notice Repay borrowed asset to Euler Finance
     * @param subAccountId The sub-account ID (0 for primary account)
     * @param asset The asset to repay
     * @param amount The amount to repay
     */
    function repay(uint256 subAccountId, address asset, uint256 amount) external;

    /**
     * @notice Repay borrowed asset to Euler Finance from a specific account
     * @param subAccountId The sub-account ID (0 for primary account)
     * @param asset The asset to repay
     * @param amount The amount to repay
     * @param from The account to repay from
     */
    function repayFrom(uint256 subAccountId, address asset, uint256 amount, address from) external;

    /**
     * @notice Get the balance of an asset for an account
     * @param account The account address
     * @param subAccountId The sub-account ID (0 for primary account)
     * @param asset The asset address
     * @return The balance of the asset
     */
    function balanceOf(address account, uint256 subAccountId, address asset) external view returns (uint256);

    /**
     * @notice Get the borrow balance of an asset for an account
     * @param account The account address
     * @param subAccountId The sub-account ID (0 for primary account)
     * @param asset The asset address
     * @return The borrow balance of the asset
     */
    function borrowBalance(address account, uint256 subAccountId, address asset) external view returns (uint256);

    /**
     * @notice Get the total supply of an asset
     * @param asset The asset address
     * @return The total supply of the asset
     */
    function totalSupply(address asset) external view returns (uint256);

    /**
     * @notice Get the total borrow of an asset
     * @param asset The asset address
     * @return The total borrow of the asset
     */
    function totalBorrow(address asset) external view returns (uint256);

    /**
     * @notice Get the supply rate for an asset
     * @param asset The asset address
     * @return The supply rate (scaled by 1e27)
     */
    function supplyRate(address asset) external view returns (uint256);

    /**
     * @notice Get the borrow rate for an asset
     * @param asset The asset address
     * @return The borrow rate (scaled by 1e27)
     */
    function borrowRate(address asset) external view returns (uint256);

    /**
     * @notice Check if an asset is listed on Euler
     * @param asset The asset address
     * @return True if the asset is listed
     */
    function isListed(address asset) external view returns (bool);

    /**
     * @notice Get the underlying asset for an eToken
     * @param eToken The eToken address
     * @return The underlying asset address
     */
    function eTokenToUnderlying(address eToken) external view returns (address);

    /**
     * @notice Get the eToken for an underlying asset
     * @param underlying The underlying asset address
     * @return The eToken address
     */
    function underlyingToEToken(address underlying) external view returns (address);

    /**
     * @notice Get the dToken for an underlying asset
     * @param underlying The underlying asset address
     * @return The dToken address
     */
    function underlyingToDToken(address underlying) external view returns (address);
} 